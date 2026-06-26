import json
import os
import re
from collections import Counter, defaultdict
from datetime import date, timedelta

try:
    from openai import AsyncOpenAI
except ImportError:
    AsyncOpenAI = None

from .models import Entry, Mood, MoodAnalysis, PatternInsight, WeeklySummary

LONG_ENTRY_CHAR_LIMIT = 1800
SUMMARY_CHAR_LIMIT = 1200

MOOD_KEYWORDS = {
    Mood.happy: {
        "happy", "grateful", "excited", "peaceful", "proud", "joy",
        "good", "great", "love", "relieved", "hopeful",
    },
    Mood.anxious: {
        "anxious", "worried", "worry", "stress", "stressed", "nervous",
        "panic", "panicked", "overwhelmed", "fear", "scared", "afraid",
        "stolen", "missing", "unsafe", "uncertain", "bullied",
        "bullying", "harassed", "threatened",
    },
    Mood.sad: {
        "sad", "lonely", "tired", "hopeless", "hurt", "cry", "cried",
        "heavy", "down", "upset", "breakup", "break-up", "heartbroken",
        "broken", "dumped", "rejected", "grief", "loss", "lost",
        "bullied", "bullying", "humiliated", "insulted",
    },
    Mood.energetic: {
        "energized", "energetic", "focused", "motivated", "productive",
        "strong", "alive", "ready",
    },
    Mood.neutral: {"okay", "fine", "normal", "average", "routine", "calm"},
}

MOOD_PHRASES = {
    Mood.sad: {
        "had a breakup",
        "went through a breakup",
        "broke up",
        "break up",
        "relationship ended",
        "got dumped",
        "was bullied",
        "got bullied",
        "bullied at school",
        "bullied today",
        "lost my grandmother",
        "lost my grandfather",
        "lost my mother",
        "lost my father",
        "lost my parent",
        "lost my sister",
        "lost my brother",
        "lost my friend",
        "passed away",
        "died today",
    },
    Mood.anxious: {
        "phone got stolen",
        "phone has got stolen",
        "phone was stolen",
        "got stolen",
        "was stolen",
        "has been stolen",
        "i lost my phone",
    },
}


def _split_sentences(content: str) -> list[str]:
    sentences = [
        sentence.strip()
        for sentence in re.split(r"(?<=[.!?])\s+", content)
        if sentence.strip()
    ]
    if len(sentences) <= 1:
        return [line.strip() for line in content.splitlines() if line.strip()]
    return sentences


def _local_summarize_for_llm(content: str) -> str:
    if len(content) <= LONG_ENTRY_CHAR_LIMIT:
        return content

    sentences = _split_sentences(content)
    if not sentences:
        return content[:SUMMARY_CHAR_LIMIT]

    emotional_terms = set().union(*MOOD_KEYWORDS.values())
    selected: list[str] = []

    selected.extend(sentences[:2])
    selected.extend(
        sentence
        for sentence in sentences[2:-1]
        if any(term in sentence.lower() for term in emotional_terms)
    )
    if len(sentences) > 2:
        selected.append(sentences[-1])

    summary = " ".join(dict.fromkeys(selected))
    if len(summary) > SUMMARY_CHAR_LIMIT:
        summary = f"{summary[:SUMMARY_CHAR_LIMIT].rsplit(' ', 1)[0]}..."

    return (
        "Local summary of a long journal entry for mood analysis. "
        f"Original length: {len(content)} characters. Summary: {summary}"
    )


def _fallback_analyze(content: str) -> MoodAnalysis:
    normalized = content.lower()
    words = {word.strip(".,!?;:()[]\"'").lower() for word in content.split()}
    scores = {
        mood: len(words & keywords)
        for mood, keywords in MOOD_KEYWORDS.items()
    }
    phrase_signals: dict[Mood, list[str]] = {}
    for mood, phrases in MOOD_PHRASES.items():
        matches = [phrase for phrase in phrases if phrase in normalized]
        if matches:
            phrase_signals[mood] = matches
            scores[mood] += len(matches) * 2

    if "bullied" in words or "bullying" in words:
        scores[Mood.sad] += 2
        scores[Mood.anxious] += 1

    loved_one_terms = {
        "grandmother", "grandfather", "mother", "father", "parent",
        "sister", "brother", "friend", "grandma", "grandpa",
    }
    grief_terms = {"lost", "died", "death", "passed"}
    if words & loved_one_terms and words & grief_terms:
        scores[Mood.sad] += 3

    mood, score = max(scores.items(), key=lambda item: item[1])
    if score == 0:
        mood = Mood.neutral
    total_hits = sum(scores.values())
    confidence = 0.52 if total_hits == 0 else min(0.95, 0.55 + (score / max(total_hits, 1)) * 0.35)
    signals = [
        *sorted(words & MOOD_KEYWORDS[mood]),
        *phrase_signals.get(mood, []),
    ][:4]
    summary = {
        Mood.happy: "Your entry carries a warm, positive emotional tone.",
        Mood.anxious: "Your entry suggests worry, pressure, or anticipation.",
        Mood.sad: "Your entry reflects heaviness or low emotional energy.",
        Mood.energetic: "Your entry feels active, motivated, and forward-moving.",
        Mood.neutral: "Your entry reads as steady and emotionally balanced.",
    }[mood]
    return MoodAnalysis(mood=mood, confidence=round(confidence, 2), summary=summary, signals=signals)


async def analyze_entry(content: str) -> MoodAnalysis:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key or AsyncOpenAI is None:
        return _fallback_analyze(content)

    analysis_text = _local_summarize_for_llm(content)
    prompt = (
        "Classify the emotional tone of this journal entry. "
        "Do not over-infer. If the entry is factual, unclear, or mixed with no dominant emotion, use neutral. "
        "Return only valid JSON with keys: mood, confidence, summary, signals. "
        "mood must be one of happy, anxious, sad, neutral, energetic. "
        "confidence must be between 0 and 1. "
        "signals must include the exact words or events that caused the mood label. "
        f"Entry: {analysis_text}"
    )
    client = AsyncOpenAI(api_key=api_key)

    try:
        response = await client.responses.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4.1-mini"),
            input=prompt,
            max_output_tokens=300,
            temperature=0.2,
        )

        text = response.output_text
        analysis = MoodAnalysis.model_validate(json.loads(text))

        if analysis.confidence < 0.60:
            return MoodAnalysis(
                mood=Mood.neutral,
                confidence=analysis.confidence,
                summary="Your entry has mixed or unclear emotional signals.",
                signals=analysis.signals,
            )

        return analysis
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
