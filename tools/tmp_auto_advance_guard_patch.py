from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


app_path = Path("apps/flutter/wavezero_app/lib/app/wavezero_app.dart")
app = app_path.read_text()
old = """    if (trigger.clearLastTrackGuard) _lastAutoAdvanceTrackId = null;
    if (!trigger.shouldAdvance) return;
    _lastAutoAdvanceTrackId = trigger.trackId;

    if (_repeatMode == WzRepeatMode.one) {
      setState(() => _queueStatus = 'Repeat one: replaying current track.');
      await _seekTo(0);
      await widget.playbackBridge.play();
      return;
    }
    if (_shuffleEnabled &&
        await _playRandomQueueTrack(
          autoStart: true,
          source: QueueAdvanceSource.auto,
        ))
      return;
    if (_canNext) {
      await _playNext(
        autoStart: true,
        source: QueueAdvanceSource.auto,
        allowShuffle: false,
      );
      return;
    }
    if (_repeatMode == WzRepeatMode.all && _queue.isNotEmpty)
      await _playQueueTrack(
        _queue.first,
        autoStart: true,
        source: QueueAdvanceSource.auto,
      );
"""
new = """    if (trigger.clearLastTrackGuard) _lastAutoAdvanceTrackId = null;
    if (!trigger.shouldAdvance) return;

    if (_repeatMode == WzRepeatMode.one) {
      _lastAutoAdvanceTrackId = trigger.trackId;
      setState(() => _queueStatus = 'Repeat one: replaying current track.');
      await _seekTo(0);
      await widget.playbackBridge.play();
      return;
    }
    if (_shuffleEnabled) {
      final shuffled = await _playRandomQueueTrack(
        autoStart: true,
        source: QueueAdvanceSource.auto,
      );
      if (shuffled) {
        _lastAutoAdvanceTrackId = trigger.trackId;
        return;
      }
    }
    if (_canNext) {
      _lastAutoAdvanceTrackId = trigger.trackId;
      await _playNext(
        autoStart: true,
        source: QueueAdvanceSource.auto,
        allowShuffle: false,
      );
      return;
    }
    if (_repeatMode == WzRepeatMode.all && _queue.isNotEmpty) {
      _lastAutoAdvanceTrackId = trigger.trackId;
      await _playQueueTrack(
        _queue.first,
        autoStart: true,
        source: QueueAdvanceSource.auto,
      );
    }
"""
app = replace_once(app, old, new, "auto-advance guard ownership")
app_path.write_text(app)

test_path = Path(
    "apps/flutter/wavezero_app/test/features/playback/end_of_track_reliability_contract_test.dart"
)
test = test_path.read_text()
marker = """  test('direct track taps play immediately instead of only selecting', () {
"""
addition = """  test('auto advance only consumes its dedupe guard when a route can run', () {
    final app = File('lib/app/wavezero_app.dart').readAsStringSync();
    final start = app.indexOf('Future<void> _maybeAutoAdvance');
    final end = app.indexOf('void _recordSmartDownloadSkip', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final autoAdvance = app.substring(start, end);

    final triggerGate = autoAdvance.indexOf('if (!trigger.shouldAdvance) return;');
    final repeatBranch = autoAdvance.indexOf('if (_repeatMode == WzRepeatMode.one)');
    final firstGuardWrite = autoAdvance.indexOf(
      '_lastAutoAdvanceTrackId = trigger.trackId;',
      triggerGate,
    );
    expect(repeatBranch, greaterThan(triggerGate));
    expect(firstGuardWrite, greaterThan(repeatBranch));
    expect(autoAdvance, contains('if (shuffled) {'));
    expect(autoAdvance, contains('if (_canNext) {'));
  });

"""
test = replace_once(test, marker, addition + marker, "auto-advance guard contract")
test_path.write_text(test)

Path(".github/workflows/tmp-auto-advance-guard-patch.yml").unlink(missing_ok=True)
Path("tools/tmp_auto_advance_guard_patch.py").unlink(missing_ok=True)
