"""Free, self-hosted prescription reader: PaddleOCR (via RapidOCR / ONNX Runtime) + text rules.

PaddleOCR's detection and recognition models run on the server's CPU; no external service, no cost
per scan. The pretrained models read printed and clear Latin text well; doctors' handwriting needs
a fine-tuned recognition model (see ml/README.md, "PaddleOCR fine-tuning"), which is loaded from
`OCR_REC_MODEL_PATH` without code changes.
"""

import logging
import threading
from dataclasses import dataclass
from typing import Protocol

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
# - text detection on the image scaled to at most 960 px, instead of enlarged to at least 736 px.
SMALL_CPU_SETTINGS = {
    "intra_op_num_threads": 1,
    "inter_op_num_threads": 1,
    "use_cls": False,
    "det_limit_side_len": 960,
    "det_limit_type": "max",
}


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
        return RapidOCR(**kwargs)

    def warm_up(self) -> None:
        """Load the models now (in the background at startup) rather than on the first scan."""
        with self._lock:
            if self._engine is None:
                self._engine = self._load()

    def lines(self, image: bytes) -> list[OcrLine]:
        with self._lock:  # ONNX sessions are shared; keep memory flat on a small instance
            if self._engine is None:
                self._engine = self._load()
            result, _ = self._engine(image)
        return [
            OcrLine(text=text, score=float(score), box=tuple((float(x), float(y)) for x, y in box))
            for box, text, score in (result or [])
        ]


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
        extraction = parse_lines([TextLine(line.text, line.score) for line in lines])
        logger.info(
            "prescription read by OCR: lines=%d medicines=%d quality=%s",
            len(lines),
            len(extraction.medicines),
            extraction.image_quality,
        )
        return extraction
