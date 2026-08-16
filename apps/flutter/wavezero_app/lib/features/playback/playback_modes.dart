import 'package:flutter/material.dart';

enum WzRepeatMode { off, one, all }

enum WzSleepTimerPreset { off, minutes15, minutes30, minutes45, minutes60 }

extension WzRepeatModePresentation on WzRepeatMode {
  String get label => switch (this) {
        WzRepeatMode.off => 'Repeat off',
        WzRepeatMode.one => 'Repeat one',
        WzRepeatMode.all => 'Repeat all',
      };

  IconData get icon => switch (this) {
        WzRepeatMode.off => Icons.repeat,
        WzRepeatMode.one => Icons.repeat_one,
        WzRepeatMode.all => Icons.repeat,
      };

  WzRepeatMode get next => switch (this) {
        WzRepeatMode.off => WzRepeatMode.one,
        WzRepeatMode.one => WzRepeatMode.all,
        WzRepeatMode.all => WzRepeatMode.off,
      };
}

extension WzSleepTimerPresetPresentation on WzSleepTimerPreset {
  String get label => switch (this) {
        WzSleepTimerPreset.off => 'Off',
        WzSleepTimerPreset.minutes15 => '15 minutes',
        WzSleepTimerPreset.minutes30 => '30 minutes',
        WzSleepTimerPreset.minutes45 => '45 minutes',
        WzSleepTimerPreset.minutes60 => '60 minutes',
      };

  Duration? get duration => switch (this) {
        WzSleepTimerPreset.off => null,
        WzSleepTimerPreset.minutes15 => const Duration(minutes: 15),
        WzSleepTimerPreset.minutes30 => const Duration(minutes: 30),
        WzSleepTimerPreset.minutes45 => const Duration(minutes: 45),
        WzSleepTimerPreset.minutes60 => const Duration(minutes: 60),
      };
}
