import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/library/library_catalog_panel.dart';
import 'package:wavezero_app/features/library/library_controls.dart';

void main() {
  Widget panel({
    required TextEditingController searchController,
    WzLibrarySourceFilter filter = WzLibrarySourceFilter.all,
    String permission = 'unknown',
    int deviceTrackCount = 0,
    Future<void> Function()? onImportDeviceMusic,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzLibraryCatalogPanel(
              tracks: const [],
              totalTrackCount: 0,
              apiTrackCount: 0,
              deviceTrackCount: deviceTrackCount,
              cachedTrackCount: 0,
              cloudTrackCount: 0,
              combinedTrackCount: deviceTrackCount,
              visibleTrackCount: 0,
              filteredTrackCount: 0,
              catalogLimit: 200,
              largeCatalogMode: false,
              onLoadMore: null,
              cacheBytes: 0,
              curatedPicks: const [],
              selectedTrackId: null,
              status: 'Catalog unavailable',
              loading: false,
              refreshDisabled: false,
              addToQueueDisabled: false,
              searchController: searchController,
              librarySourceFilter: filter,
              librarySortMode: WzLibrarySortMode.recentlyAdded,
              devicePermissionStatus: permission,
              deviceScanStatus: 'success',
              deviceLastError: null,
              onSourceFilterChanged: (_) {},
              onSortModeChanged: (_) {},
              onClearSearch: searchController.clear,
              onOpenFullSearch: () {},
              onOpenCloudVault: () {},
              onRefresh: () {},
              onImportDeviceMusic: onImportDeviceMusic ?? () async {},
              onSelectTrack: (_) {},
              onPlayCuratedPick: (_) {},
              onAddToQueue: (_) {},
              onToggleLike: (_) {},
              onAddToCollection: (_) {},
              isLiked: (_) => false,
              onOpenCollections: () {},
              onCache: (_) {},
              onDeleteCachedTrack: (_) {},
            ),
          ),
        ),
      );

  testWidgets('empty Library catalog panel keeps a human recovery path', (tester) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(panel(searchController: searchController));

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Your Library is quiet. Add Device Music or come back when your online music is available.'), findsOneWidget);
    expect(find.byTooltip('Sort Library'), findsOneWidget);
  });

  testWidgets('opening Device Music with permission refreshes it automatically', (tester) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);
    var scans = 0;

    await tester.pumpWidget(
      panel(
        searchController: searchController,
        filter: WzLibrarySourceFilter.device,
        permission: 'granted',
        deviceTrackCount: 3,
        onImportDeviceMusic: () async {
          scans += 1;
        },
      ),
    );
    await tester.pump();

    expect(scans, 1);
    expect(find.text('Device Music refreshes when you open it.'), findsOneWidget);
  });
}
