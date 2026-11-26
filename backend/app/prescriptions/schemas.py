"""প্রেসক্রিপশন পড়ার data model।

দুই স্তর:
1. `Extraction*`: AI (Agent ১) যা ফেরত দেয়। Claude-এর structured output এই আকারেই উত্তর দিতে বাধ্য।
2. `Prescription*Result`: যাচাইয়ের (Agent ২) পর অ্যাপ যা পায়: প্রতিটা ঘরের মান + চূড়ান্ত confidence।

⚠️ গোপনীয়তা: রোগীর নাম, বয়স, ফোন, ঠিকানার জন্য কোনো ঘর রাখা হয়নি, তাই AI চাইলেও এগুলো ফেরত দিতে পারবে না।
"""

from enum import StrEnum

from pydantic import BaseModel, Field

from app.drugs.models import Confidence, DrugCandidate


class Timing(StrEnum):
    BEFORE_MEAL = "before_meal"  # খাবারের আগে, AC
    AFTER_MEAL = "after_meal"  # খাবারের পরে, ভরা পেটে, PC
    WITH_MEAL = "with_meal"  # খাবারের সাথে
    EMPTY_STOMACH = "empty_stomach"  # খালি পেটে
    BEDTIME = "bedtime"  # ঘুমানোর আগে, HS
    NOT_SPECIFIED = "not_specified"  # প্রেসক্রিপশনে লেখা নেই


class ImageQuality(StrEnum):
    GOOD = "good"
    READABLE_WITH_EFFORT = "readable_with_effort"
    POOR = "poor"


# ---------------------------------------------------------------------------
# Agent ১-এর output (Claude structured output)
# ---------------------------------------------------------------------------
class ExtractedMedicine(BaseModel):
    raw_text: str = Field(description="The medicine line exactly as written, for the user to compare")
    form: str | None = Field(description="Tab, Cap, Syp, Inj, Drop, Cream... as written; null if absent")
    name: str | None = Field(description="Brand or generic name as written; null if unreadable")
    name_confidence: Confidence
    strength: str | None = Field(description='e.g. "20 mg", "500 mg", "120 mg/5 ml"; null if absent')
    strength_confidence: Confidence
    dose_raw: str | None = Field(description="Dose instruction exactly as written, e.g. ১+০+১, BD, 1 tsf TDS")
    dose_pattern: str | None = Field(
        description='Canonical "morning+noon+night" counts with ASCII digits, e.g. "1+0+1", '
        '"0.5+0+0.5", "1+1+1+1" for four times; null if not determinable'
    )
    dose_confidence: Confidence
    timing: Timing
    timing_confidence: Confidence
    duration_raw: str | None = Field(description="Duration as written, e.g. ৭ দিন, 1 month, চলবে")
    duration_days: int | None = Field(description="Duration in days; null if absent or continuing")
    continue_indefinitely: bool = Field(description="True for চলবে / continue / cont.")
    duration_confidence: Confidence
    as_needed: bool = Field(description="True for SOS / PRN / প্রয়োজনে (no fixed schedule)")
    other_instructions: str | None = Field(
        description="Any other instruction for this medicine (e.g. ব্যথা হলে, পানিতে গুলে); null if none"
    )


class PrescriptionExtraction(BaseModel):
    is_prescription: bool = Field(description="False if the image is not a medical prescription")
    image_quality: ImageQuality
    medicines: list[ExtractedMedicine]


# ---------------------------------------------------------------------------
# যাচাইয়ের পর অ্যাপের জন্য ফলাফল
# ---------------------------------------------------------------------------
class FieldResult[T](BaseModel):
    value: T | None
    confidence: Confidence
    note: str | None = Field(default=None, description="ব্যবহারকারীকে দেখানোর জন্য ছোট ব্যাখ্যা (বাংলা)")


class DurationValue(BaseModel):
    days: int | None
    continue_indefinitely: bool


class MedicineResult(BaseModel):
    raw_text: str
    name: FieldResult[str]
    matched_drug: DrugCandidate | None = Field(description="ওষুধের তালিকায় সবচেয়ে কাছের মিল")
    alternatives: list[DrugCandidate] = Field(description="নিশ্চিত না হলে ব্যবহারকারীকে দেখানোর বিকল্প")
    strength: FieldResult[str]
    dose: FieldResult[str]
    timing: FieldResult[Timing]
    duration: FieldResult[DurationValue]
    as_needed: bool
    other_instructions: str | None


class PrescriptionResult(BaseModel):
    image_quality: ImageQuality
    medicines: list[MedicineResult]
    # নীতি: AI যতই নিশ্চিত হোক, ব্যবহারকারী confirm না করা পর্যন্ত কোনো schedule চালু হবে না
    requires_confirmation: bool = True
    warnings: list[str] = Field(default_factory=list)
