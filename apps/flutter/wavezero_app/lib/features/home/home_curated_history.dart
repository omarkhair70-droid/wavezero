import 'package:flutter/material.dart';

import '../../app/curated_demo_picks.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../history/history_presentation.dart';
import '../history/listening_history_page.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WzSectionHeader(
          title: 'WaveZero Picks',
          subtitle: 'A few voices chosen to make starting feel effortless.',
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: WzSpacing.sm),
        ...shelves.map(
          (shelf) => Padding(
            padding: const EdgeInsets.only(bottom: WzSpacing.md),
            child: _HomeCuratedShelf(
              shelf: shelf,
              onPlayPick: onPlayPick,
              onAddToQueue: onAddToQueue,
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeCuratedShelf extends StatelessWidget {
  const _HomeCuratedShelf({
    required this.shelf,
    required this.onPlayPick,
    required this.onAddToQueue,
  });

  final ResolvedCuratedDemoShelf shelf;
  final ValueChanged<ResolvedCuratedDemoPick> onPlayPick;
  final ValueChanged<ResolvedCuratedDemoPick> onAddToQueue;

  @override
  Widget build(BuildContext context) => WzGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shelf.shelf.title, style: WzText.sectionTitle),
            const SizedBox(height: WzSpacing.xxs),
            Text(shelf.shelf.subtitle, style: WzText.caption),
            const SizedBox(height: WzSpacing.sm),
            SizedBox(
              height: 252,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: shelf.picks.length,
                separatorBuilder: (_, __) => const SizedBox(width: WzSpacing.sm),
                itemBuilder: (context, index) {
                  final pick = shelf.picks[index];
                  return _HomeCuratedPickCard(
                    pick: pick,
                    onPlay: () => onPlayPick(pick),
                    onAddToQueue: () => onAddToQueue(pick),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _HomeCuratedPickCard extends StatelessWidget {
  const _HomeCuratedPickCard({
    required this.pick,
    required this.onPlay,
    required this.onAddToQueue,
  });

  final ResolvedCuratedDemoPick pick;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;

  @override
  Widget build(BuildContext context) {
    final track = pick.track;
    return SizedBox(
      width: 178,
      child: WzPressableSurface(
        onTap: onPlay,
        radius: WzRadius.lg,
        decoration: WzSurface.sculpted(),
        padding: const EdgeInsets.all(WzSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(WzRadius.lg),
                boxShadow: WzSurface.softShadows,
              ),
              child: WzArtwork(
                artworkUrl: track.artworkUrl,
                size: 132,
                trackId: track.trackId,
                title: track.title,
                artist: track.artistName,
                mood: pick.pick.mood,
              ),
            ),
            const SizedBox(height: WzSpacing.sm),
            Expanded(
              child: _HomeCuratedPickText(
                pick: pick,
                onPlay: onPlay,
                onAddToQueue: onAddToQueue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCuratedPickText extends StatelessWidget {
  const _HomeCuratedPickText({
    required this.pick,
    required this.onPlay,
    required this.onAddToQueue,
  });

  final ResolvedCuratedDemoPick pick;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;

  @override
  Widget build(BuildContext context) {
    final track = pick.track;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14)),
        const SizedBox(height: WzSpacing.xxs),
        Text(track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
        const SizedBox(height: 3),
        Text('${pick.pick.shelfLabel} • ${pick.pick.mood}', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(fontSize: 10.5)),
        const Spacer(),
        Row(
          children: [
            WzSculptedIconButton(tooltip: 'Play', icon: Icons.play_arrow_rounded, size: 36, iconSize: 18, onPressed: onPlay),
            const SizedBox(width: WzSpacing.xs),
            WzSculptedIconButton(tooltip: 'Add to Queue', icon: Icons.queue_music_rounded, size: 36, iconSize: 16, onPressed: onAddToQueue),
          ],
        ),
      ],
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
    final recent = entries.take(6).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WzSectionHeader(
          title: 'Continue Listening',
          subtitle: 'Listening history stays on this device.',
          icon: Icons.history_rounded,
        ),
        WzGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (continueEntry == null)
                const Text(
                  'No listening history yet. Play a track from Library, Search, or Downloads to continue here.',
                  style: WzText.body,
                )
              else
                _HomeContinueHistoryCard(
                  entry: continueEntry!,
                  available: resolver(continueEntry!) != null,
                  onPlay: () => onPlay(continueEntry!),
                ),
              const SizedBox(height: WzSpacing.md),
              Wrap(
                spacing: WzSpacing.sm,
                runSpacing: WzSpacing.sm,
                children: [
                  WzMiniMetric(label: 'History count', value: '${entries.length}', active: entries.isNotEmpty, icon: Icons.history_rounded),
                  WzMiniMetric(label: 'Most played', value: mostPlayedEntry?.title ?? 'None yet', active: mostPlayedEntry != null, icon: Icons.repeat_rounded),
                  const WzMiniMetric(label: 'Privacy', value: 'Device only', active: true, icon: Icons.lock_outline_rounded),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        WzSectionHeader(
          title: 'Recently Played',
          subtitle: recent.isEmpty ? 'Your latest plays will show up here.' : 'Last ${recent.length} tracks saved locally.',
          icon: Icons.schedule_rounded,
        ),
        WzGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recent.isEmpty)
                const Text('No listening history yet. Play a track to start.', style: WzText.body)
              else
                ...recent.map(
                  (entry) => WzHistoryEntryTile(
                    entry: entry,
                    available: resolver(entry) != null,
                    compact: true,
                    onPlay: () => onPlay(entry),
                    onAddToQueue: () => onAddToQueue(entry),
                    onAddToCollection: () => onAddToCollection(entry),
                    onRemove: () => onRemove(entry),
                  ),
                ),
              const SizedBox(height: WzSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(onPressed: onViewAll, icon: const Icon(Icons.open_in_full_rounded), label: const Text('View all')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeContinueHistoryCard extends StatelessWidget {
  const _HomeContinueHistoryCard({required this.entry, required this.available, required this.onPlay});

  final WzListeningHistoryEntry entry;
  final bool available;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              WzStatusPill(label: wzHistorySourceLabel(entry.source), active: available, warning: !available, icon: Icons.album_rounded),
              WzStatusPill(label: entry.license.badgeLabel, warning: entry.license.needsRightsWarning, icon: Icons.policy_outlined),
              if (entry.qualityLabel != null) WzStatusPill(label: wzProductQualityLabel(entry.qualityLabel!), icon: Icons.high_quality_rounded),
            ],
          ),
          const SizedBox(height: WzSpacing.sm),
          Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.title),
          const SizedBox(height: WzSpacing.xxs),
          Text('${entry.subtitle} • ${wzHistoryPositionLabel(entry)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.body),
          if (!available) ...[
            const SizedBox(height: WzSpacing.xs),
            const Text('Track is not available right now.', style: WzText.caption),
          ],
          const SizedBox(height: WzSpacing.md),
          WzPrimaryAction(label: entry.lastPositionMs > 0 ? 'Continue' : 'Play', icon: Icons.play_arrow_rounded, onPressed: available ? onPlay : null),
        ],
      );
}
