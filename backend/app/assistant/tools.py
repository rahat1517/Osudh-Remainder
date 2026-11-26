"""Tools the assistant may call. Read-only tools answer from the user's data; `propose_*` tools only
record a suggestion that the app must show for confirmation."""

import json
from datetime import timedelta

from app.assistant.models import ActionType, AssistantContext, ProposedAction
from app.drugs.matcher import DrugMatcher
from app.schedule.engine import ScheduleError, group_reminders, occurrences_for

TOOLS = [
    {
        "name": "get_schedule",
        "description": "List the user's medicine reminders for today or tomorrow, "
        "with times and amounts.",
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {"day": {"type": "string", "enum": ["today", "tomorrow"]}},
            "required": ["day"],
            "additionalProperties": False,
        },
    },
    {
        "name": "list_medicines",
        "description": "List the user's current medicines with dose pattern, timing "
        "and course length.",
        "strict": True,
        "input_schema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "lookup_drug",
        "description": "Look up a medicine name in the Bangladeshi drug catalogue: generic name, "
        "strength and form. Gives no medical advice.",
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {"name": {"type": "string"}},
            "required": ["name"],
            "additionalProperties": False,
        },
    },
    {
        "name": "propose_stop_medicine",
        "description": "Suggest stopping reminders for one of the user's medicines. Use ONLY "
        "when the user says their doctor told them to stop it. The app asks the user to confirm.",
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {"medicine_id": {"type": "string"}},
            "required": ["medicine_id"],
            "additionalProperties": False,
        },
    },
    {
        "name": "propose_change_meal_time",
        "description": "Suggest changing a usual meal or bed time, which moves reminders "
        "tied to it. The app asks the user to confirm.",
        "strict": True,
        "input_schema": {
            "type": "object",
            "properties": {
                "meal": {
                    "type": "string",
                    "enum": ["breakfast", "lunch", "evening", "dinner", "bedtime"],
                },
                "time": {"type": "string", "description": "24-hour HH:MM"},
            },
            "required": ["meal", "time"],
            "additionalProperties": False,
        },
    },
]


class ToolExecutor:
    def __init__(self, context: AssistantContext, matcher: DrugMatcher):
        self.context = context
        self.matcher = matcher
        self.actions: list[ProposedAction] = []

    def run(self, name: str, args: dict) -> tuple[str, bool]:
        """Returns (result JSON, is_error)."""
        try:
            handler = getattr(self, f"_{name}")
        except AttributeError:
            return json.dumps({"error": f"unknown tool {name}"}), True
        try:
            return json.dumps(handler(**args), ensure_ascii=False), False
        except (ScheduleError, ValueError, TypeError) as e:
            return json.dumps({"error": str(e)}), True

    def _get_schedule(self, day: str) -> dict:
        ctx = self.context
        local_now = ctx.now.astimezone(_tz(ctx))
        day_start = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
        if day == "tomorrow":
            day_start += timedelta(days=1)
        meds = [
            m if m.start else m.model_copy(update={"start": ctx.now})
            for m in ctx.medicines
            if not m.as_needed
        ]
        occurrences = occurrences_for(meds, ctx.settings, day_start, day_start + timedelta(days=1))
        labels = {m.id: m.label for m in ctx.medicines}
        reminders = group_reminders(occurrences, ctx.settings.group_window_minutes)
        return {
            "day": day,
            "now": local_now.strftime("%H:%M"),
            "reminders": [
                {
                    "time": r.at.strftime("%H:%M"),
                    "past": r.at < local_now,
                    "medicines": [f"{labels[i.medicine_id]} × {i.amount}" for i in r.items],
                }
                for r in reminders
            ],
            "as_needed": [m.label for m in ctx.medicines if m.as_needed],
        }

    def _list_medicines(self) -> dict:
        return {
            "medicines": [
                {
                    "id": m.id,
                    "name": m.label,
                    "dose_pattern": m.dose_pattern,
                    "timing": m.timing.value,
                    "duration_days": m.duration_days,
                    "as_needed": m.as_needed,
                }
                for m in self.context.medicines
            ]
        }

    def _lookup_drug(self, name: str) -> dict:
        result = self.matcher.match(name, limit=3)
        return {
            "confidence": result.confidence.value,
            "matches": [
                {
                    "brand": c.drug.brand,
                    "generic": c.drug.generic,
                    "strength": c.drug.strength,
                    "form": c.drug.form,
                }
                for c in result.candidates
            ],
        }

    def _propose_stop_medicine(self, medicine_id: str) -> dict:
        if medicine_id not in {m.id for m in self.context.medicines}:
            raise ValueError("unknown medicine_id; call list_medicines first")
        self.actions.append(ProposedAction(type=ActionType.STOP_MEDICINE, medicine_id=medicine_id))
        return {"status": "proposed", "note": "The user will be asked to confirm in the app."}

    def _propose_change_meal_time(self, meal: str, time: str) -> dict:
        action = ProposedAction(type=ActionType.CHANGE_MEAL_TIME, meal=meal, time=time)
        self.actions.append(action)
        return {"status": "proposed", "note": "The user will be asked to confirm in the app."}


def _tz(ctx: AssistantContext):
    from zoneinfo import ZoneInfo

    return ZoneInfo(ctx.settings.timezone)
