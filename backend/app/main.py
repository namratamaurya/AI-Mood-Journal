from collections import Counter
from datetime import date

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .analysis import analyze_entry, current_streak, detect_patterns, weekly_summary
from .database import init_db, list_entries, save_entry
from .models import Entry, EntryCreate, Stats, WeeklySummary

load_dotenv()

app = FastAPI(title="AI Mood Journal API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup() -> None:
    init_db()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/entries", response_model=Entry)
async def create_entry(payload: EntryCreate) -> Entry:
    analysis = await analyze_entry(payload.content)
    return save_entry(payload.content, payload.entry_date or date.today(), analysis)


@app.get("/entries", response_model=list[Entry])
def get_entries(limit: int = 180) -> list[Entry]:
    return list_entries(limit)


@app.get("/stats", response_model=Stats)
def get_stats() -> Stats:
    entries = list_entries()
    mood_counts = Counter(entry.analysis.mood.value for entry in entries)
    recent = [entry for entry in entries if (date.today() - entry.entry_date).days <= 7]
    weekly_average = (
        sum(entry.analysis.confidence for entry in recent) / len(recent)
        if recent
        else 0
    )
    return Stats(
        current_streak=current_streak(entries),
        total_entries=len(entries),
        mood_counts=dict(mood_counts),
        weekly_average_confidence=round(weekly_average, 2),
        patterns=detect_patterns(entries),
    )


@app.get("/summaries/weekly", response_model=WeeklySummary)
async def get_weekly_summary() -> WeeklySummary:
    return await weekly_summary(list_entries())
