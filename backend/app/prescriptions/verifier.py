"""Agent ২: যাচাইকারী। AI-এর পড়া তথ্য নিয়ম দিয়ে যাচাই করে চূড়ান্ত confidence ঠিক করে।

এখানে কোনো AI নেই, শুধু নির্দিষ্ট নিয়ম, যাতে আচরণ test দিয়ে পুরোপুরি যাচাই করা যায়।

মূল নিয়ম: চূড়ান্ত confidence কখনো AI-এর নিজের দেওয়া confidence-এর চেয়ে বেশি হয় না।
যাচাই শুধু confidence কমাতে পারে, বাড়াতে পারে না।
"""

from app.drugs.matcher import DrugMatcher
from app.drugs.models import Confidence
from app.drugs.normalize import strength_numbers
from app.prescriptions.dose import normalize_dose_pattern
from app.prescriptions.schemas import (
    DurationValue,
    ExtractedMedicine,
    FieldResult,
    ImageQuality,
    MedicineResult,
    PrescriptionExtraction,
    PrescriptionResult,
    Timing,
)

_ORDER = {Confidence.LOW: 0, Confidence.MEDIUM: 1, Confidence.HIGH: 2}


def lowest(*levels: Confidence) -> Confidence:
    return min(levels, key=_ORDER.__getitem__)


class PrescriptionVerifier:
    def __init__(self, matcher: DrugMatcher):
        self._matcher = matcher

    def verify(self, extraction: PrescriptionExtraction) -> PrescriptionResult:
        warnings: list[str] = []
        # ছবি খারাপ হলে কোনো ঘরই "নিশ্চিত" ধরা হবে না
        cap = (
            Confidence.MEDIUM if extraction.image_quality == ImageQuality.POOR else Confidence.HIGH
        )
        if extraction.image_quality == ImageQuality.POOR:
            warnings.append("ছবিটা অস্পষ্ট। সব তথ্য ভালো করে মিলিয়ে দেখুন, অথবা আবার ছবি তুলুন।")

        medicines = [self._verify_medicine(m, cap) for m in extraction.medicines]
        if not medicines:
            warnings.append("কোনো ওষুধ পাওয়া যায়নি। নিজে যোগ করুন অথবা আবার ছবি তুলুন।")
        if any(m.name.confidence != Confidence.HIGH for m in medicines):
            warnings.append("হলুদ চিহ্নিত ঘরগুলো প্রেসক্রিপশনের সাথে মিলিয়ে দেখুন।")
        return PrescriptionResult(
            image_quality=extraction.image_quality, medicines=medicines, warnings=warnings
        )

    # ------------------------------------------------------------------
    def _verify_medicine(self, m: ExtractedMedicine, cap: Confidence) -> MedicineResult:
        name, matched, alternatives, strength = self._verify_name_and_strength(m, cap)
        return MedicineResult(
            raw_text=m.raw_text,
            name=name,
            matched_drug=matched,
            alternatives=alternatives,
            strength=strength,
            dose=self._verify_dose(m, cap),
            timing=self._verify_timing(m, cap),
            duration=self._verify_duration(m, cap),
            as_needed=m.as_needed,
            other_instructions=m.other_instructions,
        )

    def _verify_name_and_strength(self, m: ExtractedMedicine, cap: Confidence):
        if not m.name:
            return (
                FieldResult[str](value=None, confidence=Confidence.LOW, note="নাম পড়া যায়নি"),
                None,
                [],
                FieldResult[str](value=m.strength, confidence=Confidence.LOW),
            )

        query = f"{m.name} {m.strength or ''}".strip()
        match = self._matcher.match(query, limit=5)
        best = match.best

        if best is None or match.confidence == Confidence.LOW:
            # তালিকায় নেই: AI যা পড়েছে সেটাই দেখানো হবে, কিন্তু নিশ্চিত বলা যাবে না
            name = FieldResult[str](
                value=m.name,
                confidence=lowest(m.name_confidence, Confidence.MEDIUM, cap),
                note="ওষুধের তালিকায় এই নাম পাওয়া যায়নি",
            )
            strength = FieldResult[str](
                value=m.strength, confidence=lowest(m.strength_confidence, Confidence.MEDIUM, cap)
            )
            return name, None, match.candidates, strength

        name_conf = lowest(m.name_confidence, match.confidence, cap)
        note = None
        if best.drug.brand.lower() != m.name.strip().lower():
            note = f'প্রেসক্রিপশনে লেখা "{m.name}"'
        name = FieldResult[str](value=best.drug.brand, confidence=name_conf, note=note)
        alternatives = (
            [c for c in match.candidates if c is not best] if name_conf != Confidence.HIGH else []
        )

        strength = self._verify_strength(m, best.drug.strength, best.strength_matched, cap)
        return name, best, alternatives, strength

    def _verify_strength(self, m, catalog_strength: str, strength_matched: bool | None, cap):
        if m.strength:
            if strength_matched:
                return FieldResult[str](
                    value=catalog_strength, confidence=lowest(m.strength_confidence, cap)
                )
            return FieldResult[str](
                value=m.strength,
                confidence=lowest(m.strength_confidence, Confidence.LOW, cap),
                note="এই শক্তির ওষুধ তালিকায় নেই",
            )
        # প্রেসক্রিপশনে শক্তি লেখা নেই: তালিকা থেকে প্রস্তাব, কিন্তু ব্যবহারকারীকে মিলিয়ে দেখতে হবে
        if catalog_strength and strength_numbers(catalog_strength):
            return FieldResult[str](
                value=catalog_strength,
                confidence=Confidence.MEDIUM if cap == Confidence.HIGH else Confidence.LOW,
                note="প্রেসক্রিপশনে শক্তি লেখা নেই; তালিকা থেকে প্রস্তাব",
            )
        return FieldResult[str](value=None, confidence=Confidence.LOW)

    def _verify_dose(self, m: ExtractedMedicine, cap: Confidence) -> FieldResult[str]:
        pattern = normalize_dose_pattern(m.dose_pattern)
        if pattern is None:
            if m.as_needed:
                # প্রয়োজনে খাওয়ার ওষুধে নির্দিষ্ট pattern না থাকাই স্বাভাবিক
                return FieldResult[str](
                    value=None, confidence=lowest(m.dose_confidence, cap), note="প্রয়োজন হলে"
                )
            return FieldResult[str](
                value=None,
                confidence=Confidence.LOW,
                note=f'ডোজ বোঝা যায়নি: "{m.dose_raw}"' if m.dose_raw else "ডোজ লেখা নেই",
            )
        return FieldResult[str](value=pattern, confidence=lowest(m.dose_confidence, cap))

    @staticmethod
    def _verify_timing(m: ExtractedMedicine, cap: Confidence) -> FieldResult[Timing]:
        conf = lowest(m.timing_confidence, cap)
        note = None
        if m.timing == Timing.NOT_SPECIFIED:
            note = "খাবারের আগে না পরে, প্রেসক্রিপশনে লেখা নেই"
        return FieldResult[Timing](value=m.timing, confidence=conf, note=note)

    @staticmethod
    def _verify_duration(m: ExtractedMedicine, cap: Confidence) -> FieldResult[DurationValue]:
        conf = lowest(m.duration_confidence, cap)
        days = m.duration_days
        note = None
        if m.continue_indefinitely and days is not None:
            # দুটো একসাথে হতে পারে না: AI দ্বিধায় ছিল
            conf, note = Confidence.LOW, "মেয়াদ পরিষ্কার নয়"
        elif days is not None and not 1 <= days <= 365:
            conf, note, days = Confidence.LOW, f"মেয়াদ অস্বাভাবিক ({days} দিন)", None
        elif days is None and not m.continue_indefinitely:
            note = "কতদিন খেতে হবে লেখা নেই"
            conf = lowest(conf, Confidence.MEDIUM)
        return FieldResult[DurationValue](
            value=DurationValue(days=days, continue_indefinitely=m.continue_indefinitely),
            confidence=conf,
            note=note,
        )
