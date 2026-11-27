"""Cheaper brands of the same medicine: only true equivalents, cheapest first."""

import pytest
from fastapi.testclient import TestClient

from app.drugs.alternatives import cheaper_alternatives, same_medicine
from app.drugs.catalog import CatalogError, _parse_price, parse_rows
from app.drugs.models import Drug
from app.main import app


def drug(i, brand, strength, generic, form="Tablet", price=None, verified=False) -> Drug:
    return Drug(
        id=i,
        brand=brand,
        strength=strength,
        generic=generic,
        form=form,
        source="test",
        verified=verified,
        unit_price_bdt=price,
    )


SECLO = drug(1, "Seclo", "20 mg", "Omeprazole", "Capsule", 6)
LOSECTIL = drug(2, "Losectil", "20 mg", "Omeprazole", "Capsule", 5)
OMEP_TAB = drug(3, "Omep", "20 mg", "Omeprazole", "Tablet", 4)
SECLO_40 = drug(4, "Seclo", "40 mg", "Omeprazole", "Capsule", 3)
ESO = drug(5, "Nexum", "20 mg", "Esomeprazole", "Tablet", 2)
NO_PRICE = drug(6, "Omenix", "20 mg", "Omeprazole", "Capsule")
DEARER = drug(7, "Omidon", "20 mg", "Omeprazole", "Capsule", 8)
CATALOG = [SECLO, LOSECTIL, OMEP_TAB, SECLO_40, ESO, NO_PRICE, DEARER]


def test_only_cheaper_equivalents_cheapest_first():
    result = cheaper_alternatives(SECLO, CATALOG)
    assert [(a.drug.brand, a.saving_percent) for a in result.alternatives] == [
        ("Omep", 33),  # a plain tablet may replace a plain capsule
        ("Losectil", 16),
    ]
    assert not result.prices_verified


def test_other_strength_ingredient_or_release_is_never_offered():
    napa = drug(10, "Napa", "500 mg", "Paracetamol", price=1.2)
    extend = drug(11, "Napa Extend", "665 mg", "Paracetamol", "Tablet (Extended Release)", 0.5)
    er_500 = drug(12, "Para ER", "500 mg", "Paracetamol", "Tablet (Extended Release)", 0.5)
    syrup = drug(13, "Napa", "120 mg/5 ml", "Paracetamol", "Suspension", 0.5)
    combo = drug(14, "Napa Extra", "500 mg + 65 mg", "Paracetamol + Caffeine", price=0.5)
    assert cheaper_alternatives(napa, [napa, extend, er_500, syrup, combo]).alternatives == []


def test_ingredient_order_does_not_matter():
    a = drug(20, "Ace Plus", "500 mg + 65 mg", "Paracetamol + Caffeine", price=2.5)
    b = drug(21, "X", "500 mg + 65 mg", "caffeine +  Paracetamol", price=2)
    assert same_medicine(a, b)
    assert [x.drug.brand for x in cheaper_alternatives(a, [a, b]).alternatives] == ["X"]


def test_without_a_price_there_is_nothing_to_compare():
    assert cheaper_alternatives(NO_PRICE, CATALOG).alternatives == []


def test_a_saving_below_one_percent_is_not_worth_a_switch():
    a = drug(30, "A", "500 mg", "Paracetamol", price=100)
    b = drug(31, "B", "500 mg", "Paracetamol", price=99.5)
    assert cheaper_alternatives(a, [a, b]).alternatives == []


def test_prices_verified_only_when_every_shown_price_is():
    a = drug(40, "A", "10 mg", "Cetirizine", price=3, verified=True)
    b = drug(41, "B", "10 mg", "Cetirizine", price=2, verified=True)
    c = drug(42, "C", "10 mg", "Cetirizine", price=1)
    assert cheaper_alternatives(a, [a, b]).prices_verified
    assert not cheaper_alternatives(a, [a, b, c]).prices_verified


def test_catalogue_reads_optional_prices():
    base = {
        "brand": "Napa",
        "strength": "500 mg",
        "generic": "Paracetamol",
        "form": "Tablet",
        "manufacturer": "",
        "source": "t",
        "verified": "false",
    }
    drugs, report = parse_rows([base | {"unit_price_bdt": "1.20"}, base | {"brand": "Ace"}])
    assert [d.unit_price_bdt for d in drugs] == [1.2, None]
    _, report = parse_rows([base | {"unit_price_bdt": "free"}])
    assert report.errors and "unit_price_bdt" in report.errors[0]
    with pytest.raises(CatalogError):
        _parse_price("-3", 2)


# --- API ---------------------------------------------------------------------------------------
@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


def test_api_lists_cheaper_brands_from_the_seed(client):
    seclo = client.get("/drugs/search", params={"q": "Seclo"}).json()
    seclo_20 = next(c["drug"] for c in seclo if c["drug"]["strength"] == "20 mg")
    body = client.get(f"/drugs/{seclo_20['id']}/alternatives").json()
    assert body["drug"]["brand"] == "Seclo"
    assert body["alternatives"][0]["drug"]["brand"] == "Losectil"
    assert body["alternatives"][0]["drug"]["unit_price_bdt"] < seclo_20["unit_price_bdt"]
    assert body["prices_verified"] is False  # development seed


def test_api_unknown_drug(client):
    r = client.get("/drugs/99999/alternatives")
    assert r.status_code == 404
    assert r.json()["detail"]["code"] == "drug_not_found"
