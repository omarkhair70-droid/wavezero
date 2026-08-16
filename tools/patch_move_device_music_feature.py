from pathlib import Path
import shutil

root = Path('apps/flutter/wavezero_app')
old_dir = root / 'lib/device_music'
new_dir = root / 'lib/features/device_music'

if not old_dir.exists():
    raise SystemExit(f'missing source: {old_dir}')
if new_dir.exists():
    raise SystemExit(f'target already exists: {new_dir}')

new_dir.parent.mkdir(parents=True, exist_ok=True)
shutil.move(str(old_dir), str(new_dir))

replacements = {
    'package:wavezero_app/device_music/': 'package:wavezero_app/features/device_music/',
    "import '../device_music/": "import '../features/device_music/",
    "import '../../device_music/": "import '../../features/device_music/",
    "import '../../../device_music/": "import '../../../features/device_music/",
}

for path in root.rglob('*.dart'):
    source = path.read_text()
    updated = source
    for old, new in replacements.items():
        updated = updated.replace(old, new)
    if updated != source:
        path.write_text(updated)
