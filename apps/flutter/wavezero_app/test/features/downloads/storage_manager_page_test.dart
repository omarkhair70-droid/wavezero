import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/downloads/storage_manager_page.dart';

void main() {
  testWidgets('empty Storage Manager keeps offline and Smart Downloads controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzStorageManagerPage(
            downloads: const [],
            onBack: () {},
            cacheBytes: 0,
            trackBytes: const {},
            manualDownloadedCount: 0,
            smartDownloadedCount: 0,
            offlineReadyCount: 0,
            smartDownloadsEnabled: true,
            controlsDisabled: false,
            onSmartDownloadsChanged: (_) {},
            onPlay: (_) {},
            onDelete: (_) {},
            onClearAll: () async {},
          ),
        ),
      ),
    );
    expect(find.text('Storage Manager'), findsOneWidget);
    expect(find.text('No downloads yet'), findsWidgets);
    expect(find.text('Smart Downloads'), findsWidgets);
    expect(find.textContaining('No downloads yet. Download tracks from Library'), findsOneWidget);
  });
}
