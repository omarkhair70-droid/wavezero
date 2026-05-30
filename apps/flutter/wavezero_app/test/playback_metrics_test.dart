import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/playback/playback_metrics.dart';

void main() {
  test('PlaybackMetrics serializes bridge fields for display', () {
    const metrics = PlaybackMetrics(
      appScreenReadyMs: 10,
      tapToFirstAudioMs: 20,
      manifestLoadMs: 30,
      bufferCount: 1,
      isPlaying: true,
      currentPositionMs: 250,
      durationMs: 180000,
      sessionId: 'session-1',
      attemptId: 2,
      tapToReadyMs: 12,
      tapToIsPlayingMs: 18,
      tapToPositionAdvanceMs: 24,
      startupBufferMs: 90,
      rebufferCount: 1,
      rebufferMs: 40,
      totalBufferMs: 130,
      preparedBeforePlay: true,
      loadToManifestMs: 55,
      loadToReadyMs: 75,
      prebufferCount: 1,
      prebufferMs: 70,
      seekCount: 2,
      seekBufferMs: 44,
      lastSeekToMs: 12000,
      nativePrebufferEnabled: true,
      nativePrebufferTrackId: 'track-3',
      nativePrebufferTrackTitle: 'Song 3',
      nativePrebufferInFlight: false,
      nativePrebufferReady: true,
      nativePrebufferHitCount: 0,
      nativePrebufferMissCount: 1,
      nativePrebufferPrepareMs: 123,
      nativePrebufferHandoffAttempted: 1,
      nativePrebufferHandoffSucceeded: 0,
      nativePrebufferHandoffFallback: 1,
      nextPreparedBeforePlay: false,
      lastEvent: 'playing',
      trackTitle: 'Title',
      trackUrl: 'https://example.test/stream.m3u8',
    );

    expect(metrics.toJson()['isPlaying'], isTrue);
    expect(metrics.toJson()['sessionId'], 'session-1');
    expect(metrics.toJson()['durationMs'], 180000);
    expect(metrics.toJson()['startupBufferMs'], 90);
    expect(metrics.toJson()['rebufferCount'], 1);
    expect(metrics.toJson()['totalBufferMs'], 130);
    expect(metrics.toJson()['preparedBeforePlay'], isTrue);
    expect(metrics.toJson()['loadToManifestMs'], 55);
    expect(metrics.toJson()['loadToReadyMs'], 75);
    expect(metrics.toJson()['prebufferCount'], 1);
    expect(metrics.toJson()['prebufferMs'], 70);
    expect(metrics.toJson()['seekCount'], 2);
    expect(metrics.toJson()['seekBufferMs'], 44);
    expect(metrics.toJson()['lastSeekToMs'], 12000);
    expect(metrics.toJson()['nativePrebufferEnabled'], isTrue);
    expect(metrics.toJson()['nativePrebufferTrackId'], 'track-3');
    expect(metrics.toJson()['nativePrebufferTrackTitle'], 'Song 3');
    expect(metrics.toJson()['nativePrebufferReady'], isTrue);
    expect(metrics.toJson()['nativePrebufferMissCount'], 1);
    expect(metrics.toJson()['nativePrebufferPrepareMs'], 123);
    expect(metrics.toJson()['nativePrebufferHandoffAttempted'], 1);
    expect(metrics.toJson()['nativePrebufferHandoffSucceeded'], 0);
    expect(metrics.toJson()['nativePrebufferHandoffFallback'], 1);
    expect(metrics.toJson()['nextPreparedBeforePlay'], isFalse);
    expect(metrics.toDisplayText(), contains('tapToFirstAudioMs: 20'));
    expect(metrics.toDisplayText(), contains('startupBufferMs: 90'));
    expect(metrics.toDisplayText(), contains('preparedBeforePlay: true'));
    expect(metrics.toDisplayText(), contains('loadToReadyMs: 75'));
    expect(metrics.toDisplayText(), contains('seekCount: 2'));
    expect(metrics.toDisplayText(), contains('seekBufferMs: 44'));
    expect(metrics.toDisplayText(), contains('trackTitle: Title'));
  });

  test('PlaybackMetrics reads numeric platform channel maps', () {
    final metrics = PlaybackMetrics.fromJson(<Object?, Object?>{
      'bufferCount': 2.0,
      'isPlaying': true,
      'currentPositionMs': 1024,
      'durationMs': 180000.0,
      'playbackError': 'network',
      'attemptId': 3.0,
      'tapToReadyMs': 40.0,
      'startupBufferMs': 91.0,
      'rebufferCount': 1.0,
      'rebufferMs': 33.0,
      'totalBufferMs': 124.0,
      'preparedBeforePlay': true,
      'loadToManifestMs': 51.0,
      'loadToReadyMs': 72.0,
      'prebufferCount': 1.0,
      'prebufferMs': 66.0,
      'seekCount': 4.0,
      'seekBufferMs': 87.0,
      'lastSeekToMs': 45000.0,
      'nativePrebufferEnabled': true,
      'nativePrebufferTrackId': 'track-4',
      'nativePrebufferTrackTitle': 'Song 4',
      'nativePrebufferInFlight': false,
      'nativePrebufferReady': true,
      'nativePrebufferHitCount': 2.0,
      'nativePrebufferMissCount': 3.0,
      'nativePrebufferPrepareMs': 81.0,
      'nativePrebufferHandoffAttempted': 4.0,
      'nativePrebufferHandoffSucceeded': 2.0,
      'nativePrebufferHandoffFallback': 2.0,
      'nextPreparedBeforePlay': false,
      'sessionId': 'native-session',
      'lastEvent': 'error',
    });

    expect(metrics.bufferCount, 2);
    expect(metrics.isPlaying, isTrue);
    expect(metrics.currentPositionMs, 1024);
    expect(metrics.durationMs, 180000);
    expect(metrics.playbackError, 'network');
    expect(metrics.attemptId, 3);
    expect(metrics.tapToReadyMs, 40);
    expect(metrics.startupBufferMs, 91);
    expect(metrics.rebufferCount, 1);
    expect(metrics.rebufferMs, 33);
    expect(metrics.totalBufferMs, 124);
    expect(metrics.preparedBeforePlay, isTrue);
    expect(metrics.loadToManifestMs, 51);
    expect(metrics.loadToReadyMs, 72);
    expect(metrics.prebufferCount, 1);
    expect(metrics.prebufferMs, 66);
    expect(metrics.seekCount, 4);
    expect(metrics.seekBufferMs, 87);
    expect(metrics.lastSeekToMs, 45000);
    expect(metrics.nativePrebufferEnabled, isTrue);
    expect(metrics.nativePrebufferTrackId, 'track-4');
    expect(metrics.nativePrebufferTrackTitle, 'Song 4');
    expect(metrics.nativePrebufferReady, isTrue);
    expect(metrics.nativePrebufferHitCount, 2);
    expect(metrics.nativePrebufferMissCount, 3);
    expect(metrics.nativePrebufferPrepareMs, 81);
    expect(metrics.nativePrebufferHandoffAttempted, 4);
    expect(metrics.nativePrebufferHandoffSucceeded, 2);
    expect(metrics.nativePrebufferHandoffFallback, 2);
    expect(metrics.nextPreparedBeforePlay, isFalse);
    expect(metrics.sessionId, 'native-session');
    expect(metrics.lastEvent, 'error');
  });
}
