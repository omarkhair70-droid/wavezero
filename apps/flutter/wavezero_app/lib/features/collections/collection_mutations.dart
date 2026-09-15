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

List<WzCollection> wzUpsertCollectionTracks({
  required List<WzCollection> collections,
  required String collectionId,
  required List<WzCollectionTrackSnapshot> snapshots,
  required int updatedAtMs,
}) {
  if (snapshots.isEmpty) return collections;
  final incomingIds = snapshots.map((track) => track.trackId).toSet();
  return collections
      .map((collection) {
        if (collection.id != collectionId) return collection;
        final tracks = collection.tracks
            .where((entry) => !incomingIds.contains(entry.trackId))
            .toList(growable: true)
          ..addAll(snapshots);
        return collection.copyWith(
          updatedAtMs: updatedAtMs,
          tracks: tracks.toList(growable: false),
        );
      })
      .toList(growable: false);
}

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

List<WzCollection> wzRemoveCollectionTracks({
  required List<WzCollection> collections,
  required String collectionId,
  required Set<String> trackIds,
  required int updatedAtMs,
}) {
  if (trackIds.isEmpty) return collections;
  return collections
      .map((collection) => collection.id == collectionId
          ? collection.copyWith(
              updatedAtMs: updatedAtMs,
              tracks: collection.tracks
                  .where((entry) => !trackIds.contains(entry.trackId))
                  .toList(growable: false),
            )
          : collection)
      .toList(growable: false);
}

List<WzCollection> wzReorderCollectionTrack({
  required List<WzCollection> collections,
  required String collectionId,
  required int oldIndex,
  required int newIndex,
  required int updatedAtMs,
}) =>
    collections
        .map((collection) {
          if (collection.id != collectionId ||
              oldIndex < 0 ||
              oldIndex >= collection.tracks.length ||
              newIndex < 0 ||
              newIndex > collection.tracks.length) {
            return collection;
          }
          var targetIndex = newIndex;
          if (targetIndex > oldIndex) targetIndex -= 1;
          if (targetIndex == oldIndex) return collection;
          final tracks = collection.tracks.toList(growable: true);
          final moved = tracks.removeAt(oldIndex);
          final safeTargetIndex = targetIndex.clamp(0, tracks.length).toInt();
          tracks.insert(safeTargetIndex, moved);
          return collection.copyWith(
            updatedAtMs: updatedAtMs,
            tracks: tracks.toList(growable: false),
          );
        })
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
