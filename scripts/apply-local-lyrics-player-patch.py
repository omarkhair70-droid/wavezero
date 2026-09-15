from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/features/playback/consumer_player.dart')
text = path.read_text(encoding='utf-8')

old_import = "import '../../design/wavezero_design_system.dart';\nimport '../../playback/playback_metrics.dart';"
new_import = "import '../../design/wavezero_design_system.dart';\nimport '../lyrics/local_lyrics_panel.dart';\nimport '../../playback/playback_metrics.dart';"
if text.count(old_import) != 1:
    raise SystemExit(f'expected one import anchor, found {text.count(old_import)}')
text = text.replace(old_import, new_import, 1)

old_block = """        const SizedBox(height: 24),
        _UpNextHandle(
          nextTrack: nextTrack,
          onTap: onOpenQueue,
          onAddToQueue: onAddToQueue,
        ),
"""
new_block = """        const SizedBox(height: 24),
        WzLocalLyricsPanel(
          trackId: manifest?.trackId ?? metrics.currentTrackId,
          trackTitle: title,
          positionMs: displayedPositionMs,
          hasTrack: hasTrack,
        ),
        const SizedBox(height: 24),
        _UpNextHandle(
          nextTrack: nextTrack,
          onTap: onOpenQueue,
          onAddToQueue: onAddToQueue,
        ),
"""
if text.count(old_block) != 1:
    raise SystemExit(f'expected one Up Next anchor, found {text.count(old_block)}')
text = text.replace(old_block, new_block, 1)

path.write_text(text, encoding='utf-8')
