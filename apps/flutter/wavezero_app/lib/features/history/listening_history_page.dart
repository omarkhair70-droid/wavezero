import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import 'history_presentation.dart';
import 'listening_history_service.dart';

class WzListeningHistoryPage extends StatelessWidget {
  const WzListeningHistoryPage({
    required this.entries,
    required this.onBack,
    required this.mostPlayedEntry,
    required this.resolver,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onAddToCollection,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<WzListeningHistoryEntry> entries;
  final VoidCallback onBack;
  final WzListeningHistoryEntry? mostPlayedEntry;
  final CatalogTrackSummary? Function(WzListeningHistoryEntry entry) resolver;
  final ValueChanged<WzListeningHistoryEntry> onPlay;
  final ValueChanged<WzListeningHistoryEntry> onAddToQueue;
  final ValueChanged<WzListeningHistoryEntry> onAddToCollection;
  final ValueChanged<WzListeningHistoryEntry> onRemove;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) => WzPageScaffold(
        children: [
          Row(
            children: [
              WzSculptedIconButton(tooltip: 'Back to Library', onPressed: onBack, icon: Icons.arrow_back_rounded, size: 44, iconSize: 19),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Listening History', style: WzText.pageTitle.copyWith(fontSize: 28)),
                    const SizedBox(height: 3),
                    const Text('Local only', style: WzText.caption),
                  ],
                ),
              ),
              if (onClearAll != null)
                PopupMenuButton<String>(
                  tooltip: 'History options',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (value) {
                    if (value == 'clear') onClearAll?.call();
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'clear', child: Text('Clear listening history'))],
                ),
            ],
          ),
          const SizedBox(height: 22),
          if (mostPlayedEntry != null) ...[
            Text('You came back to', style: WzText.eyebrow),
            const SizedBox(height: 9),
            _HistoryHighlight(
              entry: mostPlayedEntry!,
              available: resolver(mostPlayedEntry!) != null,
              onPlay: () => onPlay(mostPlayedEntry!),
            ),
            const SizedBox(height: 24),
          ],
          const Text('Recently played', style: WzText.title),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const WzGlassCard(child: Text('No listening history yet. Play a track to start.', style: WzText.body))
          else
            ...entries.map(
              (entry) => WzHistoryEntryTile(
                entry: entry,
                available: resolver(entry) != null,
                onPlay: () => onPlay(entry),
                onAddToQueue: () => onAddToQueue(entry),
                onAddToCollection: () => onAddToCollection(entry),
                onRemove: () => onRemove(entry),
              ),
            ),
        ],
      );
}

class _HistoryHighlight extends StatelessWidget {
  const _HistoryHighlight({required this.entry, required this.available, required this.onPlay});

  final WzListeningHistoryEntry entry;
  final bool available;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => WzPressableSurface(
        onTap: available ? onPlay : null,
        radius: 34,
        decoration: WzSurface.sculpted(selected: true),
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(28),
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(17),
              ),
              child: WzArtwork(
                artworkUrl: entry.artworkUrl,
                size: 68,
                trackId: entry.trackId,
                title: entry.title,
                artist: entry.subtitle,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                  const SizedBox(height: 3),
                  Text(entry.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  const SizedBox(height: 4),
                  Text('${entry.playCount} plays', style: WzText.caption.copyWith(color: WzColors.accent)),
                ],
              ),
            ),
            WzSculptedIconButton(tooltip: 'Play', icon: Icons.play_arrow_rounded, size: 48, iconSize: 23, onPressed: available ? onPlay : null),
          ],
        ),
      );
}

class WzHistoryEntryTile extends StatelessWidget {
  const WzHistoryEntryTile({
    required this.entry,
    required this.available,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onAddToCollection,
    required this.onRemove,
    this.compact = false,
  });

  final WzListeningHistoryEntry entry;
  final bool available;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;
  final VoidCallback onAddToCollection;
  final VoidCallback onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: available
                ? () {
                    HapticFeedback.selectionClick();
                    onPlay();
                  }
                : null,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(17),
                      topRight: Radius.circular(23),
                      bottomLeft: Radius.circular(22),
                      bottomRight: Radius.circular(14),
                    ),
                    child: WzArtwork(
                      artworkUrl: entry.artworkUrl,
                      size: compact ? 48 : 54,
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
                        const SizedBox(height: 3),
                        Text(entry.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                        const SizedBox(height: 3),
                        Text(friendlyWzHistoryTime(entry.lastPlayedAtMs), style: WzText.caption.copyWith(fontSize: 10.5)),
                        if (!available) Text('Unavailable right now', style: WzText.caption.copyWith(fontSize: 10.5, color: WzColors.warning)),
                      ],
                    ),
                  ),
                  WzSculptedIconButton(tooltip: 'Play', icon: Icons.play_arrow_rounded, size: 38, iconSize: 19, onPressed: available ? onPlay : null),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_horiz_rounded, color: WzColors.textMuted),
                    onSelected: (value) {
                      if (value == 'queue') onAddToQueue();
                      if (value == 'collection') onAddToCollection();
                      if (value == 'remove') onRemove();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(enabled: available, value: 'queue', child: const Text('Add to queue')),
                      PopupMenuItem(enabled: available, value: 'collection', child: const Text('Add to collection')),
                      const PopupMenuItem(value: 'remove', child: Text('Remove from history')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
