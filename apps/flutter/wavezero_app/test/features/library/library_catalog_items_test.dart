import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/library/library_catalog_items.dart';

void main() {
  testWidgets('empty featured demo shelf stays hidden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzFeaturedDemoLibraryShelf(
            picks: const [],
            onPlayPick: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Featured from this demo'), findsNothing);
  });

  testWidgets('catalog row preserves core Library actions', (tester) async {
    var liked = false;
    var queued = false;
    var collected = false;
    final track = CatalogTrackSummary(
      trackId: 'catalog-test',
      title: 'Test track',
      artistName: 'Test artist',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzLibraryCatalogRow(
              track: track,
              selected: false,
              addDisabled: false,
              onTap: () {},
              onAdd: () => queued = true,
              onToggleLike: () => liked = true,
              onAddToCollection: () => collected = true,
              liked: false,
              onCache: null,
              onDeleteCached: null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Test track'), findsOneWidget);
    await tester.tap(find.byTooltip('Like'));
    await tester.tap(find.byTooltip('Add to queue'));
    await tester.tap(find.byTooltip('Add to collection'));
    await tester.pump();

    expect(liked, isTrue);
    expect(queued, isTrue);
    expect(collected, isTrue);
  });
}
