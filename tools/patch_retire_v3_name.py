from pathlib import Path

root = Path('apps/flutter/wavezero_app')
old_path = root / 'lib/app/wavezero_live_metrics_app_v3.dart'
new_path = root / 'lib/app/wavezero_app.dart'
if not old_path.exists():
    raise SystemExit(f'missing active app source: {old_path}')
if new_path.exists():
    raise SystemExit(f'target already exists: {new_path}')

text = old_path.read_text()
text = text.replace('WaveZeroLiveMetricsApp', 'WaveZeroApp')
text = text.replace('_WaveZeroLiveMetricsAppState', '_WaveZeroAppState')
new_path.write_text(text)
old_path.unlink()

for path in Path('.').rglob('*'):
    if not path.is_file() or path == new_path:
        continue
    if any(part in {'.git', '.dart_tool', 'build'} for part in path.parts):
        continue
    if path.suffix.lower() not in {'.dart', '.md', '.yml', '.yaml', '.txt'}:
        continue
    try:
        source = path.read_text()
    except UnicodeDecodeError:
        continue
    updated = source.replace('wavezero_live_metrics_app_v3.dart', 'wavezero_app.dart')
    updated = updated.replace('WaveZeroLiveMetricsApp', 'WaveZeroApp')
    updated = updated.replace('_WaveZeroLiveMetricsAppState', '_WaveZeroAppState')
    if updated != source:
        path.write_text(updated)
