import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/history/listening_history_service.dart';
import 'package:wavezero_app/features/home/home_sections.dart';

void main() {
  WzListeningHistoryEntry entry(String id, {int positionMs = 0}) =>
      WzListeningHistoryEntry(
        trackId: id,
        title: id,
        subtitle: 'Artist',
        source: WzListeningHistorySource.device,
        lastPlayedAtMs: 10,
        firstPlayedAtMs: 1,
        playCount: 1,
        lastPositionMs: positionMs,
        durationMs: 180000,
      );

  testWidgets('empty curated Home section stays out of the consumer experience', (tester) async {
    var openedLibrary = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzHomeCuratedDemoSection(
            shelves: const [],
            onPlayPick: (_) {},
            onAddToQueue: (_) {},
            onOpenLibrary: () => openedLibrary = true,
          ),
        ),
      ),
    );

    expect(find.text('WaveZero Picks'), findsNothing);
    expect(find.textContaining('demo catalog'), findsNothing);
    expect(find.text('Open Library'), findsNothing);
    expect(openedLibrary, isFalse);
  });

  testWidgets('empty Home history stays quiet instead of rendering a fake continue card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzHomeHistorySection(
            entries: const [],
            continueEntry: null,
            mostPlayedEntry: null,
            resolver: (_) => null,
            onPlay: (_) {},
            onAddToQueue: (_) {},
            onAddToCollection: (_) {},
            onRemove: (_) {},
            onViewAll: () {},
          ),
        ),
      ),
    );

    expect(find.text('Continue Listening'), findsNothing);
    expect(find.text('Recently Played'), findsOneWidget);
    expect(find.text('Play something and it will stay close here.'), findsOneWidget);
    expect(find.text('View all'), findsNothing);
  });

  testWidgets('continue track is not repeated in Recently Played', (tester) async {
    final resumed = entry('resume-me', positionMs: 45000);
    final other = entry('another-track');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzHomeHistorySection(
              entries: [resumed, other, resumed],
              continueEntry: resumed,
              mostPlayedEntry: resumed,
              resolver: (_) => null,
              onPlay: (_) {},
              onAddToQueue: (_) {},
              onAddToCollection: (_) {},
              onRemove: (_) {},
              onViewAll: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Continue Listening'), findsOneWidget);
    expect(find.text('resume-me'), findsOneWidget);
    expect(find.text('another-track'), findsOneWidget);
  });
}
