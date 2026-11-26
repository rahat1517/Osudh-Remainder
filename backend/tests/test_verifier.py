import pytest

from app.prescriptions.schemas import ImageQuality, Timing
from app.prescriptions.verifier import PrescriptionVerifier

from .prescription_factories import H, L, M, extraction, medicine


@pytest.fixture
def verifier(matcher):
    return PrescriptionVerifier(matcher)


def verify_one(verifier, **overrides):
    return verifier.verify(extraction(medicine(**overrides))).medicines[0]


def test_clear_prescription_is_high_everywhere(verifier):
    m = verify_one(verifier)
    assert (m.name.value, m.name.confidence) == ("Seclo", H)
    assert (m.strength.value, m.strength.confidence) == ("20 mg", H)
    assert (m.dose.value, m.dose.confidence) == ("1+0+1", H)
    assert m.timing.value == Timing.BEFORE_MEAL
    assert m.duration.value.days == 30
    assert m.matched_drug.drug.brand == "Seclo"
    assert m.alternatives == []


def test_result_always_requires_confirmation(verifier):
    assert verifier.verify(extraction(medicine())).requires_confirmation is True


def test_verification_never_raises_ai_confidence(verifier):
    m = verify_one(verifier, name_confidence=M, dose_confidence=L, timing_confidence=M)
    assert m.name.confidence == M
    assert m.dose.confidence == L
    assert m.timing.confidence == M


def test_typo_is_corrected_but_not_high(verifier):
    m = verify_one(verifier, name="Sargel", strength="20 mg")
    assert m.name.value == "Sergel"
    assert m.name.confidence == M
    assert "Sargel" in m.name.note
    assert m.alternatives  # বিকল্প দেখানো হবে


def test_unknown_drug_keeps_ai_reading_without_high(verifier):
    m = verify_one(verifier, name="Zxqvrol")
    assert m.name.value == "Zxqvrol"
    assert m.name.confidence != H
    assert m.matched_drug is None


def test_strength_not_in_catalog_is_low(verifier):
    m = verify_one(verifier, strength="60 mg")
    assert m.strength.value == "60 mg"
    assert m.strength.confidence == L


def test_missing_strength_is_suggested_from_catalog_as_medium(verifier):
    m = verify_one(verifier, name="Alatrol", strength=None)
    assert m.strength.value == "10 mg"
    assert m.strength.confidence == M


def test_unreadable_name(verifier):
    m = verify_one(verifier, name=None, name_confidence=L)
    assert m.name.value is None
    assert m.name.confidence == L


def test_invalid_dose_pattern_is_low_even_if_ai_is_sure(verifier):
    m = verify_one(verifier, dose_pattern="10+0+10", dose_confidence=H)
    assert m.dose.value is None
    assert m.dose.confidence == L


def test_as_needed_without_pattern_is_fine(verifier):
    m = verify_one(verifier, as_needed=True, dose_pattern=None, dose_raw="SOS")
    assert m.as_needed is True
    assert m.dose.confidence == H


def test_poor_image_caps_everything_below_high(verifier):
    result = verifier.verify(extraction(medicine(), quality=ImageQuality.POOR))
    m = result.medicines[0]
    for field in (m.name, m.strength, m.dose, m.timing, m.duration):
        assert field.confidence != H
    assert result.warnings


def test_continue_and_days_together_is_low(verifier):
    m = verify_one(verifier, continue_indefinitely=True, duration_days=30)
    assert m.duration.confidence == L


def test_absurd_duration_is_dropped(verifier):
    m = verify_one(verifier, duration_days=3000)
    assert m.duration.value.days is None
    assert m.duration.confidence == L


def test_missing_duration_is_not_high(verifier):
    m = verify_one(verifier, duration_days=None, duration_raw=None)
    assert m.duration.confidence == M


def test_continue_indefinitely(verifier):
    m = verify_one(verifier, duration_days=None, continue_indefinitely=True, duration_raw="চলবে")
    assert m.duration.value.continue_indefinitely is True
    assert m.duration.confidence == H


def test_empty_prescription_warns(verifier):
    result = verifier.verify(extraction())
    assert result.medicines == []
    assert result.warnings
