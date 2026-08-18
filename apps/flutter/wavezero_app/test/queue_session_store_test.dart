import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/features/queue/queue_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('session persistence key remains stable', () {
    expect(QueueSessionStore.sessionKey, 'wavezero_queue_session_v1');
  });

  test('snapshot encode and decode round-trip all fields', () {
    const snapshot = QueueSessionSnapshot(
      queueTrackIds: ['a', 'b', 'c'],
      currentTrackId: 'b',
      selectedTrackId: 'c',
      autoAdvanceEnabled: false,
    );

    final decoded = QueueSessionSnapshot.decode(snapshot.encode());

    expect(decoded, isNotNull);
    expect(decoded!.queueTrackIds, const ['a', 'b', 'c']);
    expect(decoded.currentTrackId, 'b');
    expect(decoded.selectedTrackId, 'c');
    expect(decoded.autoAdvanceEnabled, isFalse);
  });

  test('decode rejects malformed and non-map JSON', () {
    expect(QueueSessionSnapshot.decode('{bad json'), isNull);
    expect(QueueSessionSnapshot.decode('["a", "b"]'), isNull);
  });

  test('decode filters queue ids and defaults invalid optional field types', () {
    final decoded = QueueSessionSnapshot.decode(
      '{"queueTrackIds":["a",2,null,"b"],"currentTrackId":3,"selectedTrackId":false,"autoAdvanceEnabled":"yes"}',
    );

    expect(decoded, isNotNull);
    expect(decoded!.queueTrackIds, const ['a', 'b']);
    expect(decoded.currentTrackId, isNull);
    expect(decoded.selectedTrackId, isNull);
    expect(decoded.autoAdvanceEnabled, isTrue);
  });

  test('store saves and restores snapshots', () async {
    final store = QueueSessionStore();
    const snapshot = QueueSessionSnapshot(
      queueTrackIds: ['one', 'two'],
      currentTrackId: 'one',
      selectedTrackId: 'two',
      autoAdvanceEnabled: true,
    );

    await store.save(snapshot);
    final restored = await store.load();

    expect(restored, isNotNull);
    expect(restored!.queueTrackIds, snapshot.queueTrackIds);
    expect(restored.currentTrackId, snapshot.currentTrackId);
    expect(restored.selectedTrackId, snapshot.selectedTrackId);
    expect(restored.autoAdvanceEnabled, snapshot.autoAdvanceEnabled);
  });

  test('load returns null for missing or blank state and clear removes saved state', () async {
    final store = QueueSessionStore();

    expect(await store.load(), isNull);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(QueueSessionStore.sessionKey, '   ');
    expect(await store.load(), isNull);

    await store.save(const QueueSessionSnapshot(queueTrackIds: ['a']));
    expect(await store.load(), isNotNull);
    await store.clear();
    expect(await store.load(), isNull);
  });

  test('unawaited-style writes preserve call order and latest snapshot wins', () async {
    final store = QueueSessionStore();

    final first = store.save(
      const QueueSessionSnapshot(
        queueTrackIds: ['a', 'b'],
        currentTrackId: 'a',
      ),
    );
    final clear = store.clear();
    final latest = store.save(
      const QueueSessionSnapshot(
        queueTrackIds: ['c', 'd'],
        currentTrackId: 'd',
        selectedTrackId: 'd',
      ),
    );

    await Future.wait([first, clear, latest]);
    final restored = await store.load();

    expect(restored, isNotNull);
    expect(restored!.queueTrackIds, const ['c', 'd']);
    expect(restored.currentTrackId, 'd');
    expect(restored.selectedTrackId, 'd');
  });
}
