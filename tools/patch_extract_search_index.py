from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../features/search/search_results.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Search results import, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/search/search_index.dart';\n", 1)

prefix = '  List<WzSearchResult> get _allSearchResults {'
pos = text.find(prefix)
if pos < 0:
    raise SystemExit('missing Search index getter')
if text.find(prefix, pos + 1) >= 0:
    raise SystemExit('duplicate Search index getter')
brace = text.find('{', pos)
depth = 0
quote = None
escape = False
i = brace
end = None
while i < len(text):
    ch = text[i]
    if quote is not None:
        if escape:
            escape = False
        elif ch == '\\':
            escape = True
        elif ch == quote:
            quote = None
    else:
        if ch in "'\"":
            quote = ch
        elif ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    i += 1
if end is None:
    raise SystemExit('unclosed Search index getter')
while end < len(text) and text[end] == '\n':
    end += 1

replacement = """  List<WzSearchResult> get _allSearchResults {
    final key = _searchIndexKey();
    final memo = _searchIndexMemo;
    if (memo != null && _searchIndexMemoKey == key) return memo;
    final results = buildWzSearchIndex(
      catalogTracks: _searchableCatalogTracks,
      deviceTracks: _deviceCatalogTracks,
      downloadedTracks: _cachedCatalogTracks,
      cloudTracks: _cloudCatalogTracks,
      collections: _collections,
      historyEntries: _listeningHistory,
      resolveHistoryEntry: _resolveHistoryEntry,
      isDeviceTrack: _isDeviceCatalogTrack,
      historySourceLabel: _historySourceLabel,
    );
    _searchIndexMemoKey = key;
    _searchIndexMemo = results;
    return results;
  }

"""
text = text[:pos] + replacement + text[end:]
path.write_text(text)
