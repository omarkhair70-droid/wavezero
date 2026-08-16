import 'package:shared_preferences/shared_preferences.dart';

import '../../audio/audio_effects.dart';

class WzAudioEffectPreferences {
  const WzAudioEffectPreferences();

  static const preferenceKey = 'wavezero.selected_audio_effect_profile';

  Future<AudioEffectProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return parseAudioEffectProfile(prefs.getString(preferenceKey));
  }

  Future<void> save(AudioEffectProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, profile.id);
  }
}
