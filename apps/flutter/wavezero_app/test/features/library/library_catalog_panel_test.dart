import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/library/library_catalog_panel.dart';
import 'package:wavezero_app/features/library/library_controls.dart';

void main() {
  testWidgets('empty Library catalog panel keeps a human recovery path', (tester) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzLibraryCatalogPanel(
              tracks: const [],
              totalTrackCount: 0,
              apiTrackCount: 0,
              deviceTrackCount: 0,
              cachedTrackCount: 0,
              cloudTrackCount: 0,
              combinedTrackCount: 0,
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
              librarySourceFilter: WzLibrarySourceFilter.all,
              librarySortMode: WzLibrarySortMode.recentlyAdded,
              devicePermissionStatus: 'unknown',
              deviceScanStatus: 'Not scanned',
              deviceLastError: null,
              onSourceFilterChanged: (_) {},
              onSortModeChanged: (_) {},
              onClearSearch: searchController.clear,
              onOpenFullSearch: () {},
              onOpenCloudVault: () {},
              onRefresh: () {},
              onImportDeviceMusic: () {},
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
      ),
    );

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Your Library is quiet. Add Device Music or come back when your online music is available.'), findsOneWidget);
    expect(find.byTooltip('Sort Library'), findsOneWidget);
  });
}
