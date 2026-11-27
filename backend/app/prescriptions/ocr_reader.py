"""Free, self-hosted prescription reader: PaddleOCR (via RapidOCR / ONNX Runtime) + text rules.

PaddleOCR's detection and recognition models run on the server's CPU; no external service, no cost
per scan. The pretrained models read printed and clear Latin text well; doctors' handwriting needs
a fine-tuned recognition model (see ml/README.md, "PaddleOCR fine-tuning"), which is loaded from
`OCR_REC_MODEL_PATH` without code changes.
"""

import contextlib
import ctypes
import io
import logging
import threading
from dataclasses import dataclass
from typing import Protocol

from PIL import Image

from app.prescriptions.errors import ReaderError
from app.prescriptions.images import PreparedImage
from app.prescriptions.schemas import PrescriptionExtraction
from app.prescriptions.text_parser import TextLine, parse_lines

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class OcrLine:
    text: str
    score: float
    # Corner points [[x, y] * 4] in image pixels, top-left first
    box: tuple[tuple[float, float], ...]

    @property
    def top(self) -> float:
        return min(y for _, y in self.box)

    @property
    def left(self) -> float:
        return min(x for x, _ in self.box)

    @property
    def height(self) -> float:
        return max(y for _, y in self.box) - self.top


class OcrEngine(Protocol):
    def lines(self, image: bytes) -> list[OcrLine]: ...


def reading_order(lines: list[OcrLine]) -> list[OcrLine]:
    """Top to bottom; boxes on the same text row (overlapping vertically) left to right, merged.

    OCR often splits one written line ("Tab. Seclo 20 mg" ... "1+0+1") into several boxes.
    """
    rows: list[list[OcrLine]] = []
    for line in sorted(lines, key=lambda b: b.top):
        if rows:
            row = rows[-1]
            ref = row[0]
            centre = line.top + line.height / 2
            if ref.top <= centre <= ref.top + ref.height:
                row.append(line)
                continue
        rows.append([line])

    merged: list[OcrLine] = []
    for row in rows:
        row.sort(key=lambda b: b.left)
        merged.append(
            OcrLine(
                text=" ".join(b.text for b in row),
                score=min(b.score for b in row),
                box=row[0].box if len(row) == 1 else _union(row),
            )
        )
    return merged


def _union(row: list[OcrLine]) -> tuple[tuple[float, float], ...]:
    xs = [x for b in row for x, _ in b.box]
    ys = [y for b in row for _, y in b.box]
    return ((min(xs), min(ys)), (max(xs), min(ys)), (max(xs), max(ys)), (min(xs), max(ys)))


# Tuned for a small shared CPU (e.g. Render's free instance, a fraction of one core):
# - one thread: ONNX Runtime's idle threads spin, and many threads on a tiny CPU quota spend it
#   waiting instead of working (a scan took over a minute with the defaults);
# - no angle classifier: photos are already upright (EXIF orientation is applied beforehand);
# - text detection on the image scaled to at most DET_MAX_SIDE px (see _limit_detection_size).
SMALL_CPU_SETTINGS = {
    "intra_op_num_threads": 1,
    "inter_op_num_threads": 1,
    "use_cls": False,
}

# Longest side of the image text detection runs on. Recognition still reads each line from the
# full-resolution photo, so small print stays readable.
DET_MAX_SIDE = 960


def _limit_detection_size(engine, max_side: int = DET_MAX_SIDE) -> None:
    """RapidOCR ignores its own detection-size setting in "max" mode and picks 960, 1500 or
    2000 px from the photo's size, so a phone photo was detected at full size: a ~300 MB spike on
    a 512 MB server, which got the process killed. Fix the size here."""
    from rapidocr_onnxruntime.ch_ppocr_det.utils import DetPreProcess

    det = engine.text_det
    det.get_preprocess = lambda _max_wh: DetPreProcess(max_side, "max", det.mean, det.std)


def _release_memory() -> None:
    """Hand freed memory back to the system after a scan (glibc keeps it otherwise, and the
    process would grow towards the instance limit)."""
    with contextlib.suppress(OSError):  # not glibc (e.g. macOS): nothing to do
        ctypes.CDLL("libc.so.6").malloc_trim(0)


class RapidOcrEngine:
    """PaddleOCR models through RapidOCR (ONNX Runtime). Loaded once, on first use."""

    def __init__(self, rec_model_path: str | None = None, rec_keys_path: str | None = None):
        self._rec_model_path = rec_model_path
        self._rec_keys_path = rec_keys_path
        self._engine = None
        self._lock = threading.Lock()

    def _load(self):
        from rapidocr_onnxruntime import RapidOCR

        kwargs: dict[str, object] = dict(SMALL_CPU_SETTINGS)
        if self._rec_model_path:
            kwargs["rec_model_path"] = self._rec_model_path
            if self._rec_keys_path:
                kwargs["rec_keys_path"] = self._rec_keys_path
            logger.info("Using fine-tuned OCR recognition model %s", self._rec_model_path)
        engine = RapidOCR(**kwargs)
        _limit_detection_size(engine)
        return engine

    def warm_up(self) -> None:
        """Load the models and run them once, now (in the background at startup), rather than on
        the first scan. ONNX Runtime allocates and prepares its weights on a model's first run,
        a one-time spike of about 200 MB; paid at startup it does not add to a scan's photo."""
        with self._lock:
            if self._engine is None:
                self._engine = self._load()
            blank = io.BytesIO()
            Image.new("RGB", (320, 320), "white").save(blank, format="JPEG")
            self._engine(blank.getvalue())
        _release_memory()

    def lines(self, image: bytes) -> list[OcrLine]:
        with self._lock:  # ONNX sessions are shared; keep memory flat on a small instance
            if self._engine is None:
                self._engine = self._load()
            result, _ = self._engine(image)
        _release_memory()
        return [
            OcrLine(text=text, score=float(score), box=tuple((float(x), float(y)) for x, y in box))
            for box, text, score in (result or [])
        ]


# Variance of the Laplacian (edge strength) below which a photo counts as out of focus. Sharp text
# on paper scores in the hundreds or more; a photo blurred until letters run together scores
# below 10 (measured on prescriptions blurred and shrunk like a forwarded gallery picture).
BLUR_THRESHOLD = 10.0
# Below this a photo is not crisp: readable, but OCR may misread a digit and still be confident
# ("7 days" as "1 days" in a forwarded gallery picture, sharpness 54), so nothing is marked certain.
# Crisp prints score 600+, ordinary phone photos 70-150.
SOFT_THRESHOLD = 100.0


def sharpness(image: bytes) -> float | None:
    """Variance of the Laplacian of the image in grey; None if it cannot be decoded."""
    import cv2
    import numpy as np

    grey = cv2.imdecode(np.frombuffer(image, np.uint8), cv2.IMREAD_GRAYSCALE)
    if grey is None:
        return None
    _, std = cv2.meanStdDev(cv2.Laplacian(grey, cv2.CV_32F))
    return float(std[0][0]) ** 2


def is_blurry(image: bytes) -> bool:
    score = sharpness(image)
    return score is not None and score < BLUR_THRESHOLD


class OcrPrescriptionReader:
    def __init__(self, engine: OcrEngine):
        self._engine = engine

    def warm_up_in_background(self) -> threading.Thread | None:
        """Starts loading the models; join the returned thread before the process exits (an ONNX
        Runtime load cut short at interpreter shutdown aborts the process)."""
        warm = getattr(self._engine, "warm_up", None)
        if not warm:
            return None
        thread = threading.Thread(target=warm, name="ocr-warm-up", daemon=True)
        thread.start()
        return thread

    def read(self, image: PreparedImage) -> PrescriptionExtraction:
        try:
            raw = self._engine.lines(image.data)
        except Exception as e:  # noqa: BLE001 - any engine failure is a reader failure
            logger.exception("OCR failed")
            raise ReaderError("ai_failed", "Could not read the image", retryable=True) from e
        lines = reading_order(raw)
        score = sharpness(image.data)
        blurry = score is not None and score < BLUR_THRESHOLD
        soft = score is not None and score < SOFT_THRESHOLD
        extraction = parse_lines(
            [TextLine(line.text, line.score) for line in lines], blurry=blurry, soft=soft
        )
        logger.info(
            "prescription read by OCR: lines=%d medicines=%d quality=%s sharpness=%.0f",
            len(lines),
            len(extraction.medicines),
            extraction.image_quality,
            score or 0,
        )
        return extraction
