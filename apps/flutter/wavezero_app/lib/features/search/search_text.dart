String normalizeWzSearch(String value) {
  final withoutDiacritics = value
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp('[إأآا]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  return withoutDiacritics.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

String canonicalizeWzRecentSearch(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

List<String> buildWzRecentSearches({
  required List<String> current,
  required String query,
  int limit = 10,
}) {
  final canonical = canonicalizeWzRecentSearch(query);
  if (canonical.isEmpty) return current;
  final normalized = normalizeWzSearch(canonical);
  return <String>[
    canonical,
    ...current.where((item) => normalizeWzSearch(item) != normalized),
  ].take(limit).toList(growable: false);
}
