from pathlib import Path

root = Path.cwd()
app_path = root / 'apps/flutter/wavezero_app/lib/app/wavezero_app.dart'
workflow_path = root / '.github/workflows/_oneoff_finish_consumer_navigation.yml'
script_path = root / 'tools/_oneoff_finish_consumer_navigation.py'
app = app_path.read_text(encoding='utf-8')

replacements = [
    (
'''      WzPageScaffold(
        children: [
          const WzPageHeader(icon: Icons.library_music, title: 'Library', subtitle: 'Everything you can play, in one place.'),
          const SizedBox(height: WzSpacing.md),
          WzLibraryCatalogPanel(''',
'''      WzPageScaffold(
        children: [
          WzLibraryCatalogPanel('''
    ),
    ('''        onBack: () => _navigateTo(WzAppTab.home),
        onOpen: _openCollection,''', '''        onBack: () => _navigateTo(WzAppTab.library),
        onOpen: _openCollection,'''),
    ('''      WzStorageManagerPage(
        downloads: _cachedLibrary,
        onBack: () => _navigateTo(WzAppTab.downloads),''', '''      WzStorageManagerPage(
        downloads: _cachedLibrary,
        onBack: () => _navigateTo(WzAppTab.settings),'''),
    ('''      WzListeningHistoryPage(
        entries: _listeningHistory,
        onBack: () => _navigateTo(WzAppTab.home),''', '''      WzListeningHistoryPage(
        entries: _listeningHistory,
        onBack: () => _navigateTo(WzAppTab.library),'''),
    ('''    final settingsPage = WzConsumerSettingsPage(
      preferredAudioQuality:''', '''    final settingsPage = WzConsumerSettingsPage(
      onBack: () => _navigateTo(WzAppTab.home),
      preferredAudioQuality:'''),
    ('''      bottomNavigationBar: WaveZeroBottomShell(
        destinations: destinations,
        currentIndex: currentIndex < 0 ? 0 : currentIndex,''', '''      bottomNavigationBar: currentIndex >= 0
          ? WaveZeroBottomShell(
              destinations: destinations,
              currentIndex: currentIndex,'''),
    ('''        onDestinationSelected: (i) => _navigateTo(destinations[i].tab),
        accent: widget.themeConfig.accent,
        miniPlayer: hasPlayerTrack
            ? WzConsumerMiniPlayer(
                metrics: _metrics,
                manifest: _manifest,
                progressValue: progress,
                controlsDisabled: _playerDisabled,
                onTap: _showPremiumPlayerSheet,
                onPlayPause: _playPause,
              )
            : null,
      ),
    );''', '''              onDestinationSelected: (i) => _navigateTo(destinations[i].tab),
              accent: widget.themeConfig.accent,
              miniPlayer: hasPlayerTrack
                  ? WzConsumerMiniPlayer(
                      metrics: _metrics,
                      manifest: _manifest,
                      progressValue: progress,
                      controlsDisabled: _playerDisabled,
                      onTap: _showPremiumPlayerSheet,
                      onPlayPause: _playPause,
                    )
                  : null,
            )
          : null,
    );'''),
]

for old, new in replacements:
    count = app.count(old)
    if count != 1:
        raise SystemExit(f'guard failed: expected one match, got {count}: {old[:80]!r}')
    app = app.replace(old, new, 1)

app_path.write_text(app, encoding='utf-8')
for path in (workflow_path, script_path):
    if path.exists():
        path.unlink()
