import json
import sqlite3
from contextlib import contextmanager
from datetime import date, datetime
from pathlib import Path
from typing import Iterator

from .models import Entry, MoodAnalysis

DB_PATH = Path(__file__).resolve().parents[1] / "mood_journal.db"


@contextmanager
def connect() -> Iterator[sqlite3.Connection]:
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    try:
        yield connection
        connection.commit()
    finally:
        connection.close()


def init_db() -> None:
    with connect() as db:
        db.execute(
            """
            CREATE TABLE IF NOT EXISTS entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content TEXT NOT NULL,
                entry_date TEXT NOT NULL UNIQUE,
                created_at TEXT NOT NULL,
                mood TEXT NOT NULL,
                confidence REAL NOT NULL,
                summary TEXT NOT NULL,
                signals TEXT NOT NULL
            )
            """
        )


def row_to_entry(row: sqlite3.Row) -> Entry:
    return Entry(
        id=row["id"],
        content=row["content"],
        entry_date=date.fromisoformat(row["entry_date"]),
        created_at=datetime.fromisoformat(row["created_at"]),
        analysis=MoodAnalysis(
            mood=row["mood"],
            confidence=row["confidence"],
            summary=row["summary"],
            signals=json.loads(row["signals"]),
        ),
    )


def save_entry(content: str, entry_date: date, analysis: MoodAnalysis) -> Entry:
    created_at = datetime.utcnow().isoformat()
    with connect() as db:
        cursor = db.execute(
            """
            INSERT INTO entries (content, entry_date, created_at, mood, confidence, summary, signals)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(entry_date) DO UPDATE SET
                content = excluded.content,
                created_at = excluded.created_at,
                mood = excluded.mood,
                confidence = excluded.confidence,
                summary = excluded.summary,
                signals = excluded.signals
            RETURNING *
            """,
            (
                content,
                entry_date.isoformat(),
                created_at,
                analysis.mood.value,
                analysis.confidence,
                analysis.summary,
                json.dumps(analysis.signals),
            ),
        )
        return row_to_entry(cursor.fetchone())


def list_entries(limit: int = 180) -> list[Entry]:
    with connect() as db:
        rows = db.execute(
            "SELECT * FROM entries ORDER BY entry_date DESC LIMIT ?",
            (limit,),
        ).fetchall()
        return [row_to_entry(row) for row in rows]
