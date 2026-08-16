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
    return WzPanel(
      child: Column(
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
          const SizedBox(height: 12),
          WzFeaturedDemoLibraryShelf(picks: curatedPicks, onPlayPick: onPlayCuratedPick),
          const SizedBox(height: 12),
          DropdownButtonFormField<WzLibrarySortMode>(
            initialValue: librarySortMode,
            decoration: const InputDecoration(labelText: 'Sort library'),
            items: WzLibrarySortMode.values
                .map((mode) => DropdownMenuItem(value: mode, child: Text(mode.label)))
                .toList(growable: false),
            onChanged: (mode) {
              if (mode != null) onSortModeChanged(mode);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Search ${librarySourceFilter.label}',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasQuery ? IconButton(onPressed: onClearSearch, icon: const Icon(Icons.close)) : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery
                ? '$filteredTrackCount result${filteredTrackCount == 1 ? '' : 's'} in ${librarySourceFilter.label}; showing $visibleTrackCount.'
                : largeCatalogMode
                    ? 'Large library ready. Showing $visibleTrackCount of $filteredTrackCount tracks in a safe $catalogLimit-track window. Total available: $combinedTrackCount.'
                    : 'Showing $visibleTrackCount of $filteredTrackCount tracks in ${librarySourceFilter.label}. Total available: $combinedTrackCount.',
            style: _captionStyle,
          ),
          const SizedBox(height: 12),
          if (largeCatalogMode)
            WzStatusPill(label: 'Showing first $visibleTrackCount tracks', active: true, icon: Icons.library_music),
          const SizedBox(height: 12),
          if (totalTrackCount == 0)
            WzEmptyCatalogMessage(
              message: offlineMode
                  ? 'No downloads are ready offline yet. Save tracks from Library before going offline.'
                  : 'Your catalog is waiting. Refresh when you are online or import device music to begin.',
            )
          else if (tracks.isEmpty)
            WzEmptyCatalogMessage(
              message: hasQuery
                  ? 'No tracks match this search. Clear it to return to ${librarySourceFilter.label}.'
                  : 'No tracks available in ${librarySourceFilter.label} yet.',
            )
          else ...[
            SizedBox(
              height: math.min(560.0, math.max(220.0, tracks.length * 96.0)),
              child: ListView.builder(
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
                child: OutlinedButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.expand_more),
                  label: Text('Load more (${filteredTrackCount - visibleTrackCount} remaining)'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

const _captionStyle = TextStyle(color: Color(0xFF98A1B8), fontSize: 12);
