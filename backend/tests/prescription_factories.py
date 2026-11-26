"""Factories for AI outputs and images used in tests."""

import io

from PIL import Image

from app.drugs.models import Confidence
from app.prescriptions.schemas import (
    ExtractedMedicine,
    ImageQuality,
    PrescriptionExtraction,
    Timing,
)

H, M, L = Confidence.HIGH, Confidence.MEDIUM, Confidence.LOW


def medicine(**overrides) -> ExtractedMedicine:
    data = dict(
        raw_text="Tab. Seclo 20mg 1+0+1 খাবারের আগে ১ মাস",
        form="Tab",
        name="Seclo",
        name_confidence=H,
        strength="20 mg",
        strength_confidence=H,
        dose_raw="১+০+১",
        dose_pattern="1+0+1",
        dose_confidence=H,
        timing=Timing.BEFORE_MEAL,
        timing_confidence=H,
        duration_raw="১ মাস",
        duration_days=30,
        continue_indefinitely=False,
        duration_confidence=H,
        as_needed=False,
        other_instructions=None,
    )
    data.update(overrides)
    return ExtractedMedicine(**data)


def extraction(*medicines: ExtractedMedicine, quality=ImageQuality.GOOD, is_rx=True):
    return PrescriptionExtraction(
        is_prescription=is_rx, image_quality=quality, medicines=list(medicines)
    )


def image_bytes(size=(800, 1000), fmt="JPEG", exif=None) -> bytes:
    img = Image.new("RGB", size, "white")
    out = io.BytesIO()
    kwargs = {"exif": exif} if exif is not None else {}
    img.save(out, format=fmt, **kwargs)
    return out.getvalue()
