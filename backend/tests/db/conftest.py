"""Database tests: apply all migrations to a scratch PostgreSQL database and test them.

Set TEST_DATABASE_URL to a server where the user may create databases, e.g.
postgresql://postgres:postgres@localhost:5432/postgres. Skipped when it is not set.
"""

import os
import uuid
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

import pytest

psycopg = pytest.importorskip("psycopg")

ROOT = Path(__file__).parents[3]
SUPABASE = ROOT / "supabase"


def _sql_files() -> list[Path]:
    return [
        SUPABASE / "tests" / "auth_shim.sql",
        *sorted((SUPABASE / "migrations").glob("*.sql")),
        SUPABASE / "seed.sql",
    ]


@pytest.fixture(scope="session")
def database_url() -> Iterator[str]:
    admin_url = os.environ.get("TEST_DATABASE_URL")
    if not admin_url:
        pytest.skip("TEST_DATABASE_URL not set")
    name = f"oshudh_test_{uuid.uuid4().hex[:8]}"
    with psycopg.connect(admin_url, autocommit=True) as admin:
        admin.execute(f'create database "{name}"')
    url = admin_url.rsplit("/", 1)[0] + f"/{name}"
    try:
        with psycopg.connect(url, autocommit=True) as conn:
            for path in _sql_files():
                conn.execute(path.read_text(encoding="utf-8"))
        yield url
    finally:
        with psycopg.connect(admin_url, autocommit=True) as admin:
            admin.execute(f'drop database "{name}" with (force)')


@pytest.fixture
def db(database_url):
    """A connection as the database owner, rolled back after each test."""
    with psycopg.connect(database_url) as conn:
        yield conn
        conn.rollback()


def new_user(db) -> uuid.UUID:
    return db.execute("insert into auth.users default values returning id").fetchone()[0]


@contextmanager
def fails_with(db, error: type[Exception]):
    """Expect `error` from the statements in the block, inside a savepoint so that the
    surrounding test transaction stays usable."""
    with pytest.raises(error), db.transaction():
        yield


@contextmanager
def as_user(db, user_id: uuid.UUID | None):
    """Run statements as an app client: role `authenticated` (or `anon`) with this JWT subject."""
    role = "authenticated" if user_id else "anon"
    db.execute("select set_config('request.jwt.claim.sub', %s, true)", (str(user_id or ""),))
    db.execute(f"set local role {role}")
    try:
        yield db
    finally:
        db.execute("reset role")
