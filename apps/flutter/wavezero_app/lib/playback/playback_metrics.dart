class PlaybackMetrics {
  const PlaybackMetrics({
    this.appScreenReadyMs,
    this.tapToFirstAudioMs,
    this.manifestLoadMs,
    this.bufferCount = 0,
    this.isPlaying = false,
    this.currentPositionMs = 0,
    this.durationMs,
    this.playbackError,
    this.sessionId,
    this.attemptId = 0,
    this.tapToReadyMs,
    this.tapToIsPlayingMs,
    this.tapToPositionAdvanceMs,
    this.startupBufferMs = 0,
    this.rebufferCount = 0,
    this.rebufferMs = 0,
    this.totalBufferMs = 0,
    this.preparedBeforePlay = false,
    this.loadToManifestMs,
    this.loadToReadyMs,
    this.prebufferCount = 0,
    this.prebufferMs = 0,
    this.seekCount = 0,
    this.seekBufferMs = 0,
    this.lastSeekToMs,
    this.nativePrebufferEnabled = false,
    this.nativePrebufferTrackId,
    this.nativePrebufferTrackTitle,
    this.nativePrebufferInFlight = false,
    this.nativePrebufferReady = false,
    this.nativePrebufferHitCount = 0,
    this.nativePrebufferMissCount = 0,
    this.nativePrebufferPrepareMs,
    this.nextPreparedBeforePlay = false,
    this.lastEvent,
    this.trackTitle,
    this.trackUrl,
  });

  final int? appScreenReadyMs;
  final int? tapToFirstAudioMs;
  final int? manifestLoadMs;
  final int bufferCount;
  final bool isPlaying;
  final int currentPositionMs;
  final int? durationMs;
  final String? playbackError;
  final String? sessionId;
  final int attemptId;
  final int? tapToReadyMs;
  final int? tapToIsPlayingMs;
  final int? tapToPositionAdvanceMs;
  final int startupBufferMs;
  final int rebufferCount;
  final int rebufferMs;
  final int totalBufferMs;
  final bool preparedBeforePlay;
  final int? loadToManifestMs;
  final int? loadToReadyMs;
  final int prebufferCount;
  final int prebufferMs;
  final int seekCount;
  final int seekBufferMs;
  final int? lastSeekToMs;
  final bool nativePrebufferEnabled;
  final String? nativePrebufferTrackId;
  final String? nativePrebufferTrackTitle;
  final bool nativePrebufferInFlight;
  final bool nativePrebufferReady;
  final int nativePrebufferHitCount;
  final int nativePrebufferMissCount;
  final int? nativePrebufferPrepareMs;
  final bool nextPreparedBeforePlay;
  final String? lastEvent;
  final String? trackTitle;
  final String? trackUrl;

  PlaybackMetrics copyWith({
    int? appScreenReadyMs,
    bool clearAppScreenReadyMs = false,
    int? tapToFirstAudioMs,
    bool clearTapToFirstAudioMs = false,
    int? manifestLoadMs,
    bool clearManifestLoadMs = false,
    int? bufferCount,
    bool? isPlaying,
    int? currentPositionMs,
    int? durationMs,
    bool clearDurationMs = false,
    String? playbackError,
    bool clearPlaybackError = false,
    String? sessionId,
    int? attemptId,
    int? tapToReadyMs,
    bool clearTapToReadyMs = false,
    int? tapToIsPlayingMs,
    bool clearTapToIsPlayingMs = false,
    int? tapToPositionAdvanceMs,
    bool clearTapToPositionAdvanceMs = false,
    int? startupBufferMs,
    int? rebufferCount,
    int? rebufferMs,
    int? totalBufferMs,
    bool? preparedBeforePlay,
    int? loadToManifestMs,
    bool clearLoadToManifestMs = false,
    int? loadToReadyMs,
    bool clearLoadToReadyMs = false,
    int? prebufferCount,
    int? prebufferMs,
    int? seekCount,
    int? seekBufferMs,
    int? lastSeekToMs,
    bool clearLastSeekToMs = false,
    bool? nativePrebufferEnabled,
    String? nativePrebufferTrackId,
    bool clearNativePrebufferTrackId = false,
    String? nativePrebufferTrackTitle,
    bool clearNativePrebufferTrackTitle = false,
    bool? nativePrebufferInFlight,
    bool? nativePrebufferReady,
    int? nativePrebufferHitCount,
    int? nativePrebufferMissCount,
    int? nativePrebufferPrepareMs,
    bool clearNativePrebufferPrepareMs = false,
    bool? nextPreparedBeforePlay,
    String? lastEvent,
    String? trackTitle,
    String? trackUrl,
  }) {
    return PlaybackMetrics(
      appScreenReadyMs: clearAppScreenReadyMs
          ? null
          : appScreenReadyMs ?? this.appScreenReadyMs,
      tapToFirstAudioMs: clearTapToFirstAudioMs
          ? null
          : tapToFirstAudioMs ?? this.tapToFirstAudioMs,
      manifestLoadMs:
          clearManifestLoadMs ? null : manifestLoadMs ?? this.manifestLoadMs,
      bufferCount: bufferCount ?? this.bufferCount,
      isPlaying: isPlaying ?? this.isPlaying,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      durationMs: clearDurationMs ? null : durationMs ?? this.durationMs,
      playbackError:
          clearPlaybackError ? null : playbackError ?? this.playbackError,
      sessionId: sessionId ?? this.sessionId,
      attemptId: attemptId ?? this.attemptId,
      tapToReadyMs:
          clearTapToReadyMs ? null : tapToReadyMs ?? this.tapToReadyMs,
      tapToIsPlayingMs: clearTapToIsPlayingMs
          ? null
          : tapToIsPlayingMs ?? this.tapToIsPlayingMs,
      tapToPositionAdvanceMs: clearTapToPositionAdvanceMs
          ? null
          : tapToPositionAdvanceMs ?? this.tapToPositionAdvanceMs,
      startupBufferMs: startupBufferMs ?? this.startupBufferMs,
      rebufferCount: rebufferCount ?? this.rebufferCount,
      rebufferMs: rebufferMs ?? this.rebufferMs,
      totalBufferMs: totalBufferMs ?? this.totalBufferMs,
      preparedBeforePlay: preparedBeforePlay ?? this.preparedBeforePlay,
      loadToManifestMs: clearLoadToManifestMs
          ? null
          : loadToManifestMs ?? this.loadToManifestMs,
      loadToReadyMs:
          clearLoadToReadyMs ? null : loadToReadyMs ?? this.loadToReadyMs,
      prebufferCount: prebufferCount ?? this.prebufferCount,
      prebufferMs: prebufferMs ?? this.prebufferMs,
      seekCount: seekCount ?? this.seekCount,
      seekBufferMs: seekBufferMs ?? this.seekBufferMs,
      lastSeekToMs:
          clearLastSeekToMs ? null : lastSeekToMs ?? this.lastSeekToMs,
      nativePrebufferEnabled:
          nativePrebufferEnabled ?? this.nativePrebufferEnabled,
      nativePrebufferTrackId: clearNativePrebufferTrackId
          ? null
          : nativePrebufferTrackId ?? this.nativePrebufferTrackId,
      nativePrebufferTrackTitle: clearNativePrebufferTrackTitle
          ? null
          : nativePrebufferTrackTitle ?? this.nativePrebufferTrackTitle,
      nativePrebufferInFlight:
          nativePrebufferInFlight ?? this.nativePrebufferInFlight,
      nativePrebufferReady: nativePrebufferReady ?? this.nativePrebufferReady,
      nativePrebufferHitCount:
          nativePrebufferHitCount ?? this.nativePrebufferHitCount,
      nativePrebufferMissCount:
          nativePrebufferMissCount ?? this.nativePrebufferMissCount,
      nativePrebufferPrepareMs: clearNativePrebufferPrepareMs
          ? null
          : nativePrebufferPrepareMs ?? this.nativePrebufferPrepareMs,
      nextPreparedBeforePlay:
          nextPreparedBeforePlay ?? this.nextPreparedBeforePlay,
      lastEvent: lastEvent ?? this.lastEvent,
      trackTitle: trackTitle ?? this.trackTitle,
      trackUrl: trackUrl ?? this.trackUrl,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'appScreenReadyMs': appScreenReadyMs,
      'tapToFirstAudioMs': tapToFirstAudioMs,
      'manifestLoadMs': manifestLoadMs,
      'bufferCount': bufferCount,
      'isPlaying': isPlaying,
      'currentPositionMs': currentPositionMs,
      'durationMs': durationMs,
      'playbackError': playbackError,
      'sessionId': sessionId,
      'attemptId': attemptId,
      'tapToReadyMs': tapToReadyMs,
      'tapToIsPlayingMs': tapToIsPlayingMs,
      'tapToPositionAdvanceMs': tapToPositionAdvanceMs,
      'startupBufferMs': startupBufferMs,
      'rebufferCount': rebufferCount,
      'rebufferMs': rebufferMs,
      'totalBufferMs': totalBufferMs,
      'preparedBeforePlay': preparedBeforePlay,
      'loadToManifestMs': loadToManifestMs,
      'loadToReadyMs': loadToReadyMs,
      'prebufferCount': prebufferCount,
      'prebufferMs': prebufferMs,
      'seekCount': seekCount,
      'seekBufferMs': seekBufferMs,
      'lastSeekToMs': lastSeekToMs,
      'nativePrebufferEnabled': nativePrebufferEnabled,
      'nativePrebufferTrackId': nativePrebufferTrackId,
      'nativePrebufferTrackTitle': nativePrebufferTrackTitle,
      'nativePrebufferInFlight': nativePrebufferInFlight,
      'nativePrebufferReady': nativePrebufferReady,
      'nativePrebufferHitCount': nativePrebufferHitCount,
      'nativePrebufferMissCount': nativePrebufferMissCount,
      'nativePrebufferPrepareMs': nativePrebufferPrepareMs,
      'nextPreparedBeforePlay': nextPreparedBeforePlay,
      'lastEvent': lastEvent,
      'trackTitle': trackTitle,
      'trackUrl': trackUrl,
    };
  }

  String toDisplayText() {
    return toJson().entries.map((entry) {
      final value = entry.value ?? '—';
      return '${entry.key}: $value';
    }).join('\n');
  }

  factory PlaybackMetrics.fromJson(Map<Object?, Object?> json) {
    return PlaybackMetrics(
      appScreenReadyMs: _readInt(json['appScreenReadyMs']),
      tapToFirstAudioMs: _readInt(json['tapToFirstAudioMs']),
      manifestLoadMs: _readInt(json['manifestLoadMs']),
      bufferCount: _readInt(json['bufferCount']) ?? 0,
      isPlaying: json['isPlaying'] == true,
      currentPositionMs: _readInt(json['currentPositionMs']) ?? 0,
      durationMs: _readInt(json['durationMs']),
      playbackError: json['playbackError'] as String?,
      sessionId: json['sessionId'] as String?,
      attemptId: _readInt(json['attemptId']) ?? 0,
      tapToReadyMs: _readInt(json['tapToReadyMs']),
      tapToIsPlayingMs: _readInt(json['tapToIsPlayingMs']),
      tapToPositionAdvanceMs: _readInt(json['tapToPositionAdvanceMs']),
      startupBufferMs: _readInt(json['startupBufferMs']) ?? 0,
      rebufferCount: _readInt(json['rebufferCount']) ?? 0,
      rebufferMs: _readInt(json['rebufferMs']) ?? 0,
      totalBufferMs: _readInt(json['totalBufferMs']) ?? 0,
      preparedBeforePlay: json['preparedBeforePlay'] == true,
      loadToManifestMs: _readInt(json['loadToManifestMs']),
      loadToReadyMs: _readInt(json['loadToReadyMs']),
      prebufferCount: _readInt(json['prebufferCount']) ?? 0,
      prebufferMs: _readInt(json['prebufferMs']) ?? 0,
      seekCount: _readInt(json['seekCount']) ?? 0,
      seekBufferMs: _readInt(json['seekBufferMs']) ?? 0,
      lastSeekToMs: _readInt(json['lastSeekToMs']),
      nativePrebufferEnabled: json['nativePrebufferEnabled'] == true,
      nativePrebufferTrackId: json['nativePrebufferTrackId'] as String?,
      nativePrebufferTrackTitle: json['nativePrebufferTrackTitle'] as String?,
      nativePrebufferInFlight: json['nativePrebufferInFlight'] == true,
      nativePrebufferReady: json['nativePrebufferReady'] == true,
      nativePrebufferHitCount: _readInt(json['nativePrebufferHitCount']) ?? 0,
      nativePrebufferMissCount: _readInt(json['nativePrebufferMissCount']) ?? 0,
      nativePrebufferPrepareMs: _readInt(json['nativePrebufferPrepareMs']),
      nextPreparedBeforePlay: json['nextPreparedBeforePlay'] == true,
      lastEvent: json['lastEvent'] as String?,
      trackTitle: json['trackTitle'] as String?,
      trackUrl: json['trackUrl'] as String?,
    );
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
