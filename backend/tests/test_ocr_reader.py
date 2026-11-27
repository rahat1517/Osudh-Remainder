"""PaddleOCR reader: line ordering, error handling, reader selection and one real OCR run."""

import io

import pytest
from PIL import Image, ImageDraw, ImageFont

from app.config import Settings
from app.main import build_reader
from app.prescriptions.errors import ReaderError
from app.prescriptions.images import prepare_image
from app.prescriptions.local_reader import HybridReader, LocalModelReader
from app.prescriptions.ocr_reader import (
    OcrLine,
    OcrPrescriptionReader,
    RapidOcrEngine,
    reading_order,
)
from app.prescriptions.schemas import Timing


def box(x: float, y: float, w: float = 200, h: float = 30):
    return ((x, y), (x + w, y), (x + w, y + h), (x, y + h))


class FakeEngine:
    def __init__(self, lines=None, error=None):
        self._lines, self._error = lines or [], error

    def lines(self, image: bytes):
        if self._error:
            raise self._error
        return self._lines


def white_image() -> bytes:
    out = io.BytesIO()
    Image.new("RGB", (800, 600), "white").save(out, format="JPEG")
    return out.getvalue()


def test_boxes_on_one_row_are_merged_left_to_right():
    lines = reading_order(
        [
            OcrLine("1+0+1", 0.9, box(400, 102)),
            OcrLine("Tab. Seclo 20 mg", 0.95, box(20, 100)),
            OcrLine("7 days", 0.99, box(20, 160)),
        ]
    )
    assert [line.text for line in lines] == ["Tab. Seclo 20 mg 1+0+1", "7 days"]
    assert lines[0].score == 0.9


def test_reader_parses_ocr_lines():
    reader = OcrPrescriptionReader(
        FakeEngine(
            [
                OcrLine("Tab. Seclo 20 mg", 0.98, box(20, 100)),
                OcrLine("1+0+1 khabar age 30 din", 0.97, box(40, 150)),
            ]
        )
    )
    result = reader.read(prepare_image(white_image()))
    (m,) = result.medicines
    assert (m.name, m.dose_pattern, m.timing, m.duration_days) == (
        "Seclo",
        "1+0+1",
        Timing.BEFORE_MEAL,
        30,
    )


def test_engine_failure_is_a_retryable_reader_error():
    reader = OcrPrescriptionReader(FakeEngine(error=RuntimeError("onnx crashed")))
    with pytest.raises(ReaderError) as e:
        reader.read(prepare_image(white_image()))
    assert e.value.code == "ai_failed"
    assert e.value.retryable


# --- Reader selection --------------------------------------------------------------------------
class Cloud:
    def read(self, image):
        raise AssertionError("not called")


def settings(**kw) -> Settings:
    return Settings(_env_file=None, **kw)


def test_auto_uses_claude_when_available_and_ocr_otherwise():
    cloud = Cloud()
    assert build_reader(settings(), cloud) is cloud
    assert isinstance(build_reader(settings(), None), OcrPrescriptionReader)


def test_explicit_modes():
    cloud = Cloud()
    assert build_reader(settings(reader_mode="cloud"), None) is None
    assert isinstance(build_reader(settings(reader_mode="ocr"), cloud), OcrPrescriptionReader)
    hybrid = build_reader(settings(reader_mode="hybrid"), cloud)
    assert isinstance(hybrid, HybridReader)
    assert isinstance(hybrid._local, OcrPrescriptionReader)
    vllm = build_reader(settings(reader_mode="hybrid", local_reader_url="http://gpu:8000"), cloud)
    assert isinstance(vllm._local, LocalModelReader)
    # Hybrid without a key still works, with the free reader alone
    assert isinstance(build_reader(settings(reader_mode="hybrid"), None), OcrPrescriptionReader)


def test_invalid_mode_fails_at_startup():
    with pytest.raises(RuntimeError, match="READER_MODE"):
        build_reader(settings(reader_mode="magic"), None)
    with pytest.raises(RuntimeError, match="LOCAL_READER_URL"):
        build_reader(settings(reader_mode="local"), None)


# --- Real OCR -----------------------------------------------------------------------------------
def rendered_prescription() -> bytes:
    try:
        font = ImageFont.load_default(size=34)
    except (TypeError, OSError):  # Pillow without FreeType
        pytest.skip("No scalable font available")
    img = Image.new("RGB", (1200, 700), "white")
    draw = ImageDraw.Draw(img)
    for i, text in enumerate(
        [
            "Dr. Example, MBBS",
            "Rx",
            "1. Tab. Seclo 20 mg",
            "   1+0+1  khabar age  30 din",
            "2. Tab. Napa 500 mg",
            "   1+1+1  after meal  5 days",
            "3. Tab. Alatrol 10 mg  SOS",
        ]
    ):
        draw.text((60, 50 + i * 85), text, fill="black", font=font)
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=92)
    return out.getvalue()


def test_paddleocr_reads_a_printed_prescription():
    pytest.importorskip("rapidocr_onnxruntime")
    result = OcrPrescriptionReader(RapidOcrEngine()).read(prepare_image(rendered_prescription()))
    by_name = {m.name: m for m in result.medicines}
    assert set(by_name) == {"Seclo", "Napa", "Alatrol"}
    assert by_name["Seclo"].dose_pattern == "1+0+1"
    assert by_name["Seclo"].timing == Timing.BEFORE_MEAL
    assert by_name["Seclo"].duration_days == 30
    assert by_name["Napa"].dose_pattern == "1+1+1"
    assert by_name["Alatrol"].as_needed


def test_engine_is_tuned_for_a_small_cpu():
    from app.prescriptions.ocr_reader import SMALL_CPU_SETTINGS

    assert SMALL_CPU_SETTINGS["intra_op_num_threads"] == 1
    assert SMALL_CPU_SETTINGS["use_cls"] is False


def test_warm_up_loads_the_models_once(monkeypatch):
    engine = RapidOcrEngine()
    loads, runs = [], []

    def fake_engine(image):
        runs.append(image)  # the warm-up also runs the models once
        return [], None

    monkeypatch.setattr(engine, "_load", lambda: loads.append(1) or fake_engine)
    engine.warm_up()
    engine.warm_up()
    assert loads == [1]
    assert len(runs) == 2


def test_shutdown_waits_for_the_model_warm_up():
    # Regression: the process aborted ("terminate called without an active exception") when the
    # app stopped while ONNX Runtime was still loading the models in the warm-up thread
    from fastapi.testclient import TestClient

    from app.main import create_app

    with TestClient(create_app()) as client:
        assert client.get("/health").status_code == 200
    import threading

    assert not [t for t in threading.enumerate() if t.name == "ocr-warm-up"]


def test_text_detection_runs_on_a_small_copy_of_the_photo():
    # Regression: RapidOCR ignored its detection-size setting and detected phone photos at full
    # size, a ~300 MB spike that got the 512 MB server killed mid-scan
    pytest.importorskip("rapidocr_onnxruntime")
    engine = RapidOcrEngine()
    engine.warm_up()
    pre = engine._engine.text_det.get_preprocess(1568)
    assert pre.limit_side_len == 960
    assert pre.limit_type == "max"
