"""Synthetic line images for the PaddleOCR recognition model.

Real prescriptions write doses and instructions in Bangla script ("১+০+১  খাবারের আগে  ৭ দিন"),
which the pretrained models cannot read. Rendering such lines with Bangla fonts, then degrading them
like phone photos, gives the model thousands of correct examples before real data exists.

    uv run --extra ocr python -m oshudh_ml.synth_rec --fonts fonts/ --out data/synth --count 20000

Use several fonts, including handwriting-style ones (for Bangla, e.g. Noto Sans/Serif Bengali,
Hind Siliguri, Galada, Mina; for Latin, any handwriting font). Output is PaddleOCR's recognition
format: `images/*.jpg` and `train.txt` / `val.txt` lines of `images/name.jpg<TAB>text`.
"""

import argparse
import random
from collections.abc import Iterator
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, features

BANGLA_DIGITS = "০১২৩৪৫৬৭৮৯"
FORMS = ["Tab.", "Tab", "Cap.", "Cap", "Syp.", "T.", "C."]
BRANDS = [
    "Napa", "Napa Extra", "Ace", "Seclo", "Sergel", "Maxpro", "Nexum", "Esonix", "Pantonix",
    "Fexo", "Alatrol", "Monas", "Zimax", "Azithrocin", "Cef-3", "Moxacil", "Ciprocin", "Filmet",
    "Amdocal", "Camlodin", "Osartil", "Angilock", "Comet", "Rosuva", "Atova", "Ecosprin",
    "Calbo D", "Rolac", "Sedil", "Disopan", "Orsaline-N", "Losectil", "Finix", "Tridosil",
]  # fmt: skip
STRENGTHS = [
    "5 mg",
    "10 mg",
    "20 mg",
    "40 mg",
    "50 mg",
    "120 mg",
    "500 mg",
    "0.5 mg",
    "500mg",
    "20mg",
]
PATTERNS = ["1+0+1", "1+1+1", "0+0+1", "1+0+0", "0+1+0", "1+1+1+1", "½+0+½", "1+0+½", "2+2+2"]
TIMINGS_BN = ["খাবারের আগে", "খাবারের পরে", "খালি পেটে", "ঘুমানোর আগে", "ভরা পেটে", "খাবারের সাথে"]
TIMINGS_LATIN = ["khabar age", "khabarer pore", "before meal", "after meal", "AC", "PC", "HS"]
DURATIONS_BN = ["দিন", "মাস", "সপ্তাহ"]
DURATIONS_LATIN = ["days", "din", "month", "weeks"]
EXTRAS_BN = ["চলবে", "প্রয়োজনে", "জ্বর হলে", "ব্যথা হলে"]
FREQUENCIES = ["BD", "TDS", "QID", "OD", "HS", "SOS"]


def to_bangla_digits(text: str) -> str:
    return text.translate(str.maketrans("0123456789", BANGLA_DIGITS))


def sample_line(rng: random.Random) -> str:
    """One realistic prescription line."""
    kind = rng.random()
    if kind < 0.35:  # medicine line
        number = f"{rng.randint(1, 6)}. " if rng.random() < 0.6 else ""
        strength = f" {rng.choice(STRENGTHS)}" if rng.random() < 0.8 else ""
        return f"{number}{rng.choice(FORMS)} {rng.choice(BRANDS)}{strength}"
    pattern = rng.choice(PATTERNS)
    days = str(rng.choice([3, 5, 7, 10, 14, 15, 30, 1, 2, 3]))
    if kind < 0.75:  # Bangla instruction line
        parts = [to_bangla_digits(pattern)]
        if rng.random() < 0.8:
            parts.append(rng.choice(TIMINGS_BN))
        if rng.random() < 0.7:
            parts.append(f"{to_bangla_digits(days)} {rng.choice(DURATIONS_BN)}")
        elif rng.random() < 0.3:
            parts.append(rng.choice(EXTRAS_BN))
        return "  ".join(parts)
    # Latin instruction line
    first = pattern if rng.random() < 0.7 else f"1 {rng.choice(FREQUENCIES)}"
    parts = [first]
    if rng.random() < 0.7:
        parts.append(rng.choice(TIMINGS_LATIN))
    if rng.random() < 0.7:
        parts.append(f"{'x ' if rng.random() < 0.3 else ''}{days} {rng.choice(DURATIONS_LATIN)}")
    return "  ".join(parts)


def render(text: str, font: ImageFont.FreeTypeFont, rng: random.Random) -> Image.Image:
    """The line as a phone camera might capture it: tilt, blur, uneven light, noise."""
    left, top, right, bottom = font.getbbox(text)
    pad = rng.randint(6, 16)
    w, h = right - left + 2 * pad, bottom - top + 2 * pad
    paper = rng.randint(215, 255)
    img = Image.new("L", (max(w, 8), max(h, 8)), paper)
    ink = rng.randint(0, 80)
    ImageDraw.Draw(img).text((pad - left, pad - top), text, fill=ink, font=font)
    if rng.random() < 0.7:
        img = img.rotate(rng.uniform(-3, 3), expand=True, fillcolor=paper)
    if rng.random() < 0.5:
        img = img.filter(ImageFilter.GaussianBlur(rng.uniform(0.3, 1.2)))
    if rng.random() < 0.5:  # noise
        noise = Image.effect_noise(img.size, rng.uniform(5, 25))
        img = Image.blend(img, noise, rng.uniform(0.05, 0.15))
    if rng.random() < 0.3:  # squash, as with an oblique photo
        img = img.resize((int(img.width * rng.uniform(0.8, 1.1)), img.height))
    return img.convert("RGB")


def generate(
    fonts: list[Path], count: int, seed: int = 7, sizes: tuple[int, int] = (26, 44)
) -> Iterator[tuple[Image.Image, str]]:
    rng = random.Random(seed)
    loaded: dict[tuple[Path, int], ImageFont.FreeTypeFont] = {}
    for _ in range(count):
        text = sample_line(rng)
        path, size = rng.choice(fonts), rng.randint(*sizes)
        font = loaded.setdefault((path, size), ImageFont.truetype(str(path), size))
        yield render(text, font, rng), text


def write_dataset(fonts: list[Path], out: Path, count: int, seed: int = 7, val_share: float = 0.05):
    (out / "images").mkdir(parents=True, exist_ok=True)
    rng = random.Random(seed + 1)
    with (
        (out / "train.txt").open("w", encoding="utf-8") as train,
        (out / "val.txt").open("w", encoding="utf-8") as val,
    ):
        for i, (img, text) in enumerate(generate(fonts, count, seed)):
            name = f"images/synth_{i:06d}.jpg"
            img.save(out / name, quality=rng.randint(60, 95))
            (val if rng.random() < val_share else train).write(f"{name}\t{text}\n")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--fonts", type=Path, required=True, help="Folder of .ttf/.otf fonts")
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--count", type=int, default=20000)
    p.add_argument("--seed", type=int, default=7)
    args = p.parse_args(argv)
    fonts = sorted([*args.fonts.glob("*.ttf"), *args.fonts.glob("*.otf")])
    if not fonts:
        p.error(f"no fonts in {args.fonts}")
    if not features.check("raqm"):
        # Without complex text layout, Bangla vowel signs and conjuncts are drawn in the wrong
        # order and the model would learn broken text
        p.error("Pillow has no libraqm: install it (apt-get install libraqm0) and reinstall Pillow")
    write_dataset(fonts, args.out, args.count, args.seed)
    print(f"{args.count} synthetic lines from {len(fonts)} fonts → {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
