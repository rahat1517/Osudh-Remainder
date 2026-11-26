import json

import psycopg


class PostgresTrainingRepository:
    """Privileged connection: inserts examples and checks consent for any user."""

    def __init__(self, conn: psycopg.Connection):
        self._db = conn

    def consent_version(self, user_id: str) -> int | None:
        row = self._db.execute(
            "select version from training_consents where user_id = %s and revoked_at is null",
            (user_id,),
        ).fetchone()
        return row[0] if row else None

    def insert_example(self, **f) -> str:
        row = self._db.execute(
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
        self._db.commit()
        return row[0]
