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

  final durationMs = metricsDurationMs ?? manifestDurationMs;
  if (durationMs == null || durationMs <= 0) {
    return const WzAutoAdvanceTriggerDecision(
      shouldAdvance: false,
      clearLastTrackGuard: false,
    );
  }

  final remainingMs = durationMs - currentPositionMs;
  final nearEnd = currentPositionMs > 0 && remainingMs <= thresholdMs;
  final ended = lastEvent == 'ended' || lastEvent == 'playback_ended';
  if (!nearEnd && !ended) {
    return WzAutoAdvanceTriggerDecision(
      shouldAdvance: false,
      clearLastTrackGuard: currentPositionMs < durationMs - (thresholdMs * 2),
    );
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
