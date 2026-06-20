import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mood_journal/main.dart';

void main() {
  testWidgets('Mood journal app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MoodJournalApp());

    expect(find.byType(MoodJournalApp), findsOneWidget);
  });
}
