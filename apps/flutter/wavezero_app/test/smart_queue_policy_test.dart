import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/queue/smart_queue_policy.dart';
import 'package:wavezero_app/playback/playback_metrics.dart';

void main() {
  CatalogTrackSummary track(String id) => CatalogTrackSummary(trackId: id, title: id);

  SmartQueueDecision decide({
    bool enabled = true,
    List<CatalogTrackSummary>? queue,
    Set<String>? catalogIds,
    String? currentTrackId = 'a',
    String? selectedTrackId,
    String? previousCandidateTrackId,
    bool manifestPrefetched = false,
    PlaybackMetrics metrics = const PlaybackMetrics(),
  }) {
    final tracks = queue ?? [track('a'), track('b'), track('c')];
    return decideSmartQueueCandidate(
      smartPreloadEnabled: enabled,
      queue: tracks,
      catalogTrackIds: catalogIds ?? tracks.map((track) => track.trackId).toSet(),
      currentTrackId: currentTrackId,
      selectedTrackId: selectedTrackId,
      previousCandidateTrackId: previousCandidateTrackId,
      manifestPrefetched: manifestPrefetched,
      metrics: metrics,
    );
  }

  test('disabled preload and empty valid queue keep their existing reasons', () {
    expect(decide(enabled: false).reason, SmartQueueReason.smartPreloadOff);
    expect(decide(queue: const []).reason, SmartQueueReason.queueEmpty);
    expect(decide(catalogIds: const {'missing'}).reason, SmartQueueReason.queueEmpty);
  });

  test('chooses the next valid queue item after the current track', () {
    final decision = decide();

    expect(decision.reason, SmartQueueReason.upNext);
    expect(decision.candidateTrackId, 'b');
    expect(decision.hasCandidate, isTrue);
  });

  test('uses selected track when current track is unavailable', () {
    final decision = decide(currentTrackId: null, selectedTrackId: 'b');

    expect(decision.reason, SmartQueueReason.upNext);
    expect(decision.candidateTrackId, 'c');
  });

  test('keeps the existing first-item fallback when neither current nor selected track is found', () {
    final decision = decide(currentTrackId: 'missing', selectedTrackId: 'also-missing');

    expect(decision.reason, SmartQueueReason.upNext);
    expect(decision.candidateTrackId, 'b');
  });

  test('returns no up next when the resolved track is last', () {
    final decision = decide(currentTrackId: 'c');

    expect(decision.reason, SmartQueueReason.noUpNext);
    expect(decision.hasCandidate, isFalse);
  });

  test('marks a changed candidate when a different candidate was previously tracked', () {
    final decision = decide(previousCandidateTrackId: 'old-candidate');

    expect(decision.reason, SmartQueueReason.candidateChanged);
    expect(decision.candidateTrackId, 'b');
  });

  test('recognizes an already prepared candidate only when manifest and native prebuffer are ready', () {
    final prepared = decide(
      previousCandidateTrackId: 'b',
      manifestPrefetched: true,
      metrics: const PlaybackMetrics(
        nativePrebufferTrackId: 'b',
        nativePrebufferReady: true,
      ),
    );
    final notReady = decide(
      previousCandidateTrackId: 'b',
      manifestPrefetched: true,
      metrics: const PlaybackMetrics(
        nativePrebufferTrackId: 'b',
        nativePrebufferReady: false,
      ),
    );

    expect(prepared.reason, SmartQueueReason.alreadyPrepared);
    expect(prepared.candidateTrackId, 'b');
    expect(notReady.reason, SmartQueueReason.upNext);
    expect(notReady.candidateTrackId, 'b');
  });
}
