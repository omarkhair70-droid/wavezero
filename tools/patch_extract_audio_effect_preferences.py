from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../features/playback/playback_preferences.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one playback preferences import, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/playback/audio_effect_preferences.dart';\n", 1)

key_line = "  static const _audioEffectPreferenceKey = 'wavezero.selected_audio_effect_profile';\n"
if text.count(key_line) != 1:
    raise SystemExit(f'expected one audio effect key, found {text.count(key_line)}')
text = text.replace(key_line, '', 1)

field_anchor = "  final WzPlaybackPreferences _playbackPreferences = const WzPlaybackPreferences();\n"
if text.count(field_anchor) != 1:
    raise SystemExit(f'expected one playback prefs field, found {text.count(field_anchor)}')
text = text.replace(
    field_anchor,
    field_anchor + "  final WzAudioEffectPreferences _audioEffectPreferences = const WzAudioEffectPreferences();\n",
    1,
)

old_load = """      final prefs = await SharedPreferences.getInstance();
      final storedProfile = parseAudioEffectProfile(prefs.getString(_audioEffectPreferenceKey));
"""
new_load = """      final storedProfile = await _audioEffectPreferences.load();
"""
if text.count(old_load) != 1:
    raise SystemExit(f'expected one audio effect load block, found {text.count(old_load)}')
text = text.replace(old_load, new_load, 1)

old_save = """        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_audioEffectPreferenceKey, profile.id);
"""
new_save = """        await _audioEffectPreferences.save(profile);
"""
if text.count(old_save) != 1:
    raise SystemExit(f'expected one audio effect save block, found {text.count(old_save)}')
text = text.replace(old_save, new_save, 1)

path.write_text(text)
