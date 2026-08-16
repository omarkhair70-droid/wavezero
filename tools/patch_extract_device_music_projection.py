from pathlib import Path

root = Path('apps/flutter/wavezero_app')
v3 = root / 'lib/app/wavezero_live_metrics_app_v3.dart'
feature = root / 'lib/features/device_music/device_music_projection.dart'
test_path = root / 'test/features/device_music/device_music_projection_test.dart'
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
    ('CatalogTrackSummary _catalogSummaryFromDeviceTrack(', '_catalogSummaryFromDeviceTrack', 'wzCatalogSummaryFromDeviceTrack'),
    ('  DeviceMusicTrack? _deviceTrackFromHistory(', '_deviceTrackFromHistory', 'wzDeviceTrackFromHistory'),
    ('  CatalogTrackManifest _deviceManifest(', '_deviceManifest', 'wzDeviceManifest'),
]
blocks = []
for prefix, old, new in specs:
    block = extract_decl(text, prefix)
    blocks.append((block, old, new))

for block, _, _ in blocks:
    if text.count(block) != 1:
        raise SystemExit('extracted block is not unique')
    text = text.replace(block, '', 1)

module = (
    "import '../../catalog/catalog_track_manifest.dart';\n"
    "import '../history/listening_history_service.dart';\n"
    "import 'device_music_track.dart';\n\n"
)
for block, _, _ in blocks:
    lines = block.rstrip().splitlines()
    if lines and all((not line.strip()) or line.startswith('  ') for line in lines):
        lines = [line[2:] if line.startswith('  ') else line for line in lines]
    block = '\n'.join(lines)
    for _, old, new in specs:
        block = block.replace(old, new)
    module += block.strip() + '\n\n'
feature.write_text(module.rstrip() + '\n')

for _, old, new in specs:
    text = text.replace(old, new)
anchor = "import '../features/device_music/device_music_track.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Device Music import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/device_music/device_music_projection.dart';\n", 1)
v3.write_text(text)

test_path.parent.mkdir(parents=True, exist_ok=True)
test_path.write_text("""import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/device_music/device_music_projection.dart';
import 'package:wavezero_app/features/device_music/device_music_track.dart';
import 'package:wavezero_app/features/history/listening_history_service.dart';

void main() {
  const deviceTrack = DeviceMusicTrack(
    trackId: 'device-audio-1',
    title: 'Local Song',
    artistName: 'Local Artist',
    durationMs: 180000,
    contentUri: 'content://media/external/audio/media/1',
    codec: 'mp3',
    bitrateKbps: 320,
  );

  test('device catalog projection preserves local identity and URI', () {
    final summary = wzCatalogSummaryFromDeviceTrack(deviceTrack);
    expect(summary.trackId, deviceTrack.trackId);
    expect(summary.source, 'device');
    expect(summary.primaryAsset?.manifestUrl, deviceTrack.contentUri);
  });

  test('device manifest uses the MediaStore content URI', () {
    final manifest = wzDeviceManifest(deviceTrack);
    expect(manifest.trackId, deviceTrack.trackId);
    expect(manifest.streamUrl, deviceTrack.contentUri);
  });

  test('device history entry can be rehydrated without a rescan', () {
    const entry = WzListeningHistoryEntry(
      trackId: 'device-audio-1',
      title: 'Local Song',
      subtitle: 'Local Artist',
      source: WzListeningHistorySource.device,
      primaryUrl: 'content://media/external/audio/media/1',
      lastPlayedAtMs: 20,
      firstPlayedAtMs: 10,
      playCount: 2,
      durationMs: 180000,
      codec: 'mp3',
    );
    final restored = wzDeviceTrackFromHistory(entry);
    expect(restored, isNotNull);
    expect(restored!.contentUri, entry.primaryUrl);
    expect(restored.artistName, 'Local Artist');
  });
}
""")
