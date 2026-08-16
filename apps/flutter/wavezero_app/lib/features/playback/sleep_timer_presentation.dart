class WzSleepTimerPresentation {
  const WzSleepTimerPresentation._();

  static String statusLabel({
    required DateTime? deadline,
    required DateTime now,
  }) {
    if (deadline == null) return 'Sleep timer';
    final remaining = deadline.difference(now);
    if (remaining.inSeconds <= 0) return 'Sleep timer ending';
    final minutes = remaining.inMinutes + (remaining.inSeconds % 60 == 0 ? 0 : 1);
    return 'Sleep in ${minutes}m';
  }

  static String settingsLabel({
    required DateTime? deadline,
    required DateTime now,
  }) {
    if (deadline == null) return 'Sleep timer off';
    return statusLabel(deadline: deadline, now: now);
  }
}
