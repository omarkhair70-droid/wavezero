from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../features/library/library_sources.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Library import anchor, found {text.count(anchor)}')
text = text.replace(
    anchor,
    anchor + "import '../features/library/library_status_presentation.dart';\n",
    1,
)


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
    'String _catalogModeLabel(',
    'String _friendlyLoadError(',
    'String _consumerCatalogStatus(',
    'String? _consumerDeviceError(',
]:
    text = remove_braced_declaration(text, prefix)

for old, new in {
    '_catalogModeLabel': 'wzCatalogModeLabel',
    '_friendlyLoadError': 'friendlyWzLoadError',
    '_consumerCatalogStatus': 'wzConsumerCatalogStatus',
    '_consumerDeviceError': 'wzConsumerDeviceError',
}.items():
    text = text.replace(old, new)

path.write_text(text)
