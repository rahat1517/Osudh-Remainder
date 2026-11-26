"""ওষুধের নাম স্বাভাবিক করা।

প্রেসক্রিপশনে বা OCR-এ একই ওষুধ নানাভাবে লেখা থাকে:
"Tab. Seclo-20mg", "SECLO 20", "seclo২০", "Sec1o 20"। এখানে সবগুলোকে একই রূপে আনা হয়।
"""

import re
import unicodedata
from dataclasses import dataclass

_BANGLA_DIGITS = str.maketrans("০১২৩৪৫৬৭৮৯", "0123456789")

# ওষুধের ধরন বোঝানো শব্দ: নামের অংশ নয়, তাই খোঁজার সময় বাদ দেওয়া হয়
_FORM_WORDS = {
    "tab",
    "tabs",
    "tablet",
    "tablets",
    "cap",
    "caps",
    "capsule",
    "capsules",
    "syp",
    "syr",
    "syrup",
    "susp",
    "suspension",
    "inj",
    "injection",
    "drop",
    "drops",
    "cream",
    "oint",
    "ointment",
    "gel",
    "sachet",
    "supp",
    "suppository",
    "inh",
    "inhaler",
    "sol",
    "solution",
    "pediatric",
    "paed",
}

# একক: শক্তির সংখ্যা রাখা হয়, একক বাদ দেওয়া হয়
_UNIT_WORDS = {"mg", "mcg", "g", "gm", "ml", "iu", "unit", "units", "%"}

# প্রচলিত সংক্ষেপ → পূর্ণ রূপ
_ABBREVIATIONS = {
    "ext": "extend",
    "xtend": "extend",
    "extnd": "extend",
    "xtra": "extra",
    "plas": "plus",
}

# OCR-এ অক্ষরের মাঝে ভুল করে পড়া সংখ্যা: "Sec1o" → "seclo", "Max0pro" → "maxopro"
_OCR_DIGIT_TO_LETTER = {"0": "o", "1": "l", "5": "s", "8": "b"}
_DIGIT_BETWEEN_LETTERS = re.compile(r"(?<=[a-z])([0158])(?=[a-z])")
# নামের শেষে লেগে থাকা একটা সংখ্যা, যার পরে আসল শক্তি আছে: "Maxpr0 40" → "maxpro 40"
_DIGIT_ENDING_WORD = re.compile(r"(?<=[a-z]{3})([0158])(?=\s+\d)")


@dataclass(frozen=True)
class ParsedName:
    """স্বাভাবিক করা নাম আর শক্তির সংখ্যাগুলো।"""

    name: str
    strengths: tuple[str, ...]


def _basic_clean(text: str) -> str:
    text = unicodedata.normalize("NFKC", text).translate(_BANGLA_DIGITS).lower()
    text = _DIGIT_BETWEEN_LETTERS.sub(lambda m: _OCR_DIGIT_TO_LETTER[m.group(1)], text)
    text = _DIGIT_ENDING_WORD.sub(lambda m: _OCR_DIGIT_TO_LETTER[m.group(1)], text)
    text = text.replace("+", " plus ")
    # "seclo20" → "seclo 20", "20mg" → "20 mg"
    text = re.sub(r"(?<=[a-z])(?=\d)|(?<=\d)(?=[a-z])", " ", text)
    # দশমিক বিন্দু রেখে বাকি যতিচিহ্ন বাদ
    text = re.sub(r"(?<!\d)\.|\.(?!\d)", " ", text)
    text = re.sub(r"[^a-z0-9.\s]", " ", text)
    return text


def parse(text: str) -> ParsedName:
    """নাম আর শক্তি আলাদা করে।

    >>> parse("Tab. Seclo-20mg")
    ParsedName(name='seclo', strengths=('20',))
    """
    words: list[str] = []
    strengths: list[str] = []
    for token in _basic_clean(text).split():
        if re.fullmatch(r"\d+(\.\d+)?", token):
            strengths.append(token)
        elif token in _FORM_WORDS or token in _UNIT_WORDS:
            continue
        else:
            words.append(_ABBREVIATIONS.get(token, token))
    return ParsedName(name=" ".join(words), strengths=tuple(strengths))


def normalize_brand(brand: str) -> str:
    """Database-এ রাখার জন্য brand-এর স্বাভাবিক রূপ। "Cef-3" এর মতো নামে সংখ্যা থাকে, সেটা রাখা হয়।"""
    text = _basic_clean(brand)
    words = [_ABBREVIATIONS.get(t, t) for t in text.split() if t not in _FORM_WORDS]
    return " ".join(words)


def strength_numbers(strength: str) -> tuple[str, ...]:
    """ "500 mg + 65 mg" → ("500", "65")"""
    return tuple(re.findall(r"\d+(?:\.\d+)?", strength.translate(_BANGLA_DIGITS)))
