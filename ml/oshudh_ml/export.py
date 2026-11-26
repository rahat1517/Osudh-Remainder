"""Exports approved, de-identified examples to a JSONL dataset and marks them exported.

    uv run python -m oshudh_ml.export --out data/v1        # ml/data/ is git-ignored

Needs DATABASE_URL (privileged) and SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY to download images.
Only examples with review_status = 'approved' and an active consent are exported.
"""

import argparse
import json
import os
from collections.abc import Callable
from pathlib import Path

import psycopg

from oshudh_ml.dataset import Example, split_examples, to_chat_record

APPROVED = """
select e.id::text, e.image_path, e.group_key, e.label
  from training_examples e
  join training_consents c on c.user_id = e.user_id and c.revoked_at is null
 where e.review_status = 'approved' and e.exported_at is null
"""


def export(
    examples: list[Example], out: Path, download: Callable[[str], bytes], seed: str = "oshudh"
) -> dict[str, int]:
    out.mkdir(parents=True, exist_ok=True)
    (out / "images").mkdir(exist_ok=True)
    counts = {}
    for split, items in split_examples(examples, seed).items():
        with (out / f"{split}.jsonl").open("w", encoding="utf-8") as f:
            for e in items:
                image_file = f"images/{e.id}.jpg"
                (out / image_file).write_bytes(download(e.image_path))
                f.write(json.dumps(to_chat_record(e, image_file), ensure_ascii=False) + "\n")
        counts[split] = len(items)
    (out / "manifest.json").write_text(json.dumps({"seed": seed, "counts": counts}, indent=2))
    return counts


def main(argv: list[str] | None = None) -> int:
    import httpx2

    p = argparse.ArgumentParser()
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--seed", default="oshudh")
    p.add_argument("--bucket", default="training-examples")
    args = p.parse_args(argv)
    base = os.environ["SUPABASE_URL"].rstrip("/")
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    client = httpx2.Client(timeout=30, headers={"Authorization": f"Bearer {key}", "apikey": key})

    def download(path: str) -> bytes:
        r = client.get(f"{base}/storage/v1/object/{args.bucket}/{path}")
        r.raise_for_status()
        return r.content

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        rows = conn.execute(APPROVED).fetchall()
        examples = [Example(i, p_, g, lab) for i, p_, g, lab in rows]
        counts = export(examples, args.out, download, args.seed)
        conn.execute(
            "update training_examples set exported_at = now() where id = any(%s)",
            ([e.id for e in examples],),
        )
        conn.commit()
    print(f"exported {counts} → {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
