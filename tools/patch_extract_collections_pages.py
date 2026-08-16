from pathlib import Path

root = Path('apps/flutter/wavezero_app')
v3 = root / 'lib/app/wavezero_live_metrics_app_v3.dart'
page = root / 'lib/features/collections/collections_pages.dart'
test = root / 'test/features/collections/collections_pages_test.dart'
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
            if ch in "'\"": quote = ch
            elif ch == '{': depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    if end < len(source) and source[end] == ';': end += 1
                    while end < len(source) and source[end] in ' \t': end += 1
                    while end < len(source) and source[end] == '\n': end += 1
                    return source[start:end]
        i += 1
    raise SystemExit(f'unclosed declaration {prefix}')

specs = [
    ('class _CollectionsPage extends StatelessWidget {', '_CollectionsPage', 'WzCollectionsPage'),
    ('class _CollectionCard extends StatelessWidget {', None, None),
    ('class _CollectionDetailPage extends StatelessWidget {', '_CollectionDetailPage', 'WzCollectionDetailPage'),
    ('class _CollectionTrackRow extends StatelessWidget {', None, None),
    ('String _collectionSourceLabel(WzCollectionTrackSource source) => switch (source) {', None, None),
    ('String _friendlyUpdated(int updatedAtMs) {', None, None),
]
blocks = []
for prefix, old, new in specs:
    block = extract_braced(text, prefix)
    blocks.append((block, old, new))
for block, _, _ in blocks:
    if text.count(block) != 1:
        raise SystemExit('Collections UI block is not unique')
    text = text.replace(block, '', 1)

module = """import 'package:flutter/material.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import 'collections_service.dart';

"""
for block, old, new in blocks:
    if old and new:
        block = block.replace(old, new)
    block = block.replace('_WzTokens.caption', 'WzText.caption')
    block = block.replace('_WzTokens.canvas', 'WzColors.canvas')
    block = block.replace('_WzTokens.surfaceElevated', 'WzColors.surfaceElevated')
    block = block.replace('_WzTokens.surface', 'WzColors.surface')
    module += block.strip() + '\n\n'
page.write_text(module.rstrip() + '\n')

anchor = "import '../features/collections/collection_mutations.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Collections import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/collections/collections_pages.dart';\n", 1)
text = text.replace('_CollectionsPage', 'WzCollectionsPage')
text = text.replace('_CollectionDetailPage', 'WzCollectionDetailPage')
v3.write_text(text)

test.parent.mkdir(parents=True, exist_ok=True)
test.write_text("""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/collections/collections_pages.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';

void main() {
  testWidgets('Collections page keeps the Liked Tracks entry and create action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WzCollectionsPage(
          collections: [WzCollection.liked()],
          onBack: () {},
          onOpen: (_) {},
          onCreate: () {},
          onRename: (_, __) {},
          onDelete: (_) {},
        ),
      ),
    );
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Liked Tracks'), findsWidgets);
    expect(find.textContaining('Create'), findsWidgets);
  });
}
""")
