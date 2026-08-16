from pathlib import Path

app_path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
player_path = Path('apps/flutter/wavezero_app/lib/features/playback/player_presentation.dart')
app = app_path.read_text(encoding='utf-8')
player = player_path.read_text(encoding='utf-8')

stale_import = "import '../shared/widgets/wavezero_artwork.dart';\n"
if app.count(stale_import) != 1:
    raise SystemExit(f'Expected stale artwork import once, found {app.count(stale_import)}')
app = app.replace(stale_import, '', 1)

leftover = ") {\n  if (isPlayingFromCache) return 'Downloaded';\n  if (hasTrack) return 'Catalog';\n  if (offlineReady) return 'Offline Ready';\n  return 'Not cached';\n}\n"
if app.count(leftover) != 1:
    raise SystemExit(f'Expected truncated source-label leftover once, found {app.count(leftover)}')
app = app.replace(leftover, '', 1)

broken = "String wzPlayerSourceLabel({required bool isPlayingFromCache, required bool offlineReady, required bool hasTrack}\n\nString _statusFromEvent"
if player.count(broken) != 1:
    raise SystemExit(f'Expected broken player source declaration once, found {player.count(broken)}')
fixed = "String wzPlayerSourceLabel({required bool isPlayingFromCache, required bool offlineReady, required bool hasTrack}) {\n  if (isPlayingFromCache) return 'Downloaded';\n  if (hasTrack) return 'Catalog';\n  if (offlineReady) return 'Offline Ready';\n  return 'Not cached';\n}\n\nString _statusFromEvent"
player = player.replace(broken, fixed, 1)

if "\n) {\n  if (isPlayingFromCache)" in app:
    raise SystemExit('Truncated source-label body still remains in app')
if player.count('String wzPlayerSourceLabel(') != 1:
    raise SystemExit('Expected one complete public player source helper')
if "hasTrack}\n\nString _statusFromEvent" in player:
    raise SystemExit('Broken player source declaration still remains')

app_path.write_text(app, encoding='utf-8')
player_path.write_text(player, encoding='utf-8')
print('Fixed guarded Player presentation extraction syntax')
