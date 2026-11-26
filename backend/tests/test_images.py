import io

import pytest
from PIL import Image

from app.prescriptions.errors import ImageError
from app.prescriptions.images import MAX_LONG_EDGE, prepare_image

from .prescription_factories import image_bytes


def _gps_exif():
    exif = Image.Exif()
    exif[0x0110] = "Secret Phone Model"  # Model
    exif[0x8825] = {2: (23.0, 48.0, 0.0), 4: (90.0, 24.0, 0.0)}  # GPSInfo: Dhaka
    return exif


def test_strips_exif_and_gps():
    raw = image_bytes(exif=_gps_exif())
    assert Image.open(io.BytesIO(raw)).getexif()  # the original carries EXIF
    prepared = prepare_image(raw)
    out = Image.open(io.BytesIO(prepared.data))
    assert not out.getexif()
    assert b"Secret Phone Model" not in prepared.data


def test_resizes_large_images():
    prepared = prepare_image(image_bytes(size=(3000, 4000)))
    assert max(prepared.width, prepared.height) == MAX_LONG_EDGE
    assert prepared.media_type == "image/jpeg"


def test_applies_exif_orientation():
    exif = Image.Exif()
    exif[0x0112] = 6  # rotated 90°
    prepared = prepare_image(image_bytes(size=(1000, 600), exif=exif))
    assert (prepared.width, prepared.height) == (600, 1000)


def test_accepts_png():
    assert prepare_image(image_bytes(fmt="PNG")).media_type == "image/jpeg"


@pytest.mark.parametrize(
    "raw",
    [b"", b"not an image at all", image_bytes(size=(200, 150)), image_bytes(fmt="GIF")],
)
def test_rejects_bad_input(raw):
    with pytest.raises(ImageError) as exc:
        prepare_image(raw)
    assert exc.value.code.startswith("image_")
