import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/queue/queue_panel.dart';

void main() {
  testWidgets('empty Queue keeps recovery copy and disabled clear action', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzQueuePanel(
              queue: const [],
              currentTrackId: null,
              currentIndex: -1,
              status: 'Queue ready.',
              controlsDisabled: false,
              autoAdvanceEnabled: true,
              autoAdvanceCount: 0,
              smartQueueCandidateTrackId: null,
              smartQueueReason: 'none',
              showDeveloperDetails: false,
              onToggleAutoAdvance: (_) {},
              onPlayTrack: (_) {},
              onMoveUp: (_) {},
              onMoveDown: (_) {},
              onPlayNext: (_) {},
              onRemoveTrack: (_) {},
              onClearQueue: () => cleared = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Queue is empty. Add tracks from Library or Search to choose what plays next.'), findsOneWidget);
    expect(find.byTooltip('Clear queue'), findsOneWidget);
    expect(find.byIcon(Icons.clear_all), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear_all), warnIfMissed: false);
    await tester.pump();
    expect(cleared, isFalse);
  });

  testWidgets('Queue row preserves play-next and remove callbacks', (tester) async {
    var playNext = false;
    var removed = false;
    final tracks = [
      CatalogTrackSummary(trackId: 'one', title: 'One'),
      CatalogTrackSummary(trackId: 'two', title: 'Two'),
      CatalogTrackSummary(trackId: 'three', title: 'Three'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzQueuePanel(
              queue: tracks,
              currentTrackId: 'one',
              currentIndex: 0,
              status: 'Queue ready.',
              controlsDisabled: false,
              autoAdvanceEnabled: true,
              autoAdvanceCount: 0,
              smartQueueCandidateTrackId: null,
              smartQueueReason: 'none',
              showDeveloperDetails: false,
              onToggleAutoAdvance: (_) {},
              onPlayTrack: (_) {},
              onMoveUp: (_) {},
              onMoveDown: (_) {},
              onPlayNext: (track) {
                if (track.trackId == 'three') playNext = true;
              },
              onRemoveTrack: (track) {
                if (track.trackId == 'three') removed = true;
              },
              onClearQueue: () {},
            ),
          ),
        ),
      ),
    );

    final thirdPlayNext = find.byTooltip('Play next').last;
    final thirdRemove = find.byTooltip('Remove').last;
    await tester.tap(thirdPlayNext);
    await tester.tap(thirdRemove);
    await tester.pump();

    expect(playNext, isTrue);
    expect(removed, isTrue);
  });
}
