"""ওষুধের তালিকা লোড করা ও যাচাই করা।

এখন CSV থেকে পড়ে। পরে Supabase database থেকে পড়ার ব্যবস্থা যোগ হবে, কিন্তু বাকি কোড একই থাকবে।
"""

import csv
from collections.abc import Iterable
from dataclasses import dataclass, field
from pathlib import Path

from app.drugs.models import Drug
from app.drugs.normalize import normalize_brand

REQUIRED_COLUMNS = ("brand", "strength", "generic", "form", "manufacturer", "source", "verified")


class CatalogError(ValueError):
    pass


@dataclass
class LoadReport:
    loaded: int = 0
    duplicates: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


def _clean(value: str | None) -> str:
    return " ".join((value or "").split())


def _parse_bool(value: str, line: int) -> bool:
    v = value.strip().lower()
    if v in {"true", "1", "yes"}:
        return True
    if v in {"false", "0", "no", ""}:
        return False
    raise CatalogError(f"লাইন {line}: verified-এর মান true/false হতে হবে, পাওয়া গেছে '{value}'")


def parse_rows(
    rows: Iterable[dict[str, str]], start_line: int = 2
) -> tuple[list[Drug], LoadReport]:
    """CSV-এর সারি থেকে ওষুধের তালিকা। খারাপ সারি বাদ দিয়ে রিপোর্টে লেখে।"""
    report = LoadReport()
    drugs: list[Drug] = []
    seen: set[tuple[str, str, str]] = set()

    for line, row in enumerate(rows, start=start_line):
        brand, generic, form = (
            _clean(row.get("brand")),
            _clean(row.get("generic")),
            _clean(row.get("form")),
        )
        strength, source = _clean(row.get("strength")), _clean(row.get("source"))
        missing = [
            n
            for n, v in (("brand", brand), ("generic", generic), ("form", form), ("source", source))
            if not v
        ]
        if missing:
            report.errors.append(f"লাইন {line}: খালি ঘর: {', '.join(missing)}")
            continue
        try:
            verified = _parse_bool(row.get("verified", ""), line)
        except CatalogError as e:
            report.errors.append(str(e))
            continue

        key = (normalize_brand(brand), strength.lower(), form.lower())
        if key in seen:
            report.duplicates.append(f"লাইন {line}: {brand} {strength} ({form})")
            continue
        seen.add(key)

        drugs.append(
            Drug(
                id=len(drugs) + 1,
                brand=brand,
                strength=strength,
                generic=generic,
                form=form,
                manufacturer=_clean(row.get("manufacturer")) or None,
                source=source,
                verified=verified,
            )
        )
    report.loaded = len(drugs)
    return drugs, report


def load_csv(path: Path) -> tuple[list[Drug], LoadReport]:
    with path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        missing = [c for c in REQUIRED_COLUMNS if c not in (reader.fieldnames or [])]
        if missing:
            raise CatalogError(f"{path.name}: column নেই: {', '.join(missing)}")
        return parse_rows(reader)
