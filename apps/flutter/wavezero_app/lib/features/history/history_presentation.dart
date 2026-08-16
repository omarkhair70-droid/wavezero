import 'listening_history_service.dart';

String wzHistorySourceLabel(WzListeningHistorySource source) => switch (source) {
      WzListeningHistorySource.api => 'Catalog',
      WzListeningHistorySource.device => 'Device music',
      WzListeningHistorySource.cached => 'Downloaded',
      WzListeningHistorySource.unknown => 'Unknown',
    };

String friendlyWzHistoryTime(
  int timestampMs, {
  required DateTime now,
}) {
  final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final elapsed = now.difference(timestamp);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return '${timestamp.month}/${timestamp.day}';
}

String wzHistoryPositionLabel(WzListeningHistoryEntry entry) {
  if (entry.lastPositionMs <= 0) {
    return entry.durationMs == null ? 'Ready to play' : 'Start from beginning';
  }
  final total = entry.durationMs;
  final position = _formatWzDuration(entry.lastPositionMs);
  if (total == null || total <= 0) return 'Resume at $position';
  return 'Resume at $position of ${_formatWzDuration(total)}';
}

String _formatWzDuration(int ms) {
  final totalSeconds = (ms / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
