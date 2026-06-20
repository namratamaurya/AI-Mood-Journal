import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/journal_models.dart';
import '../services/api_client.dart';

class JournalDashboard extends StatefulWidget {
  const JournalDashboard({super.key});

  @override
  State<JournalDashboard> createState() => _JournalDashboardState();
}

class _JournalDashboardState extends State<JournalDashboard> {
  final _api = ApiClient();
  final _controller = TextEditingController();
  final _dateFormat = DateFormat('MMM d');

  List<JournalEntry> _entries = [];
  Stats? _stats;
  WeeklySummary? _summary;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.fetchEntries(),
        _api.fetchStats(),
        _api.fetchWeeklySummary(),
      ]);
      setState(() {
        _entries = results[0] as List<JournalEntry>;
        _stats = results[1] as Stats;
        _summary = results[2] as WeeklySummary;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveEntry() async {
    final content = _controller.text.trim();
    if (content.length < 3 || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.createEntry(content, DateTime.now());
      _controller.clear();
      await _loadData();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _Header(stats: _stats),
                    const SizedBox(height: 20),
                    if (_error != null) _ErrorBanner(message: _error!),
                    _ResponsiveGrid(
                      left: _Composer(
                        controller: _controller,
                        saving: _saving,
                        onSave: _saveEntry,
                      ),
                      right: _ReflectionCard(summary: _summary),
                    ),
                    const SizedBox(height: 16),
                    _ResponsiveGrid(
                      left: _TimelineCard(
                        entries: _entries,
                        dateFormat: _dateFormat,
                      ),
                      right: _InsightsCard(stats: _stats),
                    ),
                    const SizedBox(height: 16),
                    _EntriesList(entries: _entries, dateFormat: _dateFormat),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.stats});

  final Stats? stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Mood Journal',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFF243B3D),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Track patterns in how your days actually feel.',
              style: TextStyle(color: Color(0xFF6B625B), fontSize: 15),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricPill(
              icon: Icons.local_fire_department_outlined,
              label: 'Streak',
              value: '${stats?.currentStreak ?? 0} days',
            ),
            _MetricPill(
              icon: Icons.edit_note,
              label: 'Entries',
              value: '${stats?.totalEntries ?? 0}',
            ),
            _MetricPill(
              icon: Icons.psychology_alt_outlined,
              label: 'AI confidence',
              value:
                  '${(((stats?.weeklyAverageConfidence ?? 0) * 100).round())}%',
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7DFD5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF2F5D62), size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7C736A)),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF243B3D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            children: [
              left,
              const SizedBox(height: 16),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: left),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: right),
          ],
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 7,
              maxLines: 10,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText:
                    'Write what happened, what you noticed, or what you are carrying.',
                filled: true,
                fillColor: const Color(0xFFFBFAF7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE7DFD5)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(saving ? 'Analyzing' : 'Save and analyze'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({required this.summary});

  final WeeklySummary? summary;

  @override
  Widget build(BuildContext context) {
    final start = summary?.weekStart;
    final end = summary?.weekEnd;
    final range = start == null || end == null
        ? 'This week'
        : '${DateFormat('MMM d').format(start)} - '
            '${DateFormat('MMM d').format(end)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.summarize_outlined, color: Color(0xFF2F5D62)),
                const SizedBox(width: 8),
                Text(
                  range,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MoodChip(mood: summary?.dominantMood ?? Mood.neutral),
            const SizedBox(height: 14),
            Text(
              summary?.summary ??
                  'Your weekly reflection will appear after your first entry.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Color(0xFF4D4742),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.entries,
    required this.dateFormat,
  });

  final List<JournalEntry> entries;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final chartEntries = entries.take(30).toList().reversed.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mood timeline',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: chartEntries.isEmpty
                  ? const _EmptyState(
                      icon: Icons.show_chart,
                      text: 'Your mood timeline starts with one entry.',
                    )
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 4,
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 82,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  _labelForMoodScore(value.round()),
                                  style: const TextStyle(fontSize: 11),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: chartEntries.length > 8 ? 4 : 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= chartEntries.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    dateFormat.format(
                                      chartEntries[index].entryDate,
                                    ),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < chartEntries.length; i++)
                                FlSpot(
                                  i.toDouble(),
                                  _scoreForMood(
                                    chartEntries[i].analysis.mood,
                                  ).toDouble(),
                                ),
                            ],
                            isCurved: true,
                            color: const Color(0xFF2F5D62),
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0x332F5D62),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.stats});

  final Stats? stats;

  @override
  Widget build(BuildContext context) {
    final patterns = stats?.patterns ?? [];
    final moods = stats?.moodCounts.entries.toList() ?? [];
    moods.sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Patterns',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (patterns.isEmpty)
              const _EmptyState(
                icon: Icons.insights_outlined,
                text: 'More entries will reveal recurring mood patterns.',
              )
            else
              ...patterns.map(
                (pattern) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InsightTile(pattern: pattern),
                ),
              ),
            const Divider(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mood in moods)
                  _MoodChip(mood: Mood.fromJson(mood.key), count: mood.value),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.pattern});

  final PatternInsight pattern;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7DFD5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: _colorForMood(pattern.mood ?? Mood.neutral),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pattern.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  pattern.detail,
                  style: const TextStyle(color: Color(0xFF665E57)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntriesList extends StatelessWidget {
  const _EntriesList({
    required this.entries,
    required this.dateFormat,
  });

  final List<JournalEntry> entries;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent entries',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const _EmptyState(
                icon: Icons.edit_calendar_outlined,
                text: 'No entries yet.',
              )
            else
              for (final entry in entries.take(8))
                _EntryRow(entry: entry, dateFormat: dateFormat),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.dateFormat,
  });

  final JournalEntry entry;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              dateFormat.format(entry.entryDate),
              style: const TextStyle(
                color: Color(0xFF6B625B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MoodChip(mood: entry.analysis.mood),
                    Text(
                      '${(entry.analysis.confidence * 100).round()}% confidence',
                      style: const TextStyle(color: Color(0xFF7C736A)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.analysis.summary,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF4D4742)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.mood, this.count});

  final Mood mood;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = _colorForMood(mood);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        count == null ? mood.name : '${mood.name} $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF9B9086), size: 32),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B625B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5A096)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB04435)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF7A2D25)),
            ),
          ),
        ],
      ),
    );
  }
}

int _scoreForMood(Mood mood) {
  return switch (mood) {
    Mood.sad => 0,
    Mood.anxious => 1,
    Mood.neutral => 2,
    Mood.energetic => 3,
    Mood.happy => 4,
  };
}

String _labelForMoodScore(int score) {
  return switch (score) {
    0 => 'sad',
    1 => 'anxious',
    2 => 'neutral',
    3 => 'energetic',
    4 => 'happy',
    _ => '',
  };
}

Color _colorForMood(Mood mood) {
  return switch (mood) {
    Mood.happy => const Color(0xFF2F7D4F),
    Mood.anxious => const Color(0xFFB35C2E),
    Mood.sad => const Color(0xFF526A9E),
    Mood.energetic => const Color(0xFF9A6A00),
    Mood.neutral => const Color(0xFF5C6F72),
  };
}
