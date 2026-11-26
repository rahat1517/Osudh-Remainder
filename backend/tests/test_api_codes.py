"""The backend emits exactly the codes listed in spec/api/codes.json (which the app localizes)."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).parents[2]
CODES = json.loads((ROOT / "spec" / "api" / "codes.json").read_text(encoding="utf-8"))

# Code literals passed to the error/notice constructors used in app/
_PATTERNS = [
    r'(?:ImageError|ReaderError|ScheduleError|AuthError|TrainingError|fail|notice)\(\s*"([a-z_]+)"',
    r'api_error\(\s*status\.\w+,\s*"([a-z_]+)"',
    r'super\(\)\.__init__\(\s*"([a-z_]+)"',
]


def _emitted() -> set[str]:
    source = "\n".join(
        p.read_text(encoding="utf-8") for p in (ROOT / "backend" / "app").rglob("*.py")
    )
    return {code for pattern in _PATTERNS for code in re.findall(pattern, source)}


def test_emitted_codes_match_spec():
    spec = set(CODES["errors"]) | set(CODES["notices"])
    emitted = _emitted()
    assert emitted - spec == set(), "codes emitted but missing from spec/api/codes.json"
    assert spec - emitted == set(), "codes in spec/api/codes.json that are never emitted"
