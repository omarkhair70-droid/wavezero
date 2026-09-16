import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each ExoPlayer gets its own live channel processor', () {
    final processor = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/WaveZeroChannelAudioProcessor.kt',
    ).readAsStringSync();
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();

    expect(processor, contains('class WaveZeroChannelAudioState'));
    expect(processor, contains('class WaveZeroAudioRenderersFactory'));
    expect(processor, contains('WaveZeroChannelAudioProcessor(channelState)'));
    expect(processor, contains('setAudioProcessors'));
    expect(manager, contains('WaveZeroAudioRenderersFactory(appContext, channelAudioState)'));
    expect(manager, contains('private fun buildPrimaryPlayer()'));
    expect(manager, contains('private fun buildPrebufferPlayer()'));
  });

  test('balance attenuates the opposite stereo channel without boost', () {
    final processor = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/WaveZeroChannelAudioProcessor.kt',
    ).readAsStringSync();

    expect(processor, contains('balance.coerceIn(-1.0, 1.0)'));
    expect(processor, contains('if (balance > 0.0) 1.0 - balance else 1.0'));
    expect(processor, contains('if (balance < 0.0) 1.0 + balance else 1.0'));
    expect(processor, contains('coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())'));
  });

  test('mono mixes left and right before applying balance', () {
    final processor = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/WaveZeroChannelAudioProcessor.kt',
    ).readAsStringSync();

    final monoIndex = processor.indexOf('val mixed = ((left + right) / 2.0).roundToInt()');
    final leftScaleIndex = processor.indexOf('scalePcm16(left, leftGain)');
    expect(monoIndex, greaterThanOrEqualTo(0));
    expect(leftScaleIndex, greaterThan(monoIndex));
    expect(processor, contains('inputAudioFormat.channelCount == 2'));
    expect(processor, contains('C.ENCODING_PCM_16BIT'));
  });

  test('channel controls persist and are exposed through settings bridge', () {
    final manager = File(
      '../../android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt',
    ).readAsStringSync();
    final settings = File('lib/features/settings/settings_page.dart').readAsStringSync();

    expect(manager, contains('CHANNEL_BALANCE_KEY'));
    expect(manager, contains('MONO_OUTPUT_KEY'));
    expect(manager, contains('fun setChannelBalance'));
    expect(manager, contains('fun setMonoOutput'));
    expect(activity, contains('"setChannelBalance"'));
    expect(activity, contains('"setMonoOutput"'));
    expect(activity, contains('"channelAudioStatus"'));
    expect(settings, contains("Text('Channel output'"));
    expect(settings, contains("title: const Text('Mono output')"));
    expect(settings, contains('Duration(milliseconds: 80)'));
  });
}
