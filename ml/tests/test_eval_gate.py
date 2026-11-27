import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "eval_gate", Path(__file__).parents[1] / "paddleocr" / "cpu" / "eval_gate.py"
)
eval_gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(eval_gate)

REPORT = """# Prescription reader eval

## clean

| Field | Accuracy | Correct among HIGH | Wrong but HIGH |
|---|---|---|---|
| name | {name}/30 (97%) | 24/24 (100%) | 0 |
| dose | 25/29 (86%) | 17/17 (100%) | {wrong} |

## photo

| Field | Accuracy | Correct among HIGH | Wrong but HIGH |
|---|---|---|---|
| name | 29/30 (97%) | 22/22 (100%) | 0 |
"""


def report(name=29, wrong=0):
    return REPORT.format(name=name, wrong=wrong)


def test_parses_every_variant_and_field():
    scores, wrong = eval_gate.parse(report())
    assert scores == {("clean", "name"): 29, ("clean", "dose"): 25, ("photo", "name"): 29}
    assert wrong == 0


def test_equal_or_better_passes():
    assert eval_gate.gate(report(), report()) == []
    assert eval_gate.gate(report(), report(name=30)) == []


def test_any_drop_or_wrong_but_high_rejects():
    assert eval_gate.gate(report(), report(name=28)) == ["clean name: 28 correct, was 29"]
    assert eval_gate.gate(report(), report(wrong=1)) == ["1 field(s) wrong but marked high"]
    assert eval_gate.gate(report(), "nothing") == ["the candidate's report has no results"]


def test_real_reports_parse():
    reports = Path(__file__).parents[2] / "backend" / "eval" / "reports"
    scores, wrong = eval_gate.parse((reports / "ocr-bangla-v1-2026-11-27.md").read_text())
    assert len(scores) == 10 and wrong == 0
    assert (
        eval_gate.gate(
            (reports / "ocr-baseline-2026-11-26.md").read_text(),
            (reports / "ocr-bangla-v1-2026-11-27.md").read_text(),
        )
        == []
    )
