import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/history/history_presentation.dart';
import 'package:wavezero_app/features/history/history_resolution.dart';
import 'package:wavezero_app/features/history/listening_history_service.dart';

void main() {
  const entry = WzListeningHistoryEntry(
    trackId: 'track-1',
    title: 'Track One',
    subtitle: 'Artist',
    source: WzListeningHistorySource.api,
    lastPlayedAtMs: 20,
    firstPlayedAtMs: 10,
    playCount: 2,
    lastPositionMs: 65000,
    durationMs: 180000,
  );

  test('resolution prefers the live library then uses fallback', () {
    final live = CatalogTrackSummary(trackId: 'track-1', title: 'Live');
    final fallback = CatalogTrackSummary(trackId: 'track-1', title: 'Fallback');
    expect(
      wzResolveHistoryEntry(
        libraryTracks: [live],
        entry: entry,
        fallbackTrack: fallback,
      ),
      same(live),
    );
    expect(
      wzResolveHistoryEntry(
        libraryTracks: const [],
        entry: entry,
        fallbackTrack: fallback,
      ),
      same(fallback),
    );
  });

  test('manifest snapshot preserves history defaults and injected time', () {
    const manifest = CatalogTrackManifest(
      trackId: 'track-2',
      title: 'Track Two',
      streamUrl: 'https://example.test/two.mp3',
      artistName: 'Artist Two',
      durationMs: 90000,
    );
    final snapshot = wzHistorySnapshotForManifest(
      manifest,
      source: WzListeningHistorySource.api,
      playableUrl: null,
      nowMs: 1234,
    );
    expect(snapshot.trackId, 'track-2');
    expect(snapshot.primaryUrl, manifest.streamUrl);
    expect(snapshot.lastPlayedAtMs, 1234);
    expect(snapshot.firstPlayedAtMs, 1234);
    expect(snapshot.playCount, 1);
  });

  test('history presentation preserves source, relative time, and resume copy', () {
    expect(wzHistorySourceLabel(WzListeningHistorySource.cached), 'Downloaded');
    expect(
      friendlyWzHistoryTime(
        1000000,
        now: DateTime.fromMillisecondsSinceEpoch(1000000 + 30 * 60 * 1000),
      ),
      '30m ago',
    );
    expect(wzHistoryPositionLabel(entry), 'Resume at 1:05 of 3:00');
  });
}
