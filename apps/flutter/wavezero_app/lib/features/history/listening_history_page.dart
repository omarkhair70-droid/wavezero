import 'package:flutter/material.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
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
          WzPageHeader(
            icon: Icons.history,
            title: 'Listening History',
            subtitle: 'Recently played tracks saved locally on this device.',
            trailing: Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [IconButton.outlined(tooltip: 'Back to Home', onPressed: onBack, icon: const Icon(Icons.arrow_back)), OutlinedButton.icon(onPressed: onClearAll, icon: const Icon(Icons.delete_sweep), label: const Text('Clear'))]),
          ),
          const SizedBox(height: WzSpacing.md),
          WzPanel(
            child: Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzMiniMetric(label: 'Recently played', value: '${entries.length}', active: entries.isNotEmpty, icon: Icons.history),
                WzMiniMetric(label: 'Most played', value: mostPlayedEntry?.title ?? 'None yet', active: mostPlayedEntry != null, icon: Icons.repeat),
                const WzMiniMetric(label: 'Privacy', value: 'Local only', active: true, icon: Icons.lock),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entries.isEmpty)
                  const Text('No listening history yet. Play a track to start.', style: WzText.body)
                else
                  ...entries.map((entry) => _HistoryEntryTile(
                        entry: entry,
                        available: resolver(entry) != null,
                        onPlay: () => onPlay(entry),
                        onAddToQueue: () => onAddToQueue(entry),
                        onAddToCollection: () => onAddToCollection(entry),
                        onRemove: () => onRemove(entry),
                      )),
                const SizedBox(height: WzSpacing.sm),
                const Text('Removing history does not unlike tracks, delete collections, or remove downloads/cache.', style: WzText.caption),
              ],
            ),
          ),
        ],
      );
}

class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({
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
        padding: const EdgeInsets.only(bottom: WzSpacing.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: WzColors.surfaceElevated,
            borderRadius: BorderRadius.circular(WzRadius.lg),
            border: Border.all(color: WzColors.borderSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(WzSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle)),
                    const SizedBox(width: WzSpacing.xs),
                    Text(friendlyWzHistoryTime(entry.lastPlayedAtMs), style: WzText.caption),
                  ],
                ),
                const SizedBox(height: WzSpacing.xxs),
                Text(entry.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.body),
                const SizedBox(height: WzSpacing.xs),
                Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
                  WzStatusPill(label: wzHistorySourceLabel(entry.source), active: available, warning: !available, icon: Icons.album),
                  WzStatusPill(label: '${entry.playCount} play${entry.playCount == 1 ? '' : 's'}', icon: Icons.repeat),
                  if (entry.qualityLabel != null) WzStatusPill(label: wzProductQualityLabel(entry.qualityLabel!), icon: Icons.high_quality),
                  WzStatusPill(label: entry.license.badgeLabel, warning: entry.license.needsRightsWarning, icon: Icons.policy),
                ]),
                if (!available) ...[
                  const SizedBox(height: WzSpacing.xs),
                  const Text('Track is not available right now.', style: WzText.caption),
                ],
                const SizedBox(height: WzSpacing.sm),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: [
                    FilledButton.icon(onPressed: available ? onPlay : null, icon: const Icon(Icons.play_arrow), label: Text(compact ? 'Play' : 'Play / Continue')),
                    OutlinedButton.icon(onPressed: available ? onAddToQueue : null, icon: const Icon(Icons.queue_music), label: const Text('Queue')),
                    OutlinedButton.icon(onPressed: available ? onAddToCollection : null, icon: const Icon(Icons.playlist_add), label: const Text('Collection')),
                    TextButton.icon(onPressed: onRemove, icon: const Icon(Icons.close), label: const Text('Remove')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
