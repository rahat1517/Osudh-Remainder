"""Renders fictional prescription images for the eval.

Each case has two variants: "clean" (crisp print) and "photo" (like a phone photo: tilted, blurred,
noisy). Images go to eval/out/, which is not committed. The Bangla header text is fictional.

    uv run python -m eval.generate
"""

import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

EVAL_DIR = Path(__file__).parent
OUT_DIR = EVAL_DIR / "out"
FONT_DIR = EVAL_DIR.parent.parent / "app" / "assets" / "fonts"

PAGE = (1240, 1754)  # A4, ~150 dpi


def _font(weight: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(
        str(FONT_DIR / f"HindSiliguri_{weight}.ttf"), size, layout_engine=ImageFont.Layout.RAQM
    )


def load_cases() -> list[dict]:
    return json.loads((EVAL_DIR / "cases.json").read_text(encoding="utf-8"))["cases"]


def render_clean(case: dict) -> Image.Image:
    img = Image.new("RGB", PAGE, "white")
    d = ImageDraw.Draw(img)
    # Fictional doctor and patient
    d.text((80, 70), "ডা. নমুনা আহমেদ", font=_font("700Bold", 46), fill="#123")
    d.text(
        (80, 130),
        "MBBS, FCPS (Medicine) | কাল্পনিক চেম্বার, ঢাকা",
        font=_font("400Regular", 28),
        fill="#345",
    )
    d.line((80, 185, PAGE[0] - 80, 185), fill="#0F7B5F", width=4)
    d.text(
        (80, 215),
        "নাম: নমুনা রোগী      বয়স: ৪৫      তারিখ: ০১/১১/২০২৬",
        font=_font("400Regular", 30),
        fill="black",
    )
    d.text((80, 300), "Rx", font=_font("700Bold", 60), fill="black")

    y = 400
    line_font = _font("500Medium", 34)
    for i, line in enumerate(case["lines"], start=1):
        d.text((110, y), f"{i}. {line}", font=line_font, fill="black")
        y += 90
    d.line((PAGE[0] - 420, PAGE[1] - 200, PAGE[0] - 100, PAGE[1] - 200), fill="black", width=2)
    d.text((PAGE[0] - 380, PAGE[1] - 190), "স্বাক্ষর", font=_font("400Regular", 28), fill="black")
    return img


def degrade(img: Image.Image, seed: int) -> Image.Image:
    rng = random.Random(seed)
    img = img.rotate(rng.uniform(-3.5, 3.5), expand=True, fillcolor=(235, 232, 225))
    img = ImageEnhance.Brightness(img).enhance(rng.uniform(0.8, 0.95))
    img = ImageEnhance.Contrast(img).enhance(rng.uniform(0.75, 0.9))
    img = img.filter(ImageFilter.GaussianBlur(rng.uniform(0.8, 1.4)))
    noise = Image.effect_noise(img.size, rng.uniform(18, 28)).convert("RGB")
    img = Image.blend(img, noise, 0.08)
    w, h = img.size
    return img.resize((int(w * 0.7), int(h * 0.7)))


def generate() -> list[Path]:
    OUT_DIR.mkdir(exist_ok=True)
    paths = []
    for n, case in enumerate(load_cases()):
        clean = render_clean(case)
        for variant, img in (("clean", clean), ("photo", degrade(clean, seed=n))):
            path = OUT_DIR / f"{case['id']}__{variant}.jpg"
            img.save(path, quality=60 if variant == "photo" else 90)
            paths.append(path)
    return paths


if __name__ == "__main__":
    for p in generate():
        print(p.relative_to(EVAL_DIR.parent))
