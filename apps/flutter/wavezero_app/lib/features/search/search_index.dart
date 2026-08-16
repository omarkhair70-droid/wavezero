import '../../catalog/catalog_track_manifest.dart';
import '../collections/collections_service.dart';
import '../history/listening_history_service.dart';
import 'search_results.dart';
import 'search_text.dart';

typedef WzHistoryResolver = CatalogTrackSummary? Function(
  WzListeningHistoryEntry entry,
);

typedef WzDeviceTrackPredicate = bool Function(CatalogTrackSummary track);
typedef WzHistorySourceLabel = String Function(WzListeningHistorySource source);

List<WzSearchResult> buildWzSearchIndex({
  required List<CatalogTrackSummary> catalogTracks,
  required List<CatalogTrackSummary> deviceTracks,
  required List<CatalogTrackSummary> downloadedTracks,
  required List<CatalogTrackSummary> cloudTracks,
  required List<WzCollection> collections,
  required List<WzListeningHistoryEntry> historyEntries,
  required WzHistoryResolver resolveHistoryEntry,
  required WzDeviceTrackPredicate isDeviceTrack,
  required WzHistorySourceLabel historySourceLabel,
}) {
  final results = <WzSearchResult>[];

  WzSearchResult resultForTrack(
    CatalogTrackSummary track,
    WzSearchResultType type,
    WzSearchSource source,
    String secondary,
  ) {
    final asset = track.primaryAsset;
    final label = wzSearchSourceLabel(source);
    return WzSearchResult(
      id: '${source.name}:${track.trackId}',
      title: track.title,
      subtitle: track.subtitle,
      type: type,
      source: source,
      artworkUrl: track.artworkUrl,
      trackId: track.trackId,
      qualityLabel: asset?.qualityLabel,
      codec: asset?.codec,
      license: isDeviceTrack(track) ? LicenseMetadata.userDevice : track.license,
      available: asset?.manifestUrl.trim().isNotEmpty == true,
      secondaryLabel: secondary,
      searchText: normalizeWzSearch([
        track.title,
        track.subtitle,
        track.artistName ?? '',
        track.albumName ?? '',
        track.displayName ?? '',
        label,
        secondary,
        asset?.qualityLabel ?? '',
        asset?.codec ?? '',
        track.license.badgeLabel,
        track.license.sourceName ?? '',
        track.license.usageNotes ?? '',
      ].join(' ')),
      track: track,
    );
  }

  for (final track in catalogTracks) {
    final source = track.license.needsRightsWarning ||
            track.license.sourceName?.toLowerCase().contains('demo') == true
        ? WzSearchSource.legalDemo
        : WzSearchSource.apiCatalog;
    results.add(
      resultForTrack(
        track,
        WzSearchResultType.track,
        source,
        source == WzSearchSource.legalDemo ? 'Legal demo catalog' : 'Catalog',
      ),
    );
  }
  for (final track in deviceTracks) {
    results.add(
      resultForTrack(
        track,
        WzSearchResultType.deviceTrack,
        WzSearchSource.deviceMusic,
        'Your device music',
      ),
    );
  }
  for (final track in downloadedTracks) {
    results.add(
      resultForTrack(
        track,
        WzSearchResultType.downloadedTrack,
        WzSearchSource.downloads,
        'Offline Ready download',
      ),
    );
  }
  for (final track in cloudTracks) {
    results.add(
      resultForTrack(
        track,
        WzSearchResultType.cloudTrack,
        WzSearchSource.cloudVault,
        'Cloud Vault metadata only',
      ),
    );
  }

  for (final collection in collections) {
    results.add(
      WzSearchResult(
        id: 'collection:${collection.id}',
        title: collection.name,
        subtitle: collection.type == WzCollectionType.liked
            ? '${collection.trackCount} liked tracks'
            : '${collection.trackCount} collection tracks',
        type: WzSearchResultType.collection,
        source: WzSearchSource.collections,
        collectionId: collection.id,
        available: true,
        secondaryLabel: collection.type == WzCollectionType.liked
            ? 'Liked Tracks'
            : 'Collection',
        searchText: normalizeWzSearch([
          collection.name,
          collection.description ?? '',
          'Collections',
          collection.type == WzCollectionType.liked ? 'Liked Tracks' : 'Playlist',
          ...collection.tracks.expand(
            (track) => [
              track.title,
              track.subtitle,
              track.albumName ?? '',
              track.license.badgeLabel,
              track.license.sourceName ?? '',
            ],
          ),
        ].join(' ')),
        collection: collection,
      ),
    );
  }

  for (final entry in historyEntries) {
    final resolved = resolveHistoryEntry(entry);
    results.add(
      WzSearchResult(
        id: 'history:${entry.trackId}',
        title: entry.title,
        subtitle: entry.subtitle,
        type: WzSearchResultType.historyEntry,
        source: WzSearchSource.history,
        artworkUrl: entry.artworkUrl,
        trackId: resolved?.trackId,
        historyTrackId: entry.trackId,
        qualityLabel: entry.qualityLabel,
        codec: entry.codec,
        license: entry.license,
        available: resolved != null,
        secondaryLabel:
            'Recently played • ${entry.playCount} play${entry.playCount == 1 ? '' : 's'}',
        searchText: normalizeWzSearch([
          entry.title,
          entry.subtitle,
          entry.albumName ?? '',
          'History Recently Played Continue Listening',
          historySourceLabel(entry.source),
          entry.qualityLabel ?? '',
          entry.codec ?? '',
          entry.license.badgeLabel,
          entry.license.sourceName ?? '',
        ].join(' ')),
        track: resolved,
        historyEntry: entry,
      ),
    );
  }

  return results;
}
