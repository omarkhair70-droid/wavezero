from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../shared/media/media_presentation.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one shared media import anchor, found {text.count(anchor)}')
text = text.replace(
    anchor,
    anchor + "import '../shared/widgets/wavezero_artwork.dart';\n",
    1,
)


def remove_braced(source: str, prefix: str) -> str:
    pos = source.find(prefix)
    if pos < 0:
        raise SystemExit(f'missing declaration {prefix}')
    if source.find(prefix, pos + 1) >= 0:
        raise SystemExit(f'duplicate declaration {prefix}')
    start = source.rfind('\n', 0, pos) + 1
    brace = source.find('{', pos)
    if brace < 0:
        raise SystemExit(f'missing body for {prefix}')
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
    'class _WaveZeroCoverArt extends StatelessWidget {',
    'class _WaveZeroCoverPainter extends CustomPainter {',
    'int _stableArtworkSeed(String value) {',
    'List<Color> _coverColors(int seed, String hint) {',
    'String _coverInitials(String? title, String? artist) {',
    'class _Artwork extends StatelessWidget {',
]:
    text = remove_braced(text, prefix)

text = text.replace('_WaveZeroCoverArt', 'WzWaveZeroCoverArt')
text = text.replace('_Artwork', 'WzArtwork')
path.write_text(text)
