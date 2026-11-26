"""ওষুধের তালিকা যাচাই করে Supabase-এর জন্য SQL তৈরি করে।

ব্যবহার:
    uv run python -m app.drugs.importer ../database/seed/drugs_seed.csv --sql ../supabase/seed.sql
"""

import argparse
import sys
from pathlib import Path

from app.drugs.catalog import CatalogError, load_csv
from app.drugs.models import Drug
from app.drugs.normalize import normalize_brand


def _sql_str(value: str | None) -> str:
    if value is None:
        return "null"
    return "'" + value.replace("'", "''") + "'"


def to_sql(drugs: list[Drug]) -> str:
    lines = [
        "-- importer দিয়ে স্বয়ংক্রিয়ভাবে তৈরি। হাতে সম্পাদনা করবেন না।",
        "-- বদলাতে: database/seed/-এর CSV বদলে importer আবার চালান।",
        "",
        "insert into public.drugs",
        "    (brand, strength, generic, form, manufacturer, brand_normalized, source, verified)",
        "values",
    ]
    rows = [
        "    ("
        + ", ".join(
            [
                _sql_str(d.brand),
                _sql_str(d.strength),
                _sql_str(d.generic),
                _sql_str(d.form),
                _sql_str(d.manufacturer),
                _sql_str(normalize_brand(d.brand)),
                _sql_str(d.source),
                "true" if d.verified else "false",
            ]
        )
        + ")"
        for d in drugs
    ]
    lines.append(",\n".join(rows))
    lines.append("on conflict (brand, strength, form) do update set")
    lines.append(
        "    generic = excluded.generic, manufacturer = excluded.manufacturer,\n"
        "    brand_normalized = excluded.brand_normalized, source = excluded.source,\n"
        "    verified = excluded.verified;"
    )
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="ওষুধের CSV যাচাই ও SQL তৈরি")
    parser.add_argument("csv", type=Path, nargs="+", help="এক বা একাধিক CSV ফাইল")
    parser.add_argument("--sql", type=Path, help="যেখানে SQL লিখবে (না দিলে শুধু যাচাই)")
    args = parser.parse_args(argv)

    all_drugs: list[Drug] = []
    failed = False
    for path in args.csv:
        try:
            drugs, report = load_csv(path)
        except (CatalogError, OSError) as e:
            print(f"❌ {e}", file=sys.stderr)
            return 2
        print(f"📄 {path.name}: {report.loaded}টা ওষুধ")
        for d in report.duplicates:
            print(f"   ⚠️ duplicate বাদ: {d}")
        for err in report.errors:
            print(f"   ❌ {err}", file=sys.stderr)
            failed = True
        all_drugs.extend(drugs)

    unverified = sum(1 for d in all_drugs if not d.verified)
    print(
        f"✅ মোট {len(all_drugs)}টা ওষুধ, {len({normalize_brand(d.brand) for d in all_drugs})}টা brand"
    )
    if unverified:
        print(f"⚠️ {unverified}টা যাচাই করা হয়নি (verified=false)। রোগীদের জন্য চালুর আগে যাচাই করুন।")

    if failed:
        print("❌ ত্রুটি থাকায় SQL লেখা হয়নি।", file=sys.stderr)
        return 1
    if args.sql:
        args.sql.write_text(to_sql(all_drugs), encoding="utf-8")
        print(f"💾 SQL লেখা হয়েছে: {args.sql}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
