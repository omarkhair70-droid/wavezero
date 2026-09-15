import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native download bridge exposes direct audio retry through DownloadManager', () {
    final source = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/WaveZeroWebViewBridge.kt',
    ).readAsStringSync();

    expect(source, contains('"enqueueDirectAudio"'));
    expect(source, contains('WaveZeroWebDownloads.enqueue('));
    expect(source, contains('WebSettings.getDefaultUserAgent(context)'));
    expect(source, contains('Only http/https downloads are supported.'));
    expect(source, contains('This link does not look like a supported audio file.'));
  });
}
