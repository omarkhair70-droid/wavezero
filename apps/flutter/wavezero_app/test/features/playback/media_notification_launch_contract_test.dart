import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media notification and MediaSession open the installed WaveZero app', () {
    final launchIntent = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/WaveZeroAppLaunchIntent.kt',
    ).readAsStringSync();
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();
    final service = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/WaveZeroMediaSessionService.kt',
    ).readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    // Keep the shared Kotlin module independent of the Flutter/Compose host class.
    expect(launchIntent, contains('getLaunchIntentForPackage(appContext.packageName)'));
    expect(launchIntent, contains('PendingIntent.getActivity('));
    expect(launchIntent, contains('Intent.FLAG_ACTIVITY_CLEAR_TOP'));
    expect(launchIntent, contains('Intent.FLAG_ACTIVITY_SINGLE_TOP'));
    expect(launchIntent, contains('PendingIntent.FLAG_IMMUTABLE'));
    expect(manager, contains('sessionBuilder.setSessionActivity(it)'));
    expect(service, contains('.setContentIntent(WaveZeroAppLaunchIntent.pendingIntent(this))'));
    expect(manifest, contains('android:launchMode="singleTop"'));
  });
}
