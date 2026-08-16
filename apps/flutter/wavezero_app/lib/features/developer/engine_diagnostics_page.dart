import 'package:flutter/material.dart';

import '../../audio/audio_effects.dart';
import '../../catalog/audio_quality.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../playback/playback_metrics.dart';

class WzEngineDiagnosticsPage extends StatelessWidget {
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

class _AudioQualityPanel extends StatelessWidget {
  const _AudioQualityPanel({required this.preferredAudioQuality, required this.manifest, required this.currentAssetUrl, required this.currentCachedQuality, required this.lastQualityFallbackReason, required this.controlsDisabled, required this.onSelected});
  final AudioQualityTier preferredAudioQuality;
  final CatalogTrackManifest? manifest;
  final String? currentAssetUrl;
  final String? currentCachedQuality;
  final String lastQualityFallbackReason;
  final bool controlsDisabled;
  final ValueChanged<Set<AudioQualityTier>> onSelected;
  @override
  Widget build(BuildContext context) => _DiagnosticsPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _DiagnosticsPanelHeader(icon: Icons.high_quality, title: 'Audio Quality', subtitle: 'Selection foundation without changing quality logic.'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: AudioQualityTier.values.map((tier) => ChoiceChip(label: Text(tier.label, maxLines: 1, overflow: TextOverflow.ellipsis), selected: tier == preferredAudioQuality, onSelected: controlsDisabled ? null : (_) => onSelected({tier}))).toList(growable: false)),
          const SizedBox(height: 10),
          Text('Preferred quality: ${wzProductQualityLabel(preferredAudioQuality.label)}', style: WzText.caption),
          Text('Current track quality: ${wzProductQualityLabel(manifest?.qualityLabel ?? 'unknown')}', style: WzText.caption),
          Text('Current codec: ${manifest?.codec ?? 'unknown'}', style: WzText.caption),
          Text('Current bitrate: ${manifest?.bitrateKbps == null ? 'unknown' : '${manifest!.bitrateKbps} kbps'}', style: WzText.caption),
          Text('Current asset URL: ${currentAssetUrl ?? manifest?.streamUrl ?? 'none'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          Text('Quality fallback reason: $lastQualityFallbackReason', style: WzText.caption),
          Text('Cached quality: ${currentCachedQuality ?? 'not playing from cache'}', style: WzText.caption),
        ]),
      );
}

class _DeviceMusicDiagnosticsPanel extends StatelessWidget {
  const _DeviceMusicDiagnosticsPanel({required this.permissionStatus, required this.platformSupported, required this.importedCount, required this.lastScanStatus, required this.lastError, required this.importedAtMs});
  final String permissionStatus;
  final bool platformSupported;
  final int importedCount;
  final String lastScanStatus;
  final String? lastError;
  final int? importedAtMs;
  @override
  Widget build(BuildContext context) => _DiagnosticsPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _DiagnosticsMetricCard(label: 'Permission', value: permissionStatus, active: permissionStatus == 'granted'),
            _DiagnosticsMetricCard(label: 'Imported', value: '$importedCount tracks', active: importedCount > 0),
            _DiagnosticsMetricCard(label: 'Scan', value: lastScanStatus, active: lastScanStatus == 'success'),
            _DiagnosticsMetricCard(label: 'Platform', value: platformSupported ? 'Android bridge' : 'unsupported', active: platformSupported),
          ]),
          const SizedBox(height: 10),
          Text('Last import: ${importedAtMs == null ? 'never' : DateTime.fromMillisecondsSinceEpoch(importedAtMs!).toLocal()}', style: WzText.caption),
          Text('Last error: ${lastError ?? 'none'}', style: WzText.caption),
          const Text('MediaStore scan is audio-only, capped at 500 tracks, and ignores clips under 30 seconds.', style: WzText.caption),
        ]),
      );
}

class _LibraryDiagnosticsPanel extends StatelessWidget {
  const _LibraryDiagnosticsPanel({required this.selectedSource, required this.filteredResultCount, required this.sortMode, required this.deviceImportCount, required this.cachedLibraryCount});
  final String selectedSource;
  final int filteredResultCount;
  final String sortMode;
  final int deviceImportCount;
  final int cachedLibraryCount;
  @override
  Widget build(BuildContext context) => _DiagnosticsPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _DiagnosticsMetricCard(label: 'Source', value: selectedSource, active: true),
            _DiagnosticsMetricCard(label: 'Results', value: '$filteredResultCount', active: filteredResultCount > 0),
            _DiagnosticsMetricCard(label: 'Sort', value: sortMode, active: true),
            _DiagnosticsMetricCard(label: 'Device', value: '$deviceImportCount', active: deviceImportCount > 0),
            _DiagnosticsMetricCard(label: 'Cached', value: '$cachedLibraryCount', active: cachedLibraryCount > 0),
          ]),
          const SizedBox(height: 10),
          const Text('Library v2 diagnostics are UI-only and do not alter playback, queue, cache, MediaStore scan, or quality selection semantics.', style: WzText.caption),
        ]),
      );
}

class _CacheDiagnosticsPanel extends StatelessWidget {
  const _CacheDiagnosticsPanel({required this.cachedTrackCount, required this.cacheBytes, required this.offlineLibraryAvailable, required this.offlineCachedTrackCount, required this.manualDownloadedCount, required this.smartDownloadedCount, required this.lastOfflineLibraryStatus, required this.lastCacheResult, required this.lastCacheDeleteResult, required this.controlsDisabled, required this.onClearCache});
  final int cachedTrackCount;
  final int cacheBytes;
  final bool offlineLibraryAvailable;
  final int offlineCachedTrackCount;
  final int manualDownloadedCount;
  final int smartDownloadedCount;
  final String lastOfflineLibraryStatus;
  final String? lastCacheResult;
  final String? lastCacheDeleteResult;
  final bool controlsDisabled;
  final Future<void> Function() onClearCache;
  @override
  Widget build(BuildContext context) => _DiagnosticsPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _DiagnosticsPanelHeader(icon: Icons.offline_pin, title: 'Cache / Offline', subtitle: 'Offline Ready plus raw cache counters.'),
          const SizedBox(height: 10),
          Text('Cached tracks: $cachedTrackCount • ${(cacheBytes / 1024).toStringAsFixed(1)} KB', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
          Text('Offline cached library: ${offlineLibraryAvailable ? 'available' : 'unavailable'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
          Text('Offline cache items: $offlineCachedTrackCount', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
          Text('downloadedTrackCount: $cachedTrackCount', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
          Text('totalCacheBytes: $cacheBytes', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
          Text('manualDownloadedCount: $manualDownloadedCount', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
          Text('smartDownloadedCount: $smartDownloadedCount', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
          Text('Offline status: $lastOfflineLibraryStatus', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          if (lastCacheResult != null) Text('Last: $lastCacheResult', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          if (lastCacheDeleteResult != null) Text('lastCacheDeleteResult: $lastCacheDeleteResult', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: controlsDisabled ? null : () async { await onClearCache(); }, icon: const Icon(Icons.clear_all), label: const Text('Clear cache'))),
        ]),
      );
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.status, required this.detail, required this.operation, required this.refreshingMetrics});
  final String status;
  final String detail;
  final String operation;
  final bool refreshingMetrics;
  @override
  Widget build(BuildContext context) => _DiagnosticsPanel(
        padding: const EdgeInsets.symmetric(horizontal: WzSpacing.md, vertical: 14),
        child: Row(children: [
          Icon(refreshingMetrics ? Icons.sync : Icons.radio_button_checked, color: WzColors.accent, size: 18),
          const SizedBox(width: WzSpacing.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(status, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: WzSpacing.xxs),
            Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          ])),
          const SizedBox(width: WzSpacing.xs),
          Flexible(child: Text(operation, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: WzText.caption)),
        ]),
      );
}

class _PerformanceBaselinePanel extends StatelessWidget {
  const _PerformanceBaselinePanel({required this.metrics, required this.nextTapToAudioMs, required this.prefetchHitCount, required this.prefetchMissCount, required this.stopToPlayRecoveryMs, required this.sessionRecoveryMs, required this.audioPreparedBeforeNext, required this.nextPreparedBeforePlay});
  final PlaybackMetrics metrics;
  final int? nextTapToAudioMs;
  final int prefetchHitCount;
  final int prefetchMissCount;
  final int? stopToPlayRecoveryMs;
  final int? sessionRecoveryMs;
  final bool audioPreparedBeforeNext;
  final bool nextPreparedBeforePlay;
  @override
  Widget build(BuildContext context) => _DiagnosticsPanel(
        padding: const EdgeInsets.all(WzSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _DiagnosticsPanelHeader(icon: Icons.speed, title: 'Performance Baseline', subtitle: 'Clean session signals for startup, Next handoff, recovery, and playback health.'),
          const SizedBox(height: WzSpacing.md),
          Wrap(spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
            _DiagnosticsMetricCard(label: 'Tap to audio', value: _formatMetric(metrics.tapToFirstAudioMs), active: metrics.tapToFirstAudioMs != null),
            _DiagnosticsMetricCard(label: 'Next to audio', value: _formatMetric(nextTapToAudioMs), active: nextTapToAudioMs != null),
            _DiagnosticsMetricCard(label: 'Stop recovery', value: _formatMetric(stopToPlayRecoveryMs), active: stopToPlayRecoveryMs != null),
            _DiagnosticsMetricCard(label: 'Session recovery', value: _formatMetric(sessionRecoveryMs), active: sessionRecoveryMs != null),
            _DiagnosticsMetricCard(label: 'Playback error', value: metrics.playbackError ?? 'none', active: metrics.playbackError == null),
          ]),
          const SizedBox(height: WzSpacing.sm),
          Text('Hit/miss and prepared handoff detail now lives in Smart Preload. Unavailable values simply mean that flow has not been observed this session.', style: WzText.caption),
        ]),
      );
}

class _AudioEffectsPanel extends StatelessWidget {
  const _AudioEffectsPanel({required this.selectedProfile, required this.nativeStatus, required this.lastApplyResult, required this.preferredAudioQuality, required this.controlsDisabled, required this.onSelected});
  final AudioEffectProfile selectedProfile;
  final NativeAudioEffectStatus nativeStatus;
  final String lastApplyResult;
  final AudioQualityTier preferredAudioQuality;
  final bool controlsDisabled;
  final ValueChanged<AudioEffectProfile> onSelected;
  @override
  Widget build(BuildContext context) {
    final effectsMayAlterOriginalAudio = selectedProfile != AudioEffectProfile.off;
    return _DiagnosticsPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Audio Effects', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Effects may alter original audio. Original/lossless playback stays unchanged unless you explicitly select a profile.', style: WzText.caption),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: AudioEffectProfile.values.map((profile) => ChoiceChip(label: Text(profile.shortLabel), selected: profile == selectedProfile, onSelected: controlsDisabled ? null : (_) => onSelected(profile))).toList(growable: false)),
        const SizedBox(height: 12),
        Text('Selected effect profile: ${selectedProfile.label}', style: WzText.caption),
        Text('Description: ${selectedProfile.description}', style: WzText.caption),
        Text('Profile intensity: ${selectedProfile.safetyLabel}', style: WzText.caption),
        Text('Bass / Mid / Treble / Preamp: ${_formatDb(selectedProfile.bassGainDb)} / ${_formatDb(selectedProfile.midGainDb)} / ${_formatDb(selectedProfile.trebleGainDb)} / ${_formatDb(selectedProfile.preampGainDb)}', style: WzText.caption),
        Text('Native effect status: ${nativeStatus.label}', style: WzText.caption),
        Text('Last effect apply result: $lastApplyResult', style: WzText.caption),
        if (preferredAudioQuality == AudioQualityTier.original && effectsMayAlterOriginalAudio) ...[
          const SizedBox(height: 8),
          Text('Original quality is selected and ${selectedProfile.label} was explicitly enabled by the user; effects may alter original audio.', style: WzText.caption.copyWith(color: WzColors.warning)),
        ],
      ]),
    );
  }
  String _formatDb(double value) {
    if (value == 0) return '0.0 dB';
    return '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)} dB';
  }
}

class _SmartPreloadCard extends StatelessWidget {
  const _SmartPreloadCard({required this.metrics, required this.enabled, required this.prefetchedTrackId, required this.prefetchedTrackTitle, required this.prefetchInFlight, required this.manifestPrefetched, required this.audioPreparedBeforeNext, required this.lastPrefetchHit, required this.prefetchHitCount, required this.prefetchMissCount, required this.nextTapToAudioMs, required this.nextPreparedBeforePlay, required this.smartQueueCandidateTrackId, required this.smartQueueReason, required this.controlsDisabled, required this.onToggle});
  final PlaybackMetrics metrics;
  final bool enabled;
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
  final ValueChanged<bool> onToggle;
  @override
  Widget build(BuildContext context) {
    final prepareMs = metrics.nativePrebufferPrepareMs ?? metrics.lastNativePrebufferPrepareMs;
    return _DiagnosticsPanel(
      padding: const EdgeInsets.all(WzSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: _DiagnosticsPanelHeader(icon: Icons.auto_awesome, title: 'Smart Preload', subtitle: 'Predictive manifest, native prebuffer, and prepared handoff signals.')),
          Switch(value: enabled, onChanged: controlsDisabled ? null : onToggle),
        ]),
        const SizedBox(height: WzSpacing.md),
        _DiagnosticsMetricSection(title: 'Smart Queue Policy', description: smartQueueCandidateTrackId == null ? 'No deterministic queue candidate selected' : 'Candidate: $smartQueueCandidateTrackId', metrics: [
          _DiagnosticsMetricCard(label: 'smartQueueReason', value: smartQueueReason, active: smartQueueCandidateTrackId != null),
          _DiagnosticsMetricCard(label: 'Candidate', value: smartQueueCandidateTrackId ?? 'none', active: smartQueueCandidateTrackId != null),
        ]),
        const SizedBox(height: WzSpacing.md),
        _DiagnosticsMetricSection(title: 'Manifest Prefetch', description: prefetchedTrackTitle ?? 'No manifest candidate yet', metrics: [
          _DiagnosticsMetricCard(label: 'Enabled', value: enabled ? 'on' : 'off', active: enabled),
          _DiagnosticsMetricCard(label: 'Manifest ready', value: manifestPrefetched ? 'true' : 'false', active: manifestPrefetched),
          _DiagnosticsMetricCard(label: 'Last result', value: _prefetchResultLabel(lastPrefetchHit), active: lastPrefetchHit == true),
        ]),
        const SizedBox(height: WzSpacing.md),
        _DiagnosticsMetricSection(title: 'Native Prebuffer', description: metrics.nativePrebufferTrackTitle ?? prefetchedTrackId ?? 'Waiting for the up-next native candidate', metrics: [
          _DiagnosticsMetricCard(label: 'nativePrebufferReady', value: metrics.nativePrebufferReady ? 'true' : 'false', active: metrics.nativePrebufferReady),
          _DiagnosticsMetricCard(label: metrics.nativePrebufferPrepareMs == null ? 'lastNativePrebufferPrepareMs' : 'nativePrebufferPrepareMs', value: _formatMetric(prepareMs), active: prepareMs != null),
          _DiagnosticsMetricCard(label: 'nativePrebufferHit / Miss', value: '${metrics.nativePrebufferHitCount} / ${metrics.nativePrebufferMissCount}', active: metrics.nativePrebufferHitCount > 0),
        ]),
        const SizedBox(height: WzSpacing.md),
        _DiagnosticsMetricSection(title: 'Prepared Handoff', description: metrics.lastNativePrebufferTrackTitle ?? 'Explicit Next and auto-advance prepared handoff telemetry', metrics: [
          _DiagnosticsMetricCard(label: 'nativeHandoffToPlayingMs', value: _formatMetric(metrics.nativeHandoffToPlayingMs), active: metrics.nativeHandoffToPlayingMs != null),
          _DiagnosticsMetricCard(label: 'nextPreparedBeforePlay', value: nextPreparedBeforePlay ? 'true' : 'false', active: nextPreparedBeforePlay),
          _DiagnosticsMetricCard(label: 'auto prepared', value: metrics.autoAdvancePreparedBeforePlay ? 'true' : 'false', active: metrics.autoAdvancePreparedBeforePlay),
        ]),
        const SizedBox(height: WzSpacing.sm),
        Text('Track IDs, in-flight flags, clear reasons, and full counters remain available in Show raw metrics.', style: WzText.caption),
      ]),
    );
  }
}

class _SmartDownloadsCard extends StatelessWidget {
  const _SmartDownloadsCard({required this.enabled, required this.lastTrackId, required this.lastTitle, required this.lastReason, required this.lastResult, required this.startedCount, required this.completedCount, required this.failedCount, required this.skippedCount, required this.inFlight, required this.onToggle});
  final bool enabled;
  final String? lastTrackId;
  final String? lastTitle;
  final String? lastReason;
  final String? lastResult;
  final int startedCount;
  final int completedCount;
  final int failedCount;
  final int skippedCount;
  final int inFlight;
  final ValueChanged<bool> onToggle;
  @override
  Widget build(BuildContext context) => _DiagnosticsPanel(
        padding: const EdgeInsets.all(WzSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: _DiagnosticsPanelHeader(icon: Icons.download_for_offline, title: 'Smart Downloads', subtitle: 'Predictive background caching for current and up-next tracks.')),
            Switch(value: enabled, onChanged: onToggle),
          ]),
          const SizedBox(height: WzSpacing.md),
          _DiagnosticsMetricSection(title: 'Last Smart Download', description: lastTitle ?? 'No smart downloads yet', metrics: [
            _DiagnosticsMetricCard(label: 'Track', value: lastTrackId ?? 'none', active: lastTrackId != null),
            _DiagnosticsMetricCard(label: 'Result', value: lastResult ?? 'none', active: lastResult == 'cached'),
            _DiagnosticsMetricCard(label: 'Reason', value: lastReason ?? 'none', active: lastReason != null),
          ]),
          const SizedBox(height: WzSpacing.md),
          _DiagnosticsMetricSection(title: 'Counters', description: 'Started / Completed / Failed / Skipped', metrics: [
            _DiagnosticsMetricCard(label: 'Started', value: '$startedCount', active: startedCount > 0),
            _DiagnosticsMetricCard(label: 'Completed', value: '$completedCount', active: completedCount > 0),
            _DiagnosticsMetricCard(label: 'Failed', value: '$failedCount', active: failedCount > 0),
            _DiagnosticsMetricCard(label: 'Skipped', value: '$skippedCount', active: skippedCount > 0),
            _DiagnosticsMetricCard(label: 'InFlight', value: '$inFlight', active: inFlight > 0),
          ]),
        ]),
      );
}

class _DiagnosticsPanelHeader extends StatelessWidget {
  const _DiagnosticsPanelHeader({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: WzColors.accent),
        const SizedBox(width: WzSpacing.sm),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: WzText.title),
          const SizedBox(height: WzSpacing.xxs),
          Text(subtitle, style: WzText.caption),
        ])),
      ]);
}

class _DiagnosticsMetricSection extends StatelessWidget {
  const _DiagnosticsMetricSection({required this.title, required this.description, required this.metrics});
  final String title;
  final String description;
  final List<Widget> metrics;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(WzSpacing.md),
        decoration: BoxDecoration(color: WzColors.surfaceMuted, borderRadius: BorderRadius.circular(WzRadius.lg), border: Border.all(color: WzColors.borderSoft)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: WzSpacing.xxs),
          Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          const SizedBox(height: WzSpacing.sm),
          Wrap(spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: metrics),
        ]),
      );
}

class _DiagnosticsMetricCard extends StatelessWidget {
  const _DiagnosticsMetricCard({required this.label, required this.value, required this.active});
  final String label;
  final String value;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 132, maxWidth: 218),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: active ? WzColors.successSoft : WzColors.surfaceElevated, borderRadius: BorderRadius.circular(WzRadius.md), border: Border.all(color: active ? const Color(0x5538D996) : WzColors.borderSoft)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
          const SizedBox(height: WzSpacing.xxs),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      );
}

class _ContentServerDiagnosticsPanel extends StatelessWidget {
  const _ContentServerDiagnosticsPanel({required this.apiBaseUrl, required this.status, required this.catalogStatus, required this.catalogTrackCount, required this.visibleTrackCount, required this.filteredTrackCount, required this.catalogLimit, required this.largeCatalogMode});
  final String apiBaseUrl;
  final ContentStatus? status;
  final String catalogStatus;
  final int catalogTrackCount;
  final int visibleTrackCount;
  final int filteredTrackCount;
  final int catalogLimit;
  final bool largeCatalogMode;
  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return _DiagnosticsPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          _DiagnosticsMetricCard(label: 'Catalog', value: status?.friendlyLabel ?? catalogStatus, active: status?.ok ?? catalogTrackCount > 0),
          _DiagnosticsMetricCard(label: 'Mode', value: status?.contentMode ?? 'unknown', active: status?.contentMode == 'production' || status?.contentMode == 'demo'),
          _DiagnosticsMetricCard(label: 'Tracks', value: '${status?.trackCount ?? catalogTrackCount}', active: (status?.trackCount ?? catalogTrackCount) > 0),
          _DiagnosticsMetricCard(label: 'Visible', value: '$visibleTrackCount', active: visibleTrackCount > 0),
          _DiagnosticsMetricCard(label: 'Filtered', value: '$filteredTrackCount', active: filteredTrackCount > 0),
          _DiagnosticsMetricCard(label: 'Catalog limit', value: '$catalogLimit', active: largeCatalogMode),
          _DiagnosticsMetricCard(label: 'Large catalog mode', value: largeCatalogMode ? 'enabled' : 'disabled', active: largeCatalogMode),
          _DiagnosticsMetricCard(label: 'Assets', value: '${status?.assetCount ?? 0}', active: (status?.assetCount ?? 0) > 0),
          _DiagnosticsMetricCard(label: 'Production-safe', value: '${status?.productionSafeTrackCount ?? 0}', active: (status?.productionSafeTrackCount ?? 0) > 0),
          _DiagnosticsMetricCard(label: 'Local folder', value: status?.localFolderCatalogEnabled == true ? 'enabled' : 'disabled', active: status?.localFolderCatalogEnabled == true),
        ]),
        const SizedBox(height: 10),
        Text('API base URL: $apiBaseUrl', style: WzText.caption),
        Text('catalogTrackCount=$catalogTrackCount • visibleTrackCount=$visibleTrackCount • filteredTrackCount=$filteredTrackCount • catalogLimit=$catalogLimit • largeCatalogMode=${largeCatalogMode ? 'enabled' : 'disabled'}', style: WzText.caption),
        Text(status?.developerSummary ?? catalogStatus, style: WzText.caption),
      ]),
    );
  }
}

class _DeveloperModePanel extends StatelessWidget {
  const _DeveloperModePanel({required this.enabled, required this.onChanged});
  final bool enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => _DiagnosticsPanel(child: SwitchListTile(value: enabled, onChanged: onChanged, secondary: const Icon(Icons.admin_panel_settings), title: const Text('Internal developer mode'), subtitle: const Text('Turn off to return to the consumer music shell.')));
}

class _MetricsToggle extends StatelessWidget {
  const _MetricsToggle({required this.showMetrics, required this.operationBusy, required this.onToggle, required this.onCopyMetrics, required this.onResetMetrics});
  final bool showMetrics;
  final bool operationBusy;
  final VoidCallback onToggle;
  final VoidCallback onCopyMetrics;
  final VoidCallback onResetMetrics;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: onToggle, icon: Icon(showMetrics ? Icons.expand_less : Icons.analytics_outlined), label: Text(showMetrics ? 'Hide raw metrics' : 'Show raw metrics'))),
        const SizedBox(width: 10),
        IconButton.outlined(onPressed: operationBusy ? null : onCopyMetrics, icon: const Icon(Icons.copy), tooltip: 'Copy metrics'),
        const SizedBox(width: 10),
        IconButton.outlined(onPressed: operationBusy ? null : onResetMetrics, icon: const Icon(Icons.restart_alt), tooltip: 'Reset metrics'),
      ]);
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.metrics});
  final PlaybackMetrics metrics;
  @override
  Widget build(BuildContext context) => _DiagnosticsPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _DiagnosticsPanelHeader(icon: Icons.data_object, title: 'Raw metrics', subtitle: 'Complete developer telemetry without changing metric names or meaning.'),
        const SizedBox(height: WzSpacing.md),
        SelectableText(metrics.toDisplayText(), style: const TextStyle(color: Color(0xFFD7DDF0), fontFamily: 'monospace', height: 1.45)),
      ]));
}

class _DiagnosticsPanel extends StatelessWidget {
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
