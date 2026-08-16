from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../features/collections/collection_resolution.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Collections import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/collections/collection_mutations.dart';\n", 1)

old_toggle = """  Future<void> _toggleLikedTrack(CatalogTrackSummary track) async {
    final liked = _likedCollection;
    final exists = liked.tracks.any((entry) => entry.trackId == track.trackId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextTracks = exists
        ? liked.tracks.where((entry) => entry.trackId != track.trackId).toList(growable: false)
        : [...liked.tracks.where((entry) => entry.trackId != track.trackId), _snapshotForTrack(track)];
    final nextCollections = _collections
        .map((collection) => collection.id == liked.id ? collection.copyWith(updatedAtMs: now, tracks: nextTracks) : collection)
        .toList(growable: false);
    await _persistCollections(nextCollections);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exists ? 'Removed from Liked Tracks' : 'Added to Collection')));
  }
"""
new_toggle = """  Future<void> _toggleLikedTrack(CatalogTrackSummary track) async {
    final liked = _likedCollection;
    final exists = wzCollectionContainsTrack(liked, track.trackId);
    final nextCollections = wzToggleCollectionTrack(
      collections: _collections,
      collectionId: liked.id,
      snapshot: _snapshotForTrack(track),
      removeExisting: exists,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistCollections(nextCollections);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exists ? 'Removed from Liked Tracks' : 'Added to Collection')));
  }
"""

old_add = """  Future<void> _addTrackToCollection(WzCollection collection, CatalogTrackSummary track) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snapshot = _snapshotForTrack(track);
    final next = collection.tracks.where((entry) => entry.trackId != track.trackId).toList(growable: true)..add(snapshot);
    final nextCollections = _collections
        .map((item) => item.id == collection.id ? item.copyWith(updatedAtMs: now, tracks: next) : item)
        .toList(growable: false);
    await _persistCollections(nextCollections);
  }
"""
new_add = """  Future<void> _addTrackToCollection(WzCollection collection, CatalogTrackSummary track) async {
    final nextCollections = wzUpsertCollectionTrack(
      collections: _collections,
      collectionId: collection.id,
      snapshot: _snapshotForTrack(track),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistCollections(nextCollections);
  }
"""

old_remove = """  Future<void> _removeTrackFromCollection(WzCollection collection, WzCollectionTrackSnapshot track) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextCollections = _collections
        .map((item) => item.id == collection.id ? item.copyWith(updatedAtMs: now, tracks: item.tracks.where((entry) => entry.trackId != track.trackId).toList(growable: false)) : item)
        .toList(growable: false);
    await _persistCollections(nextCollections);
  }
"""
new_remove = """  Future<void> _removeTrackFromCollection(WzCollection collection, WzCollectionTrackSnapshot track) async {
    final nextCollections = wzRemoveCollectionTrack(
      collections: _collections,
      collectionId: collection.id,
      trackId: track.trackId,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistCollections(nextCollections);
  }
"""

old_rename = """  Future<void> _renameCollection(WzCollection collection, String name) async {
    if (collection.type == WzCollectionType.liked) return;
    final trimmed = name.trim().isEmpty ? 'My Collection' : name.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _persistCollections(_collections.map((item) => item.id == collection.id ? item.copyWith(name: trimmed, updatedAtMs: now) : item).toList(growable: false));
  }
"""
new_rename = """  Future<void> _renameCollection(WzCollection collection, String name) async {
    if (collection.type == WzCollectionType.liked) return;
    final trimmed = name.trim().isEmpty ? 'My Collection' : name.trim();
    await _persistCollections(wzRenameCollection(
      collections: _collections,
      collectionId: collection.id,
      name: trimmed,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }
"""

old_delete = """  Future<void> _deleteCollection(WzCollection collection) async {
    if (collection.type == WzCollectionType.liked) return;
    await _persistCollections(_collections.where((item) => item.id != collection.id).toList(growable: false));
    if (!mounted) return;
    setState(() => _selectedCollectionId = likedTracksCollectionId);
  }
"""
new_delete = """  Future<void> _deleteCollection(WzCollection collection) async {
    if (collection.type == WzCollectionType.liked) return;
    await _persistCollections(wzDeleteCollection(
      collections: _collections,
      collectionId: collection.id,
    ));
    if (!mounted) return;
    setState(() => _selectedCollectionId = likedTracksCollectionId);
  }
"""

for label, old, new in [
    ('toggle', old_toggle, new_toggle),
    ('add', old_add, new_add),
    ('remove', old_remove, new_remove),
    ('rename', old_rename, new_rename),
    ('delete', old_delete, new_delete),
]:
    if text.count(old) != 1:
        raise SystemExit(f'{label}: expected one source block, found {text.count(old)}')
    text = text.replace(old, new, 1)

path.write_text(text)
