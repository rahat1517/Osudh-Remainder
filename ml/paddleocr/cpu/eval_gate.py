"""The eval gate for a new OCR model: compares its eval report with the current model's.

    python paddleocr/cpu/eval_gate.py current.md candidate.md

Passes (exit 0) only if the candidate gets nothing wrong while marking it high, and every field of
every photo variant (clean, photo, gallery) is read correctly at least as often as before.
"""

import re
import sys
from pathlib import Path

ROW = re.compile(r"^\| (\w+) \| (\d+)/(\d+) \(\d+%\) \| [^|]* \| (\d+) \|$")


def parse(report: str) -> tuple[dict[tuple[str, str], int], int]:
    """({(variant, field): correct}, wrong-but-high total)."""
    scores: dict[tuple[str, str], int] = {}
    wrong_high = 0
    variant = None
    for line in report.splitlines():
        if line.startswith("## "):
            variant = line[3:].strip()
        elif variant and (m := ROW.match(line.strip())):
            scores[(variant, m.group(1))] = int(m.group(2))
            wrong_high += int(m.group(4))
    return scores, wrong_high


def gate(current: str, candidate: str) -> list[str]:
    """Reasons to reject the candidate (empty: it passes)."""
    cur, _ = parse(current)
    cand, cand_wrong_high = parse(candidate)
    if not cand:
        return ["the candidate's report has no results"]
    problems = []
    if cand_wrong_high:
        problems.append(f"{cand_wrong_high} field(s) wrong but marked high")
    for key, before in sorted(cur.items()):
        after = cand.get(key, 0)
        if after < before:
            problems.append(f"{key[0]} {key[1]}: {after} correct, was {before}")
    return problems


if __name__ == "__main__":
    current, candidate = (Path(p).read_text(encoding="utf-8") for p in sys.argv[1:3])
    problems = gate(current, candidate)
    better = sum(
        a - b for k, b in parse(current)[0].items() if (a := parse(candidate)[0].get(k, 0)) > b
    )
    if problems:
        print("REJECTED:\n  " + "\n  ".join(problems))
        raise SystemExit(1)
    print(f"PASSED: nothing worse, {better} more field(s) correct")
