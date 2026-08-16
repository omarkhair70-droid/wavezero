import 'listening_history_service.dart';

WzListeningHistoryEntry? wzContinueListeningEntry(
  List<WzListeningHistoryEntry> entries,
) =>
    entries.isEmpty ? null : entries.first;

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
