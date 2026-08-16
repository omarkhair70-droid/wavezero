from pathlib import Path

app_path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
app = app_path.read_text(encoding='utf-8')

old_home = '''          const SizedBox(height: WzSpacing.md),
          WzHomeCollectionsOfflineSection(
            collections: _collections,
            offlineTrackCount: _offlineCachedTrackCount,
            cacheBytes: _cacheBytes,
            onOpenCollections: () => _navigateTo(WzAppTab.collections),
            onOpenDownloads: () => _navigateTo(WzAppTab.downloads),
          ),
          const SizedBox(height: WzSpacing.md),
          WzHomeSmartListeningCards(
            smartDownloadsEnabled: _smartDownloadsEnabled,
            smartDownloadsCompleted: _smartDownloadCompletedCount,
            prefetchEnabled: _prefetchEnabled,
            prefetchedTrackTitle: _prefetchedTrackTitle,
            offlineReady: _offlineLibraryAvailable,
            offlineTrackCount: _offlineCachedTrackCount,
            qualityLabel: qualityLabel,
          ),
          const SizedBox(height: WzSpacing.md),
          WzHomeQuickActions(onNavigate: _navigateTo, showDeveloperTools: _developerMode),
          const SizedBox(height: WzSpacing.md),
          if (_developerMode) ...[
            WzDeveloperStatusStrip(status: _statusText, detail: _statusDetail, operation: _operation.label, refreshingMetrics: _refreshingMetrics),
            const SizedBox(height: WzSpacing.sm),
            WzDeveloperSessionStrip(status: _sessionStatus),
          ],
'''
new_home = '''          if (_developerMode) ...[
            const SizedBox(height: WzSpacing.md),
            WzHomeSmartListeningCards(
              smartDownloadsEnabled: _smartDownloadsEnabled,
              smartDownloadsCompleted: _smartDownloadCompletedCount,
              prefetchEnabled: _prefetchEnabled,
              prefetchedTrackTitle: _prefetchedTrackTitle,
              offlineReady: _offlineLibraryAvailable,
              offlineTrackCount: _offlineCachedTrackCount,
              qualityLabel: qualityLabel,
            ),
            const SizedBox(height: WzSpacing.md),
            WzHomeQuickActions(onNavigate: _navigateTo, showDeveloperTools: true),
            const SizedBox(height: WzSpacing.md),
            WzDeveloperStatusStrip(status: _statusText, detail: _statusDetail, operation: _operation.label, refreshingMetrics: _refreshingMetrics),
            const SizedBox(height: WzSpacing.sm),
            WzDeveloperSessionStrip(status: _sessionStatus),
          ],
'''
assert app.count(old_home) == 1, f'expected one Home system block, got {app.count(old_home)}'
app = app.replace(old_home, new_home, 1)

copy_replacements = {
    "Queue Engine v2 stays intact with cleaner product hierarchy.": "What plays next.",
    "Browse Catalog, Device music, and Downloaded tracks.": "Everything you can play, in one place.",
    "Offline Ready library with manual and smart cached tracks.": "Music saved for when you are offline.",
}
for old, new in copy_replacements.items():
    assert app.count(old) == 1, f'expected one copy occurrence for {old!r}, got {app.count(old)}'
    app = app.replace(old, new, 1)
app_path.write_text(app, encoding='utf-8')

home_path = Path('apps/flutter/wavezero_app/lib/features/home/home_curated_history.dart')
home = home_path.read_text(encoding='utf-8')
start = home.find('    if (shelves.isEmpty) {\n')
end = home.find('\n\n    return Column(', start)
assert start >= 0 and end > start, 'curated empty-state block not found'
home = home[:start] + '    if (shelves.isEmpty) return const SizedBox.shrink();' + home[end:]

old_demo_copy = '''        const SizedBox(height: WzSpacing.xs),
        const Text(CuratedDemoPicks.consumerCopy, style: WzText.caption),
        const SizedBox(height: WzSpacing.xxs),
        const Text(CuratedDemoPicks.artworkCopy, style: WzText.caption),
'''
assert home.count(old_demo_copy) == 1, f'expected one demo-copy block, got {home.count(old_demo_copy)}'
home = home.replace(old_demo_copy, '', 1)
assert 'Curated picks will appear when the demo catalog is loaded.' not in home
home_path.write_text(home, encoding='utf-8')
