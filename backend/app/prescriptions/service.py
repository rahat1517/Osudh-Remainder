from app.prescriptions.images import prepare_image
from app.prescriptions.reader import Reader, ReaderError
from app.prescriptions.schemas import PrescriptionResult
from app.prescriptions.verifier import PrescriptionVerifier


class NotAPrescriptionError(ReaderError):
    pass


class PrescriptionService:
    """ছবি → প্রস্তুত → Agent ১ (পড়া) → Agent ২ (যাচাই) → ফলাফল।

    ছবি কোথাও সংরক্ষণ করা হয় না; শুধু memory-তে থাকে।
    """

    def __init__(self, reader: Reader, verifier: PrescriptionVerifier):
        self._reader = reader
        self._verifier = verifier

    def extract(self, raw_image: bytes) -> PrescriptionResult:
        image = prepare_image(raw_image)
        extraction = self._reader.read(image)
        if not extraction.is_prescription:
            raise NotAPrescriptionError(
                "not a prescription", "এটা প্রেসক্রিপশন মনে হচ্ছে না। প্রেসক্রিপশনের ছবি দিন।"
            )
        return self._verifier.verify(extraction)
