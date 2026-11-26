import pytest

from app.drugs.normalize import normalize_brand, parse, strength_numbers


@pytest.mark.parametrize(
    ("text", "name", "strengths"),
    [
        ("Tab. Seclo-20mg", "seclo", ("20",)),
        ("SECLO 20 MG", "seclo", ("20",)),
        ("seclo২০", "seclo", ("20",)),  # Bangla digits
        ("Sec1o 20", "seclo", ("20",)),  # OCR: 1 → l
        ("Maxpr0 40", "maxpro", ("40",)),  # OCR: trailing 0 → o
        ("Vit B1 100", "vit b", ("1", "100")),  # digit after a single letter stays a digit
        ("Napa Ext", "napa extend", ()),
        ("Ace+", "ace plus", ()),
        ("Disopan 0.5mg", "disopan", ("0.5",)),
        ("Syp. Napa 120mg/5ml", "napa", ("120", "5")),
        ("", "", ()),
    ],
)
def test_parse(text, name, strengths):
    parsed = parse(text)
    assert parsed.name == name
    assert parsed.strengths == strengths


def test_normalize_brand_keeps_digits_in_brand_names():
    assert normalize_brand("Cef-3") == "cef 3"
    assert normalize_brand("Calbo D") == "calbo d"


def test_strength_numbers():
    assert strength_numbers("500 mg + 65 mg") == ("500", "65")
    assert strength_numbers("") == ()
