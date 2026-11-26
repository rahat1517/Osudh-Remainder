"""ডোজের নির্দেশনা ("১+০+১", "½+0+½", "1-0-1") যাচাই ও স্বাভাবিক করা।

AI একটা `dose_pattern` দেয়, কিন্তু সেটা অন্ধভাবে বিশ্বাস করা হয় না। এখানে নিয়ম দিয়ে যাচাই হয়:
সংখ্যাগুলো বাস্তবসম্মত কিনা, ভাগ ঠিক আছে কিনা।
"""

import re
from fractions import Fraction

_BANGLA_DIGITS = str.maketrans("০১২৩৪৫৬৭৮৯", "0123456789")
_FRACTIONS = {"½": "0.5", "¼": "0.25", "¾": "0.75"}
_SEPARATORS = re.compile(r"\s*[+\-–—]\s*")

# এক বেলায় সর্বোচ্চ এতগুলো ইউনিট বাস্তবসম্মত (এর বেশি হলে সম্ভবত ভুল পড়া)
MAX_UNITS_PER_SLOT = 4


def _parse_amount(token: str) -> Fraction | None:
    token = token.strip()
    for sym, dec in _FRACTIONS.items():
        token = token.replace(sym, dec)
    try:
        if "/" in token:
            num, den = token.split("/", 1)
            value = Fraction(int(num), int(den))
        else:
            value = Fraction(token)
    except (ValueError, ZeroDivisionError):
        return None
    if value < 0 or value > MAX_UNITS_PER_SLOT:
        return None
    return value


def _fmt(value: Fraction) -> str:
    return str(int(value)) if value.denominator == 1 else f"{float(value):g}"


def normalize_dose_pattern(pattern: str | None) -> str | None:
    """বৈধ হলে স্বাভাবিক রূপ ("1+0+1"), নইলে None।

    >>> normalize_dose_pattern("১ + ০ + ½")
    '1+0+0.5'
    """
    if not pattern:
        return None
    text = pattern.translate(_BANGLA_DIGITS).strip()
    parts = _SEPARATORS.split(text)
    if not 2 <= len(parts) <= 4:
        return None
    amounts = [_parse_amount(p) for p in parts]
    if any(a is None for a in amounts):
        return None
    if all(a == 0 for a in amounts):
        return None
    return "+".join(_fmt(a) for a in amounts)
