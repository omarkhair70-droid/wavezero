import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/playback/auto_advance_trigger.dart';
import 'package:wavezero_app/features/playback/player_operation_state.dart';

void main() {
  WzAutoAdvanceTriggerDecision decide({
    bool enabled = true,
    PlayerOperation operation = PlayerOperation.idle,
    int currentPositionMs = 0,
    int? metricsDurationMs = 10000,
    int? manifestDurationMs,
    String? lastEvent,
    String? currentTrackId = 'track-1',
    String? lastAutoAdvanceTrackId,
  }) {
    return evaluateWzAutoAdvanceTrigger(
      enabled: enabled,
      operation: operation,
      currentPositionMs: currentPositionMs,
      metricsDurationMs: metricsDurationMs,
      manifestDurationMs: manifestDurationMs,
      lastEvent: lastEvent,
      currentTrackId: currentTrackId,
      lastAutoAdvanceTrackId: lastAutoAdvanceTrackId,
    );
  }

  test('does not trigger while auto advance is disabled or another operation is active', () {
    final disabled = decide(enabled: false, currentPositionMs: 9500);
    final busy = decide(operation: PlayerOperation.seeking, currentPositionMs: 9500);

    expect(disabled.shouldAdvance, isFalse);
    expect(disabled.clearLastTrackGuard, isFalse);
    expect(busy.shouldAdvance, isFalse);
    expect(busy.clearLastTrackGuard, isFalse);
  });

  test('requires a valid duration and falls back to manifest duration', () {
    final missing = decide(metricsDurationMs: null, manifestDurationMs: null, currentPositionMs: 9500);
    final invalid = decide(metricsDurationMs: 0, currentPositionMs: 9500);
    final fallback = decide(metricsDurationMs: null, manifestDurationMs: 10000, currentPositionMs: 9000);

    expect(missing.shouldAdvance, isFalse);
    expect(invalid.shouldAdvance, isFalse);
    expect(fallback.shouldAdvance, isTrue);
    expect(fallback.trackId, 'track-1');
  });

  test('triggers at the existing near-end threshold', () {
    final atThreshold = decide(currentPositionMs: 8800);
    final beforeThreshold = decide(currentPositionMs: 8799);

    expect(atThreshold.shouldAdvance, isTrue);
    expect(beforeThreshold.shouldAdvance, isFalse);
  });

  test('ended events trigger even when position is not near the duration', () {
    expect(decide(currentPositionMs: 0, lastEvent: 'ended').shouldAdvance, isTrue);
    expect(decide(currentPositionMs: 0, lastEvent: 'playback_ended').shouldAdvance, isTrue);
  });

  test('clears the dedupe guard only after playback moves well away from the end', () {
    final clear = decide(currentPositionMs: 7599, lastAutoAdvanceTrackId: 'track-1');
    final keep = decide(currentPositionMs: 7600, lastAutoAdvanceTrackId: 'track-1');

    expect(clear.shouldAdvance, isFalse);
    expect(clear.clearLastTrackGuard, isTrue);
    expect(keep.shouldAdvance, isFalse);
    expect(keep.clearLastTrackGuard, isFalse);
  });

  test('does not retrigger the same track or advance without a current track id', () {
    final duplicate = decide(currentPositionMs: 9500, lastAutoAdvanceTrackId: 'track-1');
    final missingId = decide(currentPositionMs: 9500, currentTrackId: null);

    expect(duplicate.shouldAdvance, isFalse);
    expect(missingId.shouldAdvance, isFalse);
  });
}
