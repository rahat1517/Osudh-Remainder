"""Rule-based reading of prescription text (the output of OCR) into a `PrescriptionExtraction`.

This is the free, self-hosted alternative to the Claude reader: OCR turns the photo into lines of
text and these rules find the medicines in them. It covers the common Bangladeshi layout

    1. Tab. Seclo 20 mg
       1+0+1  khabar age  30 din

with English, Bangla and transliterated (Banglish) instructions, and Latin abbreviations (BD, TDS,
HS, SOS). Anything it is unsure about gets a lower confidence, so the app asks the user to check.

Privacy: lines before the first medicine (doctor, patient name, age, date) are never returned, and
only instruction-like lines are attached to a medicine, so names and phone numbers do not leak into
`raw_text`.
"""

import re
from dataclasses import dataclass

from app.drugs.models import Confidence
from app.prescriptions.dose import normalize_dose_pattern
from app.prescriptions.schemas import (
    ExtractedMedicine,
    ImageQuality,
    PrescriptionExtraction,
    Timing,
)


@dataclass(frozen=True)
class TextLine:
    text: str
    score: float = 1.0  # OCR recognition confidence, 0-1


# --- Medicine line ------------------------------------------------------------------------------
_FORMS = {
    "tab": "Tab",
    "tablet": "Tab",
    "tb": "Tab",
    "t": "Tab",
    "cap": "Cap",
    "capsule": "Cap",
    "c": "Cap",
    "syp": "Syp",
    "syrup": "Syp",
    "susp": "Susp",
    "suspension": "Susp",
    "inj": "Inj",
    "injection": "Inj",
    "drop": "Drop",
    "drops": "Drop",
    "eye drop": "Drop",
    "cream": "Cream",
    "oint": "Oint",
    "ointment": "Oint",
    "gel": "Gel",
    "inh": "Inh",
    "inhaler": "Inh",
    "sachet": "Sachet",
    "supp": "Supp",
    "ট্যাব": "Tab",
    "ক্যাপ": "Cap",
    "সিরাপ": "Syp",
}
_HANDWRITTEN_TAB = re.compile(r"t[o0]u?b[oa]?")
# Single letters ("T.", "C.") only count with a dot, so ordinary words are not taken as forms
# A list item may start with a number ("1.", "2)", "(3)") or, in handwriting, a bullet dot or dash
_ITEM_PREFIX = r"^\s*(?:\d{1,2}\s*[.)]|\(\d{1,2}\)|[.•·*\-–])?\s*"
_FORM_RE = re.compile(
    _ITEM_PREFIX
    # "tob", "toub", "tobo": how OCR reads a handwritten "Tab"
    + r"(?P<form>(?:eye\s+drop|tablet|tab|tb|t[o0]u?b[oa]?|capsule|cap|syrup|syp|suspension|susp"
    r"|injection|inj|drops?|cream|ointment|oint|gel|inhaler|inh|sachet|supp|ট্যাব|ক্যাপ|সিরাপ)\.?|[tc]\.)"
    # The form word ends here: "Tobacco" and "Capsicum" are not forms, "TabNapa" (glued) is
    r"(?:(?<=\.)|(?-i:(?![a-z])))"
    r"\s*(?P<rest>\S.*)$",
    re.IGNORECASE,
)
_NUMBERED_RE = re.compile(r"^\s*\d{1,2}\s*[.)]\s*(?P<rest>[A-Za-z].*)$")

_STRENGTH_RE = re.compile(
    r"\d+(?:\.\d+)?\s*(?:mg|mcg|µg|gm|g|ml|iu|%)"
    r"(?:\s*/\s*\d*(?:\.\d+)?\s*ml)?"
    r"(?:\s*\+\s*\d+(?:\.\d+)?\s*(?:mg|mcg|iu))?",
    re.IGNORECASE,
)

# --- Dose ---------------------------------------------------------------------------------------
# Characters OCR confuses with digits, only replaced inside a dose-shaped token
_DIGIT_LIKE = "0-9০-৯½¼¾lIi|oO"
_DOSE_PART = rf"[{_DIGIT_LIKE}.]+(?:/[0-9]+)?"
# One separator throughout: "1+0+1" or "1-0-1". A dash after a "+" pattern starts something else
# ("১+০+০ — ২ মাস" is 1+0+0 for 2 months, not the dose 1+0+0+2).
# Never stop inside a longer pattern: "1+0+1AC" must not be read as "1+0".
_DOSE_RE = re.compile(
    rf"(?<![\w/])("
    rf"{_DOSE_PART}(?:\s*\+\s*{_DOSE_PART}){{1,3}}(?![{_DIGIT_LIKE}./]|\s*\+)"
    rf"|{_DOSE_PART}(?:\s*[\-–—]\s*{_DOSE_PART}){{1,3}}(?![{_DIGIT_LIKE}./]|\s*[\-–—])"
    rf")"
)
_LOOKALIKES = str.maketrans({"l": "1", "I": "1", "i": "1", "|": "1", "o": "0", "O": "0"})

_FREQUENCIES = [
    (re.compile(r"\b(?:qid|qds|4\s*times)\b", re.I), "1+1+1+1"),
    (re.compile(r"\b(?:tds|tid|thrice|3\s*times)\b", re.I), "1+1+1"),
    (re.compile(r"\b(?:bd|bid|twice|2\s*times)\b", re.I), "1+0+1"),
    (re.compile(r"\b(?:od|once\s+daily|once\s+a\s+day|daily)\b", re.I), "1+0+0"),
    (re.compile(r"\b(?:hs|at\s+night|bedtime)\b", re.I), "0+0+1"),
]

# --- Timing -------------------------------------------------------------------------------------
_TIMINGS = [
    (Timing.EMPTY_STOMACH, r"khali\s*pete|empty\s*stomach|খালি\s*পেটে"),
    (
        Timing.BEFORE_MEAL,
        r"khabar(?:er)?\s*(?:age|agey|aage)|before\s*(?:meal|food|eating)s?|\ba\.?c\.?\b"
        r"|খাবারের\s*আগে|খাওয়ার\s*আগে",
    ),
    (
        Timing.AFTER_MEAL,
        r"khabar(?:er)?\s*(?:pore|porey|pre)|bhora\s*pete|after\s*(?:meal|food|eating)s?"
        r"|\bp\.?c\.?\b|খাবারের\s*পরে|খাওয়ার\s*পরে|ভরা\s*পেটে",
    ),
    (Timing.WITH_MEAL, r"with\s*(?:meal|food)s?|khabar(?:er)?\s*(?:shathe|sathe)|খাবারের\s*সাথে"),
    (Timing.BEDTIME, r"ghumanor\s*age|bed\s*time|\bh\.?s\.?\b|ঘুমানোর\s*আগে|রাতে\s*শোয়ার\s*আগে"),
]
_TIMINGS_RE = [(t, re.compile(p, re.IGNORECASE)) for t, p in _TIMINGS]

# --- Duration -----------------------------------------------------------------------------------
_BANGLA_DIGITS = str.maketrans("০১২৩৪৫৬৭৮৯", "0123456789")
_DURATIONS = [
    (re.compile(r"(\d{1,3})\s*(?:month|months|mas|mash|maas|মাস)\b", re.I), 30),
    (re.compile(r"(\d{1,3})\s*(?:weeks?|wks?|saptah|সপ্তাহ)\b", re.I), 7),
    (re.compile(r"(\d{1,3})\s*(?:days?|din|dn|d|দিন)\b", re.I), 1),
]
_CONTINUE_RE = re.compile(r"চলবে|cholbe|chalbe|continue|cont\b|\bcont\.", re.IGNORECASE)
_AS_NEEDED_RE = re.compile(
    r"\bsos\b|\bprn\b|প্রয়োজনে|proyojone|projojone|if\s+needed|when\s+needed|as\s+needed"
    r"|ব্যথা\s*হলে|jor\s*hole|জ্বর\s*হলে",
    re.IGNORECASE,
)

# Lines that end the medicine list ("Next visit after 7 days" must not become a duration)
_STOP_RE = re.compile(
    r"^\s*(?:adv|advice|next\s*visit|follow|review|investigation|inv\b|test|dx|diagnosis|c/c"
    r"|পরামর্শ|উপদেশ|পরবর্তী|আবার\s*আসবেন)",
    re.IGNORECASE,
)

_PRESCRIPTION_HINTS = re.compile(
    r"\brx\b|℞|\bmg\b|\btab\b|\bcap\b|\bsyp\b|\badv"
    # The doctor's header and a dose pattern ("1+0+1") are as telling as a medicine
    r"|\bmbbs\b|\bbmdc\b|\bfcps\b|\bfrcs\b|\bmrcp\b|\d\s*\+\s*\d\s*\+\s*\d",
    re.IGNORECASE,
)
# Fewer lines than this, or a poor read, is too little to say an image is NOT a prescription:
# a blurred photo of one often gives a few lines of garbage
_MIN_LEGIBLE_LINES = 3


def _base_confidence(score: float) -> Confidence:
    if score >= 0.9:
        return Confidence.HIGH
    if score >= 0.7:
        return Confidence.MEDIUM
    return Confidence.LOW


def _cap(level: Confidence, ceiling: Confidence) -> Confidence:
    order = [Confidence.LOW, Confidence.MEDIUM, Confidence.HIGH]
    return order[min(order.index(level), order.index(ceiling))]


_GLUED_ABBREVIATIONS = re.compile(r"(?i)\b(qid|qds|tds|tid|bd|bid|od|hs)(ac|pc)\b")


def _unglue(text: str) -> str:
    """OCR often drops spaces: "1+0+1AC x1month", "400mg1QIDPC" → separate tokens."""
    text = re.sub(r"(?<=[A-Za-z])(?=\d)|(?<=\d)(?=[A-Za-z])", " ", text)
    return _GLUED_ABBREVIATIONS.sub(r"\1 \2", text)


def _find_dose(text: str) -> tuple[str | None, str | None, bool]:
    """(raw, canonical pattern, certain).

    `certain` is False for abbreviations such as BD, and when OCR look-alikes had to be guessed
    ("o+o+1" read as 0+0+1).
    """
    for m in _DOSE_RE.finditer(text):
        raw = m.group(1).strip()
        cleaned = raw.translate(_LOOKALIKES)
        pattern = normalize_dose_pattern(cleaned)
        if pattern:
            return raw, pattern, cleaned == raw
    for regex, pattern in _FREQUENCIES:
        if m := regex.search(text):
            return m.group(0), pattern, False
    return None, None, False


def _find_timing(text: str) -> Timing:
    for timing, regex in _TIMINGS_RE:
        if regex.search(text):
            return timing
    return Timing.NOT_SPECIFIED


def _find_duration(text: str) -> tuple[str | None, int | None, bool]:
    ascii_text = text.translate(_BANGLA_DIGITS)
    for regex, factor in _DURATIONS:
        if m := regex.search(ascii_text):
            return m.group(0), int(m.group(1)) * factor, False
    if m := _CONTINUE_RE.search(text):
        return m.group(0), None, True
    return None, None, False


def _is_instruction(text: str) -> bool:
    """A line that belongs to the medicine above it (dose, timing, duration...)."""
    text = _unglue(text)
    return bool(
        _find_dose(text)[1]
        or _find_timing(text) != Timing.NOT_SPECIFIED
        or _find_duration(text)[0]
        or _AS_NEEDED_RE.search(text)
    )


_BARE_STRENGTH_RE = re.compile(r"(?<=[A-Za-z])\s+(\d{2,4}(?:\.\d+)?)(?=\s|$)")


def _split_name(rest: str) -> tuple[str | None, str | None]:
    """'Seclo 20 mg 1+0+1' → ('Seclo', '20 mg')."""
    # "Ciprocin500" → "Ciprocin 500" (a name never ends in digits glued to letters)
    rest = re.sub(r"(?<=[A-Za-z]{3})(?=\d{2,4}(?:\D|$))", " ", rest)
    strength_m = _STRENGTH_RE.search(rest)
    dose_m = _DOSE_RE.search(rest)
    # A bare number after the name is a strength without its unit: "Ciprocin 500 1BD"
    bare_m = _BARE_STRENGTH_RE.search(rest)
    cut = min([m.start() for m in (strength_m, dose_m, bare_m) if m] + [len(rest)])
    # "Napa (500mg)": the bracket around the strength is not part of the name
    name = re.sub(r"[\s,.;:(\[-]+$", "", rest[:cut]).strip() or None
    if strength_m:
        strength = re.sub(r"\s+", " ", strength_m.group(0)).strip()
    elif bare_m and (not dose_m or bare_m.start() < dose_m.start()):
        strength = bare_m.group(1)
    else:
        strength = None
    return name, strength


def _medicine_start(text: str) -> tuple[str | None, str] | None:
    """(form, rest) if the line starts a medicine."""
    if m := _FORM_RE.match(text):
        form_key = m.group("form").rstrip(".").lower()
        form_key = re.sub(r"\s+", " ", form_key)
        if _HANDWRITTEN_TAB.fullmatch(form_key):
            form_key = "tab"
        return _FORMS.get(form_key, form_key.title()), m.group("rest")
    if m := _NUMBERED_RE.match(text):
        rest = m.group("rest")
        if _STRENGTH_RE.search(rest) or _DOSE_RE.search(rest):
            return None, rest
    return None


def _dose_confidence(base: Confidence, pattern: str | None, explicit: bool) -> Confidence:
    if not pattern:
        return Confidence.LOW
    # "BD" or "TDS" says how often, not how many tablets, and a two-part pattern ("1+0") is
    # usually a partly read three-part one: always ask the user to check
    if not explicit or pattern.count("+") < 2:
        return _cap(base, Confidence.MEDIUM)
    return base


def _build(
    form: str | None,
    rest: str,
    lines: list[TextLine],
    ceiling: Confidence = Confidence.HIGH,
) -> ExtractedMedicine:
    raw_text = " ".join(line.text for line in lines)
    text = _unglue(raw_text)
    score = min(line.score for line in lines)
    base = _cap(_base_confidence(score), ceiling)
    name, strength = _split_name(rest)
    as_needed = bool(_AS_NEEDED_RE.search(text))
    dose_raw, dose_pattern, explicit = _find_dose(text)
    if dose_raw and re.search(rf"[A-Za-z]{re.escape(dose_raw)}", raw_text):
        # The pattern was glued to a letter ("V2+o+1/2" for "½+0+½"): part of it may be misread
        explicit = False
    timing = _find_timing(text)
    if timing == Timing.NOT_SPECIFIED and dose_raw and re.fullmatch(r"(?i)hs", dose_raw.strip()):
        timing = Timing.BEDTIME
    duration_raw, days, cont = _find_duration(text)

    return ExtractedMedicine(
        raw_text=raw_text,
        form=form,
        name=name,
        name_confidence=base if name else Confidence.LOW,
        strength=strength,
        # Missing strength is common and harmless; the catalogue match fills it in
        strength_confidence=base if strength else Confidence.MEDIUM,
        dose_raw=dose_raw,
        dose_pattern=dose_pattern,
        dose_confidence=_dose_confidence(base, dose_pattern, explicit),
        timing=timing,
        # OCR cannot read every script and hand; "nothing written" is never certain
        timing_confidence=_cap(base, Confidence.MEDIUM) if timing == Timing.NOT_SPECIFIED else base,
        duration_raw=duration_raw,
        duration_days=days,
        continue_indefinitely=cont,
        duration_confidence=base if (days or cont) else Confidence.MEDIUM,
        as_needed=as_needed,
        other_instructions=None,
    )


def parse_lines(
    lines: list[TextLine], *, blurry: bool = False, soft: bool = False
) -> PrescriptionExtraction:
    """Lines in reading order (top to bottom) → extraction.

    `soft`: the photo is not crisp (see `ocr_reader.is_soft`). OCR can then misread a digit with
    full confidence ("7 days" as "1 days"), so no field is marked certain: the user checks each.

    `blurry`: the photo itself is out of focus (see `ocr_reader.is_blurry`). With nothing found in
    it, it is reported as a poor photo to retake, never as "not a prescription".
    """
    lines = [TextLine(line.text.strip(), line.score) for line in lines if line.text.strip()]
    if not lines:
        return PrescriptionExtraction(
            is_prescription=True, image_quality=ImageQuality.POOR, medicines=[]
        )

    mean = sum(line.score for line in lines) / len(lines)
    quality = (
        ImageQuality.GOOD
        if mean >= 0.9
        else ImageQuality.READABLE_WITH_EFFORT
        if mean >= 0.75
        else ImageQuality.POOR
    )

    ceiling = Confidence.MEDIUM if (soft or blurry) else Confidence.HIGH
    medicines: list[ExtractedMedicine] = []
    current: tuple[str | None, str, list[TextLine]] | None = None
    for line in lines:
        start = _medicine_start(line.text)
        if _STOP_RE.match(line.text):
            start = None
            if current:
                medicines.append(_build(*current, ceiling))
                current = None
            continue
        if start:
            if current:
                medicines.append(_build(*current, ceiling))
            current = (start[0], start[1], [line])
        elif current and _is_instruction(line.text):
            current[2].append(line)
        elif current:
            medicines.append(_build(*current, ceiling))
            current = None
    if current:
        medicines.append(_build(*current, ceiling))

    looks_like_prescription = bool(medicines) or any(
        _PRESCRIPTION_HINTS.search(line.text) for line in lines
    )
    if blurry and quality == ImageQuality.GOOD:
        quality = ImageQuality.READABLE_WITH_EFFORT
    legible = not blurry and quality != ImageQuality.POOR and len(lines) >= _MIN_LEGIBLE_LINES
    if not medicines and not legible:
        # Unclear rather than wrong: the app asks for a clearer photo (or manual entry)
        looks_like_prescription, quality = True, ImageQuality.POOR
    return PrescriptionExtraction(
        is_prescription=looks_like_prescription, image_quality=quality, medicines=medicines
    )
