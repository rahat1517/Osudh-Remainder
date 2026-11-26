"""Line-level training data for the PaddleOCR recognition model.

The recognition model reads one cropped text line at a time, so it learns from (crop, text) pairs.
Users confirm canonical values ("1+0+1", "before_meal"), not the text as written ("১+০+১",
"খাবারের আগে"), so real crops are labelled conservatively:

- a crop OCR already read confidently, whose medicine values agree with what the user confirmed, is
  kept as is (it teaches the model real handwriting and photos);
- a crop whose medicine name OCR misread is kept with the name replaced by the confirmed one;
- anything else is skipped rather than guessed.

Bangla-script instructions are taught from synthetic images (`synth_rec.py`) until reviewers have
transcribed enough real ones.
"""

import re
from collections.abc import Iterable
from dataclasses import dataclass

from rapidfuzz import fuzz

MIN_CONFIDENT_SCORE = 0.9
MIN_NAME_SIMILARITY = 70


@dataclass(frozen=True)
class LabelledLine:
    text: str
    source: str  # "confident" | "name_corrected"


_WORD = re.compile(r"[A-Za-z][A-Za-z0-9-]{2,}")
_FORM_WORDS = {"tab", "tablet", "cap", "capsule", "syp", "syrup", "inj", "cream", "drop", "drops"}


def _name_words(text: str) -> list[re.Match]:
    return [m for m in _WORD.finditer(text) if m.group(0).lower() not in _FORM_WORDS]


def _confirmed_pattern_in(text: str, medicines: list[dict]) -> bool:
    digits = re.sub(r"\s+", "", text)
    return any(m.get("dose_pattern") and m["dose_pattern"] in digits for m in medicines)


def label_line(ocr_text: str, ocr_score: float, medicines: list[dict]) -> LabelledLine | None:
    """The training text for one OCR line of an approved example, or None to skip it."""
    text = ocr_text.strip()
    if not text:
        return None
    names = [m["name"] for m in medicines if m.get("name")]
    words = _name_words(text)

    # The line's medicine name, compared with the confirmed names
    best: tuple[float, re.Match | None, str | None] = (0.0, None, None)
    for w in words:
        for name in names:
            first = name.split()[0]
            score = fuzz.ratio(w.group(0).lower(), first.lower())
            if score > best[0]:
                best = (score, w, first)
    score, word, confirmed = best

    if word is not None and confirmed and score >= MIN_NAME_SIMILARITY:
        if word.group(0) != confirmed:
            fixed = text[: word.start()] + confirmed + text[word.end() :]
            return LabelledLine(fixed, "name_corrected")
        if ocr_score >= MIN_CONFIDENT_SCORE:
            return LabelledLine(text, "confident")
        return None

    # Instruction lines: only when OCR was confident and the dose agrees with the confirmed one
    if ocr_score >= MIN_CONFIDENT_SCORE and _confirmed_pattern_in(text, medicines):
        return LabelledLine(text, "confident")
    return None


def build_dict(texts: Iterable[str], base: str = "") -> list[str]:
    """PaddleOCR character dictionary: every character used, one per line, stable order."""
    chars = set(base)
    for t in texts:
        chars.update(t)
    chars.discard("\n")
    chars.discard(" ")  # PaddleOCR adds the space itself (use_space_char)
    return sorted(chars)
