import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/history/history_selection.dart';
import 'package:wavezero_app/features/history/listening_history_service.dart';

void main() {
  WzListeningHistoryEntry entry(
    String id, {
    required int playCount,
    required int lastPlayedAtMs,
  }) =>
      WzListeningHistoryEntry(
        trackId: id,
        title: id,
        subtitle: 'Artist',
        source: WzListeningHistorySource.api,
        lastPlayedAtMs: lastPlayedAtMs,
        firstPlayedAtMs: 1,
        playCount: playCount,
      );

  test('empty history has no continue or most-played entry', () {
    expect(wzContinueListeningEntry(const []), isNull);
    expect(wzMostPlayedHistoryEntry(const []), isNull);
  });

  test('continue listening keeps the first persisted entry', () {
    final first = entry('first', playCount: 1, lastPlayedAtMs: 20);
    final second = entry('second', playCount: 5, lastPlayedAtMs: 30);
    expect(wzContinueListeningEntry([first, second]), same(first));
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
