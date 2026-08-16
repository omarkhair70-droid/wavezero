import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../../shared/widgets/wavezero_empty_message.dart';
import 'cache_service.dart';
import 'downloads_presentation.dart';

class WzStorageManagerPage extends StatelessWidget {
  const WzStorageManagerPage({
    required this.downloads,
    required this.onBack,
    required this.cacheBytes,
    required this.trackBytes,
    required this.manualDownloadedCount,
    required this.smartDownloadedCount,
    required this.offlineReadyCount,
    required this.smartDownloadsEnabled,
    required this.controlsDisabled,
    required this.onSmartDownloadsChanged,
    required this.onPlay,
    required this.onDelete,
    required this.onClearAll,
  });

  final List<CachedTrackMetadata> downloads;
  final VoidCallback onBack;
  final int cacheBytes;
  final Map<String, int> trackBytes;
  final int manualDownloadedCount;
  final int smartDownloadedCount;
  final int offlineReadyCount;
  final bool smartDownloadsEnabled;
  final bool controlsDisabled;
  final ValueChanged<bool> onSmartDownloadsChanged;
  final ValueChanged<CachedTrackMetadata> onPlay;
  final ValueChanged<CachedTrackMetadata> onDelete;
  final Future<void> Function() onClearAll;

  int get _currentOrRecentCount => downloads.where((track) => track.downloadSource == 'smart_current').length;
  int get _unknownCount => downloads.where((track) => track.downloadSource != 'manual' && !track.downloadSource.startsWith('smart_')).length;

  @override
  Widget build(BuildContext context) {
    final healthLabel = downloads.isEmpty ? 'No downloads yet' : 'Ready for offline playback';
    return WzPageScaffold(
      children: [
        WzPageHeader(
          icon: Icons.storage_rounded,
          title: 'Storage Manager',
          subtitle: 'See what is already here, and keep only what you want.',
          trailing: WzSculptedIconButton(tooltip: 'Back to Downloads', onPressed: onBack, icon: Icons.arrow_back_rounded, size: 42, iconSize: 18),
        ),
        const SizedBox(height: WzSpacing.md),
        WzGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: WzSpacing.xs,
                runSpacing: WzSpacing.xs,
                children: [
                  WzStatusPill(label: healthLabel, active: downloads.isNotEmpty, icon: downloads.isEmpty ? Icons.inbox_outlined : Icons.offline_pin_rounded),
                  WzStatusPill(label: smartDownloadsEnabled ? 'Smart Downloads on' : 'Smart Downloads off', active: smartDownloadsEnabled, icon: Icons.auto_awesome_rounded),
                ],
              ),
              const SizedBox(height: WzSpacing.md),
              Wrap(
                spacing: WzSpacing.sm,
                runSpacing: WzSpacing.sm,
                children: [
                  WzMiniMetric(label: 'Cached for offline', value: '${downloads.length}', active: downloads.isNotEmpty, icon: Icons.library_music_rounded),
                  WzMiniMetric(label: 'Device storage', value: formatWzCacheBytes(cacheBytes), active: cacheBytes > 0, icon: Icons.sd_storage_rounded),
                  WzMiniMetric(label: 'Manual downloads', value: '$manualDownloadedCount', active: manualDownloadedCount > 0, icon: Icons.download_done_rounded),
                  WzMiniMetric(label: 'Smart downloads', value: '$smartDownloadedCount', active: smartDownloadedCount > 0, icon: Icons.auto_awesome_rounded),
                  WzMiniMetric(label: 'Offline-ready', value: '$offlineReadyCount', active: offlineReadyCount > 0, icon: Icons.offline_pin_rounded),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        const WzSectionHeader(title: 'Smart Downloads', subtitle: 'Keep likely next tracks ready without changing playback behavior.', icon: Icons.auto_awesome_rounded),
        WzGlassCard(
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Smart Downloads'),
            subtitle: const Text('WaveZero can keep the current and up-next tracks nearby for offline-ready playback.'),
            value: smartDownloadsEnabled,
            onChanged: controlsDisabled ? null : onSmartDownloadsChanged,
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        const WzSectionHeader(title: 'Categories', subtitle: 'What kind of downloads are using storage.', icon: Icons.category_rounded),
        WzGlassCard(
          child: Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            children: [
              _StorageCategoryCard(label: 'All cached', count: downloads.length, icon: Icons.all_inbox_rounded),
              _StorageCategoryCard(label: 'Manual downloads', count: manualDownloadedCount, icon: Icons.download_done_rounded),
              _StorageCategoryCard(label: 'Smart downloads', count: smartDownloadedCount, icon: Icons.auto_awesome_rounded),
              _StorageCategoryCard(label: 'Current / recent', count: _currentOrRecentCount, icon: Icons.flash_on_rounded),
              _StorageCategoryCard(label: 'Unknown source', count: _unknownCount, icon: Icons.help_outline_rounded),
            ],
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        WzSectionHeader(
          title: 'Downloaded tracks',
          subtitle: downloads.isEmpty ? 'No downloads yet.' : 'Play or remove individual offline-ready tracks.',
          icon: Icons.playlist_play_rounded,
        ),
        WzGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: WzSpacing.sm,
                runSpacing: WzSpacing.sm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(downloads.isEmpty ? 'Downloads cleared' : '${downloads.length} downloaded • ${formatWzCacheBytes(cacheBytes)}', style: WzText.body),
                  OutlinedButton.icon(
                    onPressed: controlsDisabled || downloads.isEmpty ? null : () => unawaited(onClearAll()),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear all downloads'),
                  ),
                ],
              ),
              const SizedBox(height: WzSpacing.md),
              if (downloads.isEmpty)
                const WzEmptyCatalogMessage(message: 'No downloads yet. Download tracks from Library to listen offline.')
              else
                ...downloads.map((track) => _StorageTrackRow(
                      track: track,
                      sizeBytes: trackBytes[track.trackId],
                      disabled: controlsDisabled,
                      onPlay: () => onPlay(track),
                      onDelete: () => onDelete(track),
                    )),
            ],
          ),
        ),
      ],
    );
  }
}

class _StorageCategoryCard extends StatelessWidget {
  const _StorageCategoryCard({required this.label, required this.count, required this.icon});

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: WzMiniMetric(label: label, value: '$count', active: count > 0, icon: icon),
      );
}

class _StorageTrackRow extends StatelessWidget {
  const _StorageTrackRow({required this.track, required this.sizeBytes, required this.disabled, required this.onPlay, required this.onDelete});

  final CachedTrackMetadata track;
  final int? sizeBytes;
  final bool disabled;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final quality = wzProductQualityLabel(track.qualityLabel);
    final details = <String>[
      if (quality != 'Unknown') quality,
      if (track.codec != null && track.codec!.trim().isNotEmpty) track.codec!,
      if (track.bitrateKbps != null) '${track.bitrateKbps}kbps',
      if (sizeBytes != null) formatWzCacheBytes(sizeBytes!),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: WzSpacing.sm),
      padding: const EdgeInsets.all(WzSpacing.sm),
      decoration: WzSurface.sculpted(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(WzRadius.md), boxShadow: WzSurface.softShadows),
                child: WzArtwork(artworkUrl: track.artworkUrl, size: 50, trackId: track.trackId, title: track.title, artist: track.artistName),
              ),
              const SizedBox(width: WzSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                    const SizedBox(height: WzSpacing.xxs),
                    Text(track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: WzSpacing.sm),
          Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              WzStatusPill(label: wzDownloadSourceLabel(track.downloadSource), active: track.downloadSource != 'unknown', icon: _downloadSourceIcon(track.downloadSource)),
              if (quality != 'Unknown') WzStatusPill(label: quality, active: true, icon: Icons.high_quality_rounded),
              if (track.codec != null && track.codec!.trim().isNotEmpty) WzStatusPill(label: track.codec!, active: true, icon: Icons.memory_rounded),
              if (track.bitrateKbps != null) WzStatusPill(label: '${track.bitrateKbps}kbps', active: true, icon: Icons.speed_rounded),
              if (sizeBytes != null) WzStatusPill(label: formatWzCacheBytes(sizeBytes!), active: true, icon: Icons.sd_storage_rounded),
              if (details.isEmpty) const WzStatusPill(label: 'Offline-ready', active: true, icon: Icons.offline_pin_rounded),
            ],
          ),
          const SizedBox(height: WzSpacing.xs),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              OutlinedButton.icon(onPressed: disabled ? null : onPlay, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Play')),
              OutlinedButton.icon(onPressed: disabled ? null : onDelete, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Remove from device')),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _downloadSourceIcon(String source) {
  switch (source) {
    case 'manual':
      return Icons.download_done_rounded;
    case 'smart_current':
      return Icons.flash_on_rounded;
    case 'smart_up_next':
      return Icons.auto_awesome_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}
