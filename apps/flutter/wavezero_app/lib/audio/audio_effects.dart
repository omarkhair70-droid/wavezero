/// User-selectable audio effect profiles and diagnostics metadata.
///
/// The gain values are intentionally subtle and are used by Flutter diagnostics
/// and native bridge requests. They do not imply that native DSP is active unless
/// the playback bridge returns [NativeAudioEffectStatus.applied].
enum AudioEffectProfile {
  off,
  bassBoost,
  vocalClarity,
  warm,
  bright,
  nightSoft,
}

enum AudioEffectSafety { qualitySafe, subtle, stronger }

enum NativeAudioEffectStatus { applied, unsupported, pending, failed, off }

extension AudioEffectProfileInfo on AudioEffectProfile {
  String get id {
    switch (this) {
      case AudioEffectProfile.off:
        return 'off';
      case AudioEffectProfile.bassBoost:
        return 'bass_boost';
      case AudioEffectProfile.vocalClarity:
        return 'vocal_clarity';
      case AudioEffectProfile.warm:
        return 'warm';
      case AudioEffectProfile.bright:
        return 'bright';
      case AudioEffectProfile.nightSoft:
        return 'night_soft';
    }
  }

  String get label {
    switch (this) {
      case AudioEffectProfile.off:
        return 'Off / Original';
      case AudioEffectProfile.bassBoost:
        return 'Bass Boost';
      case AudioEffectProfile.vocalClarity:
        return 'Vocal Clarity';
      case AudioEffectProfile.warm:
        return 'Warm';
      case AudioEffectProfile.bright:
        return 'Bright';
      case AudioEffectProfile.nightSoft:
        return 'Night / Soft';
    }
  }

  String get shortLabel {
    switch (this) {
      case AudioEffectProfile.off:
        return 'Off';
      case AudioEffectProfile.bassBoost:
        return 'Bass';
      case AudioEffectProfile.vocalClarity:
        return 'Vocal';
      case AudioEffectProfile.warm:
        return 'Warm';
      case AudioEffectProfile.bright:
        return 'Bright';
      case AudioEffectProfile.nightSoft:
        return 'Night';
    }
  }

  String get description {
    switch (this) {
      case AudioEffectProfile.off:
        return 'Preserves the original playback path with no intentional effect applied.';
      case AudioEffectProfile.bassBoost:
        return 'Subtle low-end lift for fuller playback while avoiding aggressive boost.';
      case AudioEffectProfile.vocalClarity:
        return 'Small mid and treble presence lift intended to help vocals remain clear.';
      case AudioEffectProfile.warm:
        return 'Gentle low-mid warmth with a slight treble softening feel.';
      case AudioEffectProfile.bright:
        return 'Light treble lift for a more open presentation without harsh settings.';
      case AudioEffectProfile.nightSoft:
        return 'Low-intensity listening profile foundation; no compression is claimed unless native support reports it.';
    }
  }

  AudioEffectSafety get safety {
    switch (this) {
      case AudioEffectProfile.off:
        return AudioEffectSafety.qualitySafe;
      case AudioEffectProfile.bassBoost:
        return AudioEffectSafety.stronger;
      case AudioEffectProfile.vocalClarity:
      case AudioEffectProfile.warm:
      case AudioEffectProfile.bright:
      case AudioEffectProfile.nightSoft:
        return AudioEffectSafety.subtle;
    }
  }

  String get safetyLabel {
    switch (safety) {
      case AudioEffectSafety.qualitySafe:
        return 'quality-safe/original';
      case AudioEffectSafety.subtle:
        return 'subtle';
      case AudioEffectSafety.stronger:
        return 'stronger';
    }
  }

  double get bassGainDb {
    switch (this) {
      case AudioEffectProfile.off:
        return 0;
      case AudioEffectProfile.bassBoost:
        return 2.0;
      case AudioEffectProfile.vocalClarity:
        return -0.5;
      case AudioEffectProfile.warm:
        return 1.2;
      case AudioEffectProfile.bright:
        return -0.3;
      case AudioEffectProfile.nightSoft:
        return -0.8;
    }
  }

  double get midGainDb {
    switch (this) {
      case AudioEffectProfile.off:
        return 0;
      case AudioEffectProfile.bassBoost:
        return 0.2;
      case AudioEffectProfile.vocalClarity:
        return 1.4;
      case AudioEffectProfile.warm:
        return 0.8;
      case AudioEffectProfile.bright:
        return 0.3;
      case AudioEffectProfile.nightSoft:
        return -0.5;
    }
  }

  double get trebleGainDb {
    switch (this) {
      case AudioEffectProfile.off:
        return 0;
      case AudioEffectProfile.bassBoost:
        return -0.2;
      case AudioEffectProfile.vocalClarity:
        return 1.0;
      case AudioEffectProfile.warm:
        return -0.7;
      case AudioEffectProfile.bright:
        return 1.6;
      case AudioEffectProfile.nightSoft:
        return -1.0;
    }
  }

  double get preampGainDb {
    switch (this) {
      case AudioEffectProfile.off:
        return 0;
      case AudioEffectProfile.bassBoost:
        return -1.5;
      case AudioEffectProfile.vocalClarity:
        return -1.0;
      case AudioEffectProfile.warm:
        return -0.8;
      case AudioEffectProfile.bright:
        return -1.0;
      case AudioEffectProfile.nightSoft:
        return -1.8;
    }
  }

  Map<String, Object?> toBridgeJson() => <String, Object?>{
        'id': id,
        'label': label,
        'bassGainDb': bassGainDb,
        'midGainDb': midGainDb,
        'trebleGainDb': trebleGainDb,
        'preampGainDb': preampGainDb,
      };
}

AudioEffectProfile parseAudioEffectProfile(String? value) {
  final normalized = value?.trim();
  for (final profile in AudioEffectProfile.values) {
    if (profile.id == normalized || profile.name == normalized) return profile;
  }
  return AudioEffectProfile.off;
}

extension NativeAudioEffectStatusInfo on NativeAudioEffectStatus {
  String get id {
    switch (this) {
      case NativeAudioEffectStatus.applied:
        return 'applied';
      case NativeAudioEffectStatus.unsupported:
        return 'unsupported';
      case NativeAudioEffectStatus.pending:
        return 'pending';
      case NativeAudioEffectStatus.failed:
        return 'failed';
      case NativeAudioEffectStatus.off:
        return 'off';
    }
  }

  String get label {
    switch (this) {
      case NativeAudioEffectStatus.applied:
        return 'applied';
      case NativeAudioEffectStatus.unsupported:
        return 'unsupported';
      case NativeAudioEffectStatus.pending:
        return 'pending';
      case NativeAudioEffectStatus.failed:
        return 'failed';
      case NativeAudioEffectStatus.off:
        return 'off';
    }
  }
}

NativeAudioEffectStatus parseNativeAudioEffectStatus(String? value) {
  final normalized = value?.trim();
  for (final status in NativeAudioEffectStatus.values) {
    if (status.id == normalized || status.name == normalized) return status;
  }
  return NativeAudioEffectStatus.failed;
}

class AudioEffectApplyResult {
  const AudioEffectApplyResult({
    required this.status,
    required this.message,
  });

  final NativeAudioEffectStatus status;
  final String message;

  factory AudioEffectApplyResult.fromJson(Map<Object?, Object?> json) {
    return AudioEffectApplyResult(
      status: parseNativeAudioEffectStatus(json['status'] as String?),
      message: (json['message'] as String?) ?? 'No native effect result message.',
    );
  }

  factory AudioEffectApplyResult.off([String message = 'Audio effects are off; original playback is preserved.']) {
    return AudioEffectApplyResult(status: NativeAudioEffectStatus.off, message: message);
  }

  factory AudioEffectApplyResult.unsupported(String message) {
    return AudioEffectApplyResult(status: NativeAudioEffectStatus.unsupported, message: message);
  }

  factory AudioEffectApplyResult.failed(String message) {
    return AudioEffectApplyResult(status: NativeAudioEffectStatus.failed, message: message);
  }
}
