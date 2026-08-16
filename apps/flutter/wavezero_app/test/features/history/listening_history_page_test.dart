import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/history/listening_history_page.dart';

void main() {
  testWidgets('empty Listening History keeps the existing local-only shell copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WzListeningHistoryPage(
          entries: const [],
          onBack: () {},
          mostPlayedEntry: null,
          resolver: (_) => null,
          onPlay: (_) {},
          onAddToQueue: (_) {},
          onAddToCollection: (_) {},
          onRemove: (_) {},
          onClearAll: null,
        ),
      ),
    );
    expect(find.text('Listening History'), findsOneWidget);
    expect(find.text('No listening history yet. Play a track to start.'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
  });
}
