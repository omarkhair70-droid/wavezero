from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()
anchor = "import '../shared/widgets/wavezero_artwork.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one shared artwork import, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../shared/widgets/wavezero_empty_message.dart';\n", 1)

prefix = 'class _EmptyCatalogMessage extends StatelessWidget {'
pos = text.find(prefix)
if pos < 0:
    raise SystemExit('missing empty message class')
start = text.rfind('\n', 0, pos) + 1
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
        if ch in "'\"": quote = ch
        elif ch == '{': depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    i += 1
if end is None:
    raise SystemExit('unclosed empty message class')
while end < len(text) and text[end] == '\n': end += 1
text = text[:start] + text[end:]
text = text.replace('_EmptyCatalogMessage', 'WzEmptyCatalogMessage')
path.write_text(text)
