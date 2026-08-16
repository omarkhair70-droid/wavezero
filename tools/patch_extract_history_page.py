from pathlib import Path

root = Path('apps/flutter/wavezero_app')
v3 = root / 'lib/app/wavezero_live_metrics_app_v3.dart'
page = root / 'lib/features/history/listening_history_page.dart'
test = root / 'test/features/history/listening_history_page_test.dart'
text = v3.read_text()


def extract_braced(source: str, prefix: str):
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
                    while end < len(source) and source[end] in ' \t':
                        end += 1
                    while end < len(source) and source[end] == '\n':
                        end += 1
                    return source[start:end]
        i += 1
    raise SystemExit(f'unclosed declaration {prefix}')

page_block = extract_braced(text, 'class _ListeningHistoryPage extends StatelessWidget {')
tile_block = extract_braced(text, 'class _HistoryEntryTile extends StatelessWidget {')

for block in (page_block, tile_block):
    if text.count(block) != 1:
        raise SystemExit('History UI block is not unique')
    text = text.replace(block, '', 1)

page_block = page_block.replace('_ListeningHistoryPage', 'WzListeningHistoryPage')
module = """import 'package:flutter/material.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import 'history_presentation.dart';
import 'listening_history_service.dart';

""" + page_block.strip() + '\n\n' + tile_block.strip() + '\n'
page.write_text(module)

anchor = "import '../features/history/history_presentation.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one History presentation import, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/history/listening_history_page.dart';\n", 1)
text = text.replace('_ListeningHistoryPage', 'WzListeningHistoryPage')
v3.write_text(text)

test.parent.mkdir(parents=True, exist_ok=True)
test.write_text("""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/history/listening_history_page.dart';

void main() {
  testWidgets('empty Listening History keeps the existing local-only shell copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WzListeningHistoryPage(
          entries: const [],
          onBack: () {},
          mostPlayedEntry: null,
          resolver: (_) => null,
          onPlay: (_) {},
          onAddToQueue: (_) {},
          onAddToCollection: (_) {},
          onRemove: (_) {},
          onClearAll: null,
        ),
      ),
    );
    expect(find.text('Listening History'), findsOneWidget);
    expect(find.text('No listening history yet. Play a track to start.'), findsOneWidget);
    expect(find.text('Local only'), findsOneWidget);
  });
}
""")
