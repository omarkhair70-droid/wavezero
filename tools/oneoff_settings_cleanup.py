from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
text = path.read_text(encoding='utf-8')

old_import = "import '../features/settings/settings_page.dart';"
new_import = "import '../features/settings/consumer_settings_page.dart';"
assert text.count(old_import) == 1, f'expected one settings import, got {text.count(old_import)}'
text = text.replace(old_import, new_import, 1)

start_marker = '    final settingsPage = WzSettingsPage(\n'
end_marker = '    final destinations = _developerMode ? wzDeveloperShellDestinations : wzConsumerShellDestinations;\n'
start = text.find(start_marker)
end = text.find(end_marker, start)
assert start >= 0, 'settingsPage start not found'
assert end > start, 'settingsPage end boundary not found'

replacement = '''    final settingsPage = WzConsumerSettingsPage(
      preferredAudioQuality: _preferredAudioQuality,
      onQualityChanged: (quality) => setState(() {
        _preferredAudioQuality = quality;
        _lastQualityFallbackReason = 'preferred quality set to ${quality.label}';
      }),
      smartDownloadsEnabled: _smartDownloadsEnabled,
      onSmartDownloadsChanged: (value) => setState(() => _smartDownloadsEnabled = value),
      cachedTrackCount: _cachedTrackCount,
      cacheBytes: _cacheBytes,
      controlsDisabled: _queueDisabled,
      onClearCache: _clearCache,
      onManageStorage: () => _navigateTo(WzAppTab.storage),
      onClearRecentSearches: _recentSearches.isEmpty ? null : () => unawaited(_clearRecentSearches()),
      onClearListeningHistory: _listeningHistory.isEmpty ? null : () => unawaited(_clearListeningHistory()),
      legalTracks: _libraryTracks,
    );

'''

text = text[:start] + replacement + text[end:]
assert 'final settingsPage = WzSettingsPage(' not in text
assert text.count('final settingsPage = WzConsumerSettingsPage(') == 1
path.write_text(text, encoding='utf-8')
