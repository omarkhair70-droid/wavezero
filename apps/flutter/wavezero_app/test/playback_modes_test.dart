import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/playback/playback_modes.dart';

void main() {
  test('repeat mode cycles through off, one, all, then off', () {
    expect(WzRepeatMode.off.next, WzRepeatMode.one);
    expect(WzRepeatMode.one.next, WzRepeatMode.all);
    expect(WzRepeatMode.all.next, WzRepeatMode.off);
    expect(WzRepeatMode.values.map((mode) => mode.name).toList(), ['off', 'one', 'all']);
  });

  test('repeat labels remain stable for persisted playback UI', () {
    expect(WzRepeatMode.off.label, 'Repeat off');
    expect(WzRepeatMode.one.label, 'Repeat one');
    expect(WzRepeatMode.all.label, 'Repeat all');
  });

  test('sleep timer presets keep persisted names and durations', () {
    expect(
      WzSleepTimerPreset.values.map((preset) => preset.name).toList(),
      ['off', 'minutes15', 'minutes30', 'minutes45', 'minutes60'],
    );
    expect(WzSleepTimerPreset.off.duration, isNull);
    expect(WzSleepTimerPreset.minutes15.duration, const Duration(minutes: 15));
    expect(WzSleepTimerPreset.minutes30.duration, const Duration(minutes: 30));
    expect(WzSleepTimerPreset.minutes45.duration, const Duration(minutes: 45));
    expect(WzSleepTimerPreset.minutes60.duration, const Duration(minutes: 60));
  });
}
