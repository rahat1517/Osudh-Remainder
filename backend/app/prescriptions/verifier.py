"""Agent 2, the verifier: checks the AI's reading with rules and sets the final confidence.

No AI is involved here, only fixed rules, so the behaviour is fully covered by tests.

Core rule: the final confidence of a field is never higher than the confidence the AI gave it.
Verification can only lower confidence, never raise it.
"""

from app.drugs.matcher import DrugMatcher
from app.drugs.models import Confidence, DrugCandidate
from app.drugs.normalize import strength_numbers
from app.prescriptions.dose import normalize_dose_pattern
from app.prescriptions.schemas import (
    DurationValue,
    ExtractedMedicine,
    FieldResult,
    ImageQuality,
    MedicineResult,
    Notice,
    PrescriptionExtraction,
    PrescriptionResult,
    Timing,
)

_ORDER = {Confidence.LOW: 0, Confidence.MEDIUM: 1, Confidence.HIGH: 2}


def lowest(*levels: Confidence) -> Confidence:
    return min(levels, key=_ORDER.__getitem__)


def notice(code: str, message: str, **params: object) -> Notice:
    return Notice(code=code, message=message, params={k: str(v) for k, v in params.items()})


class PrescriptionVerifier:
    def __init__(self, matcher: DrugMatcher):
        self._matcher = matcher

    def verify(self, extraction: PrescriptionExtraction) -> PrescriptionResult:
        warnings: list[Notice] = []
        poor = extraction.image_quality == ImageQuality.POOR
        # On a poor image, no field may be "high"
        cap = Confidence.MEDIUM if poor else Confidence.HIGH
        if poor:
            warnings.append(
                notice("image_poor_quality", "The photo is unclear; check every field or retake it")
            )

        medicines = [self._verify_medicine(m, cap) for m in extraction.medicines]
        if not medicines:
            warnings.append(notice("no_medicines_found", "No medicines were found"))
        if any(m.name.confidence != Confidence.HIGH for m in medicines):
            warnings.append(
                notice("review_highlighted_fields", "Compare the highlighted fields with the paper")
            )
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

    def _verify_name_and_strength(
        self, m: ExtractedMedicine, cap: Confidence
    ) -> tuple[FieldResult[str], DrugCandidate | None, list[DrugCandidate], FieldResult[str]]:
        if not m.name:
            return (
                FieldResult[str](
                    value=None,
                    confidence=Confidence.LOW,
                    note=notice("name_unreadable", "The medicine name could not be read"),
                ),
                None,
                [],
                FieldResult[str](value=m.strength, confidence=Confidence.LOW),
            )

        match = self._matcher.match(f"{m.name} {m.strength or ''}".strip(), limit=5)
        best = match.best

        if best is None or match.confidence == Confidence.LOW:
            # Not in the catalogue: show what the AI read, but never as certain
            name = FieldResult[str](
                value=m.name,
                confidence=lowest(m.name_confidence, Confidence.MEDIUM, cap),
                note=notice("name_not_in_catalog", "This name is not in the drug catalogue"),
            )
            strength = FieldResult[str](
                value=m.strength, confidence=lowest(m.strength_confidence, Confidence.MEDIUM, cap)
            )
            return name, None, match.candidates, strength

        name_conf = lowest(m.name_confidence, match.confidence, cap)
        note = None
        if best.drug.brand.lower() != m.name.strip().lower():
            note = notice(
                "name_corrected",
                f"Written as {m.name!r} on the prescription",
                written=m.name,
                matched=best.drug.brand,
            )
        name = FieldResult[str](value=best.drug.brand, confidence=name_conf, note=note)
        alternatives = (
            [c for c in match.candidates if c is not best] if name_conf != Confidence.HIGH else []
        )
        strength = self._verify_strength(m, best.drug.strength, best.strength_matched, cap)
        return name, best, alternatives, strength

    @staticmethod
    def _verify_strength(
        m: ExtractedMedicine,
        catalog_strength: str,
        strength_matched: bool | None,
        cap: Confidence,
    ) -> FieldResult[str]:
        if m.strength:
            if strength_matched:
                return FieldResult[str](
                    value=catalog_strength, confidence=lowest(m.strength_confidence, cap)
                )
            return FieldResult[str](
                value=m.strength,
                confidence=Confidence.LOW,
                note=notice(
                    "strength_not_in_catalog",
                    "No product with this strength is in the catalogue",
                    written=m.strength,
                ),
            )
        # No strength written: suggest the catalogue's, but the user must check it
        if catalog_strength and strength_numbers(catalog_strength):
            return FieldResult[str](
                value=catalog_strength,
                confidence=Confidence.MEDIUM if cap == Confidence.HIGH else Confidence.LOW,
                note=notice(
                    "strength_suggested",
                    "No strength on the prescription; suggested from the catalogue",
                    suggested=catalog_strength,
                ),
            )
        return FieldResult[str](value=None, confidence=Confidence.LOW)

    @staticmethod
    def _verify_dose(m: ExtractedMedicine, cap: Confidence) -> FieldResult[str]:
        pattern = normalize_dose_pattern(m.dose_pattern)
        if pattern is None:
            if m.as_needed:
                # As-needed medicines normally have no fixed pattern
                return FieldResult[str](
                    value=None,
                    confidence=lowest(m.dose_confidence, cap),
                    note=notice("dose_as_needed", "Take when needed"),
                )
            if m.dose_raw:
                note = notice(
                    "dose_unreadable", f"Could not interpret {m.dose_raw!r}", written=m.dose_raw
                )
            else:
                note = notice("dose_missing", "No dose is written")
            return FieldResult[str](value=None, confidence=Confidence.LOW, note=note)
        return FieldResult[str](value=pattern, confidence=lowest(m.dose_confidence, cap))

    @staticmethod
    def _verify_timing(m: ExtractedMedicine, cap: Confidence) -> FieldResult[Timing]:
        note = None
        if m.timing == Timing.NOT_SPECIFIED:
            note = notice("timing_not_specified", "Before or after food is not written")
        return FieldResult[Timing](
            value=m.timing, confidence=lowest(m.timing_confidence, cap), note=note
        )

    @staticmethod
    def _verify_duration(m: ExtractedMedicine, cap: Confidence) -> FieldResult[DurationValue]:
        conf = lowest(m.duration_confidence, cap)
        days = m.duration_days
        note = None
        if m.continue_indefinitely and days is not None:
            # Both cannot be true; the AI was unsure
            conf = Confidence.LOW
            note = notice("duration_unclear", "The duration is unclear")
        elif days is not None and not 1 <= days <= 365:
            conf = Confidence.LOW
            note = notice("duration_out_of_range", f"Unusual duration ({days} days)", days=days)
            days = None
        elif days is None and not m.continue_indefinitely:
            conf = lowest(conf, Confidence.MEDIUM)
            note = notice("duration_missing", "How long to take it is not written")
        return FieldResult[DurationValue](
            value=DurationValue(days=days, continue_indefinitely=m.continue_indefinitely),
            confidence=conf,
            note=note,
        )
