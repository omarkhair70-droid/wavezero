import '../../catalog/catalog_track_manifest.dart';
import 'collections_service.dart';

bool wzCollectionContainsTrack(WzCollection collection, String trackId) =>
    collection.tracks.any((track) => track.trackId == trackId);

CatalogTrackSummary? wzResolveCollectionTrack({
  required List<CatalogTrackSummary> libraryTracks,
  required WzCollectionTrackSnapshot snapshot,
}) {
  for (final track in libraryTracks) {
    if (track.trackId == snapshot.trackId) return track;
  }
  return null;
}
