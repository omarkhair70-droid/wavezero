import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/audio/audio_effects.dart';
import 'package:wavezero_app/features/playback/player_presentation.dart';

void main() {
  test('player source labels preserve consumer precedence', () {
    expect(
      wzPlayerSourceLabel(isPlayingFromCache: true, offlineReady: true, hasTrack: true),
      'Downloaded',
    );
    expect(
      wzPlayerSourceLabel(isPlayingFromCache: false, offlineReady: true, hasTrack: true),
      'Catalog',
    );
    expect(
      wzPlayerSourceLabel(isPlayingFromCache: false, offlineReady: true, hasTrack: false),
      'Offline Ready',
    );
    expect(
      wzPlayerSourceLabel(isPlayingFromCache: false, offlineReady: false, hasTrack: false),
      'Not cached',
    );
  });

  test('audio effect status labels preserve player copy', () {
    expect(wzEffectStatusLabel(NativeAudioEffectStatus.applied), 'Applied');
    expect(wzEffectStatusLabel(NativeAudioEffectStatus.unsupported), 'Unsupported');
    expect(wzEffectStatusLabel(NativeAudioEffectStatus.pending), 'Pending');
    expect(wzEffectStatusLabel(NativeAudioEffectStatus.failed), 'Failed');
    expect(wzEffectStatusLabel(NativeAudioEffectStatus.off), 'Off');
  });
}
