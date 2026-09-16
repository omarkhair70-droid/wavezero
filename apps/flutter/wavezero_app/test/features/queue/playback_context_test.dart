import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/queue/playback_context.dart';

void main() {
  CatalogTrackSummary track(String id) => CatalogTrackSummary(
    trackId: id,
    title: id,
  );

  test('prefers the visible Library order when the selected track is present', () {
    final result = wzPlaybackContextForTrack(
      preferredTracks: [track('a'), track('b'), track('c')],
      fallbackTracks: [track('x'), track('b'), track('y')],
      currentTrackId: 'b',
    );

    expect(result.map((item) => item.trackId), ['a', 'b', 'c']);
  });

  test('falls back to the resolvable Library when the track is outside the current filter', () {
    final result = wzPlaybackContextForTrack(
      preferredTracks: [track('a'), track('b')],
      fallbackTracks: [track('x'), track('y'), track('z')],
      currentTrackId: 'y',
    );

    expect(result.map((item) => item.trackId), ['x', 'y', 'z']);
  });

  test('returns an empty context when the track is not resolvable', () {
    final result = wzPlaybackContextForTrack(
      preferredTracks: [track('a')],
      fallbackTracks: [track('b')],
      currentTrackId: 'missing',
    );

    expect(result, isEmpty);
  });

  test('bounds large contexts while keeping next tracks after the current song', () {
    final tracks = List.generate(500, (index) => track('track-$index'));
    final result = wzPlaybackContextForTrack(
      preferredTracks: tracks,
      fallbackTracks: const [],
      currentTrackId: 'track-250',
      maxTracks: 200,
    );

    expect(result.length, 200);
    expect(result.any((item) => item.trackId == 'track-250'), isTrue);
    final selectedIndex = result.indexWhere((item) => item.trackId == 'track-250');
    expect(selectedIndex, greaterThan(0));
    expect(selectedIndex, lessThan(result.length - 1));
    expect(result[selectedIndex + 1].trackId, 'track-251');
  });
}
