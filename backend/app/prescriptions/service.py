from app.prescriptions.errors import NotAPrescriptionError
from app.prescriptions.images import prepare_image
from app.prescriptions.local_reader import HybridReader
from app.prescriptions.reader import Reader
from app.prescriptions.schemas import PrescriptionResult
from app.prescriptions.verifier import PrescriptionVerifier


class PrescriptionService:
    """Image → prepare → Agent 1 (read) → Agent 2 (verify) → result.

    The image is never stored; it only lives in memory for the duration of the request.
    """

    def __init__(self, reader: Reader, verifier: PrescriptionVerifier):
        self._reader = reader
        self._verifier = verifier

    def extract(self, raw_image: bytes, *, allow_cloud: bool = False) -> PrescriptionResult:
        """`allow_cloud`: the user agreed to a consent-only cloud reader (see HybridReader)."""
        image = prepare_image(raw_image)
        if isinstance(self._reader, HybridReader):
            extraction = self._reader.read(image, allow_cloud=allow_cloud)
        else:
            extraction = self._reader.read(image)
        if not extraction.is_prescription:
            raise NotAPrescriptionError()
        return self._verifier.verify(extraction)
