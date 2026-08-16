import 'package:shared_preferences/shared_preferences.dart';

import 'search_text.dart';

class WzRecentSearchesStore {
  const WzRecentSearchesStore();

  static const preferenceKey = 'wavezero.recent_searches.v1';
  static const maxItems = 10;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList(preferenceKey) ?? const <String>[];
    return searches.take(maxItems).toList(growable: false);
  }

  Future<List<String>> remember({
    required List<String> current,
    required String query,
  }) async {
    final next = buildWzRecentSearches(
      current: current,
      query: query,
      limit: maxItems,
    );
    if (canonicalizeWzRecentSearch(query).isEmpty) return next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(preferenceKey, next);
    return next;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(preferenceKey);
  }
}
