import 'package:shared_preferences/shared_preferences.dart';

class WzRecentSearchesStore {
  const WzRecentSearchesStore();

  static const preferenceKey = 'wavezero.recent_searches.v1';
  static const maxItems = 10;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList(preferenceKey) ?? const <String>[];
    return searches.take(maxItems).toList(growable: false);
  }

  Future<void> save(List<String> searches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      preferenceKey,
      searches.take(maxItems).toList(growable: false),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(preferenceKey);
  }
}
