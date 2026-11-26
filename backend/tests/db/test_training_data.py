"""Consent rules for training data (Phase 11)."""

import json

from .conftest import as_user, fails_with, new_user, psycopg


def _example(db, user, exported=False):
    return db.execute(
        "insert into training_examples "
        "(user_id, consent_version, image_path, label, group_key, exported_at) "
        "values (%s, 1, 'training/x.jpg', %s, 'g', %s) returning id",
        (user, json.dumps({"medicines": []}), "2026-11-01" if exported else None),
    ).fetchone()[0]


def test_consent_is_opt_in_and_revocable(db):
    user = new_user(db)
    with as_user(db, user):
        assert db.execute("select count(*) from training_consents").fetchone()[0] == 0
        db.execute("select set_training_consent(true, 1)")
        assert db.execute("select version, revoked_at from training_consents").fetchone() == (
            1,
            None,
        )
    _example(db, user)
    _example(db, user, exported=True)
    with as_user(db, user):
        db.execute("select set_training_consent(false)")
        assert db.execute("select revoked_at is not null from training_consents").fetchone()[0]
        # Unexported examples are deleted; already-exported ones stay (they are in a trained model)
        assert db.execute("select count(*) from training_examples").fetchone()[0] == 1


def test_users_cannot_write_examples_or_see_others(db):
    alice, bob = new_user(db), new_user(db)
    _example(db, alice)
    with as_user(db, bob):
        assert db.execute("select count(*) from training_examples").fetchone()[0] == 0
        with fails_with(db, psycopg.errors.InsufficientPrivilege):
            db.execute(
                "insert into training_examples "
                "(user_id, consent_version, image_path, label, group_key) "
                "values (%s, 1, 'x', '{}', 'g')",
                (bob,),
            )


def test_repository_respects_consent(db):
    from app.training.repository import PostgresTrainingRepository

    user = new_user(db)
    repo = PostgresTrainingRepository(conn=db)
    assert repo.consent_version(str(user)) is None
    with as_user(db, user):
        db.execute("select set_training_consent(true, 2)")
    assert repo.consent_version(str(user)) == 2
    example = repo.insert_example(
        user_id=user,
        consent_version=2,
        image_path="training/a.jpg",
        label={"medicines": [{"name": "Seclo"}]},
        group_key="abc",
        redacted_lines=1,
    )
    assert (
        db.execute(
            "select review_status from training_examples where id = %s", (example,)
        ).fetchone()[0]
        == "pending"
    )
