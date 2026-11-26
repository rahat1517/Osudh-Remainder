"""Prepares an uploaded image before it is sent to the AI.

- Accepts JPEG, PNG and WebP only
- Downscales large photos (faster and cheaper; larger images do not improve accuracy)
- Removes all metadata (EXIF GPS location, phone model, timestamps) for patient privacy,
  by re-encoding the pixels into a fresh JPEG
- Applies the EXIF orientation so rotated phone photos arrive upright
"""

import io
from dataclasses import dataclass

from PIL import Image, ImageOps, UnidentifiedImageError

from app.prescriptions.errors import ImageError

ALLOWED_FORMATS = {"JPEG": "image/jpeg", "PNG": "image/png", "WEBP": "image/webp"}
MAX_UPLOAD_BYTES = 15 * 1024 * 1024
MAX_LONG_EDGE = 1568
MIN_SHORT_EDGE = 300


@dataclass(frozen=True)
class PreparedImage:
    data: bytes
    media_type: str
    width: int
    height: int


def prepare_image(raw: bytes) -> PreparedImage:
    if not raw:
        raise ImageError("image_missing", "No image was uploaded")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise ImageError("image_too_large", "The image is larger than 15 MB")
    try:
        img = Image.open(io.BytesIO(raw))
        fmt = img.format
        img.load()
    except (UnidentifiedImageError, OSError) as e:
        raise ImageError("image_unreadable", "The file is not a readable image") from e
    if fmt not in ALLOWED_FORMATS:
        raise ImageError("image_format_unsupported", "Only JPEG, PNG and WebP images are accepted")

    img = ImageOps.exif_transpose(img)
    if min(img.size) < MIN_SHORT_EDGE:
        raise ImageError("image_too_small", "The image is too small to read")
    if max(img.size) > MAX_LONG_EDGE:
        img.thumbnail((MAX_LONG_EDGE, MAX_LONG_EDGE), Image.Resampling.LANCZOS)

    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=90)  # fresh encode: no metadata survives
    return PreparedImage(out.getvalue(), "image/jpeg", img.width, img.height)
