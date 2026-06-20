import json
import os
from collections import Counter, defaultdict
from datetime import date, timedelta

from anthropic import Anthropic

from .models import Entry, Mood, MoodAnalysis, PatternInsight, WeeklySummary

MOOD_KEYWORDS = {
    Mood.happy: {"happy", "grateful", "excited", "peaceful", "proud", "joy", "good", "great", "love"},
    Mood.anxious: {"anxious", "worried", "stress", "stressed", "nervous", "panic", "overwhelmed", "fear"},
    Mood.sad: {"sad", "lonely", "tired", "hopeless", "hurt", "cry", "heavy", "down", "upset"},
    Mood.energetic: {"energized", "energetic", "focused", "motivated", "productive", "strong", "alive", "ready"},
    Mood.neutral: {"okay", "fine", "normal", "average", "routine", "calm"},
}


def _fallback_analyze(content: str) -> MoodAnalysis:
    words = {word.strip(".,!?;:()[]\"'").lower() for word in content.split()}
    scores = {
        mood: len(words & keywords)
        for mood, keywords in MOOD_KEYWORDS.items()
    }
    mood, score = max(scores.items(), key=lambda item: item[1])
    if score == 0:
        mood = Mood.neutral
    total_hits = sum(scores.values())
    confidence = 0.52 if total_hits == 0 else min(0.95, 0.55 + (score / max(total_hits, 1)) * 0.35)
    signals = sorted(words & MOOD_KEYWORDS[mood])[:4]
    summary = {
        Mood.happy: "Your entry carries a warm, positive emotional tone.",
        Mood.anxious: "Your entry suggests worry, pressure, or anticipation.",
        Mood.sad: "Your entry reflects heaviness or low emotional energy.",
        Mood.energetic: "Your entry feels active, motivated, and forward-moving.",
        Mood.neutral: "Your entry reads as steady and emotionally balanced.",
    }[mood]
    return MoodAnalysis(mood=mood, confidence=round(confidence, 2), summary=summary, signals=signals)


async def analyze_entry(content: str) -> MoodAnalysis:
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        return _fallback_analyze(content)

    client = Anthropic(api_key=api_key)
    prompt = (
        "Analyze this journal entry. Return only JSON with keys: "
        "mood, confidence, summary, signals. mood must be one of "
        "happy, anxious, sad, neutral, energetic. confidence must be 0 to 1. "
        f"Entry: {content}"
    )
    try:
        message = client.messages.create(
            model=os.getenv("ANTHROPIC_MODEL", "claude-3-5-sonnet-20241022"),
            max_tokens=300,
            temperature=0.2,
            messages=[{"role": "user", "content": prompt}],
        )
        text = message.content[0].text
        return MoodAnalysis.model_validate(json.loads(text))
    except Exception:
        return _fallback_analyze(content)


def current_streak(entries: list[Entry]) -> int:
    dates = {entry.entry_date for entry in entries}
    cursor = date.today()
    streak = 0
    while cursor in dates:
        streak += 1
        cursor -= timedelta(days=1)
    return streak


def detect_patterns(entries: list[Entry]) -> list[PatternInsight]:
    if not entries:
        return []

    patterns: list[PatternInsight] = []
    by_weekday: dict[int, list[Entry]] = defaultdict(list)
    for entry in entries:
        by_weekday[entry.entry_date.weekday()].append(entry)

    day_names = ["Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays", "Sundays"]
    for weekday, day_entries in by_weekday.items():
        if len(day_entries) < 2:
            continue
        top_mood, count = Counter(entry.analysis.mood for entry in day_entries).most_common(1)[0]
        if count >= 2 and count / len(day_entries) >= 0.6:
            patterns.append(
                PatternInsight(
                    title=f"{day_names[weekday]} trend {top_mood.value}",
                    detail=f"{count} of your {len(day_entries)} recent {day_names[weekday].lower()} were tagged {top_mood.value}.",
                    mood=top_mood,
                )
            )

    sorted_entries = sorted(entries, key=lambda entry: entry.entry_date)
    if len(sorted_entries) >= 6:
        first_half = sorted_entries[: len(sorted_entries) // 2]
        second_half = sorted_entries[len(sorted_entries) // 2 :]
        positive = {Mood.happy, Mood.energetic}
        first_positive = sum(entry.analysis.mood in positive for entry in first_half) / len(first_half)
        second_positive = sum(entry.analysis.mood in positive for entry in second_half) / len(second_half)
        if second_positive - first_positive >= 0.25:
            patterns.append(
                PatternInsight(
                    title="Mood lift",
                    detail="Your recent entries show a stronger positive trend than the earlier part of this period.",
                    mood=Mood.happy,
                )
            )

    return patterns[:4]


async def weekly_summary(entries: list[Entry]) -> WeeklySummary:
    today = date.today()
    week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=6)
    week_entries = [
        entry for entry in entries
        if week_start <= entry.entry_date <= week_end
    ]
    if not week_entries:
        return WeeklySummary(
            week_start=week_start,
            week_end=week_end,
            entry_count=0,
            summary="No entries yet this week. A short check-in today would start the reflection.",
        )

    counts = Counter(entry.analysis.mood for entry in week_entries)
    dominant_mood = counts.most_common(1)[0][0]
    summaries = " ".join(entry.analysis.summary for entry in week_entries)
    summary = (
        f"This week leaned {dominant_mood.value}. Across {len(week_entries)} "
        f"entries, the strongest theme was: {summaries}"
    )
    return WeeklySummary(
        week_start=week_start,
        week_end=week_end,
        entry_count=len(week_entries),
        summary=summary,
        dominant_mood=dominant_mood,
    )
