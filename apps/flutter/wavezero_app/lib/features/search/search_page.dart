import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/curated_demo_picks.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../collections/collections_service.dart';
import '../history/listening_history_service.dart';
import 'search_controls.dart';
import 'search_results.dart';
import 'search_page_support.dart';

class WzSearchPage extends StatelessWidget {
  const WzSearchPage({
    required this.controller,
    required this.onBack,
    required this.filter,
    required this.results,
    required this.allResultCount,
    required this.recentSearches,
    required this.history,
    required this.cachedTracks,
    required this.collections,
    required this.catalogTracks,
    required this.curatedPicks,
    required this.onFilterChanged,
    required this.onClearQuery,
    required this.onRecentSearch,
    required this.onClearRecentSearches,
    required this.onSubmitted,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onAddToCollection,
    required this.onOpenCollection,
    required this.onImportDeviceMusic,
    required this.onLoadCatalog,
    required this.onPlayCuratedPick,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final WzSearchFilter filter;
  final List<WzSearchResult> results;
  final int allResultCount;
  final List<String> recentSearches;
  final List<WzListeningHistoryEntry> history;
  final List<CatalogTrackSummary> cachedTracks;
  final List<WzCollection> collections;
  final List<CatalogTrackSummary> catalogTracks;
  final List<ResolvedCuratedDemoPick> curatedPicks;
  final ValueChanged<WzSearchFilter> onFilterChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onRecentSearch;
  final VoidCallback? onClearRecentSearches;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<WzSearchResult> onPlay;
  final ValueChanged<WzSearchResult> onAddToQueue;
  final ValueChanged<WzSearchResult> onAddToCollection;
  final ValueChanged<WzSearchResult> onOpenCollection;
  final VoidCallback onImportDeviceMusic;
  final VoidCallback onLoadCatalog;
  final ValueChanged<ResolvedCuratedDemoPick> onPlayCuratedPick;

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim();
    final hasQuery = query.isNotEmpty;
    return WzPageScaffold(
      children: [
        WzPageHeader(
          icon: Icons.search,
          title: 'Search',
          subtitle: 'Find tracks, downloads, collections, and recent plays on this device.',
          trailing: IconButton.outlined(tooltip: 'Back to Home', onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        ),
        const SizedBox(height: WzSpacing.md),
        WzPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  labelText: 'Search music',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: hasQuery ? IconButton(onPressed: onClearQuery, icon: const Icon(Icons.close)) : null,
                ),
              ),
              const SizedBox(height: WzSpacing.sm),
              Wrap(
                spacing: WzSpacing.xs,
                runSpacing: WzSpacing.xs,
                children: WzSearchFilter.values
                    .map((item) => ChoiceChip(
                          label: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          selected: filter == item,
                          onSelected: (_) => onFilterChanged(item),
                        ))
                    .toList(growable: false),
              ),
              const SizedBox(height: WzSpacing.sm),
              Text(
                hasQuery ? '${filter.label} • ${results.length} result${results.length == 1 ? '' : 's'}' : 'Search your local WaveZero library across $allResultCount available items.',
                style: WzText.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        if (!hasQuery) ...[
          if (curatedPicks.isNotEmpty) ...[
            WzCuratedTryPicksPanel(picks: curatedPicks, onPlay: onPlayCuratedPick),
            const SizedBox(height: WzSpacing.md),
          ],
          if (recentSearches.isNotEmpty) ...[
            const WzSectionHeader(title: 'Recent searches', subtitle: 'Stored on this device only.', icon: Icons.manage_search),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: onClearRecentSearches, child: const Text('Clear'))),
            WzPanel(child: Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: recentSearches.map((query) => ActionChip(label: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis), onPressed: () => onRecentSearch(query))).toList(growable: false))),
            const SizedBox(height: WzSpacing.md),
          ],
          _SearchDiscoverySections(
            history: history,
            cachedTracks: cachedTracks,
            collections: collections,
            catalogTracks: catalogTracks,
            onRecent: (entry) => onRecentSearch(entry.title),
            onTrack: (track) => onRecentSearch(track.title),
            onCollection: (collection) => onRecentSearch(collection.name),
          ),
        ] else if (results.isEmpty) ...[
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No matching music found.', style: WzText.title),
                const SizedBox(height: WzSpacing.xs),
                const Text('Try a different title, import device music, or refresh the catalog when you are online.', style: WzText.body),
                const SizedBox(height: WzSpacing.md),
                Wrap(spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
                  WzPrimaryAction(label: 'Import Device music', icon: Icons.perm_media, onPressed: onImportDeviceMusic),
                  OutlinedButton.icon(onPressed: onLoadCatalog, icon: const Icon(Icons.refresh), label: const Text('Load catalog')),
                ]),
              ],
            ),
          ),
        ] else ...[
          SizedBox(
            height: math.min(620.0, math.max(260.0, results.length * 150.0)),
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: WzSpacing.sm),
                  child: _SearchResultCard(
                    result: result,
                    onPlay: () => onPlay(result),
                    onAddToQueue: () => onAddToQueue(result),
                    onAddToCollection: () => onAddToCollection(result),
                    onOpenCollection: result.type == WzSearchResultType.collection ? () => onOpenCollection(result) : null,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result, required this.onPlay, required this.onAddToQueue, required this.onAddToCollection, required this.onOpenCollection});

  final WzSearchResult result;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;
  final VoidCallback onAddToCollection;
  final VoidCallback? onOpenCollection;

  @override
  Widget build(BuildContext context) => WzPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFF20283A), child: Icon(wzSearchResultIcon(result), color: WzColors.textPrimary)),
                const SizedBox(width: WzSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.title),
                      const SizedBox(height: WzSpacing.xxs),
                      Text(result.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: WzSpacing.sm),
            Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
              WzStatusPill(label: wzSearchSourceLabel(result.source), active: true, icon: Icons.label_outline),
              WzStatusPill(label: wzSearchTypeLabel(result.type), icon: wzSearchResultIcon(result)),
              if (result.qualityLabel != null) WzStatusPill(label: wzProductQualityLabel(result.qualityLabel!), icon: Icons.high_quality),
              if (result.codec != null) WzStatusPill(label: result.codec!, icon: Icons.settings_input_component),
              if (result.license != null) WzStatusPill(label: result.license!.badgeLabel, warning: result.license!.needsRightsWarning, icon: Icons.policy),
              if (!result.available) const WzStatusPill(label: 'Unavailable', warning: true, icon: Icons.block),
            ]),
            const SizedBox(height: WzSpacing.xs),
            Text(result.secondaryLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
            const SizedBox(height: WzSpacing.sm),
            Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
              if (onOpenCollection != null)
                WzPrimaryAction(label: 'Open Collection', icon: Icons.open_in_full, onPressed: onOpenCollection)
              else ...[
                WzPrimaryAction(label: 'Play', icon: Icons.play_arrow, onPressed: result.available ? onPlay : null),
                OutlinedButton.icon(onPressed: result.available ? onAddToQueue : null, icon: const Icon(Icons.queue_music), label: const Text('Add to Queue')),
                OutlinedButton.icon(onPressed: result.available ? onAddToCollection : null, icon: const Icon(Icons.playlist_add), label: const Text('Add to Collection')),
              ],
            ]),
          ],
        ),
      );
}

class _SearchDiscoverySections extends StatelessWidget {
  const _SearchDiscoverySections({required this.history, required this.cachedTracks, required this.collections, required this.catalogTracks, required this.onRecent, required this.onTrack, required this.onCollection});

  final List<WzListeningHistoryEntry> history;
  final List<CatalogTrackSummary> cachedTracks;
  final List<WzCollection> collections;
  final List<CatalogTrackSummary> catalogTracks;
  final ValueChanged<WzListeningHistoryEntry> onRecent;
  final ValueChanged<CatalogTrackSummary> onTrack;
  final ValueChanged<WzCollection> onCollection;

  @override
  Widget build(BuildContext context) {
    final visibleCollections = collections.where((collection) => collection.trackCount > 0 || collection.type == WzCollectionType.liked).take(5).toList(growable: false);
    final sections = <Widget>[];
    if (history.isNotEmpty) {
      sections.add(WzSearchDiscoveryPanel(title: 'Continue Listening', subtitle: 'Latest saved play.', icon: Icons.play_circle, children: [WzSearchDiscoveryButton(label: history.first.title, detail: history.first.subtitle, icon: Icons.history, onTap: () => onRecent(history.first))]));
      sections.add(WzSearchDiscoveryPanel(title: 'Recently Played', subtitle: 'Local listening history.', icon: Icons.schedule, children: history.take(5).map((entry) => WzSearchDiscoveryButton(label: entry.title, detail: entry.subtitle, icon: Icons.history, onTap: () => onRecent(entry))).toList(growable: false)));
    }
    if (cachedTracks.isNotEmpty) sections.add(WzSearchDiscoveryPanel(title: 'Downloaded / Offline Ready', subtitle: 'Cached tracks available locally.', icon: Icons.download_done, children: cachedTracks.take(5).map((track) => WzSearchDiscoveryButton(label: track.title, detail: track.subtitle, icon: Icons.download_done, onTap: () => onTrack(track))).toList(growable: false)));
    if (visibleCollections.isNotEmpty) sections.add(WzSearchDiscoveryPanel(title: 'Collections', subtitle: 'Liked Tracks and local playlists.', icon: Icons.playlist_play, children: visibleCollections.map((collection) => WzSearchDiscoveryButton(label: collection.name, detail: '${collection.trackCount} tracks', icon: collection.type == WzCollectionType.liked ? Icons.favorite : Icons.playlist_play, onTap: () => onCollection(collection))).toList(growable: false)));
    if (catalogTracks.isNotEmpty) sections.add(WzSearchDiscoveryPanel(title: 'Legal demo catalog', subtitle: 'Loaded catalog tracks with license labels.', icon: Icons.cloud_queue, children: catalogTracks.take(5).map((track) => WzSearchDiscoveryButton(label: track.title, detail: '${track.subtitle} • ${track.license.badgeLabel}', icon: Icons.music_note, onTap: () => onTrack(track))).toList(growable: false)));
    if (sections.isEmpty) return const WzPanel(child: Text('Import Device music or load the Catalog to search more.', style: WzText.body));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections.expand((section) => [section, const SizedBox(height: WzSpacing.md)]).toList(growable: false));
  }
}
