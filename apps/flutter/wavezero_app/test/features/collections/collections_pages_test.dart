import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/collections/collections_pages.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';

void main() {
  testWidgets('Collections page keeps the Liked Tracks entry and create action', (tester) async {
    final collections = [WzCollection.liked(nowMs: 1)];
    await tester.pumpWidget(
      MaterialApp(
        home: WzCollectionsPage(
          collections: collections,
          onBack: () {},
          onOpen: (_) {},
          onCreate: () {},
          onRename: (_) {},
          onDelete: (_) {},
        ),
      ),
    );
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Liked Tracks'), findsWidgets);
    expect(find.textContaining('Create'), findsWidgets);
  });

  testWidgets('collection detail exposes an explicit drag handle for reordering', (tester) async {
    WzCollectionTrackSnapshot track(String id) => WzCollectionTrackSnapshot(
          trackId: id,
          title: 'Track $id',
          subtitle: 'Artist',
          source: WzCollectionTrackSource.device,
          addedAtMs: 1,
        );
    final collection = WzCollection(
      id: 'playlist-1',
      name: 'Road trip',
      type: WzCollectionType.user,
      createdAtMs: 1,
      updatedAtMs: 1,
      tracks: [track('a'), track('b')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzCollectionDetailPage(
            collection: collection,
            onBack: () {},
            onPlayFirst: (_) {},
            onAddAllToQueue: (_) {},
            onRename: (_) {},
            onDelete: (_) {},
            onPlayTrack: (_) {},
            onAddTrackToQueue: (_) {},
            onRemoveTrack: (_, __) {},
            onReorderTrack: (_, __, ___) {},
            resolver: (snapshot) => CatalogTrackSummary(
              trackId: snapshot.trackId,
              title: snapshot.title,
              artistName: snapshot.subtitle,
              source: 'device',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hold the handle to reorder'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(3));
    expect(find.text('Track a'), findsOneWidget);
    expect(find.text('Track b'), findsOneWidget);
  });
}
