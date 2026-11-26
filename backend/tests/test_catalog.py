import pytest

from app.drugs.catalog import CatalogError, load_csv, parse_rows
from app.drugs.importer import main as importer_main
from app.drugs.importer import to_sql


def _row(**overrides):
    row = {
        "brand": "Seclo",
        "strength": "20 mg",
        "generic": "Omeprazole",
        "form": "Capsule",
        "manufacturer": "",
        "source": "test",
        "verified": "false",
    }
    row.update(overrides)
    return row


def test_parse_rows_skips_bad_rows_and_duplicates():
    drugs, report = parse_rows(
        [
            _row(),
            _row(brand="SECLO"),  # একই ওষুধ, বড় হাতের অক্ষরে
            _row(generic=""),
            _row(brand="Maxpro", verified="maybe"),
        ]
    )
    assert [d.brand for d in drugs] == ["Seclo"]
    assert len(report.duplicates) == 1
    assert len(report.errors) == 2


def test_load_csv_requires_columns(tmp_path):
    path = tmp_path / "bad.csv"
    path.write_text("brand,generic\nSeclo,Omeprazole\n", encoding="utf-8")
    with pytest.raises(CatalogError):
        load_csv(path)


def test_to_sql_escapes_quotes():
    drugs, _ = parse_rows([_row(manufacturer="O'Neil Pharma")])
    sql = to_sql(drugs)
    assert "'O''Neil Pharma'" in sql
    assert "'seclo'" in sql  # brand_normalized


def test_importer_refuses_to_write_sql_on_errors(tmp_path):
    src = tmp_path / "drugs.csv"
    src.write_text(
        "brand,strength,generic,form,manufacturer,source,verified\n"
        "Seclo,20 mg,,Capsule,,test,false\n",
        encoding="utf-8",
    )
    out = tmp_path / "seed.sql"
    assert importer_main([str(src), "--sql", str(out)]) == 1
    assert not out.exists()
