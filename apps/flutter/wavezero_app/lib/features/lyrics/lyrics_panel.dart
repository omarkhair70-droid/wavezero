import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import 'lyrics_models.dart';

class WzLyricsPanel extends StatelessWidget {
  const WzLyricsPanel({
    super.key,
    required this.document,
    required this.positionMs,
    required this.hasTrack,
    required this.onEdit,
    this.onClear,
  });

  final WzLyricsDocument? document;
  final int positionMs;
  final bool hasTrack;
  final VoidCallback? onEdit;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final lyrics = document;
    return WzPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lyrics', style: WzText.sectionTitle),
                    SizedBox(height: 3),
                    Text('Private to this device.', style: WzText.caption),
                  ],
                ),
              ),
              if (lyrics != null && onClear != null)
                IconButton(
                  tooltip: 'Remove lyrics',
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                ),
              TextButton.icon(
                onPressed: hasTrack ? onEdit : null,
                icon: Icon(
                  lyrics == null ? Icons.add_rounded : Icons.edit_rounded,
                  size: 18,
                ),
                label: Text(lyrics == null ? 'Add' : 'Edit'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasTrack)
            const _LyricsEmpty(
              icon: Icons.music_note_rounded,
              title: 'Play something first',
              body: 'Lyrics are attached to the track that is currently playing.',
            )
          else if (lyrics == null || lyrics.isEmpty)
            _LyricsEmpty(
              icon: Icons.format_quote_rounded,
              title: 'No lyrics saved yet',
              body: 'Paste normal lyrics or LRC timestamps and WaveZero will keep them locally.',
              action: onEdit == null
                  ? null
                  : TextButton(
                      onPressed: onEdit,
                      child: const Text('Add lyrics'),
                    ),
            )
          else if (lyrics.isSynced)
            _SyncedLyrics(document: lyrics, positionMs: positionMs)
          else
            SelectableText(
              lyrics.rawText,
              style: WzText.body.copyWith(
                color: WzColors.textPrimary,
                fontSize: 15,
                height: 1.62,
              ),
            ),
        ],
      ),
    );
  }
}

class _SyncedLyrics extends StatelessWidget {
  const _SyncedLyrics({required this.document, required this.positionMs});

  final WzLyricsDocument document;
  final int positionMs;

  @override
  Widget build(BuildContext context) {
    final lines = document.syncedLines;
    final activeIndex = document.activeLineIndex(positionMs);
    final resolvedIndex = activeIndex < 0 ? 0 : activeIndex;
    final previous = resolvedIndex > 0 ? lines[resolvedIndex - 1] : null;
    final current = lines[resolvedIndex];
    final next = resolvedIndex + 1 < lines.length ? lines[resolvedIndex + 1] : null;

    return AnimatedSwitcher(
      duration: WzMotion.normal,
      switchInCurve: WzMotion.curve,
      switchOutCurve: WzMotion.curve,
      child: Column(
        key: ValueKey<int>(resolvedIndex),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (previous != null) ...[
            Text(
              previous.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: WzText.body.copyWith(
                color: WzColors.textSubtle,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            current.text,
            style: WzText.title.copyWith(fontSize: 25, height: 1.22),
          ),
          if (next != null) ...[
            const SizedBox(height: 12),
            Text(
              next.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: WzText.body.copyWith(
                color: WzColors.textMuted,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                size: 15,
                color: WzColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Synced lyrics • ${resolvedIndex + 1}/${lines.length}',
                style: WzText.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LyricsEmpty extends StatelessWidget {
  const _LyricsEmpty({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: WzColors.surfaceMuted.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(WzRadius.lg),
          border: Border.all(color: WzColors.borderSoft),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: WzColors.accent, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: WzText.sectionTitle.copyWith(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(body, style: WzText.caption),
                  if (action != null) ...[
                    const SizedBox(height: 5),
                    Align(alignment: Alignment.centerLeft, child: action!),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

class WzLyricsEditorSheet extends StatefulWidget {
  const WzLyricsEditorSheet({
    super.key,
    required this.trackTitle,
    required this.initialText,
    required this.onSave,
    required this.onDelete,
  });

  final String trackTitle;
  final String initialText;
  final Future<void> Function(String text) onSave;
  final Future<void> Function() onDelete;

  @override
  State<WzLyricsEditorSheet> createState() => _WzLyricsEditorSheetState();
}

class _WzLyricsEditorSheetState extends State<WzLyricsEditorSheet> {
  late final TextEditingController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSave(_controller.text);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Local lyrics', style: WzText.title),
                      const SizedBox(height: 3),
                      Text(
                        widget.trackTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WzText.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_busy,
              autofocus: true,
              minLines: 8,
              maxLines: 16,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Paste lyrics here…\n\nFor sync, LRC lines like [00:12.40] first line work too.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Stored only in WaveZero on this device. No lyrics are fetched or uploaded automatically.',
              style: WzText.caption,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _busy || widget.initialText.trim().isEmpty
                      ? null
                      : _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
