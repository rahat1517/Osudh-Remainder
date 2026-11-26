from enum import StrEnum

from pydantic import BaseModel, Field


class Drug(BaseModel):
    id: int
    brand: str
    strength: str = ""
    generic: str
    form: str
    manufacturer: str | None = None
    source: str
    verified: bool = False


class Confidence(StrEnum):
    """How certain a value read from a prescription is."""

    HIGH = "high"  # filled in automatically
    MEDIUM = "medium"  # filled in, highlighted, and the user is asked to check it
    LOW = "low"  # left for the user to enter or choose


class DrugCandidate(BaseModel):
    drug: Drug
    score: float = Field(ge=0, le=100, description="0-100, higher is a closer match")
    strength_matched: bool | None = Field(
        default=None,
        description="Whether the queried strength matched; null if no strength was given",
    )


class MatchResult(BaseModel):
    query: str
    confidence: Confidence
    best: DrugCandidate | None
    candidates: list[DrugCandidate]


class MatchRequest(BaseModel):
    text: str = Field(min_length=1, max_length=200, examples=["Tab. Sec1o 20mg"])
    limit: int = Field(default=5, ge=1, le=20)
