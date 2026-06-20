enum Mood {
  happy,
  anxious,
  sad,
  neutral,
  energetic;

  static Mood fromJson(String value) {
    return Mood.values.firstWhere((mood) => mood.name == value);
  }
}

class MoodAnalysis {
  const MoodAnalysis({
    required this.mood,
    required this.confidence,
    required this.summary,
    required this.signals,
  });

  factory MoodAnalysis.fromJson(Map<String, dynamic> json) {
    return MoodAnalysis(
      mood: Mood.fromJson(json['mood'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      summary: json['summary'] as String,
      signals: (json['signals'] as List<dynamic>).cast<String>(),
    );
  }

  final Mood mood;
  final double confidence;
  final String summary;
  final List<String> signals;
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.content,
    required this.entryDate,
    required this.createdAt,
    required this.analysis,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as int,
      content: json['content'] as String,
      entryDate: DateTime.parse(json['entry_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      analysis: MoodAnalysis.fromJson(json['analysis'] as Map<String, dynamic>),
    );
  }

  final int id;
  final String content;
  final DateTime entryDate;
  final DateTime createdAt;
  final MoodAnalysis analysis;
}

class PatternInsight {
  const PatternInsight({
    required this.title,
    required this.detail,
    this.mood,
  });

  factory PatternInsight.fromJson(Map<String, dynamic> json) {
    return PatternInsight(
      title: json['title'] as String,
      detail: json['detail'] as String,
      mood: json['mood'] == null ? null : Mood.fromJson(json['mood'] as String),
    );
  }

  final String title;
  final String detail;
  final Mood? mood;
}

class Stats {
  const Stats({
    required this.currentStreak,
    required this.totalEntries,
    required this.moodCounts,
    required this.weeklyAverageConfidence,
    required this.patterns,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      currentStreak: json['current_streak'] as int,
      totalEntries: json['total_entries'] as int,
      moodCounts: (json['mood_counts'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as int),
      ),
      weeklyAverageConfidence:
          (json['weekly_average_confidence'] as num).toDouble(),
      patterns: (json['patterns'] as List<dynamic>)
          .map((item) => PatternInsight.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int currentStreak;
  final int totalEntries;
  final Map<String, int> moodCounts;
  final double weeklyAverageConfidence;
  final List<PatternInsight> patterns;
}

class WeeklySummary {
  const WeeklySummary({
    required this.weekStart,
    required this.weekEnd,
    required this.entryCount,
    required this.summary,
    this.dominantMood,
  });

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    return WeeklySummary(
      weekStart: DateTime.parse(json['week_start'] as String),
      weekEnd: DateTime.parse(json['week_end'] as String),
      entryCount: json['entry_count'] as int,
      summary: json['summary'] as String,
      dominantMood: json['dominant_mood'] == null
          ? null
          : Mood.fromJson(json['dominant_mood'] as String),
    );
  }

  final DateTime weekStart;
  final DateTime weekEnd;
  final int entryCount;
  final String summary;
  final Mood? dominantMood;
}
