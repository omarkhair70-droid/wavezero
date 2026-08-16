import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/library/library_controls.dart';
import 'package:wavezero_app/features/library/library_source_overview.dart';

void main() {
  Widget buildSubject({ValueChanged<WzLibrarySourceFilter>? onFilterChanged}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzLibrarySourceOverview(
              apiTrackCount: 4,
              deviceTrackCount: 0,
              cachedTrackCount: 2,
              cloudTrackCount: 1,
              combinedTrackCount: 6,
              cacheBytes: 2048,
              status: 'Catalog ready',
              loading: false,
              refreshDisabled: false,
              librarySourceFilter: WzLibrarySourceFilter.all,
              devicePermissionStatus: 'unknown',
              deviceScanStatus: 'Not scanned',
              deviceLastError: null,
              onSourceFilterChanged: onFilterChanged ?? (_) {},
              onRefresh: () {},
              onImportDeviceMusic: () {},
              onOpenCollections: () {},
              onOpenFullSearch: () {},
              onOpenCloudVault: () {},
            ),
          ),
        ),
      );

  testWidgets('preserves consumer Library sources without unfinished Cloud controls', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Unified library'), findsOneWidget);
    expect(find.text('Catalog ready'), findsOneWidget);
    expect(find.text('Import Device music'), findsOneWidget);
    expect(find.text('Collections / Playlists'), findsOneWidget);
    expect(find.text('Open full search'), findsOneWidget);
    expect(find.text('Cloud Vault'), findsNothing);
    expect(find.text('Cloud'), findsNothing);
  });

  testWidgets('source filter chips preserve their navigation value', (tester) async {
    WzLibrarySourceFilter? selected;
    await tester.pumpWidget(buildSubject(onFilterChanged: (value) => selected = value));

    await tester.tap(find.text('Device'));
    await tester.pump();

    expect(selected, WzLibrarySourceFilter.device);
  });
}
