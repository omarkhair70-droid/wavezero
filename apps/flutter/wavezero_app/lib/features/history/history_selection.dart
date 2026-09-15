import 'listening_history_service.dart';

const int _minimumResumePositionMs = 8000;
const int _completedTailThresholdMs = 12000;

WzListeningHistoryEntry? wzContinueListeningEntry(
  List<WzListeningHistoryEntry> entries,
) {
  for (final entry in entries) {
    if (entry.lastPositionMs < _minimumResumePositionMs) continue;
    final durationMs = entry.durationMs;
    if (durationMs != null && durationMs > 0) {
      final remainingMs = durationMs - entry.lastPositionMs;
      if (remainingMs <= _completedTailThresholdMs) continue;
    }
    return entry;
  }
  return null;
}

WzListeningHistoryEntry? wzMostPlayedHistoryEntry(
  List<WzListeningHistoryEntry> entries,
) {
  if (entries.isEmpty) return null;
  final ranked = [...entries]
    ..sort((a, b) {
      final byPlays = b.playCount.compareTo(a.playCount);
      return byPlays == 0
          ? b.lastPlayedAtMs.compareTo(a.lastPlayedAtMs)
          : byPlays;
    });
  return ranked.first;
}
