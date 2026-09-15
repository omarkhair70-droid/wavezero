import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Web bridge exposes title, external open, and share actions', () {
    final bridge = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/WaveZeroWebViewBridge.kt',
    ).readAsStringSync();

    expect(bridge, contains('"title" to webView.title.orEmpty()'));
    expect(bridge, contains('"openExternal"'));
    expect(bridge, contains('Intent(Intent.ACTION_VIEW, Uri.parse(url))'));
    expect(bridge, contains('"shareUrl"'));
    expect(bridge, contains('Intent.ACTION_SEND'));
    expect(bridge, contains('putExtra(Intent.EXTRA_TEXT, url)'));
  });
}
