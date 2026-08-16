import '../../catalog/catalog_track_manifest.dart';
import 'library_controls.dart';

List<CatalogTrackSummary> composeWzLibraryTracks({
  required WzLibrarySourceFilter filter,
  required List<CatalogTrackSummary> catalogTracks,
  required List<CatalogTrackSummary> deviceTracks,
  required List<CatalogTrackSummary> downloadedTracks,
  required List<CatalogTrackSummary> cloudTracks,
}) {
  return switch (filter) {
    WzLibrarySourceFilter.all => <CatalogTrackSummary>[
        ...catalogTracks,
        ...deviceTracks,
        ...downloadedTracks,
        ...cloudTracks,
      ],
    WzLibrarySourceFilter.api => catalogTracks,
    WzLibrarySourceFilter.device => deviceTracks,
    WzLibrarySourceFilter.downloads => downloadedTracks,
    WzLibrarySourceFilter.cloud => cloudTracks,
  };
}
