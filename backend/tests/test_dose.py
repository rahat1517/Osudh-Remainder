import pytest

from app.prescriptions.dose import normalize_dose_pattern


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("1+0+1", "1+0+1"),
        ("১+০+১", "1+0+1"),
        ("1 - 0 - 1", "1+0+1"),
        ("½+0+½", "0.5+0+0.5"),
        ("0+0+1/2", "0+0+0.5"),
        ("1+1+1+1", "1+1+1+1"),
        ("2+0+2", "2+0+2"),
        ("1+1", "1+1"),
    ],
)
def test_valid_patterns(raw, expected):
    assert normalize_dose_pattern(raw) == expected


@pytest.mark.parametrize(
    "raw",
    [None, "", "BD", "1", "0+0+0", "1+0+1+1+1", "10+0+10", "a+b+c", "1/0+0+1"],
)
def test_invalid_patterns(raw):
    assert normalize_dose_pattern(raw) is None
