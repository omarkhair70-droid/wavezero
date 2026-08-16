from pathlib import Path

root = Path('apps/flutter/wavezero_app')
v3 = root / 'lib/app/wavezero_live_metrics_app_v3.dart'
page = root / 'lib/features/cloud_vault/cloud_vault_page.dart'
test = root / 'test/features/cloud_vault/cloud_vault_page_test.dart'
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
    ('class _CloudVaultPage extends StatelessWidget {', '_CloudVaultPage', 'WzCloudVaultPage'),
    ('class _CloudProviderCard extends StatelessWidget {', None, None),
    ('class _CloudVaultTrackRow extends StatelessWidget {', None, None),
]
blocks = []
for prefix, old, new in specs:
    block = extract_braced(text, prefix)
    blocks.append((block, old, new))
for block, _, _ in blocks:
    if text.count(block) != 1:
        raise SystemExit('Cloud Vault UI block is not unique')
    text = text.replace(block, '', 1)

module = """import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../../shared/widgets/wavezero_empty_message.dart';
import 'cloud_vault_models.dart';

"""
for block, old, new in blocks:
    if old and new:
        block = block.replace(old, new)
    module += block.strip() + '\n\n'
page.write_text(module.rstrip() + '\n')

anchor = "import '../features/cloud_vault/cloud_vault_service.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Cloud Vault import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/cloud_vault/cloud_vault_page.dart';\n", 1)
text = text.replace('_CloudVaultPage', 'WzCloudVaultPage')
v3.write_text(text)

test.parent.mkdir(parents=True, exist_ok=True)
test.write_text("""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/cloud_vault/cloud_vault_page.dart';

void main() {
  testWidgets('empty Cloud Vault keeps the privacy-first foundation copy', (tester) async {
    final title = TextEditingController();
    final artist = TextEditingController();
    final url = TextEditingController();
    final provider = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(artist.dispose);
    addTearDown(url.dispose);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WzCloudVaultPage(
          tracks: const [],
          developerMode: false,
          titleController: title,
          artistController: artist,
          playableUrlController: url,
          providerLabelController: provider,
          onAddDeveloperTrack: () async {},
          onPlay: (_) {},
          onAddToQueue: (_) {},
          onRemove: (_) {},
          onClearAll: null,
        ),
      ),
    );
    expect(find.text('Cloud Vault'), findsWidgets);
    expect(find.text('Privacy-first foundation'), findsOneWidget);
    expect(find.textContaining('does not upload your cloud files'), findsOneWidget);
    expect(find.textContaining('No cloud music connected yet.'), findsOneWidget);
  });
}
""")
