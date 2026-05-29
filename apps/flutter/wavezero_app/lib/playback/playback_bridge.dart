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
  String? _lastBridgeError;

  @override
  Future<void> loadTrack({
    required String title,
    required String url,
  }) {
    return _invokeVoid('loadTrack', <String, Object?>{
      'title': title,
      'url': url,
    });
  }

  @override
  Future<void> play() => _invokeVoid('play');

  @override
  Future<void> pause() => _invokeVoid('pause');

  @override
  Future<void> stop() => _invokeVoid('stop');

  @override
  Future<void> retry() => _invokeVoid('retry');

  @override
  Future<void> resetMetrics() => _invokeVoid('resetMetrics');

  @override
  Future<PlaybackMetrics> metricsSnapshot() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'metricsSnapshot',
      );
      final metrics = PlaybackMetrics.fromJson(
        result ?? const <Object?, Object?>{},
      );
      if (_lastBridgeError == null) {
        return metrics;
      }
      return metrics.copyWith(playbackError: _lastBridgeError);
    } on MissingPluginException catch (error) {
      return _errorMetrics('Android playback bridge is not available: $error');
    } on PlatformException catch (error) {
      return _errorMetrics(
        'Android playback bridge error: ${error.message ?? error.code}',
      );
    }
  }

  Future<void> _invokeVoid(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
      _lastBridgeError = null;
    } on MissingPluginException catch (error) {
      _lastBridgeError = 'Android playback bridge is not available: $error';
    } on PlatformException catch (error) {
      _lastBridgeError = 'Android playback bridge error: ${error.message ?? error.code}';
    }
  }

  PlaybackMetrics _errorMetrics(String message) {
    _lastBridgeError = message;
    return PlaybackMetrics(playbackError: message);
  }
}

class MockPlaybackBridge implements PlaybackBridge {
  PlaybackMetrics _metrics = const PlaybackMetrics(
    appScreenReadyMs: 42,
    manifestLoadMs: 128,
    sessionId: 'mock-session',
    lastEvent: 'mock_ready',
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
      attemptId: 0,
      trackTitle: title,
      trackUrl: url,
      lastEvent: 'track_loaded',
      clearPlaybackError: true,
      clearTapToFirstAudioMs: true,
      clearTapToReadyMs: true,
      clearTapToIsPlayingMs: true,
      clearTapToPositionAdvanceMs: true,
    );
  }

  @override
  Future<void> play() async {
    _metrics = _metrics.copyWith(
      tapToFirstAudioMs: _metrics.tapToFirstAudioMs ?? 96,
      tapToReadyMs: _metrics.tapToReadyMs ?? 72,
      tapToIsPlayingMs: _metrics.tapToIsPlayingMs ?? 96,
      tapToPositionAdvanceMs: _metrics.tapToPositionAdvanceMs ?? 128,
      bufferCount: _metrics.bufferCount,
      isPlaying: true,
      currentPositionMs: _metrics.currentPositionMs + 250,
      attemptId: _metrics.attemptId + 1,
      lastEvent: 'playing',
      clearPlaybackError: true,
    );
  }

  @override
  Future<void> pause() async {
    _metrics = _metrics.copyWith(isPlaying: false, lastEvent: 'not_playing');
  }

  @override
  Future<void> stop() async {
    _metrics = _metrics.copyWith(
      isPlaying: false,
      currentPositionMs: 0,
      lastEvent: 'stopped',
      clearTapToFirstAudioMs: true,
      clearTapToReadyMs: true,
      clearTapToIsPlayingMs: true,
      clearTapToPositionAdvanceMs: true,
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
      tapToReadyMs: 80,
      tapToIsPlayingMs: 104,
      tapToPositionAdvanceMs: 140,
      attemptId: _metrics.attemptId + 1,
      lastEvent: 'playing',
      clearPlaybackError: true,
    );
  }

  @override
  Future<void> resetMetrics() async {
    _metrics = PlaybackMetrics(
      appScreenReadyMs: _metrics.appScreenReadyMs,
      sessionId: _metrics.sessionId,
      trackTitle: _loadedTitle,
      trackUrl: _loadedUrl,
      lastEvent: 'metrics_reset',
    );
  }

  @override
  Future<PlaybackMetrics> metricsSnapshot() async => _metrics;
}
