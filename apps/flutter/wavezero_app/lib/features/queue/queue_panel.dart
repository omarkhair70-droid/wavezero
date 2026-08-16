import 'package:flutter/material.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/widgets/wavezero_empty_message.dart';

class WzQueuePanel extends StatelessWidget {
  const WzQueuePanel({
    super.key,
    required this.queue,
    required this.currentTrackId,
    required this.currentIndex,
    required this.status,
    required this.controlsDisabled,
    required this.autoAdvanceEnabled,
    required this.autoAdvanceCount,
    required this.smartQueueCandidateTrackId,
    required this.smartQueueReason,
    required this.showDeveloperDetails,
    required this.onToggleAutoAdvance,
    required this.onPlayTrack,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onPlayNext,
    required this.onRemoveTrack,
    required this.onClearQueue,
  });

  final List<CatalogTrackSummary> queue;
  final String? currentTrackId;
  final int currentIndex;
  final String status;
  final bool controlsDisabled;
  final bool autoAdvanceEnabled;
  final int autoAdvanceCount;
  final String? smartQueueCandidateTrackId;
  final String smartQueueReason;
  final bool showDeveloperDetails;
  final ValueChanged<bool> onToggleAutoAdvance;
  final ValueChanged<CatalogTrackSummary> onPlayTrack;
  final ValueChanged<CatalogTrackSummary> onMoveUp;
  final ValueChanged<CatalogTrackSummary> onMoveDown;
  final ValueChanged<CatalogTrackSummary> onPlayNext;
  final ValueChanged<CatalogTrackSummary> onRemoveTrack;
  final VoidCallback onClearQueue;

  @override
  Widget build(BuildContext context) {
    final currentTrack = currentIndex >= 0 && currentIndex < queue.length ? queue[currentIndex] : null;
    final nextTrack = currentIndex >= 0 && currentIndex < queue.length - 1 ? queue[currentIndex + 1] : null;
    return WzGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Queue', style: WzText.title),
                    SizedBox(height: 4),
                    Text('What stays with you next.', style: WzText.body),
                  ],
                ),
              ),
              Text('${queue.length} tracks', style: WzText.caption),
              const SizedBox(width: WzSpacing.xs),
              WzSculptedIconButton(
                tooltip: 'Clear queue',
                icon: Icons.clear_all,
                size: 42,
                iconSize: 19,
                onPressed: queue.isEmpty || controlsDisabled ? null : onClearQueue,
              ),
            ],
          ),
          const SizedBox(height: WzSpacing.md),
          Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              _QueueStateChip(label: 'Current', value: currentTrack?.title ?? 'none', active: currentTrack != null),
              _QueueStateChip(label: 'Up next', value: nextTrack?.title ?? 'none', active: nextTrack != null),
              if (showDeveloperDetails) _QueueStateChip(label: 'Auto', value: '$autoAdvanceCount advances', active: autoAdvanceEnabled),
            ],
          ),
          const SizedBox(height: WzSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(status, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption)),
              const SizedBox(width: WzSpacing.sm),
              Switch(value: autoAdvanceEnabled, onChanged: controlsDisabled ? null : onToggleAutoAdvance),
            ],
          ),
          if (showDeveloperDetails)
            Text(
              'smartQueueReason: $smartQueueReason • candidate: ${smartQueueCandidateTrackId ?? 'none'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WzText.caption.copyWith(fontSize: 10.5),
            ),
          const SizedBox(height: WzSpacing.md),
          if (queue.isEmpty)
            const WzEmptyCatalogMessage(message: 'Queue is empty. Add tracks from Library or Search to choose what plays next.')
          else
            ...queue.indexed.map(
              (entry) => _QueueRow(
                track: entry.$2,
                index: entry.$1,
                current: entry.$2.trackId == currentTrackId,
                upNext: entry.$1 == currentIndex + 1,
                disabled: controlsDisabled,
                canMoveUp: entry.$1 > 0,
                canMoveDown: entry.$1 < queue.length - 1,
                onPlay: () => onPlayTrack(entry.$2),
                onMoveUp: () => onMoveUp(entry.$2),
                onMoveDown: () => onMoveDown(entry.$2),
                onPlayNext: () => onPlayNext(entry.$2),
                onRemove: () => onRemoveTrack(entry.$2),
              ),
            ),
        ],
      ),
    );
  }
}

class _QueueStateChip extends StatelessWidget {
  const _QueueStateChip({required this.label, required this.value, required this.active});

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? WzColors.accentSoft : Colors.white.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? WzColors.accent.withValues(alpha: 0.22) : WzColors.borderSoft),
        ),
        child: Text('$label • $value', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(color: WzColors.textMuted)),
      );
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.track,
    required this.index,
    required this.current,
    required this.upNext,
    required this.disabled,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onPlay,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onPlayNext,
    required this.onRemove,
  });

  final CatalogTrackSummary track;
  final int index;
  final bool current;
  final bool upNext;
  final bool disabled;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onPlay;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onPlayNext;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = current
        ? 'Now playing'
        : upNext
            ? 'Up next'
            : '#${index + 1}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: WzSurface.sculpted(selected: current),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WzSculptedIcon(
                icon: current
                    ? Icons.graphic_eq_rounded
                    : upNext
                        ? Icons.skip_next_rounded
                        : Icons.queue_music_rounded,
                size: 44,
                iconSize: 19,
                color: current || upNext ? WzColors.accent : WzColors.textMuted,
              ),
              const SizedBox(width: WzSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                    const SizedBox(height: 3),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: WzSpacing.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 5,
            runSpacing: 5,
            children: [
              WzSculptedIconButton(tooltip: 'Play/select', icon: current ? Icons.check_circle_rounded : Icons.play_arrow_rounded, selected: current, size: 38, iconSize: 17, onPressed: disabled ? null : onPlay),
              WzSculptedIconButton(tooltip: 'Move up', icon: Icons.keyboard_arrow_up_rounded, size: 38, iconSize: 18, onPressed: disabled || !canMoveUp ? null : onMoveUp),
              WzSculptedIconButton(tooltip: 'Move down', icon: Icons.keyboard_arrow_down_rounded, size: 38, iconSize: 18, onPressed: disabled || !canMoveDown ? null : onMoveDown),
              WzSculptedIconButton(tooltip: 'Play next', icon: Icons.low_priority_rounded, selected: upNext, size: 38, iconSize: 17, onPressed: disabled || current || upNext ? null : onPlayNext),
              WzSculptedIconButton(tooltip: 'Remove', icon: Icons.close_rounded, size: 38, iconSize: 17, onPressed: disabled ? null : onRemove),
            ],
          ),
        ],
      ),
    );
  }
}
