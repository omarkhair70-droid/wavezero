from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../features/history/listening_history_service.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one History import anchor, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../features/history/history_selection.dart';\n", 1)

old_continue = "  WzListeningHistoryEntry? get _continueListeningEntry => _listeningHistory.isEmpty ? null : _listeningHistory.first;"
new_continue = "  WzListeningHistoryEntry? get _continueListeningEntry => wzContinueListeningEntry(_listeningHistory);"
if text.count(old_continue) != 1:
    raise SystemExit(f'expected one continue-listening getter, found {text.count(old_continue)}')
text = text.replace(old_continue, new_continue, 1)

old_most = """  WzListeningHistoryEntry? get _mostPlayedHistoryEntry {
    if (_listeningHistory.isEmpty) return null;
    final entries = [..._listeningHistory]..sort((a, b) {
        final byPlays = b.playCount.compareTo(a.playCount);
        return byPlays == 0 ? b.lastPlayedAtMs.compareTo(a.lastPlayedAtMs) : byPlays;
      });
    return entries.first;
  }
"""
new_most = "  WzListeningHistoryEntry? get _mostPlayedHistoryEntry => wzMostPlayedHistoryEntry(_listeningHistory);\n"
if text.count(old_most) != 1:
    raise SystemExit(f'expected one most-played getter, found {text.count(old_most)}')
text = text.replace(old_most, new_most, 1)
path.write_text(text)
