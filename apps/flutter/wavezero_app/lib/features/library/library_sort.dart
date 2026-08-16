import '../../catalog/catalog_track_manifest.dart';
import 'library_controls.dart';

typedef WzLibraryAddedRank = int Function(CatalogTrackSummary track);

List<CatalogTrackSummary> sortWzLibraryTracks(
  List<CatalogTrackSummary> tracks, {
  required WzLibrarySortMode mode,
  required WzLibraryAddedRank addedRank,
}) {
  final indexed = tracks.indexed.toList(growable: false);

  int compareNullableString(String? a, String? b) {
    final left = (a == null || a.trim().isEmpty) ? '~' : a.trim().toLowerCase();
    final right = (b == null || b.trim().isEmpty) ? '~' : b.trim().toLowerCase();
    return left.compareTo(right);
  }

  int compareNullableDuration(int? a, int? b, {required bool longestFirst}) {
    final left = a ?? (longestFirst ? -1 : 1 << 30);
    final right = b ?? (longestFirst ? -1 : 1 << 30);
    return longestFirst ? right.compareTo(left) : left.compareTo(right);
  }

  int compare((int, CatalogTrackSummary) a, (int, CatalogTrackSummary) b) {
    final left = a.$2;
    final right = b.$2;
    final result = switch (mode) {
      WzLibrarySortMode.recentlyAdded => addedRank(right).compareTo(addedRank(left)),
      WzLibrarySortMode.titleAz => compareNullableString(left.title, right.title),
      WzLibrarySortMode.artistAz => compareNullableString(
          left.artistName ?? left.albumName,
          right.artistName ?? right.albumName,
        ),
      WzLibrarySortMode.longestDuration => compareNullableDuration(
          left.durationMs,
          right.durationMs,
          longestFirst: true,
        ),
      WzLibrarySortMode.shortestDuration => compareNullableDuration(
          left.durationMs,
          right.durationMs,
          longestFirst: false,
        ),
      WzLibrarySortMode.quality => compareNullableString(
          left.primaryAsset?.qualityLabel,
          right.primaryAsset?.qualityLabel,
        ),
    };
    return result == 0 ? a.$1.compareTo(b.$1) : result;
  }

  indexed.sort(compare);
  return indexed.map((entry) => entry.$2).toList(growable: false);
}
