from pathlib import Path

root = Path('apps/flutter/wavezero_app')
v3 = root / 'lib/app/wavezero_live_metrics_app_v3.dart'
page = root / 'lib/features/search/search_page.dart'
test = root / 'test/features/search/search_page_test.dart'
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
            if escape: escape = False
            elif ch == '\\': escape = True
            elif ch == quote: quote = None
        else:
            if ch in "'\"": quote = ch
            elif ch == '{': depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    while end < len(source) and source[end] in ' \t': end += 1
                    while end < len(source) and source[end] == '\n': end += 1
                    return source[start:end]
        i += 1
    raise SystemExit(f'unclosed declaration {prefix}')

specs = [
    ('class _SearchPage extends StatelessWidget {', '_SearchPage', 'WzSearchPage'),
    ('class _SearchResultCard extends StatelessWidget {', None, None),
    ('class _SearchDiscoverySections extends StatelessWidget {', None, None),
]
blocks = []
for prefix, old, new in specs:
    block = extract_braced(text, prefix)
    blocks.append((block, old, new))
for block, _, _ in blocks:
    if text.count(block) != 1:
        raise SystemExit('Search UI block is not unique')
    text = text.replace(block, '', 1)

module = """import 'package:flutter/material.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../../shared/widgets/wavezero_empty_message.dart';
import '../collections/collections_service.dart';
import '../history/history_presentation.dart';
import '../history/listening_history_service.dart';
import 'search_controls.dart';
import 'search_results.dart';

"""
for block, old, new in blocks:
    if old and new: block = block.replace(old, new)
    block = block.replace('_WzTokens.caption', 'WzText.caption')
    block = block.replace('_WzTokens.canvas', 'WzColors.canvas')
    block = block.replace('_WzTokens.surfaceElevated', 'WzColors.surfaceElevated')
    block = block.replace('_WzTokens.surface', 'WzColors.surface')
    block = block.replace('_friendlyHistoryTime', 'friendlyWzHistoryTime')
    block = block.replace('_historySourceLabel', 'wzHistorySourceLabel')
    module += block.strip() + '\n\n'
page.write_text(module.rstrip() + '\n')

anchor = "import '../features/search/search_index.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Search import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/search/search_page.dart';\n", 1)
text = text.replace('_SearchPage', 'WzSearchPage')
v3.write_text(text)

test.parent.mkdir(parents=True, exist_ok=True)
test.write_text("""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/search/search_controls.dart';
import 'package:wavezero_app/features/search/search_page.dart';

void main() {
  testWidgets('empty Search page keeps filters and discovery shell', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: WzSearchPage(
          controller: controller,
          onBack: () {},
          filter: WzSearchFilter.all,
          results: const [],
          recentSearches: const [],
          history: const [],
          cachedTracks: const [],
          collections: const [],
          catalogTracks: const [],
          onQueryChanged: (_) {},
          onSubmitted: (_) {},
          onFilterChanged: (_) {},
          onRecent: (_) {},
          onClearRecent: () {},
          onPlayResult: (_) {},
          onAddResultToQueue: (_) {},
          onAddResultToCollection: (_) {},
          onOpenCollectionResult: (_) {},
          onDiscoveryTrack: (_) {},
          onDiscoveryCollection: (_) {},
        ),
      ),
    );
    expect(find.text('Search'), findsWidgets);
    expect(find.text('All'), findsWidgets);
  });
}
""")
