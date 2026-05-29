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
    );

    expect(metrics.toJson()['isPlaying'], isTrue);
    expect(metrics.toDisplayText(), contains('tapToFirstAudioMs: 20'));
  });

  test('PlaybackMetrics reads numeric platform channel maps', () {
    final metrics = PlaybackMetrics.fromJson(<Object?, Object?>{
      'bufferCount': 2.0,
      'isPlaying': true,
      'currentPositionMs': 1024,
      'playbackError': 'network',
    });

    expect(metrics.bufferCount, 2);
    expect(metrics.isPlaying, isTrue);
    expect(metrics.currentPositionMs, 1024);
    expect(metrics.playbackError, 'network');
  });
}
