"""আপলোড করা ছবি AI-তে পাঠানোর আগে প্রস্তুত করা।

- শুধু JPEG / PNG / WebP গ্রহণ
- বড় ছবি ছোট করা (দ্রুত ও কম খরচ; এর বেশি বড় ছবিতে নির্ভুলতা বাড়ে না)
- ফোনের ছবিতে থাকা EXIF তথ্য (GPS অবস্থান, ফোনের মডেল, সময়) মুছে ফেলা: রোগীর গোপনীয়তার জন্য
- ছবি ঘোরানো থাকলে (EXIF orientation) সোজা করা
"""

import io
from dataclasses import dataclass

from PIL import Image, ImageOps, UnidentifiedImageError

ALLOWED_FORMATS = {"JPEG": "image/jpeg", "PNG": "image/png", "WEBP": "image/webp"}
MAX_UPLOAD_BYTES = 15 * 1024 * 1024
MAX_LONG_EDGE = 1568
MIN_SHORT_EDGE = 300


class ImageError(ValueError):
    """ব্যবহারকারীকে দেখানোর মতো বার্তাসহ ত্রুটি (বাংলা)।"""


@dataclass(frozen=True)
class PreparedImage:
    data: bytes
    media_type: str
    width: int
    height: int


def prepare_image(raw: bytes) -> PreparedImage:
    if not raw:
        raise ImageError("ছবি পাওয়া যায়নি।")
    if len(raw) > MAX_UPLOAD_BYTES:
        raise ImageError("ছবিটা অনেক বড় (সর্বোচ্চ ১৫ MB)।")
    try:
        img = Image.open(io.BytesIO(raw))
        fmt = img.format
        img.load()
    except (UnidentifiedImageError, OSError) as e:
        raise ImageError("এটা ছবি মনে হচ্ছে না। JPEG বা PNG ছবি দিন।") from e
    if fmt not in ALLOWED_FORMATS:
        raise ImageError("শুধু JPEG, PNG বা WebP ছবি দেওয়া যাবে।")

    img = ImageOps.exif_transpose(img)
    if min(img.size) < MIN_SHORT_EDGE:
        raise ImageError("ছবিটা খুব ছোট। প্রেসক্রিপশনের কাছ থেকে আবার ছবি তুলুন।")
    if max(img.size) > MAX_LONG_EDGE:
        img.thumbnail((MAX_LONG_EDGE, MAX_LONG_EDGE), Image.Resampling.LANCZOS)

    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")
    out = io.BytesIO()
    # নতুন করে JPEG বানানো হয়, তাই আসল ফাইলের কোনো EXIF/metadata থাকে না
    img.save(out, format="JPEG", quality=90)
    return PreparedImage(out.getvalue(), "image/jpeg", img.width, img.height)
