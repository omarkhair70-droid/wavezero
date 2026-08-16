from pathlib import Path

root = Path('apps/flutter/wavezero_app')
old_path = root / 'lib/app/collections_service.dart'
new_path = root / 'lib/features/collections/collections_service.dart'

if not old_path.exists():
    raise SystemExit(f'missing source: {old_path}')
if new_path.exists():
    raise SystemExit(f'target already exists: {new_path}')

new_path.parent.mkdir(parents=True, exist_ok=True)
text = old_path.read_text().replace("import '../catalog/catalog_track_manifest.dart';", "import '../../catalog/catalog_track_manifest.dart';")
new_path.write_text(text)
old_path.unlink()

replacements = {
    'package:wavezero_app/app/collections_service.dart': 'package:wavezero_app/features/collections/collections_service.dart',
    "import 'collections_service.dart';": "import '../features/collections/collections_service.dart';",
    "import '../app/collections_service.dart';": "import '../features/collections/collections_service.dart';",
    "import '../../app/collections_service.dart';": "import '../../features/collections/collections_service.dart';",
}

for path in root.rglob('*.dart'):
    if path == new_path:
        continue
    source = path.read_text()
    updated = source
    for old, new in replacements.items():
        updated = updated.replace(old, new)
    if updated != source:
        path.write_text(updated)
