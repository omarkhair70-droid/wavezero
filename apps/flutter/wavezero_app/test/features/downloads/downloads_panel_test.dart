import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/downloads/cache_service.dart';
import 'package:wavezero_app/features/downloads/downloads_panel.dart';

void main() {
  testWidgets('empty Downloads keeps offline recovery copy and storage action', (tester) async {
    var storageOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzDownloadsPanel(
              downloads: const [],
              cacheBytes: 0,
              controlsDisabled: false,
              onPlay: (_) {},
              onDelete: (_) {},
              onClearAll: () {},
              onManageStorage: () => storageOpened = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('No downloads yet. Download tracks from Library to listen offline.'), findsOneWidget);
    expect(find.byTooltip('Clear all downloads'), findsOneWidget);

    await tester.tap(find.text('Manage Storage'));
    await tester.pump();
    expect(storageOpened, isTrue);
  });

  testWidgets('download row preserves play and delete callbacks', (tester) async {
    var played = false;
    var deleted = false;
    final track = CachedTrackMetadata(
      trackId: 'cached-one',
      title: 'Cached One',
      artistName: 'Artist',
      localFilePath: '/tmp/cached-one.mp3',
      originalRemoteUrl: 'https://example.com/cached-one.mp3',
      cachedAt: 1,
      downloadSource: 'manual',
      qualityLabel: 'high',
      codec: 'mp3',
      bitrateKbps: 320,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzDownloadsPanel(
              downloads: [track],
              cacheBytes: 2048,
              controlsDisabled: false,
              onPlay: (value) {
                if (value.trackId == track.trackId) played = true;
              },
              onDelete: (value) {
                if (value.trackId == track.trackId) deleted = true;
              },
              onClearAll: () {},
              onManageStorage: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Cached One'), findsOneWidget);
    expect(find.textContaining('Manual'), findsOneWidget);

    await tester.tap(find.byTooltip('Play downloaded track'));
    await tester.tap(find.byTooltip('Remove from device'));
    await tester.pump();

    expect(played, isTrue);
    expect(deleted, isTrue);
  });
}
