import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/queue/queue_position.dart';

void main() {
  CatalogTrackSummary track(String id) => CatalogTrackSummary(trackId: id, title: id);

  final queue = [track('a'), track('b'), track('c')];

  WzQueuePosition resolve({
    String? currentTrackId = 'b',
    String? selectedTrackId,
    bool shuffleEnabled = false,
    List<CatalogTrackSummary>? tracks,
  }) {
    return resolveWzQueuePosition(
      queue: tracks ?? queue,
      currentTrackId: currentTrackId,
      selectedTrackId: selectedTrackId,
      shuffleEnabled: shuffleEnabled,
    );
  }

  test('mismatched queue and selected ids mark a handoff pending', () {
    final position = resolve(currentTrackId: 'b', selectedTrackId: 'a');

    expect(position.transitionPending, isTrue);
    expect(position.index, -1);
    expect(position.currentTrack?.trackId, 'a');
    expect(position.upNextTrack, isNull);
    expect(position.canPrevious, isFalse);
    expect(position.canNext, isFalse);
    expect(position.canShuffleNext, isFalse);
    expect(position.canPlayNext, isFalse);
  });

  test('current track remains authoritative when selected track is outside queue', () {
    final position = resolve(currentTrackId: 'b', selectedTrackId: 'outside');

    expect(position.transitionPending, isFalse);
    expect(position.index, 1);
    expect(position.currentTrack?.trackId, 'b');
    expect(position.upNextTrack?.trackId, 'c');
    expect(position.canPrevious, isTrue);
    expect(position.canNext, isTrue);
  });

  test('selected track id is used when there is no current queue track id', () {
    final position = resolve(currentTrackId: null, selectedTrackId: 'a');

    expect(position.transitionPending, isFalse);
    expect(position.index, 0);
    expect(position.currentTrack?.trackId, 'a');
    expect(position.upNextTrack?.trackId, 'b');
    expect(position.canPrevious, isFalse);
    expect(position.canNext, isTrue);
  });

  test('matching current and selected ids resolve normal controls', () {
    final position = resolve(currentTrackId: 'b', selectedTrackId: 'b');

    expect(position.transitionPending, isFalse);
    expect(position.index, 1);
    expect(position.currentTrack?.trackId, 'b');
    expect(position.canPrevious, isTrue);
    expect(position.canNext, isTrue);
  });

  test('missing track resolves to the existing unavailable queue state', () {
    final position = resolve(currentTrackId: 'missing');

    expect(position.index, -1);
    expect(position.currentTrack, isNull);
    expect(position.upNextTrack, isNull);
    expect(position.canPrevious, isFalse);
    expect(position.canNext, isFalse);
    expect(position.canShuffleNext, isFalse);
    expect(position.canPlayNext, isFalse);
  });

  test('last queue item has previous but no sequential next', () {
    final position = resolve(currentTrackId: 'c');

    expect(position.index, 2);
    expect(position.currentTrack?.trackId, 'c');
    expect(position.upNextTrack, isNull);
    expect(position.canPrevious, isTrue);
    expect(position.canNext, isFalse);
  });

  test('shuffle next remains available at the last item when queue has multiple tracks', () {
    final position = resolve(currentTrackId: 'c', shuffleEnabled: true);

    expect(position.canNext, isFalse);
    expect(position.canShuffleNext, isTrue);
    expect(position.canPlayNext, isTrue);
  });

  test('shuffle next requires a resolved position and more than one queue track', () {
    final single = resolve(
      currentTrackId: 'a',
      shuffleEnabled: true,
      tracks: [track('a')],
    );
    final missing = resolve(currentTrackId: 'missing', shuffleEnabled: true);

    expect(single.canShuffleNext, isFalse);
    expect(single.canPlayNext, isFalse);
    expect(missing.canShuffleNext, isFalse);
  });
}
