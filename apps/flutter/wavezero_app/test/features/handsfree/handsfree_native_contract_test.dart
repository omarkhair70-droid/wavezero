import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hands-free mode is registered as a microphone foreground service', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE_MICROPHONE'));
    expect(manifest, contains('android:name=".WaveZeroVoiceService"'));
    expect(manifest, contains('android:foregroundServiceType="microphone"'));
    expect(manifest, contains('android:name=".WaveZeroHandsFreeTileService"'));
    expect(manifest, contains('android.permission.BIND_QUICK_SETTINGS_TILE'));
  });

  test('voice layer understands wake phrase and core playback commands', () {
    final parser = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/WaveZeroVoiceCommandParser.kt',
    ).readAsStringSync();

    expect(parser, contains('"wave zero"'));
    expect(parser, contains('"ويف زيرو"'));
    expect(parser, contains('data object VolumeDown'));
    expect(parser, contains('data object VolumeUp'));
    expect(parser, contains('data class SeekBy'));
    expect(parser, contains('data class PlayLocalTrack'));
    expect(parser, contains('"ارجع"'));
    expect(parser, contains('"شغلي '));
  });

  test('voice service controls the existing native WaveZero playback session', () {
    final service = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/WaveZeroVoiceService.kt',
    ).readAsStringSync();

    expect(service, contains('WaveZeroPlaybackSession.getOrCreate'));
    expect(service, contains('player.play()'));
    expect(service, contains('player.pause()'));
    expect(service, contains('player.playNextFromNotification()'));
    expect(service, contains('player.playPreviousFromNotification()'));
    expect(service, contains('player.seekTo('));
    expect(service, contains('AudioManager.ADJUST_LOWER'));
    expect(service, contains('AudioManager.ADJUST_RAISE'));
  });

  test('local song request searches MediaStore and plays through the same engine', () {
    final service = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/WaveZeroVoiceService.kt',
    ).readAsStringSync();

    expect(service, contains('MediaStore.Audio.Media.EXTERNAL_CONTENT_URI'));
    expect(service, contains('NotificationTrackSnapshot.SOURCE_DEVICE'));
    expect(service, contains('player.loadTrack(match)'));
    expect(service, contains('WaveZeroPlaybackSession.showMediaControls(this)'));
  });
}
