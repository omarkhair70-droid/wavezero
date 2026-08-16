import 'package:flutter/material.dart';

import '../../app/curated_demo_picks.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../history/history_presentation.dart';
import '../history/listening_history_service.dart';

class WzHomeCuratedDemoSection extends StatelessWidget {
  const WzHomeCuratedDemoSection({
    super.key,
    required this.shelves,
    required this.onPlayPick,
    required this.onAddToQueue,
    required this.onOpenLibrary,
  });

  final List<ResolvedCuratedDemoShelf> shelves;
  final ValueChanged<ResolvedCuratedDemoPick> onPlayPick;
  final ValueChanged<ResolvedCuratedDemoPick> onAddToQueue;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    if (shelves.isEmpty) return const SizedBox.shrink();
    final picks = shelves.expand((shelf) => shelf.picks).take(8).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('WaveZero Picks', style: WzText.title)),
            TextButton.icon(
              onPressed: onOpenLibrary,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('A few voices that feel right here.', style: WzText.body),
        const SizedBox(height: 14),
        SizedBox(
          height: 244,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: picks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final pick = picks[index];
              return _HomeCuratedPickCard(
                pick: pick,
                onPlay: () => onPlayPick(pick),
                onAddToQueue: () => onAddToQueue(pick),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HomeCuratedPickCard extends StatelessWidget {
  const _HomeCuratedPickCard({required this.pick, required this.onPlay, required this.onAddToQueue});

  final ResolvedCuratedDemoPick pick;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;

  @override
  Widget build(BuildContext context) {
    final track = pick.track;
    return SizedBox(
      width: 164,
      child: WzPressableSurface(
        onTap: onPlay,
        radius: 34,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFAFFFFFF), Color(0xEEF6F9FB)],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(34),
            topRight: Radius.circular(46),
            bottomLeft: Radius.circular(44),
            bottomRight: Radius.circular(28),
          ),
          border: Border.all(color: const Color(0xEFFFFFFF)),
          boxShadow: WzSurface.softShadows,
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(27),
                    topRight: Radius.circular(38),
                    bottomLeft: Radius.circular(35),
                    bottomRight: Radius.circular(23),
                  ),
                  child: WzArtwork(
                    artworkUrl: track.artworkUrl,
                    size: 140,
                    trackId: track.trackId,
                    title: track.title,
                    artist: track.artistName,
                    mood: pick.pick.mood,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: WzSculptedIconButton(
                    tooltip: 'Play',
                    icon: Icons.play_arrow_rounded,
                    size: 38,
                    iconSize: 20,
                    onPressed: onPlay,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 3),
            Text(track.artistName ?? track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Add to Queue',
                onPressed: onAddToQueue,
                icon: const Icon(Icons.queue_music_rounded, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WzHomeHistorySection extends StatelessWidget {
  const WzHomeHistorySection({
    super.key,
    required this.entries,
    required this.continueEntry,
    required this.mostPlayedEntry,
    required this.resolver,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onAddToCollection,
    required this.onRemove,
    required this.onViewAll,
  });

  final List<WzListeningHistoryEntry> entries;
  final WzListeningHistoryEntry? continueEntry;
  final WzListeningHistoryEntry? mostPlayedEntry;
  final CatalogTrackSummary? Function(WzListeningHistoryEntry entry) resolver;
  final ValueChanged<WzListeningHistoryEntry> onPlay;
  final ValueChanged<WzListeningHistoryEntry> onAddToQueue;
  final ValueChanged<WzListeningHistoryEntry> onAddToCollection;
  final ValueChanged<WzListeningHistoryEntry> onRemove;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final recent = entries.take(5).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Continue Listening', style: WzText.title),
        const SizedBox(height: 4),
        const Text('Listening history stays on this device.', style: WzText.caption),
        const SizedBox(height: 14),
        if (continueEntry == null)
          WzGlassCard(
            child: const Text(
              'No listening history yet. Play a track from Library, Search, or Downloads to continue here.',
              style: WzText.body,
            ),
          )
        else
          _ContinueListeningCard(
            entry: continueEntry!,
            available: resolver(continueEntry!) != null,
            onPlay: () => onPlay(continueEntry!),
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: Text('Recently Played', style: WzText.title)),
            TextButton(onPressed: onViewAll, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No listening history yet. Play a track to start.', style: WzText.body),
          )
        else
          ...recent.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _RecentListeningRow(
                entry: entry,
                available: resolver(entry) != null,
                onPlay: () => onPlay(entry),
                onAddToQueue: () => onAddToQueue(entry),
                onAddToCollection: () => onAddToCollection(entry),
                onRemove: () => onRemove(entry),
              ),
            ),
          ),
      ],
    );
  }
}

class _ContinueListeningCard extends StatelessWidget {
  const _ContinueListeningCard({required this.entry, required this.available, required this.onPlay});

  final WzListeningHistoryEntry entry;
  final bool available;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => WzPressableSurface(
        onTap: available ? onPlay : null,
        radius: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFCFFFFFF), Color(0xEEF5F9FC)]),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(38),
            topRight: Radius.circular(50),
            bottomLeft: Radius.circular(48),
            bottomRight: Radius.circular(32),
          ),
          border: Border.all(color: const Color(0xF2FFFFFF)),
          boxShadow: WzSurface.softShadows,
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(28),
                bottomLeft: Radius.circular(27),
                bottomRight: Radius.circular(18),
              ),
              child: WzArtwork(
                artworkUrl: entry.artworkUrl,
                size: 70,
                trackId: entry.trackId,
                title: entry.title,
                artist: entry.subtitle,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                  const SizedBox(height: 4),
                  Text(entry.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  const SizedBox(height: 5),
                  Text(wzHistoryPositionLabel(entry), maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(color: WzColors.accent)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            WzSculptedIconButton(
              tooltip: entry.lastPositionMs > 0 ? 'Continue' : 'Play',
              icon: Icons.play_arrow_rounded,
              size: 50,
              iconSize: 24,
              onPressed: available ? onPlay : null,
            ),
          ],
        ),
      );
}

class _RecentListeningRow extends StatelessWidget {
  const _RecentListeningRow({
    required this.entry,
    required this.available,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onAddToCollection,
    required this.onRemove,
  });

  final WzListeningHistoryEntry entry;
  final bool available;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;
  final VoidCallback onAddToCollection;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: available ? onPlay : null,
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: WzArtwork(
                    artworkUrl: entry.artworkUrl,
                    size: 52,
                    trackId: entry.trackId,
                    title: entry.title,
                    artist: entry.subtitle,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(entry.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_horiz_rounded, color: WzColors.textMuted),
                  onSelected: (value) {
                    switch (value) {
                      case 'queue':
                        onAddToQueue();
                      case 'collection':
                        onAddToCollection();
                      case 'remove':
                        onRemove();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'queue', child: Text('Add to queue')),
                    PopupMenuItem(value: 'collection', child: Text('Add to collection')),
                    PopupMenuItem(value: 'remove', child: Text('Remove from history')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
