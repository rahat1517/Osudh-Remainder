import io
import json

import httpx2
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.drugs.models import Confidence
from app.main import app
from app.prescriptions.errors import ReaderError
from app.prescriptions.images import prepare_image
from app.prescriptions.local_reader import HybridReader, LocalModelReader, needs_cloud
from app.prescriptions.schemas import ImageQuality
from app.security.auth import TokenVerifier
from app.training.deid import TextLine, is_personal_line, redact
from app.training.service import TrainingError, TrainingLabel, TrainingService, group_key

from .prescription_factories import M, extraction, image_bytes, medicine
from .test_security import SECRET, token

LABEL = TrainingLabel.model_validate(
    {
        "medicines": [
            {
                "name": "Seclo",
                "strength": "20 mg",
                "dose_pattern": "1+0+1",
                "timing": "before_meal",
                "duration_days": 30,
            }
        ]
    }
)


# --- De-identification ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "line",
    [
        "নাম: নমুনা রোগী",
        "বয়স: ৪৫",
        "Name: Rahim Uddin   Age: 62 yrs",
        "Mobile: 01712-345678",
        "০১৭১২৩৪৫৬৭৮",
        "Address: Mirpur 10, Dhaka",
        "গ্রাম: চরপাড়া, থানা: সদর",
        "Reg No: 123456",
    ],
)
def test_personal_lines_are_detected(line):
    assert is_personal_line(line)


@pytest.mark.parametrize(
    "line",
    [
        "Rx",
        "Tab. Seclo 20mg 1+0+1 খাবারের আগে ১ মাস",
        "Cap. Moxacil 500mg 1 TDS x 7 days",
        "CBC, Lipid profile",
    ],
)
def test_medicine_lines_are_kept(line):
    assert not is_personal_line(line)


def test_redaction_blacks_out_only_personal_lines():
    img = image_bytes(size=(600, 400))
    lines = [
        TextLine("Name: Rahim", (20, 20, 200, 40)),
        TextLine("Tab. Seclo 20mg", (20, 100, 300, 120)),
    ]
    out, count = redact(img, lines)
    assert count == 1
    pic = Image.open(io.BytesIO(out)).convert("L")
    assert pic.getpixel((100, 30)) < 30  # blacked out
    assert pic.getpixel((100, 110)) > 200  # untouched (white)


# --- Collection service ----------------------------------------------------------------------------


class FakeRepo:
    def __init__(self, version):
        self.version, self.inserted = version, []

    def consent_version(self, user_id):
        return self.version

    def insert_example(self, **fields):
        self.inserted.append(fields)
        return "ex-1"


class FakeStore:
    def __init__(self):
        self.files = {}

    def put(self, path, data):
        self.files[path] = data


class FakeDetector:
    def detect(self, image):
        return [TextLine("নাম: নমুনা রোগী", (10, 10, 300, 40))]


def exif_image():
    exif = Image.Exif()
    exif[0x8825] = {2: (23.0, 48.0, 0.0)}
    return image_bytes(exif=exif)


def test_submission_requires_consent():
    with pytest.raises(TrainingError) as exc:
        TrainingService(FakeRepo(None), FakeStore(), FakeDetector(), "pepper").submit(
            "u", image_bytes(), LABEL
        )
    assert exc.value.code == "training_not_consented"


def test_submission_stores_redacted_image_without_metadata():
    repo, store = FakeRepo(1), FakeStore()
    result = TrainingService(repo, store, FakeDetector(), "pepper").submit(
        "user-1", exif_image(), LABEL
    )
    assert result.redacted_lines == 1
    ((path, data),) = store.files.items()
    assert path.startswith("training/") and not Image.open(io.BytesIO(data)).getexif()
    fields = repo.inserted[0]
    assert fields["label"]["medicines"][0]["name"] == "Seclo"
    assert fields["group_key"] == group_key("user-1", "pepper") != group_key("user-1", "other")
    assert "user-1" not in fields["group_key"]


def test_labels_carry_no_free_text():
    assert set(TrainingLabel.model_json_schema()["$defs"]["ConfirmedMedicine"]["properties"]) == {
        "name",
        "strength",
        "dose_pattern",
        "timing",
        "duration_days",
        "continue_indefinitely",
        "as_needed",
    }


# --- API ------------------------------------------------------------------------------------------


@pytest.fixture
def client():
    with TestClient(app) as c:
        app.state.token_verifier = TokenVerifier(jwt_secret=SECRET)
        yield c
        app.state.token_verifier = None
        app.state.training_service = None


def post_example(client, label=None):
    return client.post(
        "/training/examples",
        files={"image": ("rx.jpg", image_bytes(), "image/jpeg")},
        data={"label": label or LABEL.model_dump_json()},
        headers={"Authorization": f"Bearer {token('user-1')}"},
    )


def test_api_disabled_without_configuration(client):
    app.state.training_service = None
    assert post_example(client).json()["detail"]["code"] == "training_disabled"


def test_api_requires_consent_and_valid_label(client):
    app.state.training_service = TrainingService(FakeRepo(None), FakeStore(), FakeDetector(), "p")
    r = post_example(client)
    assert (r.status_code, r.json()["detail"]["code"]) == (403, "training_not_consented")
    app.state.training_service = TrainingService(FakeRepo(1), FakeStore(), FakeDetector(), "p")
    assert (
        post_example(client, json.dumps({"medicines": []})).json()["detail"]["code"]
        == "invalid_label"
    )
    ok = post_example(client)
    assert ok.status_code == 202 and ok.json()["status"] == "queued_for_review"


# --- Local and hybrid readers -----------------------------------------------------------------------


def test_local_reader_parses_schema_constrained_json():
    expected = extraction(medicine())

    def handler(request):
        body = json.loads(request.content)
        assert body["response_format"]["json_schema"]["strict"] is True
        assert body["messages"][1]["content"][0]["image_url"]["url"].startswith(
            "data:image/jpeg;base64,"
        )
        return httpx2.Response(
            200, json={"choices": [{"message": {"content": expected.model_dump_json()}}]}
        )

    reader = LocalModelReader(
        "http://vllm:8000", "oshudh-reader", httpx2.Client(transport=httpx2.MockTransport(handler))
    )
    assert reader.read(prepare_image(image_bytes())) == expected


def test_local_reader_errors_become_reader_errors():
    reader = LocalModelReader(
        "http://x",
        "m",
        httpx2.Client(
            transport=httpx2.MockTransport(lambda r: httpx2.Response(200, json={"choices": []}))
        ),
    )
    with pytest.raises(ReaderError):
        reader.read(prepare_image(image_bytes()))


class StubReader:
    def __init__(self, result=None, error=None):
        self.result, self.error, self.calls = result, error, 0

    def read(self, image):
        self.calls += 1
        if self.error:
            raise self.error
        return self.result


def test_needs_cloud_policy():
    assert not needs_cloud(extraction(medicine()))
    assert needs_cloud(extraction(medicine(), quality=ImageQuality.POOR))
    assert needs_cloud(extraction(medicine(name_confidence=Confidence.LOW)))
    assert needs_cloud(extraction())
    assert needs_cloud(
        extraction(medicine(name_confidence=M, strength_confidence=M))
    )  # 2/5 uncertain


def test_hybrid_routes_and_counts():
    image = prepare_image(image_bytes())
    sure, unsure = extraction(medicine()), extraction(medicine(name_confidence=Confidence.LOW))
    cloud_answer = extraction(medicine(name="Cloud"))

    local, cloud = StubReader(sure), StubReader(cloud_answer)
    hybrid = HybridReader(local, cloud)
    assert hybrid.read(image) == sure and cloud.calls == 0

    hybrid._local = StubReader(unsure)
    assert hybrid.read(image) == cloud_answer

    hybrid._local = StubReader(error=ReaderError("ai_failed", "down"))
    assert hybrid.read(image) == cloud_answer
    assert dict(hybrid.routes) == {"local": 1, "cloud_fallback": 1, "cloud_after_error": 1}


# --- Server wiring ------------------------------------------------------------------------------
def test_repository_opens_a_pooler_safe_connection_per_call(monkeypatch):
    # Regression: the server passed DATABASE_URL (a string) where a connection was expected, so
    # every shared example failed
    from app.training import repository

    calls = []

    class FakeConn:
        def __init__(self):
            self.committed = False

        def __enter__(self):
            return self

        def __exit__(self, *exc):
            return False

        def execute(self, sql, params):
            calls.append(sql.split()[0])
            row = (2,) if sql.lstrip().startswith("select") else ("example-1",)
            return type("Cursor", (), {"fetchone": lambda _self: row})()

        def commit(self):
            self.committed = True

    def fake_connect(url, **kw):
        assert url == "postgresql://u:p@pooler:6543/postgres"
        assert kw["prepare_threshold"] is None  # Supabase's pooler has no prepared statements
        return FakeConn()

    monkeypatch.setattr(repository.psycopg, "connect", fake_connect)
    repo = repository.PostgresTrainingRepository("postgresql://u:p@pooler:6543/postgres")
    assert repo.consent_version("user") == 2
    fields = dict(
        user_id="u",
        consent_version=2,
        image_path="training/x.jpg",
        label={"medicines": []},
        group_key="g",
        redacted_lines=1,
    )
    assert repo.insert_example(**fields) == "example-1"
    assert calls == ["select", "insert"]


def test_training_service_is_built_only_with_all_settings():
    from app.config import Settings
    from app.main import build_training_service

    base = dict(
        database_url="postgresql://u:p@pooler:6543/postgres",
        supabase_url="https://x.supabase.co",
        supabase_service_role_key="service",
        training_pepper="pepper",
    )
    assert build_training_service(Settings(_env_file=None, **base)) is not None
    for missing in base:
        settings = Settings(_env_file=None, **{**base, missing: None})
        assert build_training_service(settings) is None


def test_ocr_redaction_blacks_out_the_whole_patient_row():
    pytest.importorskip("rapidocr_onnxruntime")
    from PIL import ImageDraw, ImageFont

    from app.prescriptions.ocr_reader import RapidOcrEngine
    from app.training.deid import OcrLineDetector

    font = ImageFont.load_default(size=34)
    img = Image.new("RGB", (1200, 700), "white")
    draw = ImageDraw.Draw(img)
    # Label and name far apart: OCR returns them as separate boxes
    draw.text((60, 120), "Patient:", fill="black", font=font)
    draw.text((420, 120), "Karim Uddin", fill="black", font=font)
    draw.text((60, 260), "1. Tab. Seclo 20 mg  1+0+1", fill="black", font=font)
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=92)
    engine = RapidOcrEngine()
    redacted, count = redact(out.getvalue(), OcrLineDetector(engine).detect(out.getvalue()))
    assert count == 1
    texts = " ".join(line.text for line in engine.lines(redacted))
    assert "Karim" not in texts and "Patient" not in texts
    assert "Seclo" in texts
