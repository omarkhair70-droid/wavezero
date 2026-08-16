from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../features/collections/collections_service.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Collections import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/collections/collection_resolution.dart';\n", 1)

old_liked = "  bool _isLiked(String trackId) => _likedCollection.tracks.any((track) => track.trackId == trackId);"
new_liked = "  bool _isLiked(String trackId) => wzCollectionContainsTrack(_likedCollection, trackId);"
if text.count(old_liked) != 1:
    raise SystemExit(f'expected one liked predicate, found {text.count(old_liked)}')
text = text.replace(old_liked, new_liked, 1)

old_resolver = """  CatalogTrackSummary? _resolveCollectionTrack(WzCollectionTrackSnapshot snapshot) {
    for (final track in _libraryTracks) {
      if (track.trackId == snapshot.trackId) return track;
    }
    return null;
  }
"""
new_resolver = """  CatalogTrackSummary? _resolveCollectionTrack(WzCollectionTrackSnapshot snapshot) =>
      wzResolveCollectionTrack(libraryTracks: _libraryTracks, snapshot: snapshot);
"""
if text.count(old_resolver) != 1:
    raise SystemExit(f'expected one collection resolver, found {text.count(old_resolver)}')
text = text.replace(old_resolver, new_resolver, 1)
path.write_text(text)
