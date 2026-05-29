class PlaybackMetrics {
  const PlaybackMetrics({
    this.appScreenReadyMs,
    this.tapToFirstAudioMs,
    this.manifestLoadMs,
    this.bufferCount = 0,
    this.isPlaying = false,
    this.currentPositionMs = 0,
    this.playbackError,
    this.sessionId,
    this.attemptId = 0,
    this.tapToReadyMs,
    this.tapToIsPlayingMs,
    this.tapToPositionAdvanceMs,
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
  final String? playbackError;
  final String? sessionId;
  final int attemptId;
  final int? tapToReadyMs;
  final int? tapToIsPlayingMs;
  final int? tapToPositionAdvanceMs;
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
      'playbackError': playbackError,
      'sessionId': sessionId,
      'attemptId': attemptId,
      'tapToReadyMs': tapToReadyMs,
      'tapToIsPlayingMs': tapToIsPlayingMs,
      'tapToPositionAdvanceMs': tapToPositionAdvanceMs,
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
      playbackError: json['playbackError'] as String?,
      sessionId: json['sessionId'] as String?,
      attemptId: _readInt(json['attemptId']) ?? 0,
      tapToReadyMs: _readInt(json['tapToReadyMs']),
      tapToIsPlayingMs: _readInt(json['tapToIsPlayingMs']),
      tapToPositionAdvanceMs: _readInt(json['tapToPositionAdvanceMs']),
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
