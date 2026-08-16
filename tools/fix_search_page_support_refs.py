from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/features/search/search_page.dart')
text = path.read_text()
text = text.replace(
    'WzCuratedTryPicksPanel(picks: curatedPicks, onPlayPick: onPlayCuratedPick)',
    'WzCuratedTryPicksPanel(picks: curatedPicks, onPlay: onPlayCuratedPick)',
)
text = text.replace('_DiscoveryPanel(', 'WzSearchDiscoveryPanel(')
text = text.replace('_DiscoveryButton(', 'WzSearchDiscoveryButton(')
path.write_text(text)
