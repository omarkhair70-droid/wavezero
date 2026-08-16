from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../features/history/history_selection.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one History import anchor, found {text.count(anchor)}')
text = text.replace(
    anchor,
    anchor
    + "import '../features/history/history_resolution.dart';\n"
    + "import '../features/history/history_presentation.dart';\n",
    1,
)

old_resolve = """  CatalogTrackSummary? _resolveHistoryEntry(WzListeningHistoryEntry entry) {
    for (final track in _libraryTracks) {
      if (track.trackId == entry.trackId) return track;
    }

    final restoredDeviceTrack = _findDeviceTrack(entry.trackId);
    return restoredDeviceTrack == null ? null : wzCatalogSummaryFromDeviceTrack(restoredDeviceTrack);
  }
"""
new_resolve = """  CatalogTrackSummary? _resolveHistoryEntry(WzListeningHistoryEntry entry) {
    final restoredDeviceTrack = _findDeviceTrack(entry.trackId);
    return wzResolveHistoryEntry(
      libraryTracks: _libraryTracks,
      entry: entry,
      fallbackTrack: restoredDeviceTrack == null ? null : wzCatalogSummaryFromDeviceTrack(restoredDeviceTrack),
    );
  }
"""
if text.count(old_resolve) != 1:
    raise SystemExit(f'expected one History resolver, found {text.count(old_resolve)}')
text = text.replace(old_resolve, new_resolve, 1)

old_snapshot = """  WzListeningHistoryEntry _historySnapshotForManifest(
    CatalogTrackManifest manifest, {
    required WzListeningHistorySource source,
    required String? playableUrl,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WzListeningHistoryEntry(
      trackId: manifest.trackId,
      title: manifest.title,
      subtitle: manifest.subtitle,
      artworkUrl: manifest.artworkUrl,
      source: source,
      primaryUrl: playableUrl ?? manifest.streamUrl,
      qualityLabel: manifest.qualityLabel,
      codec: manifest.codec,
      license: source == WzListeningHistorySource.device ? LicenseMetadata.userDevice : manifest.license,
      lastPlayedAtMs: now,
      firstPlayedAtMs: now,
      playCount: 1,
      lastPositionMs: 0,
      durationMs: manifest.durationMs,
    );
  }
"""
new_snapshot = """  WzListeningHistoryEntry _historySnapshotForManifest(
    CatalogTrackManifest manifest, {
    required WzListeningHistorySource source,
    required String? playableUrl,
  }) =>
      wzHistorySnapshotForManifest(
        manifest,
        source: source,
        playableUrl: playableUrl,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
"""
if text.count(old_snapshot) != 1:
    raise SystemExit(f'expected one History snapshot builder, found {text.count(old_snapshot)}')
text = text.replace(old_snapshot, new_snapshot, 1)


def remove_braced_declaration(source: str, prefix: str) -> str:
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
    'String _historySourceLabel(',
    'String _friendlyHistoryTime(',
    'String _historyPositionLabel(',
]:
    text = remove_braced_declaration(text, prefix)

text = text.replace('_historySourceLabel', 'wzHistorySourceLabel')
text = text.replace('_friendlyHistoryTime', 'friendlyWzHistoryTime')
text = text.replace('_historyPositionLabel', 'wzHistoryPositionLabel')

path.write_text(text)
