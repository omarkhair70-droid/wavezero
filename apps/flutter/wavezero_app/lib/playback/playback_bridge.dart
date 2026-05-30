import 'package:flutter/services.dart';

import 'playback_metrics.dart';

abstract class PlaybackBridge {
  Future<void> loadTrack({
    required String title,
    required String url,
  });

  Future<void> prepareNextTrack({
    required String trackId,
    required String title,
    required String url,
  });

  Future<void> clearNextTrackPrebuffer();

  Future<bool> playPreparedNextTrackIfReady({
    required String trackId,
    required String title,
    required String url,
  });

  Future<void> recordNextTrackPrebufferOutcome({
    required String trackId,
    required bool usedPreparedPath,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> retry();

  Future<void> seekTo(int positionMs);

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
  Future<void> prepareNextTrack({
    required String trackId,
    required String title,
    required String url,
  }) {
    return _invokeVoid('prepareNextTrack', <String, Object?>{
      'trackId': trackId,
      'title': title,
      'url': url,
    });
  }

  @override
  Future<void> clearNextTrackPrebuffer() => _invokeVoid('clearNextTrackPrebuffer');

  @override
  Future<bool> playPreparedNextTrackIfReady({
    required String trackId,
    required String title,
    required String url,
  }) async {
    try {
      final usedPreparedPath = await _channel.invokeMethod<bool>(
        'playPreparedNextTrackIfReady',
        <String, Object?>{
          'trackId': trackId,
          'title': title,
          'url': url,
        },
      );
      _lastBridgeError = null;
      return usedPreparedPath == true;
    } on MissingPluginException catch (error) {
      _lastBridgeError = 'Android playback bridge is not available: $error';
      return false;
    } on PlatformException catch (error) {
      _lastBridgeError = 'Android playback bridge error: ${error.message ?? error.code}';
      return false;
    }
  }

  @override
  Future<void> recordNextTrackPrebufferOutcome({
    required String trackId,
    required bool usedPreparedPath,
  }) {
    return _invokeVoid('recordNextTrackPrebufferOutcome', <String, Object?>{
      'trackId': trackId,
      'usedPreparedPath': usedPreparedPath,
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
  Future<void> seekTo(int positionMs) => _invokeVoid(
        'seekTo',
        <String, Object?>{'positionMs': positionMs},
      );

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
      if (_lastBridgeError == null) return metrics;
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
    durationMs: 180000,
    sessionId: 'mock-session',
    lastEvent: 'mock_ready',
  );
  String? _loadedTitle;
  String? _loadedUrl;
  String? _prebufferUrl;

  @override
  Future<void> loadTrack({
    required String title,
    required String url,
  }) async {
    _loadedTitle = title;
    _loadedUrl = url;
    _metrics = _metrics.copyWith(
      currentPositionMs: 0,
      durationMs: 180000,
      attemptId: 0,
      seekCount: 0,
      seekBufferMs: 0,
      trackTitle: title,
      trackUrl: url,
      lastEvent: 'track_loaded',
      clearPlaybackError: true,
      clearTapToFirstAudioMs: true,
      clearTapToReadyMs: true,
      clearTapToIsPlayingMs: true,
      clearTapToPositionAdvanceMs: true,
      clearLastSeekToMs: true,
    );
  }

  @override
  Future<void> prepareNextTrack({
    required String trackId,
    required String title,
    required String url,
  }) async {
    _prebufferUrl = url;
    _metrics = _metrics.copyWith(
      nativePrebufferEnabled: true,
      nativePrebufferTrackId: trackId,
      nativePrebufferTrackTitle: title,
      nativePrebufferInFlight: false,
      nativePrebufferReady: true,
      nativePrebufferPrepareMs: 40,
      lastNativePrebufferTrackId: trackId,
      lastNativePrebufferTrackTitle: title,
      lastNativePrebufferPrepareMs: 40,
      nextPreparedBeforePlay: false,
      lastEvent: 'native_prebuffer_ready',
    );
  }

  @override
  Future<void> clearNextTrackPrebuffer() async {
    _prebufferUrl = null;
    _metrics = _metrics.copyWith(
      nativePrebufferEnabled: false,
      clearNativePrebufferTrackId: true,
      clearNativePrebufferTrackTitle: true,
      nativePrebufferInFlight: false,
      nativePrebufferReady: false,
      clearNativePrebufferPrepareMs: true,
      nextPreparedBeforePlay: false,
      lastEvent: 'native_prebuffer_cleared',
    );
  }

  @override
  Future<bool> playPreparedNextTrackIfReady({
    required String trackId,
    required String title,
    required String url,
  }) async {
    final matchedReady = _metrics.nativePrebufferTrackId == trackId &&
        _metrics.nativePrebufferReady &&
        _prebufferUrl == url;
    _metrics = _metrics.copyWith(
      trackTitle: matchedReady ? title : _metrics.trackTitle,
      trackUrl: matchedReady ? url : _metrics.trackUrl,
      isPlaying: matchedReady ? true : _metrics.isPlaying,
      tapToFirstAudioMs: matchedReady ? (_metrics.tapToFirstAudioMs ?? 24) : _metrics.tapToFirstAudioMs,
      tapToReadyMs: matchedReady ? (_metrics.tapToReadyMs ?? 0) : _metrics.tapToReadyMs,
      tapToIsPlayingMs: matchedReady ? (_metrics.tapToIsPlayingMs ?? 24) : _metrics.tapToIsPlayingMs,
      nativePrebufferHitCount: matchedReady ? _metrics.nativePrebufferHitCount + 1 : _metrics.nativePrebufferHitCount,
      nativePrebufferMissCount: matchedReady ? _metrics.nativePrebufferMissCount : _metrics.nativePrebufferMissCount + 1,
      nativePrebufferHandoffAttempted: _metrics.nativePrebufferHandoffAttempted + 1,
      clearNativeHandoffToPlayingMs: true,
      nativePrebufferHandoffSucceeded: matchedReady ? _metrics.nativePrebufferHandoffSucceeded + 1 : _metrics.nativePrebufferHandoffSucceeded,
      nativePrebufferHandoffFallback: matchedReady ? _metrics.nativePrebufferHandoffFallback : _metrics.nativePrebufferHandoffFallback + 1,
      nextPreparedBeforePlay: matchedReady,
      nativePrebufferEnabled: false,
      nativePrebufferInFlight: false,
      nativePrebufferReady: false,
      clearNativePrebufferTrackId: matchedReady,
      clearNativePrebufferTrackTitle: matchedReady,
      clearNativePrebufferPrepareMs: matchedReady,
      lastEvent: matchedReady ? 'native_prebuffer_handoff_succeeded' : 'native_prebuffer_outcome',
    );
    if (matchedReady) {
      _loadedTitle = title;
      _loadedUrl = url;
      _prebufferUrl = null;
    }
    return matchedReady;
  }

  @override
  Future<void> recordNextTrackPrebufferOutcome({
    required String trackId,
    required bool usedPreparedPath,
  }) async {
    final matchedReady = _metrics.nativePrebufferTrackId == trackId && _metrics.nativePrebufferReady;
    _metrics = _metrics.copyWith(
      nativePrebufferHitCount: usedPreparedPath && matchedReady ? _metrics.nativePrebufferHitCount + 1 : _metrics.nativePrebufferHitCount,
      nativePrebufferMissCount: usedPreparedPath && matchedReady ? _metrics.nativePrebufferMissCount : _metrics.nativePrebufferMissCount + 1,
      nativePrebufferHandoffFallback: usedPreparedPath && matchedReady ? _metrics.nativePrebufferHandoffFallback : _metrics.nativePrebufferHandoffFallback + 1,
      nextPreparedBeforePlay: usedPreparedPath && matchedReady,
      lastEvent: 'native_prebuffer_outcome',
    );
  }

  @override
  Future<void> play() async {
    _metrics = _metrics.copyWith(
      tapToFirstAudioMs: _metrics.tapToFirstAudioMs ?? 96,
      tapToReadyMs: _metrics.tapToReadyMs ?? 72,
      tapToIsPlayingMs: _metrics.tapToIsPlayingMs ?? 96,
      tapToPositionAdvanceMs: _metrics.tapToPositionAdvanceMs ?? 128,
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
  Future<void> seekTo(int positionMs) async {
    final duration = _metrics.durationMs;
    final safePosition = duration == null
        ? positionMs
        : positionMs.clamp(0, duration).toInt();
    _metrics = _metrics.copyWith(
      currentPositionMs: safePosition,
      seekCount: _metrics.seekCount + 1,
      lastSeekToMs: safePosition,
      lastEvent: 'position',
    );
  }

  @override
  Future<void> resetMetrics() async {
    _metrics = PlaybackMetrics(
      appScreenReadyMs: _metrics.appScreenReadyMs,
      durationMs: _metrics.durationMs,
      sessionId: _metrics.sessionId,
      trackTitle: _loadedTitle,
      trackUrl: _loadedUrl,
      lastEvent: 'metrics_reset',
    );
  }

  @override
  Future<PlaybackMetrics> metricsSnapshot() async => _metrics;
}
