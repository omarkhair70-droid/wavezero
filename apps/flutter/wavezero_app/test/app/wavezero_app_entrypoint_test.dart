import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/app/wavezero_app.dart';

void main() {
  test('WaveZeroApp is the stable product entrypoint', () {
    const app = WaveZeroApp();
    expect(app, isA<StatefulWidget>());
  });
}
