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
    """প্রেসক্রিপশন থেকে পড়া নামের সাথে মিল কতটা নিশ্চিত।"""

    HIGH = "high"  # নিজে থেকে পূরণ হবে ✅
    MEDIUM = "medium"  # পূরণ হবে, কিন্তু হলুদ চিহ্ন দিয়ে "এটা কি ঠিক?" জিজ্ঞেস করবে
    LOW = "low"  # খালি থাকবে, ব্যবহারকারী বেছে নেবেন


class DrugCandidate(BaseModel):
    drug: Drug
    score: float = Field(ge=0, le=100, description="০–১০০, বেশি মানে বেশি মিল")
    strength_matched: bool | None = Field(
        default=None, description="প্রশ্নে শক্তি থাকলে মিলেছে কিনা; শক্তি না থাকলে null"
    )


class MatchResult(BaseModel):
    query: str
    confidence: Confidence
    best: DrugCandidate | None
    candidates: list[DrugCandidate]


class MatchRequest(BaseModel):
    text: str = Field(min_length=1, max_length=200, examples=["Tab. Sec1o 20mg"])
    limit: int = Field(default=5, ge=1, le=20)
