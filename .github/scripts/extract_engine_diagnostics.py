from pathlib import Path

app_path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
target_path = Path('apps/flutter/wavezero_app/lib/features/developer/engine_diagnostics_page.dart')
text = app_path.read_text(encoding='utf-8')


def class_span(source: str, class_name: str):
    marker = f'class {class_name} extends StatelessWidget {{'
    start = source.find(marker)
    if start < 0:
        raise SystemExit(f'Class marker not found: {class_name}')
    brace = source.find('{', start)
    depth = 0
    end = None
    for i in range(brace, len(source)):
        ch = source[i]
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise SystemExit(f'Closing brace not found: {class_name}')
    return start, end, source[start:end]


def expression_span(source: str, start_marker: str):
    start = source.find(start_marker)
    if start < 0:
        raise SystemExit(f'Expression marker not found: {start_marker[:80]}')
    paren = source.find('(', start)
    depth = 0
    end = None
    for i in range(paren, len(source)):
        ch = source[i]
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end is None:
        raise SystemExit('Expression closing parenthesis not found')
    return start, end


engine_start_marker = "      WzPageScaffold(\n        children: [\n          const WzPageHeader(icon: Icons.engineering, title: 'Engine diagnostics'"
engine_start, engine_end = expression_span(text, engine_start_marker)
engine_call = '''      WzEngineDiagnosticsPage(
        developerMode: _developerMode,
        onDeveloperModeChanged: (enabled) => _setAppMode(enabled ? WzAppMode.developer : WzAppMode.consumer),
        apiBaseUrl: _apiBaseUrlController.text,
        contentStatus: _contentStatus,
        catalogStatus: _catalogStatus,
        catalogTrackCount: _catalog.length,
        visibleTrackCount: _effectiveVisibleTrackCount,
        filteredTrackCount: _filteredTrackCount,
        catalogLimit: _defaultCatalogLimit,
        largeCatalogMode: _largeCatalogMode,
        playbackStatus: _statusText,
        playbackDetail: _statusDetail,
        operationLabel: _operation.label,
        refreshingMetrics: _refreshingMetrics,
        metrics: _metrics,
        prefetchEnabled: _prefetchEnabled,
        prefetchedTrackId: _prefetchedTrackId,
        prefetchedTrackTitle: _prefetchedTrackTitle,
        prefetchInFlight: _prefetchInFlight,
        manifestPrefetched: _manifestPrefetched,
        audioPreparedBeforeNext: _audioPreparedBeforeNext,
        lastPrefetchHit: _lastPrefetchHit,
        prefetchHitCount: _prefetchHitCount,
        prefetchMissCount: _prefetchMissCount,
        nextTapToAudioMs: _nextTapToAudioMs,
        nextPreparedBeforePlay: _nextPreparedBeforePlay,
        smartQueueCandidateTrackId: _smartQueueCandidateTrackId,
        smartQueueReason: _smartQueueReason,
        controlsDisabled: _queueDisabled,
        onPrefetchToggle: _setPrefetchEnabled,
        smartDownloadsEnabled: _smartDownloadsEnabled,
        lastSmartDownloadTrackId: _lastSmartDownloadTrackId,
        lastSmartDownloadTitle: _lastSmartDownloadTitle,
        lastSmartDownloadReason: _lastSmartDownloadReason,
        lastSmartDownloadResult: _lastSmartDownloadResult,
        smartDownloadStartedCount: _smartDownloadStartedCount,
        smartDownloadCompletedCount: _smartDownloadCompletedCount,
        smartDownloadFailedCount: _smartDownloadFailedCount,
        smartDownloadSkippedCount: _smartDownloadSkippedCount,
        smartDownloadInFlight: _autoCacheInFlight.length,
        onSmartDownloadsToggle: (value) => setState(() => _smartDownloadsEnabled = value),
        preferredAudioQuality: _preferredAudioQuality,
        manifest: _manifest,
        currentAssetUrl: _currentAssetUrl,
        currentCachedQuality: _currentCachedQuality,
        lastQualityFallbackReason: _lastQualityFallbackReason,
        onAudioQualityChanged: (quality) => setState(() {
          _preferredAudioQuality = quality;
          _lastQualityFallbackReason = 'preferred quality set to ${quality.label}';
        }),
        selectedAudioEffectProfile: _selectedAudioEffectProfile,
        nativeAudioEffectStatus: _nativeAudioEffectStatus,
        lastAudioEffectApplyResult: _lastAudioEffectApplyResult,
        onAudioEffectChanged: _setAudioEffectProfile,
        cachedTrackCount: _cachedTrackCount,
        cacheBytes: _cacheBytes,
        offlineLibraryAvailable: _offlineLibraryAvailable,
        offlineCachedTrackCount: _offlineCachedTrackCount,
        manualDownloadedCount: _manualDownloadedCount,
        smartDownloadedCount: _smartDownloadedCount,
        lastOfflineLibraryStatus: _lastOfflineLibraryStatus,
        lastCacheResult: _lastCacheResult,
        lastCacheDeleteResult: _lastCacheDeleteResult,
        onClearCache: _clearCache,
        devicePermissionStatus: _deviceMusicPermissionStatus.status,
        devicePlatformSupported: _deviceMusicPermissionStatus.platformSupported,
        importedDeviceTrackCount: _deviceMusicTracks.length,
        deviceScanStatus: _deviceMusicScanStatus,
        deviceLastError: _deviceMusicLastError,
        deviceImportedAtMs: _deviceMusicImportedAtMs,
        librarySourceLabel: _librarySourceFilter.label,
        libraryFilteredResultCount: _filteredCatalog.length,
        librarySortLabel: _librarySortMode.label,
        deviceImportCount: _deviceMusicTracks.length,
        cachedLibraryCount: _cachedLibrary.length,
        stopToPlayRecoveryMs: _stopToPlayRecoveryMs,
        sessionRecoveryMs: _sessionRecoveryMs,
        showMetrics: _showMetrics,
        operationBusy: _operation != PlayerOperation.idle,
        onToggleMetrics: () => setState(() => _showMetrics = !_showMetrics),
        onCopyMetrics: _copyMetrics,
        onResetMetrics: _resetMetrics,
      )'''
text = text[:engine_start] + engine_call + text[engine_end:]

class_names = [
    '_AudioQualityPanel',
    '_DeviceMusicDiagnosticsPanel',
    '_LibraryDiagnosticsPanel',
    '_CacheDiagnosticsPanel',
    '_StatusStrip',
    '_PerformanceBaselinePanel',
    '_AudioEffectsPanel',
    '_SmartPreloadCard',
    '_SmartDownloadsCard',
    '_PanelHeader',
    '_MetricSection',
    '_MetricCard',
    '_ContentServerDiagnosticsPanel',
    '_DeveloperModePanel',
    '_MetricsToggle',
    '_MetricsPanel',
]

blocks = []
# Capture from the original-ish transformed text before deleting, then delete one by one with fresh offsets.
for name in class_names:
    _, _, block = class_span(text, name)
    blocks.append(block)
for name in class_names:
    start, end, _ = class_span(text, name)
    text = text[:start] + text[end:]

# Remove diagnostics-only helpers from the app file.
for line in [
    "String _prefetchResultLabel(bool? value) {\n  if (value == null) return 'none';\n  return value ? 'hit' : 'miss';\n}\n",
    "String _formatMetric(int? valueMs) => valueMs == null ? '—' : '${valueMs}ms';\n",
]:
    if text.count(line) != 1:
        raise SystemExit(f'Expected diagnostics helper exactly once: {line[:40]}')
    text = text.replace(line, '', 1)

import_line = "import '../features/developer/engine_diagnostics_page.dart';\n"
anchor = "import '../features/device_music/device_music_projection.dart';\n"
if import_line not in text:
    if anchor not in text:
        raise SystemExit('Developer import anchor missing')
    text = text.replace(anchor, anchor + import_line, 1)

for name in class_names:
    if f'class {name} ' in text:
        raise SystemExit(f'Old diagnostics class remains: {name}')
if "title: 'Engine diagnostics'" in text:
    raise SystemExit('Old inline Engine page remains')
if '_formatMetric(' in text or '_prefetchResultLabel(' in text:
    raise SystemExit('Diagnostics-only helper remains in app file')
if text.count('WzEngineDiagnosticsPage(') != 1:
    raise SystemExit('Expected one Engine diagnostics callsite')

# Convert the moved classes to developer-local primitives backed by the shared design system.
joined = '\n\n'.join(blocks)
replacements = {
    '_PanelHeader': '_DiagnosticsPanelHeader',
    '_MetricSection': '_DiagnosticsMetricSection',
    '_MetricCard': '_DiagnosticsMetricCard',
    '_Panel(': '_DiagnosticsPanel(',
    '_WzTokens.space1': 'WzSpacing.xxs',
    '_WzTokens.space2': 'WzSpacing.xs',
    '_WzTokens.space3': 'WzSpacing.sm',
    '_WzTokens.space4': 'WzSpacing.md',
    '_WzTokens.space5': 'WzSpacing.lg',
    '_WzTokens.radiusMd': 'WzRadius.md',
    '_WzTokens.radiusLg': 'WzRadius.lg',
    '_WzTokens.radiusXl': 'WzRadius.xl',
    '_WzTokens.surface': 'WzColors.surface',
    '_WzTokens.surfaceElevated': 'WzColors.surfaceElevated',
    '_WzTokens.surfaceMuted': 'WzColors.surfaceMuted',
    '_WzTokens.border': 'WzColors.border',
    '_WzTokens.borderSoft': 'WzColors.borderSoft',
    '_WzTokens.accent': 'WzColors.accent',
    '_WzTokens.successSoft': 'WzColors.successSoft',
    '_WzTokens.warning': 'WzColors.warning',
    '_WzTokens.textPrimary': 'WzColors.textPrimary',
    '_WzTokens.textMuted': 'WzColors.textMuted',
    '_WzTokens.textSubtle': 'WzColors.textSubtle',
    '_WzTokens.title': 'WzText.title',
    '_WzTokens.body': 'WzText.body',
    '_WzTokens.caption': 'WzText.caption',
}
for old, new in replacements.items():
    joined = joined.replace(old, new)
if '_WzTokens.' in joined or '_Panel(' in joined or '_PanelHeader' in joined or '_MetricCard' in joined or '_MetricSection' in joined:
    raise SystemExit('Private app presentation dependency remains in moved diagnostics blocks')

page = r'''class WzEngineDiagnosticsPage extends StatelessWidget {
  const WzEngineDiagnosticsPage({
    super.key,
    required this.developerMode,
    required this.onDeveloperModeChanged,
    required this.apiBaseUrl,
    required this.contentStatus,
    required this.catalogStatus,
    required this.catalogTrackCount,
    required this.visibleTrackCount,
    required this.filteredTrackCount,
    required this.catalogLimit,
    required this.largeCatalogMode,
    required this.playbackStatus,
    required this.playbackDetail,
    required this.operationLabel,
    required this.refreshingMetrics,
    required this.metrics,
    required this.prefetchEnabled,
    required this.prefetchedTrackId,
    required this.prefetchedTrackTitle,
    required this.prefetchInFlight,
    required this.manifestPrefetched,
    required this.audioPreparedBeforeNext,
    required this.lastPrefetchHit,
    required this.prefetchHitCount,
    required this.prefetchMissCount,
    required this.nextTapToAudioMs,
    required this.nextPreparedBeforePlay,
    required this.smartQueueCandidateTrackId,
    required this.smartQueueReason,
    required this.controlsDisabled,
    required this.onPrefetchToggle,
    required this.smartDownloadsEnabled,
    required this.lastSmartDownloadTrackId,
    required this.lastSmartDownloadTitle,
    required this.lastSmartDownloadReason,
    required this.lastSmartDownloadResult,
    required this.smartDownloadStartedCount,
    required this.smartDownloadCompletedCount,
    required this.smartDownloadFailedCount,
    required this.smartDownloadSkippedCount,
    required this.smartDownloadInFlight,
    required this.onSmartDownloadsToggle,
    required this.preferredAudioQuality,
    required this.manifest,
    required this.currentAssetUrl,
    required this.currentCachedQuality,
    required this.lastQualityFallbackReason,
    required this.onAudioQualityChanged,
    required this.selectedAudioEffectProfile,
    required this.nativeAudioEffectStatus,
    required this.lastAudioEffectApplyResult,
    required this.onAudioEffectChanged,
    required this.cachedTrackCount,
    required this.cacheBytes,
    required this.offlineLibraryAvailable,
    required this.offlineCachedTrackCount,
    required this.manualDownloadedCount,
    required this.smartDownloadedCount,
    required this.lastOfflineLibraryStatus,
    required this.lastCacheResult,
    required this.lastCacheDeleteResult,
    required this.onClearCache,
    required this.devicePermissionStatus,
    required this.devicePlatformSupported,
    required this.importedDeviceTrackCount,
    required this.deviceScanStatus,
    required this.deviceLastError,
    required this.deviceImportedAtMs,
    required this.librarySourceLabel,
    required this.libraryFilteredResultCount,
    required this.librarySortLabel,
    required this.deviceImportCount,
    required this.cachedLibraryCount,
    required this.stopToPlayRecoveryMs,
    required this.sessionRecoveryMs,
    required this.showMetrics,
    required this.operationBusy,
    required this.onToggleMetrics,
    required this.onCopyMetrics,
    required this.onResetMetrics,
  });

  final bool developerMode;
  final ValueChanged<bool> onDeveloperModeChanged;
  final String apiBaseUrl;
  final ContentStatus? contentStatus;
  final String catalogStatus;
  final int catalogTrackCount;
  final int visibleTrackCount;
  final int filteredTrackCount;
  final int catalogLimit;
  final bool largeCatalogMode;
  final String playbackStatus;
  final String playbackDetail;
  final String operationLabel;
  final bool refreshingMetrics;
  final PlaybackMetrics metrics;
  final bool prefetchEnabled;
  final String? prefetchedTrackId;
  final String? prefetchedTrackTitle;
  final bool prefetchInFlight;
  final bool manifestPrefetched;
  final bool audioPreparedBeforeNext;
  final bool? lastPrefetchHit;
  final int prefetchHitCount;
  final int prefetchMissCount;
  final int? nextTapToAudioMs;
  final bool nextPreparedBeforePlay;
  final String? smartQueueCandidateTrackId;
  final String smartQueueReason;
  final bool controlsDisabled;
  final ValueChanged<bool> onPrefetchToggle;
  final bool smartDownloadsEnabled;
  final String? lastSmartDownloadTrackId;
  final String? lastSmartDownloadTitle;
  final String? lastSmartDownloadReason;
  final String? lastSmartDownloadResult;
  final int smartDownloadStartedCount;
  final int smartDownloadCompletedCount;
  final int smartDownloadFailedCount;
  final int smartDownloadSkippedCount;
  final int smartDownloadInFlight;
  final ValueChanged<bool> onSmartDownloadsToggle;
  final AudioQualityTier preferredAudioQuality;
  final CatalogTrackManifest? manifest;
  final String? currentAssetUrl;
  final String? currentCachedQuality;
  final String lastQualityFallbackReason;
  final ValueChanged<AudioQualityTier> onAudioQualityChanged;
  final AudioEffectProfile selectedAudioEffectProfile;
  final NativeAudioEffectStatus nativeAudioEffectStatus;
  final String lastAudioEffectApplyResult;
  final ValueChanged<AudioEffectProfile> onAudioEffectChanged;
  final int cachedTrackCount;
  final int cacheBytes;
  final bool offlineLibraryAvailable;
  final int offlineCachedTrackCount;
  final int manualDownloadedCount;
  final int smartDownloadedCount;
  final String lastOfflineLibraryStatus;
  final String? lastCacheResult;
  final String? lastCacheDeleteResult;
  final Future<void> Function() onClearCache;
  final String devicePermissionStatus;
  final bool devicePlatformSupported;
  final int importedDeviceTrackCount;
  final String deviceScanStatus;
  final String? deviceLastError;
  final int? deviceImportedAtMs;
  final String librarySourceLabel;
  final int libraryFilteredResultCount;
  final String librarySortLabel;
  final int deviceImportCount;
  final int cachedLibraryCount;
  final int? stopToPlayRecoveryMs;
  final int? sessionRecoveryMs;
  final bool showMetrics;
  final bool operationBusy;
  final VoidCallback onToggleMetrics;
  final VoidCallback onCopyMetrics;
  final VoidCallback onResetMetrics;

  @override
  Widget build(BuildContext context) => WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.engineering,
            title: 'Engine diagnostics',
            subtitle: 'Advanced playback, preload, cache, quality, and effects diagnostics remain available.',
          ),
          const SizedBox(height: WzSpacing.md),
          _DeveloperModePanel(enabled: developerMode, onChanged: onDeveloperModeChanged),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Content Server', subtitle: 'Developer-only catalog and content status.', icon: Icons.cloud_queue),
          _ContentServerDiagnosticsPanel(
            apiBaseUrl: apiBaseUrl,
            status: contentStatus,
            catalogStatus: catalogStatus,
            catalogTrackCount: catalogTrackCount,
            visibleTrackCount: visibleTrackCount,
            filteredTrackCount: filteredTrackCount,
            catalogLimit: catalogLimit,
            largeCatalogMode: largeCatalogMode,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Playback Engine', subtitle: 'Current player state and operation summary.', icon: Icons.graphic_eq),
          _StatusStrip(status: playbackStatus, detail: playbackDetail, operation: operationLabel, refreshingMetrics: refreshingMetrics),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Smart Preload', subtitle: 'Instant Next readiness and preload hit/miss telemetry.', icon: Icons.offline_bolt),
          _SmartPreloadCard(
            metrics: metrics,
            enabled: prefetchEnabled,
            prefetchedTrackId: prefetchedTrackId,
            prefetchedTrackTitle: prefetchedTrackTitle,
            prefetchInFlight: prefetchInFlight,
            manifestPrefetched: manifestPrefetched,
            audioPreparedBeforeNext: audioPreparedBeforeNext,
            lastPrefetchHit: lastPrefetchHit,
            prefetchHitCount: prefetchHitCount,
            prefetchMissCount: prefetchMissCount,
            nextTapToAudioMs: nextTapToAudioMs,
            nextPreparedBeforePlay: nextPreparedBeforePlay,
            smartQueueCandidateTrackId: smartQueueCandidateTrackId,
            smartQueueReason: smartQueueReason,
            controlsDisabled: controlsDisabled,
            onToggle: onPrefetchToggle,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Smart Downloads', subtitle: 'Predictive cache activity and counters.', icon: Icons.download_for_offline),
          _SmartDownloadsCard(
            enabled: smartDownloadsEnabled,
            lastTrackId: lastSmartDownloadTrackId,
            lastTitle: lastSmartDownloadTitle,
            lastReason: lastSmartDownloadReason,
            lastResult: lastSmartDownloadResult,
            startedCount: smartDownloadStartedCount,
            completedCount: smartDownloadCompletedCount,
            failedCount: smartDownloadFailedCount,
            skippedCount: smartDownloadSkippedCount,
            inFlight: smartDownloadInFlight,
            onToggle: onSmartDownloadsToggle,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Audio Quality', subtitle: 'Preferred and currently selected audio asset quality.', icon: Icons.high_quality),
          _AudioQualityPanel(
            preferredAudioQuality: preferredAudioQuality,
            manifest: manifest,
            currentAssetUrl: currentAssetUrl,
            currentCachedQuality: currentCachedQuality,
            lastQualityFallbackReason: lastQualityFallbackReason,
            controlsDisabled: controlsDisabled,
            onSelected: (values) => onAudioQualityChanged(values.first),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Audio Effects', subtitle: 'Effect profile bridge status and diagnostics.', icon: Icons.tune),
          _AudioEffectsPanel(
            selectedProfile: selectedAudioEffectProfile,
            nativeStatus: nativeAudioEffectStatus,
            lastApplyResult: lastAudioEffectApplyResult,
            preferredAudioQuality: preferredAudioQuality,
            controlsDisabled: controlsDisabled,
            onSelected: onAudioEffectChanged,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Cache / Offline', subtitle: 'Manual downloads, smart downloads, and offline library counters.', icon: Icons.offline_pin),
          _CacheDiagnosticsPanel(
            cachedTrackCount: cachedTrackCount,
            cacheBytes: cacheBytes,
            offlineLibraryAvailable: offlineLibraryAvailable,
            offlineCachedTrackCount: offlineCachedTrackCount,
            manualDownloadedCount: manualDownloadedCount,
            smartDownloadedCount: smartDownloadedCount,
            lastOfflineLibraryStatus: lastOfflineLibraryStatus,
            lastCacheResult: lastCacheResult,
            lastCacheDeleteResult: lastCacheDeleteResult,
            controlsDisabled: controlsDisabled,
            onClearCache: onClearCache,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Device music', subtitle: 'Android MediaStore import diagnostics.', icon: Icons.perm_media),
          _DeviceMusicDiagnosticsPanel(
            permissionStatus: devicePermissionStatus,
            platformSupported: devicePlatformSupported,
            importedCount: importedDeviceTrackCount,
            lastScanStatus: deviceScanStatus,
            lastError: deviceLastError,
            importedAtMs: deviceImportedAtMs,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Library v2', subtitle: 'Unified library filter, search, and source diagnostics.', icon: Icons.library_music),
          _LibraryDiagnosticsPanel(
            selectedSource: librarySourceLabel,
            filteredResultCount: libraryFilteredResultCount,
            sortMode: librarySortLabel,
            deviceImportCount: deviceImportCount,
            cachedLibraryCount: cachedLibraryCount,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Raw Metrics', subtitle: 'Complete developer telemetry keeps original metric names.', icon: Icons.data_object),
          _PerformanceBaselinePanel(
            metrics: metrics,
            nextTapToAudioMs: nextTapToAudioMs,
            prefetchHitCount: prefetchHitCount,
            prefetchMissCount: prefetchMissCount,
            stopToPlayRecoveryMs: stopToPlayRecoveryMs,
            sessionRecoveryMs: sessionRecoveryMs,
            audioPreparedBeforeNext: audioPreparedBeforeNext,
            nextPreparedBeforePlay: nextPreparedBeforePlay,
          ),
          const SizedBox(height: WzSpacing.md),
          _MetricsToggle(
            showMetrics: showMetrics,
            operationBusy: operationBusy,
            onToggle: onToggleMetrics,
            onCopyMetrics: onCopyMetrics,
            onResetMetrics: onResetMetrics,
          ),
          if (showMetrics) ...[
            const SizedBox(height: WzSpacing.md),
            _MetricsPanel(metrics: metrics),
          ],
        ],
      );
}
'''

imports = '''import 'package:flutter/material.dart';

import '../../audio/audio_effects.dart';
import '../../catalog/audio_quality.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../playback/playback_metrics.dart';

'''

primitives = r'''class _DiagnosticsPanel extends StatelessWidget {
  const _DiagnosticsPanel({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: WzSurface.panel(),
        child: Padding(padding: padding, child: child),
      );
}

String _formatMetric(int? valueMs) => valueMs == null ? '—' : '${valueMs}ms';

String _prefetchResultLabel(bool? value) {
  if (value == null) return 'none';
  return value ? 'hit' : 'miss';
}
'''

target_path.parent.mkdir(parents=True, exist_ok=True)
target_path.write_text(imports + page + '\n' + joined.strip() + '\n\n' + primitives, encoding='utf-8')
app_path.write_text(text, encoding='utf-8')
print(f'Extracted Engine diagnostics with {len(class_names)} private presentation classes')
