from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    assert count == 1, f'{label}: expected 1 occurrence, got {count}'
    return text.replace(old, new, 1)

app_path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
app = app_path.read_text(encoding='utf-8')

app = replace_once(
    app,
    '        cloudTracks: _cloudCatalogTracks,\n',
    '        cloudTracks: _developerMode ? _cloudCatalogTracks : const <CatalogTrackSummary>[],\n',
    'consumer library cloud composition',
)
app = replace_once(
    app,
    '  int get _libraryCombinedTrackCount => _catalog.length + _deviceMusicTracks.length + _cachedLibrary.length + _cloudVaultTracks.length;\n',
    '  int get _libraryCombinedTrackCount => _catalog.length + _deviceMusicTracks.length + _cachedLibrary.length + (_developerMode ? _cloudVaultTracks.length : 0);\n',
    'consumer library count',
)
app = replace_once(
    app,
    '        _cloudVaultTracks.length,\n        _collections.length,\n',
    '        _cloudVaultTracks.length,\n        _developerMode,\n        _collections.length,\n',
    'search index mode key',
)
app = replace_once(
    app,
    '      cloudTracks: _cloudCatalogTracks,\n',
    '      cloudTracks: _developerMode ? _cloudCatalogTracks : const <CatalogTrackSummary>[],\n',
    'consumer search cloud composition',
)
app = replace_once(
    app,
    '    _loadCatalog(fallbackToDemo: true);\n',
    '    _loadCatalog(fallbackToDemo: false);\n',
    'consumer demo fallback',
)
app = replace_once(
    app,
    '    unawaited(_loadCloudVault());\n',
    '',
    'startup Cloud Vault load',
)
app = replace_once(
    app,
    '  Future<void> _openCloudVaultPage() async {\n    await Navigator.of(context).push(MaterialPageRoute<void>(\n',
    '  Future<void> _openCloudVaultPage() async {\n    if (!_developerMode) return;\n    await _loadCloudVault();\n    if (!mounted) return;\n    await Navigator.of(context).push(MaterialPageRoute<void>(\n',
    'developer-only Cloud Vault page',
)
app = replace_once(
    app,
    '            cloudTrackCount: _cloudVaultTracks.length,\n            combinedTrackCount: _libraryCombinedTrackCount,\n',
    '            cloudTrackCount: _developerMode ? _cloudVaultTracks.length : 0,\n            showCloudSource: _developerMode,\n            combinedTrackCount: _libraryCombinedTrackCount,\n',
    'library Cloud source flag',
)

set_mode_start = app.find('  Future<void> _setAppMode(WzAppMode mode) async {\n')
set_mode_end = app.find('  Future<void> _toggleAppMode()', set_mode_start)
assert set_mode_start >= 0 and set_mode_end > set_mode_start, 'setAppMode function boundaries not found'
old_set_mode = app[set_mode_start:set_mode_end]
assert '_appMode = mode;' in old_set_mode, 'setAppMode body shape changed'
assert '_appModePreferences.save(mode)' in old_set_mode, 'setAppMode persistence missing'
new_set_mode = '''  Future<void> _setAppMode(WzAppMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    await _appModePreferences.save(mode);
    if (!mounted) return;
    setState(() {
      _appMode = mode;
      if (mode == WzAppMode.consumer) {
        if (_selectedTab == WzAppTab.engine) _selectedTab = WzAppTab.home;
        if (_librarySourceFilter == WzLibrarySourceFilter.cloud) _librarySourceFilter = WzLibrarySourceFilter.all;
        _cloudVaultTracks = const <CloudVaultTrack>[];
        _invalidateCatalogMemos();
      }
    });
    messenger.showSnackBar(SnackBar(content: Text(mode == WzAppMode.developer ? 'Developer mode enabled' : 'Consumer mode enabled')));
  }

'''
app = app[:set_mode_start] + new_set_mode + app[set_mode_end:]
app_path.write_text(app, encoding='utf-8')

panel_path = Path('apps/flutter/wavezero_app/lib/features/library/library_catalog_panel.dart')
panel = panel_path.read_text(encoding='utf-8')
panel = replace_once(
    panel,
    '    required this.onDeleteCachedTrack,\n    this.offlineMode = false,\n',
    '    required this.onDeleteCachedTrack,\n    this.showCloudSource = false,\n    this.offlineMode = false,\n',
    'catalog panel constructor flag',
)
panel = replace_once(
    panel,
    '  final ValueChanged<CatalogTrackSummary> onDeleteCachedTrack;\n  final bool offlineMode;\n',
    '  final ValueChanged<CatalogTrackSummary> onDeleteCachedTrack;\n  final bool showCloudSource;\n  final bool offlineMode;\n',
    'catalog panel flag field',
)
panel = replace_once(
    panel,
    '            onOpenCloudVault: onOpenCloudVault,\n          ),\n',
    '            onOpenCloudVault: onOpenCloudVault,\n            showCloudSource: showCloudSource,\n          ),\n',
    'source overview Cloud flag',
)
panel_path.write_text(panel, encoding='utf-8')

overview_path = Path('apps/flutter/wavezero_app/lib/features/library/library_source_overview.dart')
overview = overview_path.read_text(encoding='utf-8')
overview = replace_once(
    overview,
    '    required this.onOpenCloudVault,\n  });\n',
    '    required this.onOpenCloudVault,\n    this.showCloudSource = false,\n  });\n',
    'source overview constructor flag',
)
overview = replace_once(
    overview,
    '  final VoidCallback onOpenCloudVault;\n\n  @override\n',
    '  final VoidCallback onOpenCloudVault;\n  final bool showCloudSource;\n\n  @override\n',
    'source overview flag field',
)
overview = replace_once(
    overview,
    "                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'Cloud', detail: '$cloudTrackCount local entries', status: 'Saved metadata • playback coming soon', icon: Icons.cloud_done_outlined, active: librarySourceFilter == WzLibrarySourceFilter.cloud)),\n",
    "                  if (showCloudSource) SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'Cloud', detail: '$cloudTrackCount local entries', status: 'Developer preview source', icon: Icons.cloud_done_outlined, active: librarySourceFilter == WzLibrarySourceFilter.cloud)),\n",
    'Cloud summary card',
)
overview = replace_once(
    overview,
    '            children: WzLibrarySourceFilter.values\n                .map(\n',
    '            children: WzLibrarySourceFilter.values\n                .where((filter) => showCloudSource || filter != WzLibrarySourceFilter.cloud)\n                .map(\n',
    'Cloud source filter',
)
overview = replace_once(
    overview,
    "              OutlinedButton.icon(onPressed: onOpenCloudVault, icon: const Icon(Icons.cloud_done_outlined), label: const Text('Cloud Vault')),\n",
    "              if (showCloudSource) OutlinedButton.icon(onPressed: onOpenCloudVault, icon: const Icon(Icons.cloud_done_outlined), label: const Text('Cloud Vault')),\n",
    'Cloud Vault action',
)
overview_path.write_text(overview, encoding='utf-8')
