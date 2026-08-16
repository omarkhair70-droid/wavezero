from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../features/search/search_text.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Search import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/search/search_results.dart';\n", 1)

for enum_line in [
    'enum WzSearchResultType { track, deviceTrack, downloadedTrack, cloudTrack, collection, historyEntry, artistLike, unknown }\n\n',
    'enum WzSearchSource { apiCatalog, deviceMusic, downloads, cloudVault, collections, history, legalDemo }\n\n',
]:
    if text.count(enum_line) != 1:
        raise SystemExit(f'expected enum block once: {enum_line[:32]!r}')
    text = text.replace(enum_line, '', 1)


def remove_braced_declaration(source: str, prefix: str) -> str:
    pos = source.find(prefix)
    if pos < 0:
        raise SystemExit(f'missing declaration {prefix}')
    if source.find(prefix, pos + 1) >= 0:
        raise SystemExit(f'duplicate declaration {prefix}')
    start = source.rfind('\n', 0, pos) + 1
    brace = source.find('{', pos)
    if brace < 0:
        raise SystemExit(f'missing body {prefix}')
    depth = 0
    quote = None
    escape = False
    i = brace
    while i < len(source):
        ch = source[i]
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
                    if end < len(source) and source[end] == ';':
                        end += 1
                    while end < len(source) and source[end] in ' \t':
                        end += 1
                    while end < len(source) and source[end] == '\n':
                        end += 1
                    return source[:start] + source[end:]
        i += 1
    raise SystemExit(f'unclosed declaration {prefix}')

for prefix in [
    'class WzSearchResult {',
    'String _searchSourceLabel(',
    'String _searchTypeLabel(',
    'bool _searchFilterAllows(',
    'int _searchRank(',
]:
    text = remove_braced_declaration(text, prefix)

replacements = {
    '_searchSourceLabel': 'wzSearchSourceLabel',
    '_searchTypeLabel': 'wzSearchTypeLabel',
    '_searchFilterAllows': 'wzSearchFilterAllows',
    '_searchRank': 'wzSearchRank',
}
for old, new in replacements.items():
    text = text.replace(old, new)

path.write_text(text)
