from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
text = path.read_text()

old_method = '''  Future<void> _removeTrackFromCollection(
    WzCollection collection,
    WzCollectionTrackSnapshot track,
  ) async {
    final nextCollections = wzRemoveCollectionTrack(
      collections: _collections,
      collectionId: collection.id,
      trackId: track.trackId,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistCollections(nextCollections);
  }
'''
new_method = old_method + '''
  Future<void> _reorderCollectionTracks(
    WzCollection collection,
    int oldIndex,
    int newIndex,
  ) async {
    final nextCollections = wzReorderCollectionTrack(
      collections: _collections,
      collectionId: collection.id,
      oldIndex: oldIndex,
      newIndex: newIndex,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistCollections(nextCollections);
  }
'''
if old_method not in text:
    raise SystemExit('Expected collection removal method was not found')
text = text.replace(old_method, new_method, 1)

old_wiring = '''        onRemoveTrack: (collection, snapshot) =>
            unawaited(_removeTrackFromCollection(collection, snapshot)),
        resolver: _resolveCollectionTrack,
'''
new_wiring = '''        onRemoveTrack: (collection, snapshot) =>
            unawaited(_removeTrackFromCollection(collection, snapshot)),
        onReorderTrack: (collection, oldIndex, newIndex) =>
            unawaited(_reorderCollectionTracks(collection, oldIndex, newIndex)),
        resolver: _resolveCollectionTrack,
'''
if old_wiring not in text:
    raise SystemExit('Expected collection detail wiring was not found')
path.write_text(text.replace(old_wiring, new_wiring, 1))
