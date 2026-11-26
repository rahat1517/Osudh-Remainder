"""Tests the eval scoring itself: a perfect reader must score 100% and mistakes must be caught."""

from app.drugs.models import Confidence
from app.prescriptions.schemas import Timing
from app.prescriptions.verifier import PrescriptionVerifier
from eval.generate import load_cases
from eval.run_eval import FIELDS, Tally, score

from .prescription_factories import extraction, medicine


def perfect_medicine(exp: dict):
    return medicine(
        raw_text=exp["brand"],
        name=exp["brand"],
        strength=exp.get("strength"),
        dose_pattern=exp.get("dose"),
        timing=Timing(exp.get("timing", "not_specified")),
        duration_days=exp.get("days"),
        continue_indefinitely=exp.get("continue", False),
        as_needed=exp.get("as_needed", False),
    )


def test_perfect_reader_scores_100_percent(matcher):
    verifier = PrescriptionVerifier(matcher)
    tallies = {f: Tally() for f in FIELDS}
    log: list[str] = []
    for case in load_cases():
        result = verifier.verify(extraction(*[perfect_medicine(e) for e in case["expected"]]))
        score(result, case["expected"], tallies, log, case["id"])
    assert not [line for line in log if "MISSING" in line or "WRONG" in line], log
    for f, t in tallies.items():
        assert t.total > 0, f
        assert t.correct == t.total, f


def test_wrong_but_high_is_reported(matcher):
    verifier = PrescriptionVerifier(matcher)
    exp = {
        "brand": "Seclo",
        "strength": "20 mg",
        "dose": "1+0+1",
        "timing": "before_meal",
        "days": 30,
    }
    wrong = medicine(dose_pattern="1+1+1")  # the AI is confident but wrong
    tallies = {f: Tally() for f in FIELDS}
    log: list[str] = []
    score(verifier.verify(extraction(wrong)), [exp], tallies, log, "t")
    assert tallies["dose"].correct == 0
    assert tallies["dose"].by_conf[Confidence.HIGH] == [1, 0]
    assert any("WRONG BUT HIGH" in line for line in log)
