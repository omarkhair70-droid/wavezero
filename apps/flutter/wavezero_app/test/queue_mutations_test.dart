import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/queue/queue_mutations.dart';

void main() {
  CatalogTrackSummary track(String id) => CatalogTrackSummary(trackId: id, title: id);

  test('add appends a missing track and initializes the current queue id', () {
    final a = track('a');
    final b = track('b');

    final result = addWzQueueTrack(
      queue: [a],
      track: b,
      currentTrackId: null,
    );

    expect(result.queue.map((item) => item.trackId), ['a', 'b']);
    expect(result.currentTrackId, 'b');
    expect(result.alreadyPresent, isFalse);
  });

  test('add preserves the existing queue and current id for duplicates', () {
    final queue = [track('a'), track('b')];

    final result = addWzQueueTrack(
      queue: queue,
      track: track('b'),
      currentTrackId: 'a',
    );

    expect(identical(result.queue, queue), isTrue);
    expect(result.currentTrackId, 'a');
    expect(result.alreadyPresent, isTrue);
  });

  test('move reorders by delta and keeps boundary or missing moves as no-ops', () {
    final queue = [track('a'), track('b'), track('c')];

    final moved = moveWzQueueTrack(queue: queue, trackId: 'b', delta: -1);
    final boundary = moveWzQueueTrack(queue: queue, trackId: 'a', delta: -1);
    final missing = moveWzQueueTrack(queue: queue, trackId: 'missing', delta: 1);

    expect(moved.queue.map((item) => item.trackId), ['b', 'a', 'c']);
    expect(moved.changed, isTrue);
    expect(identical(boundary.queue, queue), isTrue);
    expect(boundary.changed, isFalse);
    expect(identical(missing.queue, queue), isTrue);
    expect(missing.changed, isFalse);
  });

  test('play next moves a later track directly after the current queue track', () {
    final queue = [track('a'), track('b'), track('c'), track('d')];

    final result = moveWzQueueTrackNext(
      queue: queue,
      trackId: 'd',
      resolvedCurrentIndex: 1,
      currentTrackId: 'b',
    );

    expect(result.queue.map((item) => item.trackId), ['a', 'b', 'd', 'c']);
    expect(result.changed, isTrue);
  });

  test('play next preserves adjusted current position when moving an earlier track', () {
    final queue = [track('a'), track('b'), track('c'), track('d')];

    final result = moveWzQueueTrackNext(
      queue: queue,
      trackId: 'a',
      resolvedCurrentIndex: 1,
      currentTrackId: 'b',
    );

    expect(result.queue.map((item) => item.trackId), ['b', 'a', 'c', 'd']);
    expect(result.changed, isTrue);
  });

  test('play next remains a no-op without a resolved current track or for current item', () {
    final queue = [track('a'), track('b'), track('c')];

    final unresolved = moveWzQueueTrackNext(
      queue: queue,
      trackId: 'c',
      resolvedCurrentIndex: -1,
      currentTrackId: null,
    );
    final current = moveWzQueueTrackNext(
      queue: queue,
      trackId: 'b',
      resolvedCurrentIndex: 1,
      currentTrackId: 'b',
    );

    expect(unresolved.changed, isFalse);
    expect(current.changed, isFalse);
    expect(identical(unresolved.queue, queue), isTrue);
    expect(identical(current.queue, queue), isTrue);
  });

  test('removing the current track advances to the item at its old index', () {
    final queue = [track('a'), track('b'), track('c')];

    final result = removeWzQueueTrack(
      queue: queue,
      trackId: 'b',
      currentTrackId: 'b',
    );

    expect(result.queue.map((item) => item.trackId), ['a', 'c']);
    expect(result.wasCurrent, isTrue);
    expect(result.currentTrackId, 'c');
    expect(result.currentTrack?.trackId, 'c');
  });

  test('removing the last current track falls back to the new last item', () {
    final queue = [track('a'), track('b'), track('c')];

    final result = removeWzQueueTrack(
      queue: queue,
      trackId: 'c',
      currentTrackId: 'c',
    );

    expect(result.queue.map((item) => item.trackId), ['a', 'b']);
    expect(result.currentTrackId, 'b');
    expect(result.currentTrack?.trackId, 'b');
  });

  test('removing a non-current track preserves the current queue id', () {
    final queue = [track('a'), track('b'), track('c')];

    final result = removeWzQueueTrack(
      queue: queue,
      trackId: 'a',
      currentTrackId: 'b',
    );

    expect(result.queue.map((item) => item.trackId), ['b', 'c']);
    expect(result.wasCurrent, isFalse);
    expect(result.currentTrackId, 'b');
  });

  test('removing the only queue track clears the current queue id', () {
    final result = removeWzQueueTrack(
      queue: [track('a')],
      trackId: 'a',
      currentTrackId: 'a',
    );

    expect(result.queue, isEmpty);
    expect(result.currentTrackId, isNull);
    expect(result.currentTrack, isNull);
  });
}
