from pathlib import Path

app_path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
target_path = Path('apps/flutter/wavezero_app/lib/features/playback/player_presentation.dart')
text = app_path.read_text(encoding='utf-8')


def class_span(source: str, class_name: str, extends='StatelessWidget'):
    marker = f'class {class_name} extends {extends} {{'
    start = source.find(marker)
    if start < 0:
        raise SystemExit(f'Class marker not found: {class_name}')
    brace = source.find('{', start)
    depth = 0
    end = None
    for i in range(brace, len(source)):
        if source[i] == '{':
            depth += 1
        elif source[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise SystemExit(f'Class closing brace not found: {class_name}')
    return start, end, source[start:end]


def function_span(source: str, marker: str):
    start = source.find(marker)
    if start < 0:
        raise SystemExit(f'Function marker not found: {marker}')
    brace = source.find('{', start)
    if brace < 0:
        raise SystemExit(f'Function opening brace not found: {marker}')
    depth = 0
    end = None
    for i in range(brace, len(source)):
        if source[i] == '{':
            depth += 1
        elif source[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise SystemExit(f'Function closing brace not found: {marker}')
    return start, end, source[start:end]


class_names = [
    '_NowContextPanel',
    '_PremiumPlayerSheet',
    '_PremiumPlayerSurface',
    '_PlaybackModesCard',
    '_PlayerArtworkHero',
    '_NowTrackIdentity',
    '_PlayerContextBadges',
    '_PlayerProgressBlock',
    '_PlayerPrimaryControls',
    '_PlayerUpNextPreview',
    '_PlayerSourceCard',
    '_PremiumMiniPlayer',
    '_MiniArtwork',
    '_MiniBadge',
]

blocks = []
for name in class_names:
    _, _, block = class_span(text, name)
    blocks.append(block)
for name in class_names:
    start, end, _ = class_span(text, name)
    text = text[:start] + text[end:]

# Move presentation helpers.
helper_blocks = []
for marker in ['String _effectStatusLabel(', 'String _playerSourceLabel(']:
    start, end, block = function_span(text, marker)
    helper_blocks.append(block)
    text = text[:start] + text[end:]

for line in [
    "String _statusFromEvent(String? event) { switch (event) { case 'track_loaded': case 'buffering_started': return 'Preparing'; case 'ready': case 'buffering_ended': case 'manifest_loaded': return 'Ready'; case 'not_playing': return 'Paused'; case 'stopped': return 'Paused'; case 'ended': case 'playback_ended': return 'Ended'; default: return 'Ready'; } }\n",
    "String _formatTime(int? valueMs) { if (valueMs == null || valueMs < 0) return '—:—'; final totalSeconds = (valueMs / 1000).floor(); final minutes = totalSeconds ~/ 60; final seconds = totalSeconds % 60; return '$minutes:${seconds.toString().padLeft(2, '0')}'; }\n",
]:
    if text.count(line) != 1:
        raise SystemExit(f'Expected player helper exactly once: {line[:45]}')
    helper_blocks.append(line.strip())
    text = text.replace(line, '', 1)

# Update app callsites to public playback presentation ownership.
public_names = {
    '_NowContextPanel': 'WzNowContextPanel',
    '_PremiumPlayerSheet': 'WzPremiumPlayerSheet',
    '_PremiumPlayerSurface': 'WzPremiumPlayerSurface',
    '_PremiumMiniPlayer': 'WzPremiumMiniPlayer',
}
for old, new in public_names.items():
    text = text.replace(f'{old}(', f'{new}(')
text = text.replace('_effectStatusLabel(', 'wzEffectStatusLabel(')
text = text.replace('_playerSourceLabel(', 'wzPlayerSourceLabel(')

# Last non-player consumers of the legacy private tokens are shell colors.
text = text.replace('_WzTokens.border', 'WzColors.border')
text = text.replace('_WzTokens.textMuted', 'WzColors.textMuted')

# Remove the legacy token alias class entirely.
start, end, _ = class_span(text, '_WzTokens', extends='Object') if False else (None, None, None)
marker = 'class _WzTokens {'
start = text.find(marker)
if start < 0:
    raise SystemExit('Legacy _WzTokens class missing')
brace = text.find('{', start)
depth = 0
end = None
for i in range(brace, len(text)):
    if text[i] == '{': depth += 1
    elif text[i] == '}':
        depth -= 1
        if depth == 0:
            end = i + 1
            break
if end is None:
    raise SystemExit('Legacy _WzTokens class close missing')
text = text[:start] + text[end:]

player_import = "import '../features/playback/player_presentation.dart';\n"
anchor = "import '../features/playback/playback_preferences.dart';\n"
if player_import not in text:
    if anchor not in text:
        raise SystemExit('Player import anchor missing')
    text = text.replace(anchor, anchor + player_import, 1)

for old in class_names:
    if f'class {old} ' in text:
        raise SystemExit(f'Old player presentation class remains in app: {old}')
for old in public_names:
    if f'{old}(' in text:
        raise SystemExit(f'Old player callsite remains in app: {old}')
if '_effectStatusLabel(' in text or '_playerSourceLabel(' in text or '_statusFromEvent(' in text or '_formatTime(' in text:
    raise SystemExit('Moved player presentation helper remains in app')
if '_WzTokens' in text:
    raise SystemExit('Legacy _WzTokens remains after player extraction')

joined = '\n\n'.join(blocks)
for old, new in public_names.items():
    joined = joined.replace(f'class {old} extends StatelessWidget', f'class {new} extends StatelessWidget')
    joined = joined.replace(f'const {old}(', f'const {new}(')
    joined = joined.replace(f'{old}(', f'{new}(')

# Use the shared design system directly in moved player presentation.
token_replacements = {
    '_WzTokens.surface': 'WzColors.surface',
    '_WzTokens.border': 'WzColors.border',
    '_WzTokens.accent': 'WzColors.accent',
    '_WzTokens.textPrimary': 'WzColors.textPrimary',
    '_WzTokens.textMuted': 'WzColors.textMuted',
    '_WzTokens.textSubtle': 'WzColors.textSubtle',
    '_WzTokens.space4': 'WzSpacing.md',
    '_WzTokens.radiusXl': 'WzRadius.xl',
    '_WzTokens.motionNormal': 'WzMotion.normal',
    '_WzTokens.motionSlow': 'WzMotion.slow',
    '_WzTokens.motionCurve': 'WzMotion.curve',
    '_WzTokens.caption': 'WzText.caption',
}
for old, new in token_replacements.items():
    joined = joined.replace(old, new)
if '_WzTokens.' in joined:
    raise SystemExit('Legacy tokens remain in moved player presentation')

helpers = '\n\n'.join(helper_blocks)
helpers = helpers.replace('_effectStatusLabel', 'wzEffectStatusLabel')
helpers = helpers.replace('_playerSourceLabel', 'wzPlayerSourceLabel')
joined = joined.replace('_effectStatusLabel(', 'wzEffectStatusLabel(')
joined = joined.replace('_playerSourceLabel(', 'wzPlayerSourceLabel(')

imports = '''import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio/audio_effects.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../playback/playback_metrics.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import 'playback_modes.dart';

'''

target_path.parent.mkdir(parents=True, exist_ok=True)
target_path.write_text(imports + joined.strip() + '\n\n' + helpers.strip() + '\n', encoding='utf-8')
app_path.write_text(text, encoding='utf-8')
print(f'Extracted {len(class_names)} Player presentation classes and removed legacy _WzTokens')
