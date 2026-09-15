import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android local video to audio path stays wired into WaveZero', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final extractor = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/WaveZeroVideoShareActivity.kt',
    ).readAsStringSync();
    final shareActivity = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/WaveZeroShareActivity.kt',
    ).readAsStringSync();

    expect(manifest, contains('android:name=".WaveZeroVideoShareActivity"'));
    expect(manifest, contains('android:mimeType="video/*"'));
    expect(gradle, contains('androidx.media3:media3-transformer:\$media3Version'));
    expect(extractor, contains('.setRemoveVideo(true)'));
    expect(extractor, contains('.setAudioMimeType(MimeTypes.AUDIO_AAC)'));
    expect(extractor, contains('WaveZeroImportInbox.append'));
    expect(extractor, contains('Music/WaveZero/Imports/'));
    expect(extractor, contains('.m4a'));
    expect(shareActivity, contains('internal object WaveZeroImportInbox'));
  });
}
