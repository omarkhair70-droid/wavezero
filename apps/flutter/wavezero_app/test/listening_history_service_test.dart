import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/features/history/listening_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  WzListeningHistoryEntry entry(String id) => WzListeningHistoryEntry(
    trackId: id,
    title: 'Track $id',
    subtitle: 'Artist $id',
    source: WzListeningHistorySource.api,
    lastPlayedAtMs: 1,
    firstPlayedAtMs: 1,
    playCount: 0,
    durationMs: 1000,
  );

  test('concurrent recordPlay calls preserve both tracks', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = ListeningHistoryService(prefs: prefs);

    final first = service.recordPlay(entry('a'));
    final second = service.recordPlay(entry('b'));
    await Future.wait([first, second]);

    final history = await service.load();
    expect(history.map((item) => item.trackId).toSet(), {'a', 'b'});
  });

  test('concurrent plays of the same track increment instead of losing a play', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = ListeningHistoryService(prefs: prefs);

    final first = service.recordPlay(entry('a'));
    final second = service.recordPlay(entry('a'));
    await Future.wait([first, second]);

    final history = await service.load();
    expect(history, hasLength(1));
    expect(history.single.playCount, 2);
  });

  test('position update queued behind recordPlay keeps the recorded entry', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = ListeningHistoryService(prefs: prefs);

    final recorded = service.recordPlay(entry('a'));
    final positioned = service.updatePosition(
      'a',
      positionMs: 420,
      durationMs: 1000,
    );
    await Future.wait([recorded, positioned]);

    final history = await service.load();
    expect(history, hasLength(1));
    expect(history.single.trackId, 'a');
    expect(history.single.lastPositionMs, 420);
  });

  test('clear participates in mutation ordering', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = ListeningHistoryService(prefs: prefs);

    final first = service.recordPlay(entry('a'));
    final clear = service.clear();
    final latest = service.recordPlay(entry('b'));
    await Future.wait([first, clear, latest]);

    final history = await service.load();
    expect(history.map((item) => item.trackId).toList(), ['b']);
  });
}
