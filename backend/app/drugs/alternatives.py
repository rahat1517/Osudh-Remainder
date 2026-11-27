"""Cheaper brands of the same medicine.

Two brands count as the same medicine only when all of these match:
- the active ingredients (in any order: "Paracetamol + Caffeine" = "Caffeine + Paracetamol"),
- every strength number ("500 mg + 65 mg"),
- the dosage form. Plain tablets and capsules may stand in for each other; anything with a
  modifier, such as "Tablet (Extended Release)", only for exactly the same form, since releasing
  the medicine over hours instead of at once changes how it is taken.

The app shows these as information only: the user is told to ask a doctor or pharmacist before
switching, and nothing changes on its own.
"""

import math
import re

from app.drugs.models import Alternative, AlternativesResult, Drug
from app.drugs.normalize import strength_numbers

_INTERCHANGEABLE_FORMS = {"tablet", "capsule"}


def ingredients(generic: str) -> frozenset[str]:
    return frozenset(
        " ".join(part.lower().split()) for part in re.split(r"\s*\+\s*", generic) if part.strip()
    )


def _form_key(form: str) -> str:
    form = " ".join(form.lower().split())
    return "oral solid" if form in _INTERCHANGEABLE_FORMS else form


def same_medicine(a: Drug, b: Drug) -> bool:
    return (
        ingredients(a.generic) == ingredients(b.generic)
        and strength_numbers(a.strength) == strength_numbers(b.strength)
        and _form_key(a.form) == _form_key(b.form)
    )


def cheaper_alternatives(drug: Drug, catalog: list[Drug], limit: int = 5) -> AlternativesResult:
    """Up to `limit` cheaper brands of the same medicine, cheapest first."""
    found: list[Alternative] = []
    price = drug.unit_price_bdt
    if price is not None:
        for other in catalog:
            if other.id == drug.id or other.unit_price_bdt is None:
                continue
            if other.unit_price_bdt >= price or not same_medicine(drug, other):
                continue
            saving = math.floor((1 - other.unit_price_bdt / price) * 100)
            if saving >= 1:  # a few paisa is not worth a switch
                found.append(Alternative(drug=other, saving_percent=saving))
    found.sort(key=lambda a: (a.drug.unit_price_bdt, a.drug.brand))
    found = found[:limit]
    shown = [drug] + [a.drug for a in found]
    return AlternativesResult(
        drug=drug,
        alternatives=found,
        prices_verified=all(d.verified for d in shown if d.unit_price_bdt is not None),
    )
