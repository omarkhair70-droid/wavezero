from pathlib import Path

root = Path('apps/flutter/wavezero_app')
v3 = root / 'lib/app/wavezero_live_metrics_app_v3.dart'
feature = root / 'lib/features/downloads/downloads_presentation.dart'
test_path = root / 'test/features/downloads/downloads_presentation_test.dart'
text = v3.read_text()


def extract_decl(source: str, declaration_prefix: str):
    pos = source.find(declaration_prefix)
    if pos < 0:
        raise SystemExit(f'missing declaration {declaration_prefix}')
    if source.find(declaration_prefix, pos + 1) >= 0:
        raise SystemExit(f'duplicate declaration {declaration_prefix}')
    start = source.rfind('\n', 0, pos) + 1
    brace = source.find('{', pos)
    if brace < 0:
        raise SystemExit(f'missing body {declaration_prefix}')
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
                    if end < len(source) and source[end] == '\n':
                        end += 1
                    return source[start:end]
        i += 1
    raise SystemExit(f'unclosed declaration {declaration_prefix}')

specs = [
    ('CatalogTrackSummary _catalogSummaryFromCachedTrack(', '_catalogSummaryFromCachedTrack', 'wzCatalogSummaryFromCachedTrack'),
    ('String _formatCacheBytes(', '_formatCacheBytes', 'formatWzCacheBytes'),
    ('String _downloadSourceLabel(', '_downloadSourceLabel', 'wzDownloadSourceLabel'),
    ('String _cachedSourceBadgeLabel(', '_cachedSourceBadgeLabel', 'wzCachedSourceBadgeLabel'),
]
blocks = []
for prefix, old, new in specs:
    block = extract_decl(text, prefix)
    blocks.append((block, old, new))

for block, _, _ in blocks:
    if text.count(block) != 1:
        raise SystemExit('extracted block is not unique')
    text = text.replace(block, '', 1)

module = "import '../../catalog/catalog_track_manifest.dart';\nimport 'cache_service.dart';\n\n"
for block, _, _ in blocks:
    for _, old, new in specs:
        block = block.replace(old, new)
    module += block.strip() + '\n\n'
feature.parent.mkdir(parents=True, exist_ok=True)
feature.write_text(module.rstrip() + '\n')

for _, old, new in specs:
    text = text.replace(old, new)
anchor = "import '../features/downloads/cache_service.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Downloads import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/downloads/downloads_presentation.dart';\n", 1)
v3.write_text(text)

test_path.parent.mkdir(parents=True, exist_ok=True)
test_path.write_text("""import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/downloads/cache_service.dart';
import 'package:wavezero_app/features/downloads/downloads_presentation.dart';

void main() {
  test('cache byte formatting preserves existing units', () {
    expect(formatWzCacheBytes(0), '0 B');
    expect(formatWzCacheBytes(1024), '1.0 KB');
    expect(formatWzCacheBytes(1024 * 1024), '1.0 MB');
  });

  test('cached track projection preserves identity and source URL', () {
    const cached = CachedTrackMetadata(
      trackId: 'track-1',
      title: 'Track One',
      artistName: 'Artist',
      localFilePath: '/tmp/track-1.mp3',
      originalRemoteUrl: 'https://example.test/track-1.mp3',
      cachedAt: 123,
      downloadSource: 'manual',
      qualityLabel: 'high',
      codec: 'mp3',
      bitrateKbps: 320,
    );
    final summary = wzCatalogSummaryFromCachedTrack(cached);
    expect(summary.trackId, cached.trackId);
    expect(summary.title, cached.title);
    expect(summary.source, 'cached');
    expect(summary.primaryAsset?.manifestUrl, cached.originalRemoteUrl);
  });
}
""")
