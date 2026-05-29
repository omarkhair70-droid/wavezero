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
      sessionId: 'session-1',
      attemptId: 2,
      tapToReadyMs: 12,
      tapToIsPlayingMs: 18,
      tapToPositionAdvanceMs: 24,
      startupBufferMs: 90,
      rebufferCount: 1,
      rebufferMs: 40,
      totalBufferMs: 130,
      lastEvent: 'playing',
      trackTitle: 'Title',
      trackUrl: 'https://example.test/stream.m3u8',
    );

    expect(metrics.toJson()['isPlaying'], isTrue);
    expect(metrics.toJson()['sessionId'], 'session-1');
    expect(metrics.toJson()['startupBufferMs'], 90);
    expect(metrics.toJson()['rebufferCount'], 1);
    expect(metrics.toJson()['totalBufferMs'], 130);
    expect(metrics.toDisplayText(), contains('tapToFirstAudioMs: 20'));
    expect(metrics.toDisplayText(), contains('startupBufferMs: 90'));
    expect(metrics.toDisplayText(), contains('trackTitle: Title'));
  });

  test('PlaybackMetrics reads numeric platform channel maps', () {
    final metrics = PlaybackMetrics.fromJson(<Object?, Object?>{
      'bufferCount': 2.0,
      'isPlaying': true,
      'currentPositionMs': 1024,
      'playbackError': 'network',
      'attemptId': 3.0,
      'tapToReadyMs': 40.0,
      'startupBufferMs': 91.0,
      'rebufferCount': 1.0,
      'rebufferMs': 33.0,
      'totalBufferMs': 124.0,
      'sessionId': 'native-session',
      'lastEvent': 'error',
    });

    expect(metrics.bufferCount, 2);
    expect(metrics.isPlaying, isTrue);
    expect(metrics.currentPositionMs, 1024);
    expect(metrics.playbackError, 'network');
    expect(metrics.attemptId, 3);
    expect(metrics.tapToReadyMs, 40);
    expect(metrics.startupBufferMs, 91);
    expect(metrics.rebufferCount, 1);
    expect(metrics.rebufferMs, 33);
    expect(metrics.totalBufferMs, 124);
    expect(metrics.sessionId, 'native-session');
    expect(metrics.lastEvent, 'error');
  });
}
