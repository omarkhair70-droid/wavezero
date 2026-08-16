from pathlib import Path
import shutil

root = Path('apps/flutter/wavezero_app')
old_dir = root / 'lib/cloud_vault'
new_dir = root / 'lib/features/cloud_vault'

if not old_dir.exists():
    raise SystemExit(f'missing source: {old_dir}')
if new_dir.exists():
    raise SystemExit(f'target already exists: {new_dir}')

new_dir.parent.mkdir(parents=True, exist_ok=True)
shutil.move(str(old_dir), str(new_dir))

models = new_dir / 'cloud_vault_models.dart'
models.write_text(models.read_text().replace("import '../catalog/catalog_track_manifest.dart';", "import '../../catalog/catalog_track_manifest.dart';"))

replacements = {
    'package:wavezero_app/cloud_vault/': 'package:wavezero_app/features/cloud_vault/',
    "import '../cloud_vault/": "import '../features/cloud_vault/",
    "import '../../cloud_vault/": "import '../../features/cloud_vault/",
    "import '../../../cloud_vault/": "import '../../../features/cloud_vault/",
}

for path in root.rglob('*.dart'):
    if path == models:
        continue
    source = path.read_text()
    updated = source
    for old, new in replacements.items():
        updated = updated.replace(old, new)
    if updated != source:
        path.write_text(updated)
