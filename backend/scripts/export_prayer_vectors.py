"""Reference sehri/iftar times computed with the `astral` library, for the app's Ramadan mode test.

    uv run python -m scripts.export_prayer_vectors

Definitions (Islamic Foundation Bangladesh convention, University of Karachi method):
- Fajr (end of sehri): sun 18° below the horizon before sunrise
- Maghrib (iftar): sunset (upper limb at the horizon, with standard refraction)
"""

import datetime as dt
import json
from pathlib import Path

from astral import Observer
from astral.sun import dawn, sunset

OUT = Path(__file__).parents[2] / "spec" / "ramadan" / "vectors.json"
TZ = dt.timezone(dt.timedelta(hours=6))

DISTRICTS = {
    "dhaka": (23.8103, 90.4125),
    "chattogram": (22.3569, 91.7832),
    "sylhet": (24.8949, 91.8687),
    "rajshahi": (24.3745, 88.6042),
    "khulna": (22.8456, 89.5403),
    "barishal": (22.7010, 90.3535),
    "rangpur": (25.7439, 89.2752),
    "mymensingh": (24.7471, 90.4203),
}

# Ramadan 2027 is expected around 8 February to 9 March; include other seasons too
DATES = ["2027-02-08", "2027-02-23", "2027-03-09", "2026-06-21", "2026-12-21", "2028-01-28"]


def main() -> None:
    cases = []
    for name, (lat, lon) in DISTRICTS.items():
        obs = Observer(latitude=lat, longitude=lon, elevation=0)
        for d in DATES:
            day = dt.date.fromisoformat(d)
            fajr = dawn(obs, day, depression=18, tzinfo=TZ)
            maghrib = sunset(obs, day, tzinfo=TZ)
            cases.append(
                {
                    "district": name,
                    "date": d,
                    "fajr": fajr.strftime("%H:%M:%S"),
                    "sunset": maghrib.strftime("%H:%M:%S"),
                }
            )
    OUT.write_text(
        json.dumps(
            {
                "source": "astral (Python), depression 18 for Fajr, UTC+6",
                "districts": DISTRICTS,
                "cases": cases,
            },
            indent=1,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"{len(cases)} cases → {OUT}")


if __name__ == "__main__":
    main()
