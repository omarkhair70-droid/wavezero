from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
text = path.read_text(encoding='utf-8')

needle = "import '../features/device_music/device_music_projection.dart';\n"
replacement = needle + "import '../features/device_music/device_music_recency.dart';\n"
if replacement not in text:
    if needle not in text:
        raise SystemExit('device projection import anchor missing')
    text = text.replace(needle, replacement, 1)

needle = "import '../features/home/consumer_home.dart';\n"
replacement = needle + "import '../features/home/home_device_recency.dart';\n"
if replacement not in text:
    if needle not in text:
        raise SystemExit('home import anchor missing')
    text = text.replace(needle, replacement, 1)

old_rank = """  int _libraryAddedRank(CatalogTrackSummary track) {\n    final cached = _cachedMetadataForTrack(track);\n    if (cached != null) return cached.cachedAt;\n    if (isWzDeviceCatalogTrack(track)) return _deviceMusicImportedAtMs ?? 0;\n    return 0;\n  }\n"""
new_rank = """  int _libraryAddedRank(CatalogTrackSummary track) {\n    final cached = _cachedMetadataForTrack(track);\n    if (cached != null) return cached.cachedAt;\n    if (isWzDeviceCatalogTrack(track)) {\n      final deviceTrack = wzFindDeviceTrackById(_deviceMusicTracks, track.trackId);\n      if (deviceTrack != null) return wzDeviceTrackAddedRank(deviceTrack);\n      return _deviceMusicImportedAtMs ?? 0;\n    }\n    return 0;\n  }\n"""
if new_rank not in text:
    if old_rank not in text:
        raise SystemExit('library rank block missing')
    text = text.replace(old_rank, new_rank, 1)

old_home = """          WzConsumerNowCard(\n            metrics: _metrics,\n            manifest: _manifest,\n            progressValue: progress,\n            onOpen: _showPremiumPlayerSheet,\n            onPlayPause: _playPause,\n            controlsDisabled: _playerDisabled,\n          ),\n          const SizedBox(height: WzSpacing.xl),\n          WzHomeCuratedDemoSection(\n"""
new_home = """          WzConsumerNowCard(\n            metrics: _metrics,\n            manifest: _manifest,\n            progressValue: progress,\n            onOpen: _showPremiumPlayerSheet,\n            onPlayPause: _playPause,\n            controlsDisabled: _playerDisabled,\n          ),\n          if (_deviceMusicTracks.isNotEmpty) ...[\n            const SizedBox(height: WzSpacing.xl),\n            WzHomeFreshDeviceSection(\n              tracks: wzFreshDeviceTracks(_deviceMusicTracks, limit: 8),\n              onPlay: (track) => _loadDeviceMusicTrack(track, autoPlay: true),\n              onAddToQueue: (track) => _addToQueue(wzCatalogSummaryFromDeviceTrack(track)),\n              onOpenDeviceMusic: () {\n                setState(() {\n                  _librarySourceFilter = WzLibrarySourceFilter.device;\n                  _visibleTrackCount = _initialVisibleTrackCount;\n                  _invalidateCatalogMemos();\n                });\n                _navigateTo(WzAppTab.library);\n                unawaited(_importDeviceMusic());\n              },\n            ),\n          ],\n          const SizedBox(height: WzSpacing.xl),\n          WzHomeCuratedDemoSection(\n"""
if new_home not in text:
    if old_home not in text:
        raise SystemExit('Home insertion anchor missing')
    text = text.replace(old_home, new_home, 1)

path.write_text(text, encoding='utf-8')
print('Daily Driver recency patch applied')
