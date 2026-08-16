import 'package:shared_preferences/shared_preferences.dart';

import '../../app/navigation/wavezero_navigation.dart';

class WzAppModePreferences {
  const WzAppModePreferences();

  static const preferenceKey = 'wavezero.app_mode';

  Future<WzAppMode> load({required bool allowDeveloper}) async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(preferenceKey);
    if (allowDeveloper && savedMode == WzAppMode.developer.name) {
      return WzAppMode.developer;
    }
    return WzAppMode.consumer;
  }

  Future<void> save(WzAppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, mode.name);
  }
}
