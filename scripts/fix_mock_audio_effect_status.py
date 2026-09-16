from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/playback/playback_bridge.dart')
text = path.read_text()
anchor = '''  @override
  Future<PlaybackMetrics> metricsSnapshot() async => _metrics;
}
'''
method = '''  @override
  Future<AudioEffectApplyResult> audioEffectStatus() async {
    return AudioEffectApplyResult.off('Mock playback has no native DSP session.');
  }

'''
if method not in text:
    if anchor not in text:
        raise SystemExit('mock metrics anchor not found')
    text = text.replace(anchor, method + anchor, 1)
path.write_text(text)
