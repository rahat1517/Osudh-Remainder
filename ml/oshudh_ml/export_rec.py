"""Exports line crops of approved examples as PaddleOCR recognition training data.

    uv run --extra ocr python -m oshudh_ml.export_rec --out data/rec-v1

Each approved, consented, de-identified example is run through the current OCR model; every line it
finds is labelled with `rec_dataset.label_line` (confident reads that agree with the confirmed values,
or names corrected from them) and cropped. Lines that cannot be labelled safely are skipped, and
listed in `skipped.tsv` with their crops so a reviewer can type the correct text and add them.

Needs SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY (rows are read through Supabase's API with it), or
DATABASE_URL (privileged) for the rows. Examples are not marked as exported (that is done by
`oshudh_ml.export`), so this can be re-run after every model.
"""

import argparse
import io
import os
from collections import Counter
from collections.abc import Callable, Iterable
from pathlib import Path

from PIL import Image

from oshudh_ml.dataset import Example, split_of
from oshudh_ml.rec_dataset import build_dict, label_line

APPROVED = """
select e.id::text, e.image_path, e.group_key, e.label
  from training_examples e
  join training_consents c on c.user_id = e.user_id and c.revoked_at is null
 where e.review_status = 'approved'
"""

OcrFn = Callable[[bytes], list[tuple[list[list[float]], str, float]]]


def crop(image: Image.Image, box: list[list[float]], pad: int = 4) -> Image.Image:
    xs = [p[0] for p in box]
    ys = [p[1] for p in box]
    return image.crop(
        (
            max(0, int(min(xs)) - pad),
            max(0, int(min(ys)) - pad),
            min(image.width, int(max(xs)) + pad),
            min(image.height, int(max(ys)) + pad),
        )
    )


def export(
    examples: Iterable[Example],
    out: Path,
    download: Callable[[str], bytes],
    ocr: OcrFn,
    seed: str = "oshudh",
) -> Counter:
    (out / "images").mkdir(parents=True, exist_ok=True)
    (out / "skipped").mkdir(exist_ok=True)
    files = {s: (out / f"{s}.txt").open("w", encoding="utf-8") for s in ("train", "val", "test")}
    skipped = (out / "skipped.tsv").open("w", encoding="utf-8")
    skipped.write("crop\tocr_text\tcorrect_text\n")
    stats: Counter = Counter()
    texts: list[str] = []
    try:
        for e in examples:
            split = {"train": "train", "validation": "val", "test": "test"}[
                split_of(e.group_key, seed)
            ]
            raw = download(e.image_path)
            image = Image.open(io.BytesIO(raw)).convert("RGB")
            medicines = e.label.get("medicines", [])
            for i, (box, text, score) in enumerate(ocr(raw)):
                piece = crop(image, box)
                labelled = label_line(text, float(score), medicines)
                if labelled is None:
                    name = f"skipped/{e.id}_{i}.jpg"
                    piece.save(out / name, quality=92)
                    skipped.write(f"{name}\t{text}\t\n")
                    stats["skipped"] += 1
                    continue
                name = f"images/{e.id}_{i}.jpg"
                piece.save(out / name, quality=92)
                files[split].write(f"{name}\t{labelled.text}\n")
                texts.append(labelled.text)
                stats[labelled.source] += 1
                stats[split] += 1
    finally:
        for f in files.values():
            f.close()
        skipped.close()
    (out / "dict.txt").write_text("\n".join(build_dict(texts)) + "\n", encoding="utf-8")
    return stats


def approved_via_api(client, base: str) -> list[tuple[str, str, str, dict]]:
    """APPROVED through Supabase's REST API (the service role bypasses row-level security)."""
    r = client.get(
        f"{base}/rest/v1/training_examples",
        params={"select": "id,user_id,image_path,group_key,label", "review_status": "eq.approved"},
    )
    r.raise_for_status()
    examples = r.json()
    r = client.get(
        f"{base}/rest/v1/training_consents",
        params={"select": "user_id", "revoked_at": "is.null"},
    )
    r.raise_for_status()
    consented = {c["user_id"] for c in r.json()}
    return [
        (e["id"], e["image_path"], e["group_key"], e["label"])
        for e in examples
        if e["user_id"] in consented
    ]


def main(argv: list[str] | None = None) -> int:
    import httpx2
    from rapidocr_onnxruntime import RapidOCR

    p = argparse.ArgumentParser()
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--seed", default="oshudh")
    p.add_argument("--bucket", default="training-examples")
    p.add_argument("--rec-model", help="Current fine-tuned recognition model (ONNX), if any")
    p.add_argument("--rec-keys", help="Its character list (dict.txt); needed with --rec-model")
    args = p.parse_args(argv)

    base = os.environ["SUPABASE_URL"].rstrip("/")
    key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
    client = httpx2.Client(timeout=30, headers={"Authorization": f"Bearer {key}", "apikey": key})
    if args.rec_model and not args.rec_keys:
        p.error(
            "--rec-model needs --rec-keys: a model read with the wrong character list is garbage"
        )
    engine = RapidOCR(
        **(
            {"rec_model_path": args.rec_model, "rec_keys_path": args.rec_keys}
            if args.rec_model
            else {}
        )
    )

    def download(path: str) -> bytes:
        r = client.get(f"{base}/storage/v1/object/{args.bucket}/{path}")
        r.raise_for_status()
        return r.content

    def ocr(raw: bytes):
        result, _ = engine(raw)
        return result or []

    if os.environ.get("DATABASE_URL"):
        import psycopg

        with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
            rows = conn.execute(APPROVED).fetchall()
    else:
        rows = approved_via_api(client, base)
    stats = export((Example(*row) for row in rows), args.out, download, ocr, args.seed)
    print(f"{len(rows)} examples → {dict(stats)} in {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
