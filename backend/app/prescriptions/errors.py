"""Errors raised while reading a prescription.

Every error carries a stable machine-readable `code` and an English `message`. The app shows the
user a localized text for the code; it never displays `message` directly.
"""


class PrescriptionError(Exception):
    def __init__(self, code: str, message: str, *, retryable: bool = False):
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable


class ImageError(PrescriptionError):
    """The uploaded file cannot be used (codes: image_*)."""


class ReaderError(PrescriptionError):
    """The AI could not read the prescription (codes: ai_*, prescription_too_long)."""


class NotAPrescriptionError(PrescriptionError):
    def __init__(self) -> None:
        super().__init__("not_a_prescription", "The image does not look like a prescription")
