"""Downloads the training fonts and the held-out ones (never trained on, for checking).

python paddleocr/fetch_fonts.py fonts fonts_holdout
"""

import sys
import urllib.request
from pathlib import Path

from fonts import FONTS, HOLDOUT_FONTS

BASE = "https://raw.githubusercontent.com/google/fonts/main"


def fetch(fonts: dict[str, str], folder: Path) -> int:
    folder.mkdir(parents=True, exist_ok=True)
    got = 0
    for name, path in fonts.items():
        for licence in ("ofl", "apache"):
            try:
                urllib.request.urlretrieve(f"{BASE}/{licence}/{path}", folder / name)
                got += 1
                break
            except OSError:
                continue
        else:
            print("skipped", name)
    return got


if __name__ == "__main__":
    train, holdout = Path(sys.argv[1]), Path(sys.argv[2])
    print(fetch(FONTS, train), "training fonts,", fetch(HOLDOUT_FONTS, holdout), "held out")
