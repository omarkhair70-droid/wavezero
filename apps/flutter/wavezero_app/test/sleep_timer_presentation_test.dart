import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/playback/sleep_timer_presentation.dart';

void main() {
  final now = DateTime(2026, 8, 16, 8, 0, 0);

  test('status and settings labels preserve the off copy', () {
    expect(
      WzSleepTimerPresentation.statusLabel(deadline: null, now: now),
      'Sleep timer',
    );
    expect(
      WzSleepTimerPresentation.settingsLabel(deadline: null, now: now),
      'Sleep timer off',
    );
  });

  test('positive remaining time rounds up to the next minute', () {
    expect(
      WzSleepTimerPresentation.statusLabel(
        deadline: now.add(const Duration(minutes: 15)),
        now: now,
      ),
      'Sleep in 15m',
    );
    expect(
      WzSleepTimerPresentation.statusLabel(
        deadline: now.add(const Duration(minutes: 14, seconds: 1)),
        now: now,
      ),
      'Sleep in 15m',
    );
    expect(
      WzSleepTimerPresentation.statusLabel(
        deadline: now.add(const Duration(seconds: 1)),
        now: now,
      ),
      'Sleep in 1m',
    );
  });

  test('expired and sub-second deadlines keep the ending copy', () {
    expect(
      WzSleepTimerPresentation.statusLabel(deadline: now, now: now),
      'Sleep timer ending',
    );
    expect(
      WzSleepTimerPresentation.statusLabel(
        deadline: now.subtract(const Duration(seconds: 1)),
        now: now,
      ),
      'Sleep timer ending',
    );
  });

  test('settings label delegates to the active timer copy', () {
    expect(
      WzSleepTimerPresentation.settingsLabel(
        deadline: now.add(const Duration(minutes: 30)),
        now: now,
      ),
      'Sleep in 30m',
    );
  });
}
