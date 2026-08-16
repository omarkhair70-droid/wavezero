import '../../catalog/catalog_track_manifest.dart';
import '../collections/collections_service.dart';
import '../history/listening_history_service.dart';
import 'search_controls.dart';
import 'search_text.dart';

enum WzSearchResultType {
  track,
  deviceTrack,
  downloadedTrack,
  cloudTrack,
  collection,
  historyEntry,
  artistLike,
  unknown,
}

enum WzSearchSource {
  apiCatalog,
  deviceMusic,
  downloads,
  cloudVault,
  collections,
  history,
  legalDemo,
}

class WzSearchResult {
  const WzSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.source,
    this.artworkUrl,
    this.trackId,
    this.collectionId,
    this.historyTrackId,
    this.qualityLabel,
    this.codec,
    this.license,
    this.available = true,
    required this.secondaryLabel,
    required this.searchText,
    this.track,
    this.collection,
    this.historyEntry,
  });

  final String id;
  final String title;
  final String subtitle;
  final WzSearchResultType type;
  final WzSearchSource source;
  final String? artworkUrl;
  final String? trackId;
  final String? collectionId;
  final String? historyTrackId;
  final String? qualityLabel;
  final String? codec;
  final LicenseMetadata? license;
  final bool available;
  final String secondaryLabel;
  final String searchText;
  final CatalogTrackSummary? track;
  final WzCollection? collection;
  final WzListeningHistoryEntry? historyEntry;

  bool get isTrackLike => track != null || historyEntry != null;
}

String wzSearchSourceLabel(WzSearchSource source) => switch (source) {
      WzSearchSource.apiCatalog => 'Catalog',
      WzSearchSource.deviceMusic => 'Device music',
      WzSearchSource.downloads => 'Downloads',
      WzSearchSource.cloudVault => 'Cloud Vault',
      WzSearchSource.collections => 'Collections',
      WzSearchSource.history => 'History',
      WzSearchSource.legalDemo => 'Legal demo catalog',
    };

String wzSearchTypeLabel(WzSearchResultType type) => switch (type) {
      WzSearchResultType.track => 'Song',
      WzSearchResultType.deviceTrack => 'Device song',
      WzSearchResultType.downloadedTrack => 'Offline song',
      WzSearchResultType.cloudTrack => 'Cloud track',
      WzSearchResultType.collection => 'Collection',
      WzSearchResultType.historyEntry => 'Recent play',
      WzSearchResultType.artistLike => 'Artist',
      WzSearchResultType.unknown => 'Result',
    };

bool wzSearchFilterAllows(WzSearchFilter filter, WzSearchResult result) => switch (filter) {
      WzSearchFilter.all => true,
      WzSearchFilter.songs => result.type == WzSearchResultType.track ||
          result.type == WzSearchResultType.deviceTrack ||
          result.type == WzSearchResultType.downloadedTrack ||
          result.type == WzSearchResultType.cloudTrack,
      WzSearchFilter.device => result.source == WzSearchSource.deviceMusic,
      WzSearchFilter.downloads => result.source == WzSearchSource.downloads,
      WzSearchFilter.cloud => result.source == WzSearchSource.cloudVault,
      WzSearchFilter.collections => result.type == WzSearchResultType.collection || result.source == WzSearchSource.collections,
      WzSearchFilter.history => result.source == WzSearchSource.history,
      WzSearchFilter.legalDemo => result.source == WzSearchSource.legalDemo || result.license?.needsRightsWarning == true,
    };

int wzSearchRank(WzSearchResult result, String query) {
  final q = normalizeWzSearch(query);
  final title = normalizeWzSearch(result.title);
  final subtitle = normalizeWzSearch(result.subtitle);
  final source = normalizeWzSearch(wzSearchSourceLabel(result.source));
  final license = normalizeWzSearch(result.license?.badgeLabel ?? '');
  if (title == q) return 0;
  if (title.startsWith(q)) return 10;
  if (title.contains(q)) return 20;
  if (subtitle.contains(q)) return 30;
  if (result.type == WzSearchResultType.collection && result.searchText.contains(q)) return 40;
  if (result.source == WzSearchSource.history ||
      result.source == WzSearchSource.downloads ||
      result.source == WzSearchSource.deviceMusic) {
    return 50;
  }
  if (source.contains(q) || license.contains(q)) return 60;
  return 80;
}
