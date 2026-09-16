import 'player_operation_state.dart';

class WzAutoAdvanceTriggerDecision {
  const WzAutoAdvanceTriggerDecision({
    required this.shouldAdvance,
    required this.clearLastTrackGuard,
    this.trackId,
  });

  final bool shouldAdvance;
  final bool clearLastTrackGuard;
  final String? trackId;
}

WzAutoAdvanceTriggerDecision evaluateWzAutoAdvanceTrigger({
  required bool enabled,
  required PlayerOperation operation,
  required int currentPositionMs,
  required int? metricsDurationMs,
  required int? manifestDurationMs,
  required String? lastEvent,
  required String? currentTrackId,
  required String? lastAutoAdvanceTrackId,
  int thresholdMs = 1200,
}) {
  if (!enabled || operation != PlayerOperation.idle) {
    return const WzAutoAdvanceTriggerDecision(
      shouldAdvance: false,
      clearLastTrackGuard: false,
    );
  }

  final ended = lastEvent == 'ended' || lastEvent == 'playback_ended';
  final durationMs = metricsDurationMs ?? manifestDurationMs;

  // A real native end event is authoritative even when the source does not
  // expose a usable duration. For unknown-duration tracks, clear the initial
  // dedupe guard once playback has made meaningful forward progress so the
  // eventual end event can advance exactly once.
  if (durationMs == null || durationMs <= 0) {
    if (!ended) {
      return WzAutoAdvanceTriggerDecision(
        shouldAdvance: false,
        clearLastTrackGuard: currentPositionMs > thresholdMs,
      );
    }
  } else {
    final remainingMs = durationMs - currentPositionMs;
    final nearEnd = currentPositionMs > 0 && remainingMs <= thresholdMs;
    if (!nearEnd && !ended) {
      return WzAutoAdvanceTriggerDecision(
        shouldAdvance: false,
        clearLastTrackGuard:
            currentPositionMs < durationMs - (thresholdMs * 2),
      );
    }
  }

  if (currentTrackId == null || currentTrackId == lastAutoAdvanceTrackId) {
    return const WzAutoAdvanceTriggerDecision(
      shouldAdvance: false,
      clearLastTrackGuard: false,
    );
  }

  return WzAutoAdvanceTriggerDecision(
    shouldAdvance: true,
    clearLastTrackGuard: false,
    trackId: currentTrackId,
  );
}
