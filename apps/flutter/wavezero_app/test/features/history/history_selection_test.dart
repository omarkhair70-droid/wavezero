import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/history/history_selection.dart';
import 'package:wavezero_app/features/history/listening_history_service.dart';

void main() {
  WzListeningHistoryEntry entry(
    String id, {
    required int playCount,
    required int lastPlayedAtMs,
    int lastPositionMs = 0,
    int? durationMs,
  }) =>
      WzListeningHistoryEntry(
        trackId: id,
        title: id,
        subtitle: 'Artist',
        source: WzListeningHistorySource.api,
        lastPlayedAtMs: lastPlayedAtMs,
        firstPlayedAtMs: 1,
        playCount: playCount,
        lastPositionMs: lastPositionMs,
        durationMs: durationMs,
      );

  test('empty history has no continue or most-played entry', () {
    expect(wzContinueListeningEntry(const []), isNull);
    expect(wzMostPlayedHistoryEntry(const []), isNull);
  });

  test('continue listening skips tracks that barely started', () {
    final barelyStarted = entry(
      'first',
      playCount: 1,
      lastPlayedAtMs: 30,
      lastPositionMs: 3000,
      durationMs: 180000,
    );
    final resumable = entry(
      'second',
      playCount: 1,
      lastPlayedAtMs: 20,
      lastPositionMs: 45000,
      durationMs: 180000,
    );
    expect(wzContinueListeningEntry([barelyStarted, resumable]), same(resumable));
  });

  test('continue listening skips tracks already at the end', () {
    final completed = entry(
      'completed',
      playCount: 1,
      lastPlayedAtMs: 30,
      lastPositionMs: 176000,
      durationMs: 180000,
    );
    final resumable = entry(
      'resumable',
      playCount: 1,
      lastPlayedAtMs: 20,
      lastPositionMs: 70000,
      durationMs: 180000,
    );
    expect(wzContinueListeningEntry([completed, resumable]), same(resumable));
  });

  test('continue listening returns null when nothing is meaningfully resumable', () {
    final fresh = entry('fresh', playCount: 1, lastPlayedAtMs: 10);
    expect(wzContinueListeningEntry([fresh]), isNull);
  });

  test('most played prefers larger play count', () {
    final low = entry('low', playCount: 2, lastPlayedAtMs: 100);
    final high = entry('high', playCount: 4, lastPlayedAtMs: 10);
    expect(wzMostPlayedHistoryEntry([low, high]), same(high));
  });

  test('most played breaks ties by most recent last-played time', () {
    final older = entry('older', playCount: 3, lastPlayedAtMs: 20);
    final newer = entry('newer', playCount: 3, lastPlayedAtMs: 30);
    expect(wzMostPlayedHistoryEntry([older, newer]), same(newer));
  });
}
