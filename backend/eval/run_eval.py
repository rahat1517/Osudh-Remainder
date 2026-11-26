"""প্রেসক্রিপশন পাঠকের নির্ভুলতা মাপা (আসল Claude API ডাকে, তাই খরচ হয়)।

    export ANTHROPIC_API_KEY=...
    uv run python -m eval.run_eval --yes                 # সব case (২০টা ছবি)
    uv run python -m eval.run_eval --yes --limit 2       # দ্রুত পরীক্ষা

ফলাফল: eval/reports/<তারিখ>.md
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
from app.prescriptions.reader import ClaudePrescriptionReader, ReaderError
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
    """None = এই ঘর এই case-এ মাপা হয় না।"""
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
            log.append(f"- ❌ `{tag}` **{exp['brand']}**: পাওয়া যায়নি")
            for f in FIELDS:
                tallies[f].add(False, Confidence.LOW)
            continue
        found.append(m)
        if exp.get("as_needed") and not m.as_needed:
            log.append(f"- ❌ `{tag}` **{exp['brand']}**: as_needed ধরা পড়েনি")
        for f in FIELDS:
            ok = _check(f, exp, m)
            if ok is None:
                continue
            conf = getattr(m, f).confidence
            tallies[f].add(ok, conf)
            if not ok:
                got = getattr(m, f).value
                mark = "🚨 ভুল কিন্তু HIGH" if conf == Confidence.HIGH else f"⚠️ ভুল ({conf})"
                log.append(f"- {mark} `{tag}` **{exp['brand']}** {f}: পাওয়া `{got}`, সঠিক `{exp}`")
    extra = [m for m in result.medicines if m not in found]
    for m in extra:
        log.append(f"- ℹ️ `{tag}` অতিরিক্ত: `{m.raw_text}` (name conf {m.name.confidence})")


def main(argv=None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--yes", action="store_true", help="আসল API ডাকার অনুমতি (খরচ হবে)")
    p.add_argument("--limit", type=int, help="প্রথম N টা case")
    p.add_argument("--variant", choices=["clean", "photo", "both"], default="both")
    args = p.parse_args(argv)

    settings = get_settings()
    if not settings.anthropic_api_key:
        print("❌ ANTHROPIC_API_KEY নেই", file=sys.stderr)
        return 2
    cases = load_cases()[: args.limit]
    variants = ["clean", "photo"] if args.variant == "both" else [args.variant]
    n_calls = len(cases) * len(variants)
    if not args.yes:
        print(
            f"এটা {n_calls} বার Claude API ডাকবে ({settings.reader_model}), খরচ হবে। চালাতে --yes দিন।"
        )
        return 1

    generate()
    matcher = DrugMatcher(load_csv(settings.drugs_csv_path)[0])
    client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
    reader = ClaudePrescriptionReader(client, settings.reader_model, settings.reader_effort)
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
            except ReaderError as e:
                log.append(f"- ❌ `{tag}`: {e}")
                for _ in case["expected"]:
                    for f in FIELDS:
                        tallies[v][f].add(False, Confidence.LOW)
                continue
            score(result, case["expected"], tallies[v], log, tag)

    lines = [
        f"# প্রেসক্রিপশন পাঠক: eval রিপোর্ট ({dt.date.today()})",
        "",
        f"- Model: `{settings.reader_model}`, effort `{settings.reader_effort}`",
        f"- Case: {len(cases)}টা কাল্পনিক ছাপা প্রেসক্রিপশন × {', '.join(variants)}",
        "",
    ]
    for v in variants:
        lines += [
            f"## {v}",
            "",
            "| ঘর | নির্ভুলতা | HIGH-এর মধ্যে সঠিক | ভুল কিন্তু HIGH |",
            "|---|---|---|---|",
        ]
        for f in FIELDS:
            t = tallies[v][f]
            hn, hc = t.by_conf[Confidence.HIGH]
            acc = f"{t.correct}/{t.total} ({t.correct / t.total:.0%})" if t.total else "—"
            high = f"{hc}/{hn} ({hc / hn:.0%})" if hn else "—"
            lines.append(f"| {f} | {acc} | {high} | {hn - hc} |")
        lines.append("")
    lines += ["## বিস্তারিত", "", *(log or ["সব ঠিক ✅"]), ""]

    report = "\n".join(lines)
    out_dir = EVAL_DIR / "reports"
    out_dir.mkdir(exist_ok=True)
    path = out_dir / f"{dt.datetime.now():%Y-%m-%d_%H%M}.md"
    path.write_text(report, encoding="utf-8")
    print(report)
    print(f"💾 {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
