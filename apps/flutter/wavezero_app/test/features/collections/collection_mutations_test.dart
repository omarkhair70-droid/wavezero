import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/collections/collection_mutations.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';

void main() {
  WzCollectionTrackSnapshot track(String id, {String? title}) =>
      WzCollectionTrackSnapshot(
        trackId: id,
        title: title ?? id,
        subtitle: 'Artist',
        source: WzCollectionTrackSource.unknown,
        addedAtMs: 1,
      );

  WzCollection collection({
    String id = 'c1',
    String name = 'List',
    List<WzCollectionTrackSnapshot> tracks = const [],
  }) =>
      WzCollection(
        id: id,
        name: name,
        type: WzCollectionType.user,
        createdAtMs: 1,
        updatedAtMs: 1,
        tracks: tracks,
      );

  test('toggle removes an existing track and preserves other order', () {
    final result = wzToggleCollectionTrack(
      collections: [collection(tracks: [track('a'), track('b')])],
      collectionId: 'c1',
      snapshot: track('a'),
      removeExisting: true,
      updatedAtMs: 10,
    ).single;
    expect(result.tracks.map((item) => item.trackId), ['b']);
    expect(result.updatedAtMs, 10);
  });

  test('upsert deduplicates then appends the newest snapshot', () {
    final newest = track('a', title: 'Newest');
    final result = wzUpsertCollectionTrack(
      collections: [collection(tracks: [track('a'), track('b')])],
      collectionId: 'c1',
      snapshot: newest,
      updatedAtMs: 20,
    ).single;
    expect(result.tracks.map((item) => item.trackId), ['b', 'a']);
    expect(result.tracks.last.title, 'Newest');
  });

  test('bulk upsert preserves untouched order and appends selected order once', () {
    final result = wzUpsertCollectionTracks(
      collections: [collection(tracks: [track('a'), track('b'), track('c')])],
      collectionId: 'c1',
      snapshots: [track('b', title: 'B new'), track('d')],
      updatedAtMs: 25,
    ).single;

    expect(result.tracks.map((item) => item.trackId), ['a', 'c', 'b', 'd']);
    expect(result.tracks[2].title, 'B new');
    expect(result.updatedAtMs, 25);
  });

  test('bulk remove deletes only selected ids', () {
    final result = wzRemoveCollectionTracks(
      collections: [collection(tracks: [track('a'), track('b'), track('c')])],
      collectionId: 'c1',
      trackIds: {'a', 'c'},
      updatedAtMs: 35,
    ).single;

    expect(result.tracks.map((item) => item.trackId), ['b']);
    expect(result.updatedAtMs, 35);
  });

  test('reorder follows Flutter list semantics and persists the new order', () {
    final original = collection(tracks: [track('a'), track('b'), track('c')]);

    final movedToEnd = wzReorderCollectionTrack(
      collections: [original],
      collectionId: 'c1',
      oldIndex: 0,
      newIndex: 3,
      updatedAtMs: 50,
    ).single;
    expect(movedToEnd.tracks.map((item) => item.trackId), ['b', 'c', 'a']);
    expect(movedToEnd.updatedAtMs, 50);

    final movedToStart = wzReorderCollectionTrack(
      collections: [original],
      collectionId: 'c1',
      oldIndex: 2,
      newIndex: 0,
      updatedAtMs: 60,
    ).single;
    expect(movedToStart.tracks.map((item) => item.trackId), ['c', 'a', 'b']);
  });

  test('invalid reorder leaves collection order untouched', () {
    final original = collection(tracks: [track('a'), track('b')]);
    final result = wzReorderCollectionTrack(
      collections: [original],
      collectionId: 'c1',
      oldIndex: 9,
      newIndex: 0,
      updatedAtMs: 70,
    ).single;
    expect(result.tracks.map((item) => item.trackId), ['a', 'b']);
    expect(result.updatedAtMs, 1);
  });

  test('remove, rename, and delete target only the requested collection', () {
    final first = collection(id: 'c1', tracks: [track('a')]);
    final second = collection(id: 'c2', name: 'Second', tracks: [track('b')]);
    final removed = wzRemoveCollectionTrack(
      collections: [first, second],
      collectionId: 'c1',
      trackId: 'a',
      updatedAtMs: 30,
    );
    expect(removed.first.tracks, isEmpty);
    expect(removed.last.tracks.single.trackId, 'b');

    final renamed = wzRenameCollection(
      collections: removed,
      collectionId: 'c2',
      name: 'Renamed',
      updatedAtMs: 40,
    );
    expect(renamed.last.name, 'Renamed');

    final deleted = wzDeleteCollection(
      collections: renamed,
      collectionId: 'c1',
    );
    expect(deleted.map((item) => item.id), ['c2']);
  });
}
