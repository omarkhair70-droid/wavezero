import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/features/search/recent_searches_store.dart';
import 'package:wavezero_app/features/search/search_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('search normalization preserves the existing Arabic and whitespace rules', () {
    expect(normalizeWzSearch('  أَغْنِيَة   جديدة  '), 'اغنيه جديده');
    expect(normalizeWzSearch('إلى'), 'الي');
    expect(normalizeWzSearch('HELLO   World'), 'hello world');
  });

  test('recent search canonicalization trims and collapses spaces without changing display text otherwise', () {
    expect(canonicalizeWzRecentSearch('  New   Song  '), 'New Song');
  });

  test('remember moves an equivalent normalized query to the front and preserves newest display form', () async {
    const store = WzRecentSearchesStore();
    final next = await store.remember(
      current: const ['اغنيه جديده', 'Other'],
      query: '  أَغْنِيَة   جديدة  ',
    );

    expect(next, const ['أَغْنِيَة جديدة', 'Other']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(WzRecentSearchesStore.preferenceKey), next);
  });

  test('remember keeps at most ten items and ignores an empty query', () async {
    const store = WzRecentSearchesStore();
    final current = List<String>.generate(10, (index) => 'q$index');

    final next = await store.remember(current: current, query: 'new');
    expect(next.length, 10);
    expect(next.first, 'new');
    expect(next.last, 'q8');

    final unchanged = await store.remember(current: next, query: '   ');
    expect(unchanged, next);
  });

  test('load truncates persisted history to ten items and clear removes the key', () async {
    final persisted = List<String>.generate(12, (index) => 'q$index');
    SharedPreferences.setMockInitialValues(<String, Object>{
      WzRecentSearchesStore.preferenceKey: persisted,
    });
    const store = WzRecentSearchesStore();

    final loaded = await store.load();
    expect(loaded, persisted.take(10).toList());

    await store.clear();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(WzRecentSearchesStore.preferenceKey), isFalse);
  });
}
