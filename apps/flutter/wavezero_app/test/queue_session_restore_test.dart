import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/queue/queue_session_restore.dart';
import 'package:wavezero_app/features/queue/queue_session_store.dart';

void main() {
  CatalogTrackSummary track(String id) => CatalogTrackSummary(trackId: id, title: id);

  final catalog = [track('a'), track('b'), track('c')];

  test('sanitize keeps only queue ids that still exist in the catalog', () {
    final restored = sanitizeWzQueueSessionSnapshot(
      catalogTracks: catalog,
      snapshot: const QueueSessionSnapshot(
        queueTrackIds: ['a', 'missing', 'c'],
        currentTrackId: 'c',
        selectedTrackId: 'a',
        autoAdvanceEnabled: false,
      ),
    );

    expect(restored, isNotNull);
    expect(restored!.queueTrackIds, ['a', 'c']);
    expect(restored.currentTrackId, 'c');
    expect(restored.selectedTrackId, 'a');
    expect(restored.autoAdvanceEnabled, isFalse);
  });

  test('sanitize clears invalid current and selected ids', () {
    final restored = sanitizeWzQueueSessionSnapshot(
      catalogTracks: catalog,
      snapshot: const QueueSessionSnapshot(
        queueTrackIds: ['b'],
        currentTrackId: 'missing-current',
        selectedTrackId: 'missing-selected',
      ),
    );

    expect(restored, isNotNull);
    expect(restored!.queueTrackIds, ['b']);
    expect(restored.currentTrackId, isNull);
    expect(restored.selectedTrackId, isNull);
  });

  test('sanitize preserves a valid current id even when saved queue ids are empty', () {
    final restored = sanitizeWzQueueSessionSnapshot(
      catalogTracks: catalog,
      snapshot: const QueueSessionSnapshot(
        queueTrackIds: [],
        currentTrackId: 'b',
      ),
    );

    expect(restored, isNotNull);
    expect(restored!.queueTrackIds, isEmpty);
    expect(restored.currentTrackId, 'b');
  });

  test('sanitize preserves old non-null decision before invalid ids are filtered', () {
    final restored = sanitizeWzQueueSessionSnapshot(
      catalogTracks: catalog,
      snapshot: const QueueSessionSnapshot(
        queueTrackIds: [],
        currentTrackId: 'missing',
      ),
    );

    expect(restored, isNotNull);
    expect(restored!.queueTrackIds, isEmpty);
    expect(restored.currentTrackId, isNull);
    expect(restored.selectedTrackId, isNull);
  });

  test('sanitize returns null only when saved queue and both saved ids are empty', () {
    final restored = sanitizeWzQueueSessionSnapshot(
      catalogTracks: catalog,
      snapshot: const QueueSessionSnapshot(queueTrackIds: []),
    );

    expect(restored, isNull);
  });

  test('resolve queue follows saved id order and ignores unresolved ids', () {
    final resolved = resolveWzQueueFromSnapshot(
      catalogTracks: catalog,
      snapshot: const QueueSessionSnapshot(queueTrackIds: ['c', 'missing', 'a']),
    );

    expect(resolved.map((item) => item.trackId), ['c', 'a']);
  });
}
