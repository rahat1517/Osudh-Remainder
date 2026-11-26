import json
from pathlib import Path
from types import SimpleNamespace

import anthropic
import httpx2
import pytest
from fastapi.testclient import TestClient

from app.assistant.models import ActionType, AssistantContext, ChatMessage, ChatRequest
from app.assistant.safety import Emergency, detect_emergency, emergency_response
from app.assistant.service import AssistantService
from app.assistant.tools import TOOLS, ToolExecutor
from app.main import app

CASES = json.loads((Path(__file__).parents[1] / "eval" / "assistant_cases.json").read_text("utf-8"))
CONTEXT = AssistantContext.model_validate(CASES["context"])


# --- Emergency rules (offline part of the eval) ----------------------------------------------


@pytest.mark.parametrize(
    "case", [c for c in CASES["cases"] if c["category"] == "emergency"], ids=lambda c: c["id"]
)
def test_every_emergency_case_is_caught_by_rules(case):
    assert detect_emergency(case["text"]) is not None, case["text"]


@pytest.mark.parametrize(
    "case", [c for c in CASES["cases"] if c["category"] != "emergency"], ids=lambda c: c["id"]
)
def test_ordinary_questions_are_not_flagged(case):
    assert detect_emergency(case["text"]) is None, case["text"]


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("I took my pills twice by mistake", "overdose"),
        ("আমার ছেলে ভুল করে দুটো ট্যাবলেট খেয়ে ফেলেছে", "overdose"),
        ("ডাবল ডোজ খেয়ে ফেলেছি", "overdose"),
        ("বিষ খেয়েছে", "overdose"),
        ("কীটনাশক খেয়ে ফেলেছে", "overdose"),
        ("My daughter ate two of my tablets", "overdose"),
        # Must NOT trigger
        ("বিষণ্ণ লাগছে", None),  # "depressed" contains বিষ (poison)
        ("এই বিষয়ে জানতে চাই", None),  # "topic" contains বিষ
        ("My son ate lunch, now what?", None),
        ("Can my daughter see my medicines?", None),
        ("Is the swelling in my ankle normal?", None),
        ("ব্যথার ওষুধ কখন খাব?", None),
    ],
)
def test_tricky_phrases(text, expected):
    kind = detect_emergency(text)
    assert (kind.value if kind else None) == expected


def test_emergency_responses_mention_999_in_both_languages():
    for kind in Emergency:
        assert "৯৯৯" in emergency_response(kind, "bn")
        assert "999" in emergency_response(kind, "en")


# --- Tools ------------------------------------------------------------------------------------


@pytest.fixture
def executor(matcher):
    return ToolExecutor(CONTEXT, matcher)


def test_tool_schemas_are_strict():
    for tool in TOOLS:
        assert tool["strict"] is True
        assert tool["input_schema"]["additionalProperties"] is False


def test_get_schedule_today(executor):
    out, err = executor.run("get_schedule", {"day": "today"})
    data = json.loads(out)
    assert not err
    assert data["now"] == "10:00"
    assert [(r["time"], r["past"]) for r in data["reminders"]] == [
        ("07:30", True),
        ("13:45", False),
        ("21:00", False),
        ("21:45", False),
    ]
    assert data["reminders"][1]["medicines"] == ["Napa 500 mg × 1"]
    assert data["as_needed"] == ["Napa Extend 665 mg"]


def test_get_schedule_tomorrow(executor):
    data = json.loads(executor.run("get_schedule", {"day": "tomorrow"})[0])
    assert [r["time"] for r in data["reminders"]] == ["07:30", "08:15", "13:45", "21:00", "21:45"]


def test_lookup_drug_gives_catalogue_facts_only(executor):
    data = json.loads(executor.run("lookup_drug", {"name": "Seclo"})[0])
    assert data["matches"][0]["generic"] == "Omeprazole"


def test_proposals_are_recorded_not_executed(executor):
    executor.run("propose_stop_medicine", {"medicine_id": "napa"})
    executor.run("propose_change_meal_time", {"meal": "dinner", "time": "22:00"})
    assert [(a.type, a.medicine_id, a.meal, a.time) for a in executor.actions] == [
        (ActionType.STOP_MEDICINE, "napa", None, None),
        (ActionType.CHANGE_MEAL_TIME, None, "dinner", "22:00"),
    ]


def test_unknown_medicine_and_tool_are_errors(executor):
    assert executor.run("propose_stop_medicine", {"medicine_id": "nope"})[1] is True
    assert executor.run("delete_everything", {})[1] is True
    assert executor.actions == []


# --- Conversation loop with a fake Claude ------------------------------------------------------


def text_block(text):
    return SimpleNamespace(type="text", text=text)


def tool_block(name, args, id_="t1"):
    return SimpleNamespace(type="tool_use", name=name, input=args, id=id_)


def reply(*blocks, stop="end_turn"):
    return SimpleNamespace(content=list(blocks), stop_reason=stop)


class FakeMessages:
    def __init__(self, *responses, error=None):
        self.responses, self.error, self.calls = list(responses), error, []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        if self.error:
            raise self.error
        return self.responses.pop(0)


def service(matcher, messages):
    client = SimpleNamespace(beta=SimpleNamespace(messages=messages))
    return AssistantService(client, matcher, "claude-opus-5-5", "low")


def ask(text):
    return ChatRequest(messages=[ChatMessage(role="user", text=text)], context=CONTEXT)


def test_tool_loop_answers_from_the_schedule(matcher):
    fake = FakeMessages(
        reply(tool_block("get_schedule", {"day": "today"}), stop="tool_use"),
        reply(text_block("পরের ওষুধ দুপুর ১:৪৫-এ, Napa 500 mg একটা।")),
    )
    out = service(matcher, fake).chat(ask("পরের ওষুধ কখন?"))
    assert out.reply == "পরের ওষুধ দুপুর ১:৪৫-এ, Napa 500 mg একটা।"
    assert out.actions == [] and out.emergency is None
    first, second = fake.calls
    assert first["model"] == "claude-opus-5-5"
    assert first["output_config"] == {"effort": "low"}
    assert first["fallbacks"] == "default"
    assert first["system"][0]["cache_control"] == {"type": "ephemeral"}
    tool_result = second["messages"][-1]["content"][0]
    assert tool_result["tool_use_id"] == "t1" and not tool_result["is_error"]
    assert "13:45" in tool_result["content"]


def test_proposed_actions_are_returned_for_confirmation(matcher):
    fake = FakeMessages(
        reply(tool_block("propose_stop_medicine", {"medicine_id": "napa"}), stop="tool_use"),
        reply(text_block("স্ক্রিনে নিশ্চিত করুন।")),
    )
    out = service(matcher, fake).chat(ask("ডাক্তার নাপা বন্ধ করতে বলেছেন"))
    assert [a.type for a in out.actions] == [ActionType.STOP_MEDICINE]


def test_emergency_skips_the_model(matcher):
    fake = FakeMessages()
    out = service(matcher, fake).chat(ask("আমার বুকে প্রচণ্ড ব্যথা"))
    assert out.emergency == "cardiac" and "৯৯৯" in out.reply
    assert fake.calls == []


def test_api_errors_and_refusals_give_a_polite_fallback(matcher):
    req = httpx2.Request("POST", "https://api.anthropic.com/v1/messages")
    err = anthropic.InternalServerError("x", response=httpx2.Response(500, request=req), body=None)
    assert "দুঃখিত" in service(matcher, FakeMessages(error=err)).chat(ask("hi")).reply
    refused = service(matcher, FakeMessages(reply(stop="refusal"))).chat(ask("hi"))
    assert "দুঃখিত" in refused.reply


def test_runaway_tool_loops_are_cut_off(matcher):
    loops = [reply(tool_block("list_medicines", {}), stop="tool_use") for _ in range(10)]
    out = service(matcher, FakeMessages(*loops)).chat(ask("medicines?"))
    assert "দুঃখিত" in out.reply


# --- API ---------------------------------------------------------------------------------------


def test_api_emergency_works_without_ai():
    with TestClient(app) as client:
        app.state.assistant_service = None
        r = client.post(
            "/assistant/chat",
            json={
                "messages": [{"role": "user", "text": "I can't breathe"}],
                "context": CASES["context"],
            },
        )
        assert r.status_code == 200
        assert r.json()["emergency"] == "breathing"
        r = client.post(
            "/assistant/chat",
            json={"messages": [{"role": "user", "text": "hello"}], "context": CASES["context"]},
        )
        assert r.json()["detail"]["code"] == "ai_not_configured"
