"""De-identification of prescription images before they can be used for training.

Layer 1 (automatic): a text-line detector (OCR) finds lines; lines that look like patient identity
(name, age, sex, phone, address, registration numbers) are blacked out.
Layer 2 (mandatory): a human reviewer checks every example before it can be exported for training.
Automatic redaction alone is never trusted.
"""

import io
import re
from dataclasses import dataclass
from typing import Protocol

from PIL import Image, ImageDraw


@dataclass(frozen=True)
class TextLine:
    text: str
    box: tuple[int, int, int, int]  # left, top, right, bottom in pixels


class LineDetector(Protocol):
    def detect(self, image: bytes) -> list[TextLine]: ...


_PERSONAL = re.compile(
    "|".join(
        [
            r"\b(name|patient|pt\.?|age|sex|gender|mobile|phone|cell|contact|address|addr|reg(istration)?\s*no|id\s*no|nid)\b",
            r"নাম",
            r"রোগী",
            r"বয়স",
            r"বয়স",
            r"লিঙ্গ",
            r"মোবাইল",
            r"ফোন",
            r"ঠিকানা",
            r"গ্রাম",
            r"থানা",
            r"জেলা",
            r"(\+?88)?0\s*1[3-9](\s*-?\d){8}",  # Bangladeshi mobile numbers
            r"(\+?৮৮)?০\s*১[৩-৯](\s*-?[০-৯]){8}",  # in Bangla digits
            r"\b\d{1,3}\s*(y|yrs?|years?)\b",
            r"[০-৯]{1,3}\s*বছর",  # ages
        ]
    ),
    re.IGNORECASE,
)


def is_personal_line(text: str) -> bool:
    return bool(_PERSONAL.search(text))


def redact(image: bytes, lines: list[TextLine], padding: int = 6) -> tuple[bytes, int]:
    """Blacks out personal lines. Returns the new JPEG and the number of redacted lines."""
    img = Image.open(io.BytesIO(image)).convert("RGB")
    draw = ImageDraw.Draw(img)
    count = 0
    for line in lines:
        if is_personal_line(line.text):
            left, top, right, bottom = line.box
            draw.rectangle(
                (left - padding, top - padding, right + padding, bottom + padding), fill="black"
            )
            count += 1
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=90)
    return out.getvalue(), count


class TesseractLineDetector:
    """OCR line detector using Tesseract (optional: `pip install pytesseract` and install tesseract
    with the `ben` and `eng` language data)."""

    def detect(self, image: bytes) -> list[TextLine]:
        import pytesseract  # optional dependency

        img = Image.open(io.BytesIO(image))
        data = pytesseract.image_to_data(img, lang="ben+eng", output_type=pytesseract.Output.DICT)
        lines: dict[tuple[int, int, int], list[int]] = {}
        for i, word in enumerate(data["text"]):
            if word.strip():
                lines.setdefault(
                    (data["block_num"][i], data["par_num"][i], data["line_num"][i]), []
                ).append(i)
        result = []
        for idx in lines.values():
            left = min(data["left"][i] for i in idx)
            top = min(data["top"][i] for i in idx)
            right = max(data["left"][i] + data["width"][i] for i in idx)
            bottom = max(data["top"][i] + data["height"][i] for i in idx)
            result.append(
                TextLine(" ".join(data["text"][i] for i in idx), (left, top, right, bottom))
            )
        return result


class NoLineDetector:
    """No OCR available: nothing is redacted automatically; human review must catch everything."""

    def detect(self, image: bytes) -> list[TextLine]:
        return []
