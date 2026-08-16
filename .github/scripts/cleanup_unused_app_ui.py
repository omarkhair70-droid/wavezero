from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
text = path.read_text(encoding='utf-8')


def remove_exact(snippet: str) -> None:
    global text
    count = text.count(snippet)
    if count != 1:
        raise SystemExit(f'Expected exact snippet once, found {count}: {snippet!r}')
    text = text.replace(snippet, '', 1)


def remove_between(start_marker: str, end_marker: str) -> None:
    global text
    start = text.find(start_marker)
    if start < 0:
        raise SystemExit(f'Start marker not found: {start_marker}')
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f'End marker not found after {start_marker}: {end_marker}')
    text = text[:start] + text[end:]


# Imports made stale by the Settings/Downloads extractions.
remove_exact("import '../features/settings/legal_licenses_page.dart';\n")
remove_exact("import '../shared/widgets/wavezero_empty_message.dart';\n")

# Unreferenced members inside the orchestrator.
remove_exact("  bool get _canShuffleNext => _queuePosition.canShuffleNext;\n")
remove_exact("  Future<void> _saveCollections() => _collectionsService.save(_collections);\n\n")
remove_between(
    '  CatalogTrackSummary _summaryFromSnapshot(WzCollectionTrackSnapshot snapshot)',
    '  CatalogTrackSummary? _resolveCollectionTrack(WzCollectionTrackSnapshot snapshot)',
)

# Obsolete presentation helpers left behind after Search/Home extraction.
remove_between('IconData _searchResultIcon(', 'class _DiscoveryPanel extends StatelessWidget {')
remove_between('class _DiscoveryPanel extends StatelessWidget {', 'Map<String, int> _cachedTrackSizeMap(')

# Old top bar and health widgets are no longer part of the active shell.
remove_between('class _TopBar extends StatelessWidget {', 'class _NowContextPanel extends StatelessWidget {')
remove_between('class _HealthStrip extends StatelessWidget {', 'class _DeveloperModePanel extends StatelessWidget {')

# Analyzer-confirmed unused legacy token aliases.
for line in [
    '  static const Color canvas = WzColors.canvas;\n',
    '  static const Color surfacePremium = WzColors.surfacePremium;\n',
    '  static const Color accentSoft = WzColors.accentSoft;\n',
    '  static const Color success = WzColors.success;\n',
    '  static const Color warningSoft = WzColors.warningSoft;\n',
    '  static const double space6 = 24;\n',
    '  static const Duration motionFast = WzMotion.fast;\n',
    '  static const TextStyle eyebrow = TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6);\n',
]:
    remove_exact(line)

remove_exact("const _timeStyle = TextStyle(color: Color(0xFF9BA3B4), fontSize: 12);\n")

for symbol in [
    '_canShuffleNext',
    '_saveCollections',
    '_summaryFromSnapshot',
    '_searchResultIcon',
    '_formatDuration',
    '_DiscoveryPanel',
    '_DiscoveryButton',
    '_TopBar',
    '_HealthStrip',
    '_HealthChip',
    '_timeStyle',
]:
    if symbol in text:
        raise SystemExit(f'Guard failed: {symbol} remains after cleanup')

path.write_text(text, encoding='utf-8')
print('Guarded unused app UI cleanup completed')
