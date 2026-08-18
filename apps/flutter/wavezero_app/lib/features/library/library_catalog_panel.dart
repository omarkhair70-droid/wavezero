import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/curated_demo_picks.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/track_source.dart';
import '../../shared/widgets/wavezero_empty_message.dart';
import 'library_catalog_items.dart';
import 'library_controls.dart';
import 'library_source_overview.dart';

class WzLibraryCatalogPanel extends StatelessWidget {
  const WzLibraryCatalogPanel({
    super.key,
    required this.tracks,
    required this.totalTrackCount,
    required this.apiTrackCount,
    required this.deviceTrackCount,
    required this.cachedTrackCount,
    required this.cloudTrackCount,
    required this.combinedTrackCount,
    required this.visibleTrackCount,
    required this.filteredTrackCount,
    required this.catalogLimit,
    required this.largeCatalogMode,
    required this.onLoadMore,
    required this.cacheBytes,
    required this.curatedPicks,
    required this.selectedTrackId,
    required this.status,
    required this.loading,
    required this.refreshDisabled,
    required this.addToQueueDisabled,
    required this.searchController,
    required this.librarySourceFilter,
    required this.librarySortMode,
    required this.devicePermissionStatus,
    required this.deviceScanStatus,
    required this.deviceLastError,
    required this.onSourceFilterChanged,
    required this.onSortModeChanged,
    required this.onClearSearch,
    required this.onOpenFullSearch,
    required this.onOpenCloudVault,
    required this.onRefresh,
    required this.onImportDeviceMusic,
    required this.onSelectTrack,
    required this.onPlayCuratedPick,
    required this.onAddToQueue,
    required this.onToggleLike,
    required this.onAddToCollection,
    required this.isLiked,
    required this.onOpenCollections,
    required this.onCache,
    required this.onDeleteCachedTrack,
    this.showCloudSource = false,
    this.offlineMode = false,
  });

  final List<CatalogTrackSummary> tracks;
  final int totalTrackCount;
  final int apiTrackCount;
  final int deviceTrackCount;
  final int cachedTrackCount;
  final int cloudTrackCount;
  final int combinedTrackCount;
  final int visibleTrackCount;
  final int filteredTrackCount;
  final int catalogLimit;
  final bool largeCatalogMode;
  final VoidCallback? onLoadMore;
  final int cacheBytes;
  final List<ResolvedCuratedDemoPick> curatedPicks;
  final String? selectedTrackId;
  final String status;
  final bool loading;
  final bool refreshDisabled;
  final bool addToQueueDisabled;
  final TextEditingController searchController;
  final WzLibrarySourceFilter librarySourceFilter;
  final WzLibrarySortMode librarySortMode;
  final String devicePermissionStatus;
  final String deviceScanStatus;
  final String? deviceLastError;
  final ValueChanged<WzLibrarySourceFilter> onSourceFilterChanged;
  final ValueChanged<WzLibrarySortMode> onSortModeChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenFullSearch;
  final VoidCallback onOpenCloudVault;
  final VoidCallback onRefresh;
  final VoidCallback onImportDeviceMusic;
  final ValueChanged<CatalogTrackSummary> onSelectTrack;
  final ValueChanged<ResolvedCuratedDemoPick> onPlayCuratedPick;
  final ValueChanged<CatalogTrackSummary> onAddToQueue;
  final ValueChanged<CatalogTrackSummary> onToggleLike;
  final ValueChanged<CatalogTrackSummary> onAddToCollection;
  final bool Function(CatalogTrackSummary track) isLiked;
  final VoidCallback onOpenCollections;
  final ValueChanged<CatalogTrackSummary> onCache;
  final ValueChanged<CatalogTrackSummary> onDeleteCachedTrack;
  final bool showCloudSource;
  final bool offlineMode;

  @override
  Widget build(BuildContext context) {
    final hasQuery = searchController.text.trim().isNotEmpty;
    final countLabel = filteredTrackCount == 1 ? '1 track' : '$filteredTrackCount tracks';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WzLibrarySourceOverview(
          apiTrackCount: apiTrackCount,
          deviceTrackCount: deviceTrackCount,
          cachedTrackCount: cachedTrackCount,
          cloudTrackCount: cloudTrackCount,
          combinedTrackCount: combinedTrackCount,
          cacheBytes: cacheBytes,
          status: status,
          loading: loading,
          refreshDisabled: refreshDisabled,
          librarySourceFilter: librarySourceFilter,
          devicePermissionStatus: devicePermissionStatus,
          deviceScanStatus: deviceScanStatus,
          deviceLastError: deviceLastError,
          onSourceFilterChanged: onSourceFilterChanged,
          onRefresh: onRefresh,
          onImportDeviceMusic: onImportDeviceMusic,
          onOpenCollections: onOpenCollections,
          onOpenFullSearch: onOpenFullSearch,
          onOpenCloudVault: onOpenCloudVault,
          showCloudSource: showCloudSource,
        ),
        const SizedBox(height: 24),
        WzGlassCard(
          borderRadius: 32,
          padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 20, color: WzColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search your music',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: hasQuery
                        ? IconButton(
                            tooltip: 'Clear search',
                            onPressed: onClearSearch,
                            icon: const Icon(Icons.close_rounded, size: 18),
                          )
                        : null,
                  ),
                ),
              ),
              PopupMenuButton<WzLibrarySortMode>(
                tooltip: 'Sort Library',
                icon: const Icon(Icons.swap_vert_rounded, color: WzColors.textMuted),
                onSelected: onSortModeChanged,
                itemBuilder: (_) => WzLibrarySortMode.values
                    .map((mode) => PopupMenuItem(value: mode, child: Text(mode.label)))
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                librarySourceFilter == WzLibrarySourceFilter.all ? 'Your music' : wzLibrarySourceFilterShortLabel(librarySourceFilter),
                style: WzText.title,
              ),
            ),
            Text(countLabel, style: WzText.caption),
          ],
        ),
        const SizedBox(height: 12),
        if (totalTrackCount == 0)
          WzEmptyCatalogMessage(
            message: offlineMode
                ? 'Nothing is saved offline yet.'
                : 'Your Library is quiet. Add Device Music or come back when your online music is available.',
          )
        else if (tracks.isEmpty)
          WzEmptyCatalogMessage(
            message: hasQuery
                ? 'Nothing matches this search.'
                : 'Nothing is in ${wzLibrarySourceFilterShortLabel(librarySourceFilter)} yet.',
          )
        else ...[
          SizedBox(
            height: math.min(610.0, math.max(230.0, tracks.length * 82.0)),
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return WzLibraryCatalogRow(
                  track: track,
                  selected: track.trackId == selectedTrackId,
                  addDisabled: addToQueueDisabled || (track.source == 'cloud_vault' && track.primaryAsset == null),
                  onTap: () => onSelectTrack(track),
                  onAdd: () => onAddToQueue(track),
                  onToggleLike: () => onToggleLike(track),
                  onAddToCollection: () => onAddToCollection(track),
                  liked: isLiked(track),
                  onCache: isWzDeviceCatalogTrack(track) || isWzCachedCatalogTrack(track) || track.source == 'cloud_vault'
                      ? null
                      : () => onCache(track),
                  onDeleteCached: isWzCachedCatalogTrack(track) ? () => onDeleteCachedTrack(track) : null,
                );
              },
            ),
          ),
          if (onLoadMore != null) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: onLoadMore,
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Show more'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
