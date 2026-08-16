from pathlib import Path

root = Path('apps/flutter/wavezero_app')
v3 = root / 'lib/app/wavezero_live_metrics_app_v3.dart'
page = root / 'lib/features/settings/legal_licenses_page.dart'
test = root / 'test/features/settings/legal_licenses_page_test.dart'
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
                    while end < len(source) and source[end] in ' \t': end += 1
                    while end < len(source) and source[end] == '\n': end += 1
                    return source[start:end]
        i += 1
    raise SystemExit(f'unclosed declaration {prefix}')

page_block = extract_braced(text, 'class _LegalLicensesPage extends StatelessWidget {')
card_block = extract_braced(text, 'class _LegalTrackCard extends StatelessWidget {')
for block in (page_block, card_block):
    if text.count(block) != 1:
        raise SystemExit('Legal UI block is not unique')
    text = text.replace(block, '', 1)

page_block = page_block.replace('_LegalLicensesPage', 'WzLegalLicensesPage')
module = """import 'package:flutter/material.dart';

import '../../app/navigation/wavezero_navigation.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/track_source.dart';

""" + page_block.strip() + '\n\n' + card_block.strip() + '\n'
module = module.replace('_WzTokens.canvas', 'WzColors.canvas')
module = module.replace('_isDeviceCatalogTrack', 'isWzDeviceCatalogTrack')
module = module.replace('_isCachedCatalogTrack', 'isWzCachedCatalogTrack')
page.parent.mkdir(parents=True, exist_ok=True)
page.write_text(module)

anchor = "import '../features/settings/app_mode_preferences.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Settings import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/settings/legal_licenses_page.dart';\n", 1)
text = text.replace('_LegalLicensesPage', 'WzLegalLicensesPage')
v3.write_text(text)

test.parent.mkdir(parents=True, exist_ok=True)
test.write_text("""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/app/navigation/wavezero_navigation.dart';
import 'package:wavezero_app/features/settings/legal_licenses_page.dart';

void main() {
  testWidgets('empty Legal page keeps the release-safe rights copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WzLegalLicensesPage(
          tracks: [],
          appMode: WzAppMode.consumer,
        ),
      ),
    );
    expect(find.text('Legal & licenses'), findsOneWidget);
    expect(find.textContaining('Rights metadata'), findsOneWidget);
    expect(find.textContaining('No tracks are loaded yet.'), findsOneWidget);
  });
}
""")
