from pathlib import Path

root = Path('apps/flutter/wavezero_app')
v3 = root / 'lib/app/wavezero_live_metrics_app_v3.dart'
page = root / 'lib/features/downloads/storage_manager_page.dart'
test = root / 'test/features/downloads/storage_manager_page_test.dart'
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

specs = [
    ('class _StorageManagerPage extends StatelessWidget {', '_StorageManagerPage', 'WzStorageManagerPage'),
    ('class _StorageCategoryCard extends StatelessWidget {', None, None),
    ('class _StorageTrackRow extends StatelessWidget {', None, None),
    ('IconData _downloadSourceIcon(String source) {', None, None),
]
blocks = []
for prefix, old, new in specs:
    block = extract_braced(text, prefix)
    blocks.append((block, old, new))
for block, _, _ in blocks:
    if text.count(block) != 1:
        raise SystemExit('Storage UI block is not unique')
    text = text.replace(block, '', 1)

module = """import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../../shared/widgets/wavezero_empty_message.dart';
import 'cache_service.dart';
import 'downloads_presentation.dart';

"""
for block, old, new in blocks:
    if old and new:
        block = block.replace(old, new)
    module += block.strip() + '\n\n'
page.write_text(module.rstrip() + '\n')

anchor = "import '../features/downloads/smart_download_policy.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Downloads import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/downloads/storage_manager_page.dart';\n", 1)
text = text.replace('_StorageManagerPage', 'WzStorageManagerPage')
v3.write_text(text)

test.parent.mkdir(parents=True, exist_ok=True)
test.write_text("""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/downloads/storage_manager_page.dart';

void main() {
  testWidgets('empty Storage Manager keeps offline and Smart Downloads controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WzStorageManagerPage(
          downloads: const [],
          onBack: () {},
          cacheBytes: 0,
          trackBytes: const {},
          manualDownloadedCount: 0,
          smartDownloadedCount: 0,
          offlineReadyCount: 0,
          smartDownloadsEnabled: true,
          controlsDisabled: false,
          onSmartDownloadsChanged: (_) {},
          onPlay: (_) {},
          onDelete: (_) {},
          onClearAll: () async {},
        ),
      ),
    );
    expect(find.text('Storage Manager'), findsOneWidget);
    expect(find.text('No downloads yet'), findsWidgets);
    expect(find.text('Smart Downloads'), findsWidgets);
    expect(find.textContaining('No downloads yet. Download tracks from Library'), findsOneWidget);
  });
}
""")
