import 'package:flutter/services.dart';

import 'playback_metrics.dart';

abstract class PlaybackBridge {
  Future<void> loadTrack({
    required String title,
    required String url,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> retry();

  Future<void> resetMetrics();

  Future<PlaybackMetrics> metricsSnapshot();
}

class PlatformChannelPlaybackBridge implements PlaybackBridge {
  PlatformChannelPlaybackBridge({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'wavezero/playback';
  final MethodChannel _channel;

  @override
  Future<void> loadTrack({
    required String title,
    required String url,
  }) {
    return _channel.invokeMethod<void>('loadTrack', <String, Object?>{
      'title': title,
      'url': url,
    });
  }

  @override
  Future<void> play() => _channel.invokeMethod<void>('play');

  @override
  Future<void> pause() => _channel.invokeMethod<void>('pause');

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<void> retry() => _channel.invokeMethod<void>('retry');

  @override
  Future<void> resetMetrics() => _channel.invokeMethod<void>('resetMetrics');

  @override
  Future<PlaybackMetrics> metricsSnapshot() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'metricsSnapshot',
    );
    return PlaybackMetrics.fromJson(result ?? const <Object?, Object?>{});
  }
}

class MockPlaybackBridge implements PlaybackBridge {
  PlaybackMetrics _metrics = const PlaybackMetrics(
    appScreenReadyMs: 42,
    manifestLoadMs: 128,
  );
  String? _loadedTitle;
  String? _loadedUrl;

  @override
  Future<void> loadTrack({
    required String title,
    required String url,
  }) async {
    _loadedTitle = title;
    _loadedUrl = url;
    _metrics = _metrics.copyWith(
      currentPositionMs: 0,
      clearPlaybackError: true,
      clearTapToFirstAudioMs: true,
    );
  }

  @override
  Future<void> play() async {
    _metrics = _metrics.copyWith(
      tapToFirstAudioMs: _metrics.tapToFirstAudioMs ?? 96,
      bufferCount: _metrics.bufferCount,
      isPlaying: true,
      currentPositionMs: _metrics.currentPositionMs + 250,
      clearPlaybackError: true,
    );
  }

  @override
  Future<void> pause() async {
    _metrics = _metrics.copyWith(isPlaying: false);
  }

  @override
  Future<void> stop() async {
    _metrics = _metrics.copyWith(
      isPlaying: false,
      currentPositionMs: 0,
      clearTapToFirstAudioMs: true,
      clearPlaybackError: true,
    );
  }

  @override
  Future<void> retry() async {
    if (_loadedTitle == null || _loadedUrl == null) {
      _metrics = _metrics.copyWith(playbackError: 'No track loaded');
      return;
    }
    _metrics = _metrics.copyWith(
      bufferCount: _metrics.bufferCount + 1,
      isPlaying: true,
      tapToFirstAudioMs: 104,
      clearPlaybackError: true,
    );
  }

  @override
  Future<void> resetMetrics() async {
    _metrics = const PlaybackMetrics(appScreenReadyMs: 0);
  }

  @override
  Future<PlaybackMetrics> metricsSnapshot() async => _metrics;
}
