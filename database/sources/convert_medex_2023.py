"""Builds database/seed/drugs_seed.csv from the public "Assorted Medicine Dataset of Bangladesh"
(21,714 brands with prices, collected from medex.com.bd in 2023; a copy is at
https://github.com/Kabbo45/medicine-dataset-for-bangladesh-21714).

    cd backend && uv run python ../database/sources/convert_medex_2023.py \
        "Dataset Excel File.csv" ../database/seed/drugs_seed.csv

Only facts are taken: brand, generic, strength, form, manufacturer, price and pack. The
descriptive texts (indications, side effects...) are not.

The first rows of the current CSV keep their positions, because a row's position is its drug id
and medicines saved by users point at those ids. They get the dataset's data where it has the
same brand and strength (the form there is more precise, e.g. "Capsule (Delayed Release)");
otherwise they keep their data, without a price. Every other brand follows, once each.

Prices are from 2023 and not checked against the DGDA list: `verified=false`, so the app calls
them approximate.
"""

import csv
import re
import sys
from pathlib import Path

# The catalogue's own brand normalisation, so rows it would treat as duplicates are left out here
# and every row keeps the position (id) the backend and the database give it
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "backend"))
from app.drugs.normalize import normalize_brand  # noqa: E402

SOURCE = "medex-2023"
COLUMNS = [
    "brand", "strength", "generic", "form", "manufacturer", "source", "verified",
    "unit_price_bdt", "pack",
]  # fmt: skip

_UNIT = re.compile(r"^\s*Unit Price:\s*TK\s*([\d,]+(?:\.\d+)?)\s*$", re.I)
_PACK = re.compile(r"^\s*(.+?):\s*TK\s*([\d,]+(?:\.\d+)?)\s*$", re.I)


def clean(value: str | None) -> str:
    return " ".join((value or "").split())


def parse_price(raw: str) -> tuple[str, str]:
    """(unit_price_bdt, pack): pack is empty when the price is per piece."""
    if m := _UNIT.match(raw or ""):
        price, pack = m.group(1), ""
    elif m := _PACK.match(raw or ""):
        price, pack = m.group(2), clean(m.group(1))
    else:
        return "", ""
    value = float(price.replace(",", ""))
    if not 0 < value < 100_000:
        return "", ""
    return f"{value:g}", pack


def numbers(strength: str) -> tuple[str, ...]:
    return tuple(re.findall(r"\d+(?:\.\d+)?", strength))


def key(brand: str, strength: str, form: str) -> tuple[str, str, str]:
    return (normalize_brand(brand), strength.lower(), form.lower())


def main(dataset: Path, seed: Path) -> None:
    csv.field_size_limit(10**9)
    with dataset.open(encoding="utf-8-sig", errors="replace", newline="") as f:
        source = [
            {
                "brand": clean(r["brand"]),
                "strength": clean(r["strength"]).replace(" + ", "+"),
                "generic": clean(r["generic"]),
                "form": clean(r["form"]),
                "manufacturer": clean(r["manufacturer"]),
                "price": r["price"] or "",
            }
            for r in csv.DictReader(f)
        ]
    with seed.open(encoding="utf-8", newline="") as f:
        existing = list(csv.DictReader(f))
    # Keep only the original development rows: their positions are drug ids in use
    existing = [r for r in existing if r["source"] == "dev-seed"]

    def row(r: dict) -> dict:
        price, pack = parse_price(r["price"])
        return {
            "brand": r["brand"],
            "strength": r["strength"],
            "generic": r["generic"],
            "form": r["form"],
            "manufacturer": r["manufacturer"],
            "source": SOURCE,
            "verified": "false",
            "unit_price_bdt": price,
            "pack": pack,
        }

    out: list[dict] = []
    seen: set[tuple[str, str, str]] = set()
    used: set[int] = set()
    for old in existing:
        base_form = old["form"].lower().split(" (")[0]
        match = next(
            (
                i
                for i, r in enumerate(source)
                if i not in used
                and r["brand"].lower() == old["brand"].lower()
                and numbers(r["strength"]) == numbers(old["strength"])
                # "Capsule" → "Capsule (Delayed Release)", "Suspension" → "Oral Suspension"
                and base_form in r["form"].lower()
            ),
            None,
        )
        if match is None:
            new = {c: old.get(c, "") for c in COLUMNS} | {"unit_price_bdt": "", "pack": ""}
        else:
            used.add(match)
            new = row(source[match])
        out.append(new)
        seen.add(key(new["brand"], new["strength"], new["form"]))

    skipped = 0
    for i, r in enumerate(source):
        if i in used or not (r["brand"] and r["generic"] and r["form"]):
            skipped += i not in used
            continue
        k = key(r["brand"], r["strength"], r["form"])
        if k in seen:  # the same brand, strength and form in another pack
            skipped += 1
            continue
        seen.add(k)
        out.append(row(r))

    with seed.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS, lineterminator="\n")
        w.writeheader()
        w.writerows(out)
    priced = sum(1 for r in out if r["unit_price_bdt"])
    print(f"{len(out)} drugs ({len(existing)} kept in place), {priced} with a price, {skipped} skipped")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
