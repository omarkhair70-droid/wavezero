import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/curated_demo_picks.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../collections/collections_service.dart';
import '../history/listening_history_service.dart';
import 'search_controls.dart';
import 'search_results.dart';

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

  static const _consumerFilters = <WzSearchFilter>[
    WzSearchFilter.all,
    WzSearchFilter.songs,
    WzSearchFilter.device,
    WzSearchFilter.downloads,
    WzSearchFilter.collections,
    WzSearchFilter.history,
  ];

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim();
    final hasQuery = query.isNotEmpty;

    return WzPageScaffold(
      children: [
        Text('Search', style: WzText.pageTitle.copyWith(fontSize: 31)),
        const SizedBox(height: 18),
        _SearchField(
          controller: controller,
          hasQuery: hasQuery,
          onClearQuery: onClearQuery,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 13),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _consumerFilters
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item.label),
                      selected: filter == item,
                      onSelected: (_) => onFilterChanged(item),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 24),
        if (!hasQuery) ...[
          if (recentSearches.isNotEmpty) ...[
            Row(
              children: [
                const Expanded(child: Text('Recent searches', style: WzText.title)),
                TextButton(onPressed: onClearRecentSearches, child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentSearches
                  .map(
                    (item) => ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 16),
                      label: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onPressed: () => onRecentSearch(item),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 26),
          ],
          _DiscoveryGrid(
            history: history,
            cachedTracks: cachedTracks,
            collections: collections,
            catalogTracks: catalogTracks,
            onRecent: (entry) => onRecentSearch(entry.title),
            onTrack: (track) => onRecentSearch(track.title),
            onCollection: (collection) => onRecentSearch(collection.name),
          ),
          if (allResultCount == 0) ...[
            const SizedBox(height: 24),
            _QuietSearchEmpty(
              onImportDeviceMusic: onImportDeviceMusic,
              onLoadCatalog: onLoadCatalog,
            ),
          ],
        ] else if (results.isEmpty) ...[
          _QuietSearchEmpty(
            title: 'Nothing found',
            subtitle: 'Try another title, artist, or something already on this device.',
            onImportDeviceMusic: onImportDeviceMusic,
            onLoadCatalog: onLoadCatalog,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(child: Text('Results', style: WzText.title)),
              Text('${results.length}', style: WzText.caption),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: math.min(620.0, math.max(260.0, results.length * 78.0)),
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _SearchResultRow(
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hasQuery, required this.onClearQuery, required this.onSubmitted});

  final TextEditingController controller;
  final bool hasQuery;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(15, 5, 8, 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFCFFFFFF), Color(0xF1F7FAFC)]),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: const Color(0xF2FFFFFF)),
          boxShadow: WzSurface.softShadows,
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: WzColors.textMuted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmitted,
                decoration: const InputDecoration(
                  hintText: 'Songs, artists, collections…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            if (hasQuery)
              IconButton(
                tooltip: 'Clear search',
                onPressed: onClearQuery,
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
          ],
        ),
      );
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.result,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onAddToCollection,
    required this.onOpenCollection,
  });

  final WzSearchResult result;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;
  final VoidCallback onAddToCollection;
  final VoidCallback? onOpenCollection;

  @override
  Widget build(BuildContext context) {
    final isCollection = onOpenCollection != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: isCollection
            ? onOpenCollection
            : result.available
                ? () {
                    HapticFeedback.selectionClick();
                    onPlay();
                  }
                : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(23),
                  bottomRight: Radius.circular(15),
                ),
                child: WzArtwork(
                  artworkUrl: result.artworkUrl,
                  size: 58,
                  trackId: result.trackId ?? result.historyTrackId ?? result.id,
                  title: result.title,
                  artist: result.subtitle,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(result.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                    if (!result.available) ...[
                      const SizedBox(height: 2),
                      Text('Unavailable right now', style: WzText.caption.copyWith(fontSize: 10.5, color: WzColors.warning)),
                    ],
                  ],
                ),
              ),
              if (isCollection)
                const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: WzColors.textSubtle)
              else ...[
                WzSculptedIconButton(
                  tooltip: 'Play',
                  icon: Icons.play_arrow_rounded,
                  size: 38,
                  iconSize: 19,
                  onPressed: result.available ? onPlay : null,
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_horiz_rounded, color: WzColors.textMuted),
                  onSelected: (value) {
                    if (value == 'queue') onAddToQueue();
                    if (value == 'collection') onAddToCollection();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(enabled: result.available, value: 'queue', child: const Text('Add to queue')),
                    PopupMenuItem(enabled: result.available, value: 'collection', child: const Text('Add to collection')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryGrid extends StatelessWidget {
  const _DiscoveryGrid({
    required this.history,
    required this.cachedTracks,
    required this.collections,
    required this.catalogTracks,
    required this.onRecent,
    required this.onTrack,
    required this.onCollection,
  });

  final List<WzListeningHistoryEntry> history;
  final List<CatalogTrackSummary> cachedTracks;
  final List<WzCollection> collections;
  final List<CatalogTrackSummary> catalogTracks;
  final ValueChanged<WzListeningHistoryEntry> onRecent;
  final ValueChanged<CatalogTrackSummary> onTrack;
  final ValueChanged<WzCollection> onCollection;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    if (history.isNotEmpty) {
      cards.add(_DiscoveryTile(icon: Icons.history_rounded, title: 'Recently played', subtitle: history.first.title, onTap: () => onRecent(history.first)));
    }
    if (cachedTracks.isNotEmpty) {
      cards.add(_DiscoveryTile(icon: Icons.download_done_rounded, title: 'Offline', subtitle: '${cachedTracks.length} saved', onTap: () => onTrack(cachedTracks.first)));
    }
    final visibleCollections = collections.where((item) => item.trackCount > 0 || item.type == WzCollectionType.liked).toList(growable: false);
    if (visibleCollections.isNotEmpty) {
      cards.add(_DiscoveryTile(icon: Icons.favorite_outline_rounded, title: 'Collections', subtitle: visibleCollections.first.name, onTap: () => onCollection(visibleCollections.first)));
    }
    if (catalogTracks.isNotEmpty) {
      cards.add(_DiscoveryTile(icon: Icons.auto_awesome_rounded, title: 'Explore', subtitle: 'Find another voice', onTap: () => onTrack(catalogTracks.first)));
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Browse', style: WzText.title),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cards.map((card) => SizedBox(width: width, child: card)).toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _DiscoveryTile extends StatelessWidget {
  const _DiscoveryTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WzPressableSurface(
        onTap: onTap,
        radius: 30,
        decoration: WzSurface.sculpted(),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WzSculptedIcon(icon: icon, size: 42, iconSize: 18, color: WzColors.accent),
            const SizedBox(height: 13),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          ],
        ),
      );
}

class _QuietSearchEmpty extends StatelessWidget {
  const _QuietSearchEmpty({
    this.title = 'Your music will appear here',
    this.subtitle = 'Add music from this device or try again when your online music is ready.',
    required this.onImportDeviceMusic,
    required this.onLoadCatalog,
  });

  final String title;
  final String subtitle;
  final VoidCallback onImportDeviceMusic;
  final VoidCallback onLoadCatalog;

  @override
  Widget build(BuildContext context) => WzGlassCard(
        borderRadius: 34,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: WzText.title),
            const SizedBox(height: 6),
            Text(subtitle, style: WzText.body),
            const SizedBox(height: 16),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                WzPrimaryAction(label: 'Device Music', icon: Icons.phone_android_rounded, onPressed: onImportDeviceMusic),
                OutlinedButton.icon(onPressed: onLoadCatalog, icon: const Icon(Icons.refresh_rounded), label: const Text('Try online music')),
              ],
            ),
          ],
        ),
      );
}
