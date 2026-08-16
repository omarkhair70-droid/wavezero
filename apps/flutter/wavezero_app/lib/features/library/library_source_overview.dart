import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import 'library_controls.dart';

class WzLibrarySourceOverview extends StatelessWidget {
  const WzLibrarySourceOverview({
    super.key,
    required this.apiTrackCount,
    required this.deviceTrackCount,
    required this.cachedTrackCount,
    required this.cloudTrackCount,
    required this.combinedTrackCount,
    required this.cacheBytes,
    required this.status,
    required this.loading,
    required this.refreshDisabled,
    required this.librarySourceFilter,
    required this.devicePermissionStatus,
    required this.deviceScanStatus,
    required this.deviceLastError,
    required this.onSourceFilterChanged,
    required this.onRefresh,
    required this.onImportDeviceMusic,
    required this.onOpenCollections,
    required this.onOpenFullSearch,
    required this.onOpenCloudVault,
  });

  final int apiTrackCount;
  final int deviceTrackCount;
  final int cachedTrackCount;
  final int cloudTrackCount;
  final int combinedTrackCount;
  final int cacheBytes;
  final String status;
  final bool loading;
  final bool refreshDisabled;
  final WzLibrarySourceFilter librarySourceFilter;
  final String devicePermissionStatus;
  final String deviceScanStatus;
  final String? deviceLastError;
  final ValueChanged<WzLibrarySourceFilter> onSourceFilterChanged;
  final VoidCallback onRefresh;
  final VoidCallback onImportDeviceMusic;
  final VoidCallback onOpenCollections;
  final VoidCallback onOpenFullSearch;
  final VoidCallback onOpenCloudVault;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Library', style: WzText.title),
                    SizedBox(height: 4),
                    Text('Everything you can listen to, kept in one calm place.', style: WzText.body),
                  ],
                ),
              ),
              WzSculptedIconButton(
                tooltip: 'Refresh Library',
                onPressed: refreshDisabled ? null : onRefresh,
                icon: Icons.refresh,
                size: 44,
                iconSize: 19,
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: WzSpacing.xs),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: WzSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 360 ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'All', detail: '$combinedTrackCount tracks', status: 'Unified library', icon: Icons.library_music_rounded, active: librarySourceFilter == WzLibrarySourceFilter.all)),
                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'Catalog', detail: '$apiTrackCount tracks', status: status, icon: Icons.cloud_queue_rounded, active: librarySourceFilter == WzLibrarySourceFilter.api)),
                  SizedBox(
                    width: cardWidth,
                    child: _LibrarySourceSummaryCard(
                      title: 'Device music',
                      detail: '$deviceTrackCount imported',
                      status: devicePermissionStatus == 'granted' ? 'Device access ready • $deviceScanStatus' : 'Device access optional • $deviceScanStatus',
                      icon: Icons.phone_android_rounded,
                      active: librarySourceFilter == WzLibrarySourceFilter.device,
                    ),
                  ),
                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'Downloads', detail: '$cachedTrackCount cached', status: '${(cacheBytes / 1024).toStringAsFixed(1)} KB stored', icon: Icons.download_done_rounded, active: librarySourceFilter == WzLibrarySourceFilter.downloads)),
                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'Cloud', detail: '$cloudTrackCount local entries', status: 'Saved metadata • playback coming soon', icon: Icons.cloud_done_outlined, active: librarySourceFilter == WzLibrarySourceFilter.cloud)),
                ],
              );
            },
          ),
          const SizedBox(height: WzSpacing.md),
          Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: WzLibrarySourceFilter.values
                .map(
                  (filter) => ChoiceChip(
                    avatar: Icon(wzLibrarySourceFilterIcon(filter), size: 16),
                    label: Text(wzLibrarySourceFilterShortLabel(filter), maxLines: 1, overflow: TextOverflow.ellipsis),
                    selected: librarySourceFilter == filter,
                    onSelected: (_) => onSourceFilterChanged(filter),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: WzSpacing.sm),
          Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(onPressed: refreshDisabled ? null : onImportDeviceMusic, icon: const Icon(Icons.perm_media_rounded), label: Text(deviceTrackCount == 0 ? 'Import Device music' : 'Rescan Device music')),
              OutlinedButton.icon(onPressed: onOpenCollections, icon: const Icon(Icons.playlist_play_rounded), label: const Text('Collections / Playlists')),
              OutlinedButton.icon(onPressed: onOpenFullSearch, icon: const Icon(Icons.search_rounded), label: const Text('Open full search')),
              OutlinedButton.icon(onPressed: onOpenCloudVault, icon: const Icon(Icons.cloud_done_outlined), label: const Text('Cloud Vault')),
              WzStatusPill(label: devicePermissionStatus == 'granted' ? 'Device access ready' : 'Device access optional', active: devicePermissionStatus == 'granted', icon: Icons.phone_android_rounded),
              WzStatusPill(label: 'Device music • $deviceScanStatus • $deviceTrackCount tracks', active: deviceTrackCount > 0, icon: Icons.library_music_rounded),
            ],
          ),
          if (deviceLastError != null) ...[
            const SizedBox(height: WzSpacing.xs),
            Text(deviceLastError!, style: WzText.caption.copyWith(color: WzColors.warning)),
          ],
        ],
      );
}

IconData wzLibrarySourceFilterIcon(WzLibrarySourceFilter filter) => switch (filter) {
      WzLibrarySourceFilter.all => Icons.library_music_rounded,
      WzLibrarySourceFilter.api => Icons.cloud_queue_rounded,
      WzLibrarySourceFilter.device => Icons.phone_android_rounded,
      WzLibrarySourceFilter.downloads => Icons.download_done_rounded,
      WzLibrarySourceFilter.cloud => Icons.cloud_done_outlined,
    };

String wzLibrarySourceFilterShortLabel(WzLibrarySourceFilter filter) => switch (filter) {
      WzLibrarySourceFilter.all => 'All',
      WzLibrarySourceFilter.api => 'Catalog',
      WzLibrarySourceFilter.device => 'Device',
      WzLibrarySourceFilter.downloads => 'Downloads',
      WzLibrarySourceFilter.cloud => 'Cloud',
    };

class _LibrarySourceSummaryCard extends StatelessWidget {
  const _LibrarySourceSummaryCard({required this.title, required this.detail, required this.status, required this.icon, required this.active});

  final String title;
  final String detail;
  final String status;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: WzMotion.normal,
        curve: WzMotion.curve,
        constraints: const BoxConstraints(minWidth: 132, maxWidth: 240),
        padding: const EdgeInsets.all(WzSpacing.sm),
        decoration: WzSurface.sculpted(selected: active),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WzSculptedIcon(icon: icon, size: 42, iconSize: 18, color: active ? WzColors.accent : WzColors.textMuted),
            const SizedBox(height: WzSpacing.xs),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
            const SizedBox(height: 4),
            Text(detail, style: WzText.caption.copyWith(color: WzColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(status, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          ],
        ),
      );
}
