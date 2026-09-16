import 'dart:math' as math;

import '../../catalog/catalog_track_manifest.dart';

/// Builds a bounded queue around the track the listener explicitly chose.
///
/// Prefer the currently visible Library ordering when the track belongs to it.
/// Otherwise fall back to the full resolvable local-first Library. This keeps
/// direct taps continuous without replacing an existing queue that already
/// contains the selected track.
List<CatalogTrackSummary> wzPlaybackContextForTrack({
  required List<CatalogTrackSummary> preferredTracks,
  required List<CatalogTrackSummary> fallbackTracks,
  required String currentTrackId,
  int maxTracks = 200,
}) {
  if (currentTrackId.isEmpty || maxTracks <= 0) {
    return const <CatalogTrackSummary>[];
  }

  List<CatalogTrackSummary>? source;
  var index = preferredTracks.indexWhere(
    (track) => track.trackId == currentTrackId,
  );
  if (index >= 0) {
    source = preferredTracks;
  } else {
    index = fallbackTracks.indexWhere(
      (track) => track.trackId == currentTrackId,
    );
    if (index >= 0) source = fallbackTracks;
  }

  if (source == null || source.isEmpty) {
    return const <CatalogTrackSummary>[];
  }
  if (source.length <= maxTracks) {
    return List<CatalogTrackSummary>.of(source, growable: false);
  }

  // Keep some history before the selected song while reserving most of the
  // bounded queue for what naturally comes next.
  final before = math.min(index, maxTracks ~/ 4);
  var start = index - before;
  var end = math.min(source.length, start + maxTracks);
  start = math.max(0, end - maxTracks);

  return source.sublist(start, end).toList(growable: false);
}
