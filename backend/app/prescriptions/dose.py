"""Validating and normalising dose patterns ("১+০+১", "½+0+½", "1-0-1").

The AI returns a `dose_pattern`, but it is not trusted blindly: these rules check that the
amounts are realistic and the fractions valid. Mirrored in app/lib/schedule/dose_pattern.dart.
"""

import re
from fractions import Fraction

_BANGLA_DIGITS = str.maketrans("০১২৩৪৫৬৭৮৯", "0123456789")
_FRACTIONS = {"½": "0.5", "¼": "0.25", "¾": "0.75"}
_SEPARATORS = re.compile(r"\s*[+\-–—]\s*")

# Maximum realistic units per slot; more is probably a misreading
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
    """Canonical form ("1+0+1") if valid, otherwise None.

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
