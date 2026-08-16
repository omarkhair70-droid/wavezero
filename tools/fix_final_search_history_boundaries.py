from pathlib import Path

root = Path('apps/flutter/wavezero_app')
search = root / 'lib/features/search/search_page.dart'
history = root / 'lib/features/history/listening_history_page.dart'
app = root / 'lib/app/wavezero_app.dart'

text = search.read_text()
if "import 'dart:math' as math;" not in text:
    text = "import 'dart:math' as math;\n\n" + text
anchor = "import '../../catalog/catalog_track_manifest.dart';\n"
if "../../app/curated_demo_picks.dart" not in text:
    text = text.replace(anchor, "import '../../app/curated_demo_picks.dart';\n" + anchor, 1)
anchor2 = "import 'search_results.dart';\n"
if "search_page_support.dart" not in text:
    text = text.replace(anchor2, anchor2 + "import 'search_page_support.dart';\n", 1)
text = text.replace('_CuratedTryPicksPanel', 'WzCuratedTryPicksPanel')
text = text.replace('_searchResultIcon', 'wzSearchResultIcon')
search.write_text(text)

text = history.read_text()
text = text.replace('class _HistoryEntryTile extends StatelessWidget {', 'class WzHistoryEntryTile extends StatelessWidget {')
text = text.replace('  const _HistoryEntryTile({', '  const WzHistoryEntryTile({')
text = text.replace('_HistoryEntryTile(', 'WzHistoryEntryTile(')
history.write_text(text)

text = app.read_text()
text = text.replace('_HistoryEntryTile(', 'WzHistoryEntryTile(')
app.write_text(text)
