import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/journal_models.dart';

class ApiClient {
  ApiClient({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8000',
    ),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<List<JournalEntry>> fetchEntries() async {
    final response = await _client.get(Uri.parse('$baseUrl/entries'));
    _check(response);
    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((item) => JournalEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<JournalEntry> createEntry(String content, DateTime entryDate) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/entries'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'content': content,
        'entry_date': _dateOnly(entryDate),
      }),
    );
    _check(response);
    return JournalEntry.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<Stats> fetchStats() async {
    final response = await _client.get(Uri.parse('$baseUrl/stats'));
    _check(response);
    return Stats.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<WeeklySummary> fetchWeeklySummary() async {
    final response = await _client.get(Uri.parse('$baseUrl/summaries/weekly'));
    _check(response);
    return WeeklySummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  void _check(http.Response response) {
    if (response.statusCode >= 400) {
      throw Exception(
        'API request failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
