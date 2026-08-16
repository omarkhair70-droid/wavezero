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
    return WzPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Queue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text(
                      'Queue Engine v2: reorder, remove, Play Next, and persistence.',
                      style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text('${queue.length} tracks', style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Clear queue',
                onPressed: queue.isEmpty || controlsDisabled ? null : onClearQueue,
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _QueueStateChip(label: 'Current', value: currentTrack?.title ?? 'none', active: currentTrack != null),
              _QueueStateChip(label: 'Up next', value: nextTrack?.title ?? 'none', active: nextTrack != null),
              if (showDeveloperDetails)
                _QueueStateChip(label: 'Auto', value: '$autoAdvanceCount advances', active: autoAdvanceEnabled),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
                ),
              ),
              Switch(value: autoAdvanceEnabled, onChanged: controlsDisabled ? null : onToggleAutoAdvance),
            ],
          ),
          if (showDeveloperDetails)
            Text(
              'smartQueueReason: $smartQueueReason • candidate: ${smartQueueCandidateTrackId ?? 'none'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
            ),
          const SizedBox(height: 12),
          if (queue.isEmpty)
            const WzEmptyCatalogMessage(
              message: 'Queue is empty. Add tracks from Library or Search to choose what plays next.',
            )
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0x227C5CFF) : WzColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? WzColors.accent : WzColors.border),
        ),
        child: Text('$label: $value', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: current ? const Color(0x227C5CFF) : const Color(0xFF0B0E18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: current
              ? const Color(0xFF8D7CFF)
              : upNext
                  ? const Color(0xFF38D996)
                  : const Color(0xFF20273A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                current
                    ? Icons.equalizer
                    : upNext
                        ? Icons.next_plan
                        : Icons.queue_music,
                color: current || upNext ? const Color(0xFF8D7CFF) : const Color(0xFF98A1B8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 2,
            runSpacing: 2,
            children: [
              IconButton(
                tooltip: 'Play/select',
                onPressed: disabled ? null : onPlay,
                icon: Icon(current ? Icons.check_circle : Icons.play_arrow, color: const Color(0xFF8D7CFF)),
              ),
              IconButton(
                tooltip: 'Move up',
                onPressed: disabled || !canMoveUp ? null : onMoveUp,
                icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF98A1B8)),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: disabled || !canMoveDown ? null : onMoveDown,
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF98A1B8)),
              ),
              IconButton(
                tooltip: 'Play next',
                onPressed: disabled || current || upNext ? null : onPlayNext,
                icon: const Icon(Icons.low_priority, color: Color(0xFF38D996)),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: disabled ? null : onRemove,
                icon: const Icon(Icons.close, color: Color(0xFF98A1B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
