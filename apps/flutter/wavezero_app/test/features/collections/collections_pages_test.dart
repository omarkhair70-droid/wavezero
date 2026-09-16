import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/collections/collections_pages.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';

void main() {
  WzCollectionTrackSnapshot track(String id) => WzCollectionTrackSnapshot(
        trackId: id,
        title: 'Track $id',
        subtitle: 'Artist',
        source: WzCollectionTrackSource.device,
        addedAtMs: 1,
      );

  WzCollection collection({
    String id = 'playlist-1',
    String name = 'Road trip',
    List<WzCollectionTrackSnapshot>? tracks,
  }) =>
      WzCollection(
        id: id,
        name: name,
        type: WzCollectionType.user,
        createdAtMs: 1,
        updatedAtMs: 1,
        tracks: tracks ?? [track('a'), track('b')],
      );

  CatalogTrackSummary resolve(WzCollectionTrackSnapshot snapshot) => CatalogTrackSummary(
        trackId: snapshot.trackId,
        title: snapshot.title,
        artistName: snapshot.subtitle,
        source: 'device',
      );

  testWidgets('Collections page keeps Liked Tracks plus create and import actions', (tester) async {
    final collections = [WzCollection.liked(nowMs: 1)];
    await tester.pumpWidget(
      MaterialApp(
        home: WzCollectionsPage(
          collections: collections,
          onBack: () {},
          onOpen: (_) {},
          onCreate: () {},
          onImportM3u: () {},
          onRename: (_) {},
          onDelete: (_) {},
        ),
      ),
    );
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Liked Tracks'), findsWidgets);
    expect(find.byTooltip('Import M3U playlist'), findsOneWidget);
    expect(find.textContaining('Create'), findsWidgets);
  });

  testWidgets('collection detail exposes an explicit drag handle for reordering', (tester) async {
    final playlist = collection();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzCollectionDetailPage(
            collection: playlist,
            collections: [playlist],
            onBack: () {},
            onPlayFirst: (_) {},
            onAddAllToQueue: (_) {},
            onRename: (_) {},
            onDelete: (_) {},
            onExportM3u: (_) {},
            onPlayTrack: (_) {},
            onAddTrackToQueue: (_) {},
            onRemoveTrack: (_, __) {},
            onReorderTrack: (_, __, ___) {},
            onBulkAddToQueue: (_, __) {},
            onBulkRemove: (_, __) {},
            onBulkAddToCollection: (_, __, ___) {},
            resolver: resolve,
          ),
        ),
      ),
    );

    expect(find.text('Hold the handle to reorder'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(3));
    expect(find.text('Track a'), findsOneWidget);
    expect(find.text('Track b'), findsOneWidget);
  });

  testWidgets('multi-select can select all and queue selected tracks in one action', (tester) async {
    final playlist = collection();
    List<WzCollectionTrackSnapshot> queued = const [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzCollectionDetailPage(
            collection: playlist,
            collections: [playlist],
            onBack: () {},
            onPlayFirst: (_) {},
            onAddAllToQueue: (_) {},
            onRename: (_) {},
            onDelete: (_) {},
            onExportM3u: (_) {},
            onPlayTrack: (_) {},
            onAddTrackToQueue: (_) {},
            onRemoveTrack: (_, __) {},
            onReorderTrack: (_, __, ___) {},
            onBulkAddToQueue: (_, tracks) => queued = tracks,
            onBulkRemove: (_, __) {},
            onBulkAddToCollection: (_, __, ___) {},
            resolver: resolve,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Select tracks'));
    await tester.pumpAndSettle();
    expect(find.text('0 selected'), findsWidgets);

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Queue'));
    await tester.pumpAndSettle();
    expect(queued.map((item) => item.trackId), ['a', 'b']);
    expect(find.byTooltip('Select tracks'), findsOneWidget);
  });

  testWidgets('collection menu exposes M3U export', (tester) async {
    final playlist = collection();
    WzCollection? exported;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzCollectionDetailPage(
            collection: playlist,
            collections: [playlist],
            onBack: () {},
            onPlayFirst: (_) {},
            onAddAllToQueue: (_) {},
            onRename: (_) {},
            onDelete: (_) {},
            onExportM3u: (collection) => exported = collection,
            onPlayTrack: (_) {},
            onAddTrackToQueue: (_) {},
            onRemoveTrack: (_, __) {},
            onReorderTrack: (_, __, ___) {},
            onBulkAddToQueue: (_, __) {},
            onBulkRemove: (_, __) {},
            onBulkAddToCollection: (_, __, ___) {},
            resolver: resolve,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Collection options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export M3U'));
    await tester.pumpAndSettle();
    expect(exported?.id, playlist.id);
  });
}
