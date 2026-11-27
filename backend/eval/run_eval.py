"""Measures prescription-reader accuracy.

The cloud and hybrid readers call the real Claude API, so they cost money; `--reader ocr`
(PaddleOCR, on this machine) is free.

    export ANTHROPIC_API_KEY=...
    uv run python -m eval.run_eval --yes                 # all cases (20 images)
    uv run python -m eval.run_eval --yes --limit 2       # quick check

Report: eval/reports/<timestamp>.md
"""

import argparse
import datetime as dt
import sys
from collections import defaultdict
from dataclasses import dataclass, field

import anthropic

from app.config import get_settings
from app.drugs.catalog import load_csv
from app.drugs.matcher import DrugMatcher
from app.drugs.models import Confidence
from app.drugs.normalize import strength_numbers
from app.main import build_reader
from app.prescriptions.errors import PrescriptionError
from app.prescriptions.reader import ClaudePrescriptionReader
from app.prescriptions.schemas import MedicineResult, PrescriptionResult
from app.prescriptions.service import PrescriptionService
from app.prescriptions.verifier import PrescriptionVerifier
from eval.generate import EVAL_DIR, generate, load_cases

FIELDS = ("name", "strength", "dose", "timing", "duration")


@dataclass
class Tally:
    total: int = 0
    correct: int = 0
    by_conf: dict = field(
        default_factory=lambda: defaultdict(lambda: [0, 0])
    )  # conf → [n, correct]

    def add(self, ok: bool, conf: Confidence) -> None:
        self.total += 1
        self.correct += ok
        self.by_conf[conf][0] += 1
        self.by_conf[conf][1] += ok


def _find(expected: dict, medicines: list[MedicineResult]) -> MedicineResult | None:
    brand = expected["brand"].lower()
    for m in medicines:
        if m.name.value and m.name.value.lower() == brand:
            return m
    for m in medicines:
        if brand.split()[0] in m.raw_text.lower():
            return m
    return None


def _check(field_name: str, exp: dict, m: MedicineResult) -> bool | None:
    """None means the field is not measured for this case."""
    match field_name:
        case "name":
            return (m.name.value or "").lower() == exp["brand"].lower()
        case "strength":
            if "strength" not in exp:
                return None
            return strength_numbers(m.strength.value or "") == strength_numbers(exp["strength"])
        case "dose":
            if "dose" not in exp:
                return None
            return m.dose.value == exp["dose"]
        case "timing":
            if "timing" not in exp:
                return None
            return m.timing.value == exp["timing"]
        case "duration":
            if "days" not in exp and "continue" not in exp:
                return None
            v = m.duration.value
            return (
                v is not None
                and v.days == exp.get("days")
                and v.continue_indefinitely == exp.get("continue", False)
            )
    return None


def score(
    result: PrescriptionResult, expected: list[dict], tallies: dict, log: list[str], tag: str
):
    found = []
    for exp in expected:
        m = _find(exp, result.medicines)
        if m is None:
            log.append(f"- MISSING `{tag}` **{exp['brand']}**: not found")
            for f in FIELDS:
                tallies[f].add(False, Confidence.LOW)
            continue
        found.append(m)
        if exp.get("as_needed") and not m.as_needed:
            log.append(f"- WRONG `{tag}` **{exp['brand']}**: as_needed not detected")
        for f in FIELDS:
            ok = _check(f, exp, m)
            if ok is None:
                continue
            conf = getattr(m, f).confidence
            tallies[f].add(ok, conf)
            if not ok:
                got = getattr(m, f).value
                mark = "WRONG BUT HIGH" if conf == Confidence.HIGH else f"WRONG ({conf})"
                log.append(
                    f"- {mark} `{tag}` **{exp['brand']}** {f}: got `{got}`, expected `{exp}`"
                )
    extra = [m for m in result.medicines if m not in found]
    for m in extra:
        log.append(f"- EXTRA `{tag}`: `{m.raw_text}` (name confidence {m.name.confidence})")


def main(argv=None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--yes", action="store_true", help="Allow real (billed) API calls")
    p.add_argument("--limit", type=int, help="Only the first N cases")
    p.add_argument(
        "--variant",
        choices=["clean", "photo", "gallery", "both", "all"],
        default="both",
        help="both = clean and photo; all adds gallery (blurred, low-resolution, compressed)",
    )
    p.add_argument(
        "--reader",
        choices=["cloud", "local", "hybrid", "ocr"],
        default="cloud",
        help="Which reader to evaluate (local needs LOCAL_READER_URL; ocr is free)",
    )
    args = p.parse_args(argv)

    settings = get_settings()
    billed = args.reader in ("cloud", "hybrid")
    if billed and not settings.anthropic_api_key:
        print("error: ANTHROPIC_API_KEY is not set", file=sys.stderr)
        return 2
    cases = load_cases()[: args.limit]
    variants = {"both": ["clean", "photo"], "all": ["clean", "photo", "gallery"]}.get(
        args.variant, [args.variant]
    )
    n_calls = len(cases) * len(variants)
    if billed and not args.yes:
        model = settings.reader_model
        print(f"This makes {n_calls} billed Claude API calls ({model}). Re-run with --yes.")
        return 1

    generate()
    matcher = DrugMatcher(load_csv(settings.drugs_csv_path)[0])
    cloud = None
    if billed:
        client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        cloud = ClaudePrescriptionReader(client, settings.reader_model, settings.reader_effort)
    try:
        reader = build_reader(settings.model_copy(update={"reader_mode": args.reader}), cloud)
    except RuntimeError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    service = PrescriptionService(reader, PrescriptionVerifier(matcher))

    tallies = {v: {f: Tally() for f in FIELDS} for v in variants}
    log: list[str] = []
    for case in cases:
        for v in variants:
            tag = f"{case['id']}/{v}"
            print(f"… {tag}", flush=True)
            raw = (EVAL_DIR / "out" / f"{case['id']}__{v}.jpg").read_bytes()
            try:
                result = service.extract(raw)
            except PrescriptionError as e:
                log.append(f"- MISSING `{tag}`: {e.code}: {e.message}")
                for _ in case["expected"]:
                    for f in FIELDS:
                        tallies[v][f].add(False, Confidence.LOW)
                continue
            score(result, case["expected"], tallies[v], log, tag)

    lines = [
        f"# Prescription reader eval ({dt.date.today()})",
        "",
        # The cloud model's settings only matter when it reads; reports are committed, so they
        # stay out of OCR-only runs
        f"- Reader: `{args.reader}`"
        + ("" if args.reader == "ocr" else f", effort `{settings.reader_effort}`"),
        f"- Cases: {len(cases)} fictional printed prescriptions × {', '.join(variants)}",
        "",
    ]
    for v in variants:
        lines += [
            f"## {v}",
            "",
            "| Field | Accuracy | Correct among HIGH | Wrong but HIGH |",
            "|---|---|---|---|",
        ]
        for f in FIELDS:
            t = tallies[v][f]
            hn, hc = t.by_conf[Confidence.HIGH]
            acc = f"{t.correct}/{t.total} ({t.correct / t.total:.0%})" if t.total else "—"
            high = f"{hc}/{hn} ({hc / hn:.0%})" if hn else "—"
            lines.append(f"| {f} | {acc} | {high} | {hn - hc} |")
        lines.append("")
    lines += ["## Details", "", *(log or ["All correct."]), ""]

    report = "\n".join(lines)
    out_dir = EVAL_DIR / "reports"
    out_dir.mkdir(exist_ok=True)
    path = out_dir / f"{dt.datetime.now():%Y-%m-%d_%H%M}.md"
    path.write_text(report, encoding="utf-8")
    if hasattr(reader, "routes"):
        report += f"\nHybrid routing: {dict(reader.routes)}\n"
        path.write_text(report, encoding="utf-8")
    print(report)
    print(f"Report: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
