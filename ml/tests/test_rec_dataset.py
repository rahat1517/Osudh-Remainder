"""Line labels and synthetic images for the PaddleOCR recognition model."""

import io
import random

from PIL import Image, ImageFont

from oshudh_ml.dataset import Example
from oshudh_ml.export_rec import export
from oshudh_ml.rec_dataset import build_dict, label_line
from oshudh_ml.synth_rec import render, sample_line, to_bangla_digits

MEDICINES = [
    {"name": "Seclo", "strength": "20 mg", "dose_pattern": "1+0+1", "timing": "before_meal"},
    {"name": "Napa Extra", "strength": "500 mg", "dose_pattern": "1+1+1"},
]


def test_confident_correct_lines_are_kept():
    assert label_line("1. Tab. Seclo 20 mg", 0.97, MEDICINES).source == "confident"
    line = label_line("1+0+1 khabar age 30 din", 0.95, MEDICINES)
    assert (line.text, line.source) == ("1+0+1 khabar age 30 din", "confident")


def test_misread_names_are_corrected_from_the_confirmed_value():
    line = label_line("2. Tab. Napa Extro 500 mg", 0.71, MEDICINES)
    assert line is None or line.text == "2. Tab. Napa Extro 500 mg"  # "Napa" itself is right
    line = label_line("1. Tab. Sec1o 20 mg", 0.62, MEDICINES)
    assert (line.text, line.source) == ("1. Tab. Seclo 20 mg", "name_corrected")


def test_unsure_or_unrelated_lines_are_skipped():
    assert label_line("（+0+-", 0.55, MEDICINES) is None  # garbled Bangla digits
    assert label_line("1+0+1 khabar age", 0.6, MEDICINES) is None  # not confident
    assert label_line("2+2+2 after meal", 0.99, MEDICINES) is None  # disagrees with the user
    assert label_line("Dr. Rahim, MBBS", 0.99, MEDICINES) is None


def test_dictionary_has_every_character_once():
    chars = build_dict(["Tab. Seclo 20 mg", "১+০+১ খাবারের আগে"])
    assert len(chars) == len(set(chars))
    assert {"S", "১", "খ", "+", "."} <= set(chars)
    assert " " not in chars


def test_synthetic_lines_cover_bangla_and_latin():
    rng = random.Random(1)
    lines = [sample_line(rng) for _ in range(300)]
    assert any(any(ch in "০১২৩৪৫৬৭৮৯" for ch in line) for line in lines)
    assert any("Tab" in line for line in lines)
    assert any("খাবারের" in line for line in lines)
    assert to_bangla_digits("1+0+1") == "১+০+১"
    assert max(len(line) for line in lines) <= 25  # the model's label limit


def test_rendered_line_is_an_rgb_image():
    font = ImageFont.load_default(size=30)
    img = render("1. Tab. Seclo 20 mg", font, random.Random(3))
    assert img.mode == "RGB" and img.width > img.height > 10


def test_export_writes_paddleocr_lists(tmp_path):
    page = Image.new("RGB", (600, 200), "white")
    buf = io.BytesIO()
    page.save(buf, format="JPEG")

    def ocr(raw):
        return [
            ([[10, 10], [300, 10], [300, 40], [10, 40]], "1. Tab. Sec1o 20 mg", 0.6),
            ([[10, 60], [300, 60], [300, 90], [10, 90]], "（+0+-", 0.5),
        ]

    examples = [Example("e1", "a.jpg", "g1", {"medicines": MEDICINES})]
    stats = export(examples, tmp_path, lambda _: buf.getvalue(), ocr)
    assert stats["name_corrected"] == 1 and stats["skipped"] == 1
    listed = "".join((tmp_path / f"{s}.txt").read_text() for s in ("train", "val", "test"))
    assert listed == "images/e1_0.jpg\t1. Tab. Seclo 20 mg\n"
    assert (tmp_path / "images" / "e1_0.jpg").exists()
    assert "（+0+-" in (tmp_path / "skipped.tsv").read_text()
    assert "S" in (tmp_path / "dict.txt").read_text()


def test_lines_are_only_drawn_with_fonts_that_have_every_character(tmp_path, monkeypatch):
    import oshudh_ml.synth_rec as synth

    latin_only, full = tmp_path / "latin.ttf", tmp_path / "full.ttf"
    latin = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.+-½")
    monkeypatch.setattr(
        synth, "coverage", lambda p: latin if p == latin_only else {chr(c) for c in range(0x10000)}
    )
    monkeypatch.setattr(synth.ImageFont, "truetype", lambda path, size: path)
    drawn = []
    monkeypatch.setattr(synth, "render", lambda text, font, rng: drawn.append((text, font)))
    assert len(list(synth.generate([latin_only, full], 80, seed=2))) == 80
    bangla = [font for text, font in drawn if any("\u0980" <= ch <= "\u09ff" for ch in text)]
    assert bangla and set(bangla) == {str(full)}
    assert str(latin_only) in {font for _, font in drawn}
