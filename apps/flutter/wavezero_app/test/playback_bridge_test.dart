import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/playback/playback_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('wavezero/playback-test');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('successful metrics refresh clears an older bridge transport error', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'play') {
        throw PlatformException(code: 'temporary_bridge_failure', message: 'temporary failure');
      }
      if (call.method == 'metricsSnapshot') {
        return <String, Object?>{
          'isPlaying': false,
          'currentPositionMs': 0,
          'lastEvent': 'ready',
        };
      }
      return null;
    });

    final bridge = PlatformChannelPlaybackBridge(channel: channel);

    await bridge.play();
    final recovered = await bridge.metricsSnapshot();

    expect(recovered.playbackError, isNull);
    expect(recovered.lastEvent, 'ready');
  });

  test('successful metrics refresh preserves a real native playback error', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'metricsSnapshot') {
        return <String, Object?>{
          'isPlaying': false,
          'playbackError': 'decoder failed',
          'lastEvent': 'error',
        };
      }
      return null;
    });

    final bridge = PlatformChannelPlaybackBridge(channel: channel);
    final metrics = await bridge.metricsSnapshot();

    expect(metrics.playbackError, 'decoder failed');
    expect(metrics.lastEvent, 'error');
  });
}
