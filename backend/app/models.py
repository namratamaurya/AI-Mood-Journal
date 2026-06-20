from datetime import date, datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class Mood(str, Enum):
    happy = "happy"
    anxious = "anxious"
    sad = "sad"
    neutral = "neutral"
    energetic = "energetic"


class EntryCreate(BaseModel):
    content: str = Field(min_length=3, max_length=5000)
    entry_date: Optional[date] = None


class MoodAnalysis(BaseModel):
    mood: Mood
    confidence: float = Field(ge=0, le=1)
    summary: str
    signals: list[str] = Field(default_factory=list)


class Entry(BaseModel):
    id: int
    content: str
    entry_date: date
    created_at: datetime
    analysis: MoodAnalysis


class PatternInsight(BaseModel):
    title: str
    detail: str
    mood: Optional[Mood] = None


class Stats(BaseModel):
    current_streak: int
    total_entries: int
    mood_counts: dict[str, int]
    weekly_average_confidence: float
    patterns: list[PatternInsight]


class WeeklySummary(BaseModel):
    week_start: date
    week_end: date
    entry_count: int
    summary: str
    dominant_mood: Optional[Mood] = None
