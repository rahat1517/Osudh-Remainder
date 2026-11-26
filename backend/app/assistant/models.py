from datetime import datetime
from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, Field

from app.schedule.models import MedicineInput, ScheduleSettings


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    text: str = Field(min_length=1, max_length=2000)


class ContextMedicine(MedicineInput):
    label: str = Field(max_length=120, description='Display name, e.g. "Seclo 20 mg"')


class AssistantContext(BaseModel):
    """The user's own data, sent by the app so answers match what the phone shows."""

    locale: Literal["bn", "en"] = "bn"
    now: datetime = Field(description="Current time with offset")
    settings: ScheduleSettings = Field(default_factory=ScheduleSettings)
    medicines: list[ContextMedicine] = Field(default_factory=list, max_length=50)
    patient_name: str | None = Field(default=None, max_length=100)


class ChatRequest(BaseModel):
    messages: list[ChatMessage] = Field(min_length=1, max_length=20)
    context: AssistantContext


class ActionType(StrEnum):
    STOP_MEDICINE = "stop_medicine"
    CHANGE_MEAL_TIME = "change_meal_time"


class ProposedAction(BaseModel):
    """A change the assistant suggests. The app shows it for confirmation; nothing changes until the
    user taps Confirm."""

    type: ActionType
    medicine_id: str | None = None
    meal: Literal["breakfast", "lunch", "evening", "dinner", "bedtime"] | None = None
    time: str | None = Field(default=None, pattern=r"^\d{2}:\d{2}$")


class ChatResponse(BaseModel):
    reply: str
    actions: list[ProposedAction] = Field(default_factory=list)
    emergency: str | None = Field(default=None, description="Emergency kind when detected by rules")
