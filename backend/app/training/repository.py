import json
from collections.abc import Iterator
from contextlib import contextmanager

import psycopg


class PostgresTrainingRepository:
    """Server-side database access: inserts examples and checks consent for any user.

    `conn` is a connection, or a connection URL: then each call opens a short-lived connection, so
    a dropped one never breaks later submissions. Prepared statements are off, as Supabase's
    connection pooler (the only IPv4 route to the database) does not support them.
    """

    def __init__(self, conn: psycopg.Connection | str):
        self._conn = conn

    @contextmanager
    def _db(self) -> Iterator[psycopg.Connection]:
        if not isinstance(self._conn, str):
            yield self._conn
            return
        with psycopg.connect(self._conn, prepare_threshold=None, connect_timeout=10) as conn:
            yield conn

    def consent_version(self, user_id: str) -> int | None:
        with self._db() as db:
            row = db.execute(
                "select version from training_consents where user_id = %s and revoked_at is null",
                (user_id,),
            ).fetchone()
        return row[0] if row else None

    def insert_example(self, **f) -> str:
        with self._db() as db:
            return self._insert(db, f)

    @staticmethod
    def _insert(db: psycopg.Connection, f: dict) -> str:
        row = db.execute(
            """
            insert into training_examples
                (user_id, consent_version, image_path, label, group_key, redacted_lines)
            values (%s, %s, %s, %s, %s, %s) returning id::text
            """,
            (
                f["user_id"],
                f["consent_version"],
                f["image_path"],
                json.dumps(f["label"]),
                f["group_key"],
                f["redacted_lines"],
            ),
        ).fetchone()
        db.commit()
        return row[0]
