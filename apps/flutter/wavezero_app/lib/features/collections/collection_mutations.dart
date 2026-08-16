import 'collections_service.dart';

List<WzCollection> wzToggleCollectionTrack({
  required List<WzCollection> collections,
  required String collectionId,
  required WzCollectionTrackSnapshot snapshot,
  required bool removeExisting,
  required int updatedAtMs,
}) {
  return collections
      .map((collection) {
        if (collection.id != collectionId) return collection;
        final withoutTrack = collection.tracks
            .where((entry) => entry.trackId != snapshot.trackId)
            .toList(growable: false);
        final tracks = removeExisting
            ? withoutTrack
            : [...withoutTrack, snapshot];
        return collection.copyWith(updatedAtMs: updatedAtMs, tracks: tracks);
      })
      .toList(growable: false);
}

List<WzCollection> wzUpsertCollectionTrack({
  required List<WzCollection> collections,
  required String collectionId,
  required WzCollectionTrackSnapshot snapshot,
  required int updatedAtMs,
}) =>
    collections
        .map((collection) {
          if (collection.id != collectionId) return collection;
          final tracks = collection.tracks
              .where((entry) => entry.trackId != snapshot.trackId)
              .toList(growable: true)
            ..add(snapshot);
          return collection.copyWith(updatedAtMs: updatedAtMs, tracks: tracks);
        })
        .toList(growable: false);

List<WzCollection> wzRemoveCollectionTrack({
  required List<WzCollection> collections,
  required String collectionId,
  required String trackId,
  required int updatedAtMs,
}) =>
    collections
        .map((collection) => collection.id == collectionId
            ? collection.copyWith(
                updatedAtMs: updatedAtMs,
                tracks: collection.tracks
                    .where((entry) => entry.trackId != trackId)
                    .toList(growable: false),
              )
            : collection)
        .toList(growable: false);

List<WzCollection> wzRenameCollection({
  required List<WzCollection> collections,
  required String collectionId,
  required String name,
  required int updatedAtMs,
}) =>
    collections
        .map((collection) => collection.id == collectionId
            ? collection.copyWith(name: name, updatedAtMs: updatedAtMs)
            : collection)
        .toList(growable: false);

List<WzCollection> wzDeleteCollection({
  required List<WzCollection> collections,
  required String collectionId,
}) =>
    collections
        .where((collection) => collection.id != collectionId)
        .toList(growable: false);
