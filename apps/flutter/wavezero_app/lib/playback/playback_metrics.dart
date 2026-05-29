class PlaybackMetrics {
  const PlaybackMetrics({
    this.appScreenReadyMs,
    this.tapToFirstAudioMs,
    this.manifestLoadMs,
    this.bufferCount = 0,
    this.isPlaying = false,
    this.currentPositionMs = 0,
    this.playbackError,
  });

  final int? appScreenReadyMs;
  final int? tapToFirstAudioMs;
  final int? manifestLoadMs;
  final int bufferCount;
  final bool isPlaying;
  final int currentPositionMs;
  final String? playbackError;

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
