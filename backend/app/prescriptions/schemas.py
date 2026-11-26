"""Data models for prescription reading.

Two layers:
1. `Extraction*`: what the AI (Agent 1) returns. Claude's structured output is constrained to this
   schema.
2. `*Result`: what the app receives after verification (Agent 2): each field's value plus its final
   confidence and an optional notice.

Privacy: there are deliberately no fields for the patient's name, age, phone or address, so the AI
cannot return them even if it reads them.
"""

from enum import StrEnum

from pydantic import BaseModel, Field

from app.drugs.models import Confidence, DrugCandidate


class Timing(StrEnum):
    BEFORE_MEAL = "before_meal"  # Bangla "khabarer age", Latin AC
    AFTER_MEAL = "after_meal"  # "khabarer pore", "bhora pete", PC
    WITH_MEAL = "with_meal"  # "khabarer shathe"
    EMPTY_STOMACH = "empty_stomach"  # "khali pete"
    BEDTIME = "bedtime"  # "ghumanor age", HS
    NOT_SPECIFIED = "not_specified"  # nothing written on the prescription


class ImageQuality(StrEnum):
    GOOD = "good"
    READABLE_WITH_EFFORT = "readable_with_effort"
    POOR = "poor"


# ---------------------------------------------------------------------------
# Agent 1 output (Claude structured output)
# ---------------------------------------------------------------------------
class ExtractedMedicine(BaseModel):
    raw_text: str = Field(
        description="The medicine line exactly as written, for the user to compare"
    )
    form: str | None = Field(
        description="Tab, Cap, Syp, Inj, Drop, Cream... as written; null if absent"
    )
    name: str | None = Field(description="Brand or generic name as written; null if unreadable")
    name_confidence: Confidence
    strength: str | None = Field(
        description='e.g. "20 mg", "500 mg", "120 mg/5 ml"; null if absent'
    )
    strength_confidence: Confidence
    dose_raw: str | None = Field(
        description="Dose instruction exactly as written, e.g. ১+০+১, BD, 1 tsf TDS"
    )
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
        description="Any other instruction for this medicine "
        "(e.g. ব্যথা হলে, পানিতে গুলে); null if none"
    )


class PrescriptionExtraction(BaseModel):
    is_prescription: bool = Field(description="False if the image is not a medical prescription")
    image_quality: ImageQuality
    medicines: list[ExtractedMedicine]


# ---------------------------------------------------------------------------
# Verified result returned to the app
# ---------------------------------------------------------------------------
class Notice(BaseModel):
    """Something the user should know about a field or the whole prescription.

    The app localizes `code` (with `params`); `message` is an English fallback for logs and tools.
    """

    code: str
    message: str
    params: dict[str, str] = Field(default_factory=dict)


class FieldResult[T](BaseModel):
    value: T | None
    confidence: Confidence
    note: Notice | None = None


class DurationValue(BaseModel):
    days: int | None
    continue_indefinitely: bool


class MedicineResult(BaseModel):
    raw_text: str
    name: FieldResult[str]
    matched_drug: DrugCandidate | None = Field(description="Closest match in the drug catalogue")
    alternatives: list[DrugCandidate] = Field(
        description="Other candidates to offer the user when the match is not certain"
    )
    strength: FieldResult[str]
    dose: FieldResult[str]
    timing: FieldResult[Timing]
    duration: FieldResult[DurationValue]
    as_needed: bool
    other_instructions: str | None


class PrescriptionResult(BaseModel):
    image_quality: ImageQuality
    medicines: list[MedicineResult]
    # Policy: however confident the AI is, nothing is scheduled until the user confirms.
    requires_confirmation: bool = True
    warnings: list[Notice] = Field(default_factory=list)
