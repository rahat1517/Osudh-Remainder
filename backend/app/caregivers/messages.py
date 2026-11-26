"""Push notification texts.

Push notifications are rendered by the operating system from the server's payload, so this is the
one place the backend holds user-facing text. The caregiver's profile locale selects the language.
"""

TEXTS = {
    "bn": {
        "missed_title": "{patient}-এর ওষুধ খাওয়া হয়নি",
        "missed_body": "{time}-এর {medicines} এখনো খাওয়া হয়নি।",
    },
    "en": {
        "missed_title": "{patient} has not taken a medicine",
        "missed_body": "{medicines} due at {time} has not been taken yet.",
    },
}

_BN_DIGITS = str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯")


def missed_dose_text(locale: str, patient: str, medicines: list[str], time: str) -> tuple[str, str]:
    t = TEXTS.get(locale, TEXTS["bn"])
    if locale == "bn":
        time = time.translate(_BN_DIGITS)
    names = ", ".join(medicines)
    return (
        t["missed_title"].format(patient=patient),
        t["missed_body"].format(medicines=names, time=time),
    )
