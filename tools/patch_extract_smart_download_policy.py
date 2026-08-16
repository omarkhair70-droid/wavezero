from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../features/downloads/downloads_presentation.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one Downloads import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/downloads/smart_download_policy.dart';\n", 1)


def remove_braced_declaration(source: str, prefix: str) -> str:
    pos = source.find(prefix)
    if pos < 0:
        raise SystemExit(f'missing declaration {prefix}')
    if source.find(prefix, pos + 1) >= 0:
        raise SystemExit(f'duplicate declaration {prefix}')
    start = source.rfind('\n', 0, pos) + 1
    brace = source.find('{', pos)
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
                    return source[:start] + source[end:]
        i += 1
    raise SystemExit(f'unclosed declaration {prefix}')

text = remove_braced_declaration(
    text,
    '  Future<bool> _canAutoCacheTrack({required String trackId, required String? url}) async {',
)

method_prefix = '  Future<void> _autoCacheTrack({' 
method_pos = text.find(method_prefix)
if method_pos < 0:
    raise SystemExit('missing auto cache method')
body_start = text.find('{', method_pos)
gate_start = text.find('    // Gatekeeper checks: do not early-return before updating diagnostics.\n', body_start)
add_marker = '    _autoCacheInFlight.add(trackId);\n'
gate_end = text.find(add_marker, gate_start)
if gate_start < 0 or gate_end < 0:
    raise SystemExit('missing Smart Downloads gate block')

replacement = """    // Gatekeeper checks: preserve the existing reason precedence before I/O.
    final preflight = evaluateWzSmartDownloadPreflight(
      enabled: _smartDownloadsEnabled,
      trackId: trackId,
      url: url,
      isDeviceTrack: _isDeviceTrackId(trackId),
      isDeviceUrl: _isDeviceUrl(url),
    );
    if (!preflight.allowed) {
      _recordSmartDownloadSkip(preflight.reason!);
      return;
    }

    await _cacheService.ensureInitialized();
    final cacheState = evaluateWzSmartDownloadCacheState(
      status: _cacheService.statusForTrack(trackId),
      alreadyInFlight: _autoCacheInFlight.contains(trackId),
    );
    if (!cacheState.allowed) {
      _recordSmartDownloadSkip(cacheState.reason!);
      return;
    }

    final cachedLibrary = await _cacheService.cachedLibrary();
    final capacity = evaluateWzSmartDownloadCapacity(
      cachedTrackCount: cachedLibrary.length,
      maxCachedTracks: _maxSmartDownloadCachedTracks,
    );
    if (!capacity.allowed) {
      _recordSmartDownloadSkip(capacity.reason!);
      return;
    }
"""
text = text[:gate_start] + replacement + text[gate_end:]

helper = """  void _recordSmartDownloadSkip(String reason) {
    _lastSmartDownloadReason = reason;
    if (mounted) setState(() => _smartDownloadSkippedCount += 1);
  }

"""
method_pos = text.find(method_prefix)
if method_pos < 0:
    raise SystemExit('auto cache method vanished')
text = text[:method_pos] + helper + text[method_pos:]

path.write_text(text)
