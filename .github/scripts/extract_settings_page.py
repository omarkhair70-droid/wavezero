from pathlib import Path

app_path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
target_path = Path('apps/flutter/wavezero_app/lib/features/settings/settings_page.dart')
text = app_path.read_text(encoding='utf-8')
marker = 'class _SettingsPage extends StatelessWidget {'
start = text.find(marker)
if start < 0:
    raise SystemExit('Settings class marker not found')

brace_start = text.find('{', start)
depth = 0
end = None
for i in range(brace_start, len(text)):
    ch = text[i]
    if ch == '{':
        depth += 1
    elif ch == '}':
        depth -= 1
        if depth == 0:
            end = i + 1
            break
if end is None:
    raise SystemExit('Settings class closing brace not found')

block = text[start:end]
if block.count('class _SettingsPage') != 1:
    raise SystemExit('Unexpected Settings class count')
if 'const _SettingsPage(' not in block:
    raise SystemExit('Settings constructor not found inside extracted block')

public_block = block.replace('class _SettingsPage', 'class WzSettingsPage', 1)
public_block = public_block.replace('const _SettingsPage(', 'const WzSettingsPage(', 1)

imports = '''import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/navigation/wavezero_navigation.dart';
import '../../app/theme/wavezero_theme.dart';
import '../../audio/audio_effects.dart';
import '../../catalog/audio_quality.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../downloads/downloads_presentation.dart';
import '../playback/playback_modes.dart';
import 'legal_licenses_page.dart';

'''

target_path.parent.mkdir(parents=True, exist_ok=True)
target_path.write_text(imports + public_block.strip() + '\n', encoding='utf-8')

new_text = text[:start] + text[end:]
new_text = new_text.replace('_SettingsPage(', 'WzSettingsPage(')
settings_import = "import '../features/settings/settings_page.dart';\n"
anchor = "import '../features/settings/legal_licenses_page.dart';\n"
if settings_import not in new_text:
    if anchor not in new_text:
        raise SystemExit('Settings import anchor not found')
    new_text = new_text.replace(anchor, anchor + settings_import, 1)

if 'class _SettingsPage' in new_text or '_SettingsPage(' in new_text:
    raise SystemExit('Old Settings symbols remain after extraction')
if new_text.count('WzSettingsPage(') < 1:
    raise SystemExit('New Settings page callsite not found')

app_path.write_text(new_text, encoding='utf-8')
print(f'Extracted {block.count(chr(10)) + 1} Settings lines')
