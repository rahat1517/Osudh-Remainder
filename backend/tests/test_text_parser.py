"""Rule-based reading of OCR text into medicines."""

import pytest

from app.drugs.models import Confidence
from app.prescriptions.schemas import ImageQuality, Timing
from app.prescriptions.text_parser import TextLine, parse_lines


def parse(*texts: str, score: float = 0.97):
    return parse_lines([TextLine(t, score) for t in texts])


def only(*texts: str, score: float = 0.97):
    result = parse(*texts, score=score)
    assert len(result.medicines) == 1, result.medicines
    return result.medicines[0]


def test_typical_prescription_with_header():
    result = parse(
        "Dr. Rahim Uddin, MBBS",
        "Name: Karim  Age: 45  01712345678",
        "Rx",
        "1. Tab. Seclo 20 mg",
        "1+0+1  khabar age  30 din",
        "2. Cap. Cef-3 200 mg 0+0+1 7 days",
        "Advice: drink plenty of water",
        "Next visit after 15 days",
    )
    assert result.is_prescription
    assert result.image_quality == ImageQuality.GOOD
    seclo, cef = result.medicines
    assert (seclo.form, seclo.name, seclo.strength) == ("Tab", "Seclo", "20 mg")
    assert (seclo.dose_pattern, seclo.timing, seclo.duration_days) == (
        "1+0+1",
        Timing.BEFORE_MEAL,
        30,
    )
    assert (cef.name, cef.strength, cef.dose_pattern, cef.duration_days) == (
        "Cef-3",
        "200 mg",
        "0+0+1",
        7,
    )
    # "Next visit after 15 days" must not become Cef-3's duration, and the header never leaks
    everything = " ".join(m.raw_text for m in result.medicines)
    for private in ("Karim", "01712345678", "Rahim", "visit"):
        assert private not in everything


@pytest.mark.parametrize(
    ("line", "pattern"),
    [
        ("Tab Napa 500mg 1+1+1", "1+1+1"),
        ("Tab Napa 500mg 1-0-1", "1+0+1"),
        ("Tab Napa 500mg ১+০+১", "1+0+1"),
        ("Tab Napa 500mg ½+0+½", "0.5+0+0.5"),
        ("Tab Napa 500mg 1+1+1+1", "1+1+1+1"),
    ],
)
def test_dose_patterns(line, pattern):
    m = only(line)
    assert m.dose_pattern == pattern
    assert m.dose_confidence == Confidence.HIGH


@pytest.mark.parametrize(
    ("text", "pattern"),
    [("BD", "1+0+1"), ("TDS", "1+1+1"), ("QID", "1+1+1+1"), ("OD", "1+0+0"), ("HS", "0+0+1")],
)
def test_frequency_abbreviations_are_used_but_flagged(text, pattern):
    m = only(f"Tab. Napa 500 mg {text}")
    assert m.dose_pattern == pattern
    assert m.dose_confidence == Confidence.MEDIUM


def test_hs_means_bedtime():
    assert only("Tab Rivotril 0.5 mg HS").timing == Timing.BEDTIME


@pytest.mark.parametrize(
    ("instruction", "timing"),
    [
        ("khabar age", Timing.BEFORE_MEAL),
        ("khabarer pore", Timing.AFTER_MEAL),
        ("after meal", Timing.AFTER_MEAL),
        ("before food", Timing.BEFORE_MEAL),
        ("খাবারের আগে", Timing.BEFORE_MEAL),
        ("খাবারের পরে", Timing.AFTER_MEAL),
        ("khali pete", Timing.EMPTY_STOMACH),
        ("খালি পেটে", Timing.EMPTY_STOMACH),
        ("ghumanor age", Timing.BEDTIME),
        ("with food", Timing.WITH_MEAL),
    ],
)
def test_timing(instruction, timing):
    m = only("Tab. Seclo 20 mg", f"1+0+1 {instruction}")
    assert m.timing == timing


def test_missing_timing_is_never_certain():
    m = only("Tab. Seclo 20 mg 1+0+1")
    assert m.timing == Timing.NOT_SPECIFIED
    assert m.timing_confidence == Confidence.MEDIUM


@pytest.mark.parametrize(
    ("text", "days", "cont"),
    [
        ("7 days", 7, False),
        ("৭ দিন", 7, False),
        ("10 din", 10, False),
        ("1 month", 30, False),
        ("2 mas", 60, False),
        ("2 weeks", 14, False),
        ("চলবে", None, True),
        ("continue", None, True),
    ],
)
def test_duration(text, days, cont):
    m = only("Tab. Seclo 20 mg", f"1+0+1 {text}")
    assert (m.duration_days, m.continue_indefinitely) == (days, cont)


@pytest.mark.parametrize("text", ["SOS", "PRN", "প্রয়োজনে", "if needed", "jor hole"])
def test_as_needed(text):
    m = only(f"Tab. Napa 500 mg {text}")
    assert m.as_needed


def test_forms_and_numbered_lines():
    result = parse(
        "Syp. Ambrox 100 ml 2 tsf TDS",
        "C. Omep 20 mg 1+0+1",
        "3) Fexo 120 mg 0+0+1",
        "Cream Neosporin apply",
    )
    assert [(m.form, m.name) for m in result.medicines] == [
        ("Syp", "Ambrox"),
        ("Cap", "Omep"),
        (None, "Fexo"),
        ("Cream", "Neosporin apply"),
    ]


def test_strength_variants():
    assert only("Tab Napa Extra 500 mg + 65 mg 1+0+1").strength == "500 mg + 65 mg"
    assert only("Syp Napa 120 mg/5 ml 1+1+1").strength == "120 mg/5 ml"


def test_dates_and_phone_numbers_are_not_doses():
    result = parse("Date: 12-05-2026", "Mobile 017-1234-5678")
    assert result.medicines == []


def test_low_ocr_confidence_lowers_every_field():
    m = only("Tab. Seclo 20 mg 1+0+1 7 days", score=0.6)
    assert m.name_confidence == Confidence.LOW
    assert m.dose_confidence == Confidence.LOW
    assert parse("Tab. Seclo 20 mg 1+0+1", score=0.6).image_quality == ImageQuality.POOR


def test_unreadable_photo_is_a_poor_prescription_not_a_rejection():
    result = parse_lines([])
    assert result.is_prescription
    assert result.image_quality == ImageQuality.POOR
    assert result.medicines == []


def test_text_without_any_prescription_signs_is_rejected():
    assert not parse("Weekly shopping list", "Rice 5 kg", "Oil 2 litre").is_prescription


def test_instruction_lines_only_attach_to_a_medicine():
    result = parse("1+0+1 after meal", "Tab. Seclo 20 mg", "Hello world")
    assert len(result.medicines) == 1
    assert result.medicines[0].dose_pattern is None


def test_glued_ocr_text_is_split():
    m = only("3.Tab.Esonix 20mg 1+0+1AC x1month")
    assert (m.name, m.dose_pattern, m.timing, m.duration_days) == (
        "Esonix",
        "1+0+1",
        Timing.BEFORE_MEAL,
        30,
    )
    m = only("2.Tab.Filmet 400mg1QIDPC x 7 days")
    assert (m.dose_pattern, m.timing, m.duration_days) == ("1+1+1+1", Timing.AFTER_MEAL, 7)


def test_a_cut_off_pattern_is_never_certain():
    # Regression: "1+0+1AC" was read as "1+0" with high confidence
    assert only("Tab. Esonix 20 mg 1+0").dose_confidence == Confidence.MEDIUM


def test_garbled_bangla_digits_give_no_dose():
    m = only("1. Tab.Zimax 500mg （+0+-")
    assert m.dose_pattern is None
    assert m.dose_confidence == Confidence.LOW


def test_strength_without_unit_ends_the_name():
    m = only("2.Tab.Ciprocin 500 1BD PC x7 days")
    assert (m.name, m.strength, m.dose_pattern, m.timing, m.duration_days) == (
        "Ciprocin",
        "500",
        "1+0+1",
        Timing.AFTER_MEAL,
        7,
    )


def test_glued_weeks_and_written_fractions():
    m = only("1. Tab. Maxpo 20mg 1+0+1beforemeal2wks")
    assert (m.dose_pattern, m.timing, m.duration_days) == ("1+0+1", Timing.BEFORE_MEAL, 14)
    assert only("Tab. Disopan 0.5mg 1/2+0+1/2").dose_pattern == "0.5+0+0.5"


@pytest.mark.parametrize(
    ("line", "pattern"),
    [
        ("Tab Napa 500mg 1+1+l", "1+1+1"),  # OCR read 1 as l
        ("Tab Napa 500mg O+O+1", "0+0+1"),  # OCR read 0 as O
    ],
)
def test_lookalike_digits_are_fixed_but_flagged(line, pattern):
    m = only(line)
    assert m.dose_pattern == pattern
    assert m.dose_confidence == Confidence.MEDIUM


def test_a_pattern_glued_to_a_letter_is_never_certain():
    # Regression: "V2+o+1/2" (OCR for "½+0+½") was read as 2+0+0.5 with high confidence
    m = only("1. Tab. Disopan 0.5mg V2+o+1/2")
    assert m.dose_confidence != Confidence.HIGH


def test_strength_glued_to_the_name_is_split():
    m = only("2.Tab.Ciprocin500 1BD PC x7days")
    assert (m.name, m.strength, m.duration_days) == ("Ciprocin", "500", 7)
    assert only("Tab. Cef-3 200 mg 1+0+1").name == "Cef-3"  # digits that belong to the name


# --- Blurred photos -----------------------------------------------------------------------------
def test_a_few_garbled_lines_are_an_unclear_photo_not_a_non_prescription():
    # A blurred gallery photo of a prescription: OCR returns a little garbage
    result = parse_lines([TextLine("L.T", 0.6), TextLine("14-1ibeg", 0.55)])
    assert result.is_prescription
    assert result.image_quality == ImageQuality.POOR
    assert result.medicines == []


def test_a_blurry_photo_without_medicines_asks_for_a_retake():
    lines = [TextLine(t, 0.95) for t in ["Grocery list", "Rice 5 kg", "Oil 2 litre", "Eggs"]]
    assert not parse_lines(lines).is_prescription  # read clearly: really not a prescription
    blurred = parse_lines(lines, blurry=True)
    assert blurred.is_prescription
    assert blurred.image_quality == ImageQuality.POOR


def test_a_blurry_photo_is_never_good_quality():
    lines = [TextLine("Tab. Seclo 20 mg", 0.98), TextLine("1+0+1 30 din", 0.97)]
    assert parse_lines(lines).image_quality == ImageQuality.GOOD
    blurred = parse_lines(lines, blurry=True)
    assert blurred.image_quality == ImageQuality.READABLE_WITH_EFFORT
    assert [m.name for m in blurred.medicines] == ["Seclo"]


def test_doctor_header_or_dose_pattern_marks_a_prescription():
    header = [TextLine(t, 0.95) for t in ["Dr. Rahman", "MBBS, FCPS", "Chamber: Dhanmondi"]]
    assert parse_lines(header).is_prescription
    dose = [TextLine(t, 0.95) for t in ["Unreadable name", "1 + 0 + 1", "after meal"]]
    assert parse_lines(dose).is_prescription
