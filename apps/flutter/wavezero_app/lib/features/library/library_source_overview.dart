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
                    Text('Library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text(
                      'Browse catalog music, device tracks, downloads, and Cloud Vault entries without loading everything at once.',
                      style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                onPressed: refreshDisabled ? null : onRefresh,
                icon: loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 360 ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _LibrarySourceSummaryCard(
                      title: 'All',
                      detail: '$combinedTrackCount tracks',
                      status: 'Unified library',
                      icon: Icons.library_music,
                      active: librarySourceFilter == WzLibrarySourceFilter.all,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _LibrarySourceSummaryCard(
                      title: 'Catalog',
                      detail: '$apiTrackCount tracks',
                      status: status,
                      icon: Icons.cloud_queue,
                      active: librarySourceFilter == WzLibrarySourceFilter.api,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _LibrarySourceSummaryCard(
                      title: 'Device music',
                      detail: '$deviceTrackCount imported',
                      status: devicePermissionStatus == 'granted'
                          ? 'Device access ready • $deviceScanStatus'
                          : 'Device access optional • $deviceScanStatus',
                      icon: Icons.phone_android,
                      active: librarySourceFilter == WzLibrarySourceFilter.device,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _LibrarySourceSummaryCard(
                      title: 'Downloads',
                      detail: '$cachedTrackCount cached',
                      status: '${(cacheBytes / 1024).toStringAsFixed(1)} KB stored',
                      icon: Icons.download_done,
                      active: librarySourceFilter == WzLibrarySourceFilter.downloads,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _LibrarySourceSummaryCard(
                      title: 'Cloud',
                      detail: '$cloudTrackCount local entries',
                      status: 'Saved metadata • playback coming soon',
                      icon: Icons.cloud_done_outlined,
                      active: librarySourceFilter == WzLibrarySourceFilter.cloud,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: refreshDisabled ? null : onImportDeviceMusic,
                icon: const Icon(Icons.perm_media),
                label: Text(deviceTrackCount == 0 ? 'Import Device music' : 'Rescan Device music'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenCollections,
                icon: const Icon(Icons.playlist_play),
                label: const Text('Collections / Playlists'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenFullSearch,
                icon: const Icon(Icons.search),
                label: const Text('Open full search'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenCloudVault,
                icon: const Icon(Icons.cloud_done_outlined),
                label: const Text('Cloud Vault'),
              ),
              Text(
                devicePermissionStatus == 'granted' ? 'Device access ready' : 'Device access optional',
                style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
              ),
              Text(
                'Device music: $deviceScanStatus • $deviceTrackCount tracks',
                style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
              ),
            ],
          ),
          if (deviceLastError != null) ...[
            const SizedBox(height: 6),
            Text(deviceLastError!, style: const TextStyle(color: Color(0xFFFFC46B), fontSize: 12)),
          ],
        ],
      );
}

IconData wzLibrarySourceFilterIcon(WzLibrarySourceFilter filter) => switch (filter) {
      WzLibrarySourceFilter.all => Icons.library_music,
      WzLibrarySourceFilter.api => Icons.cloud_queue,
      WzLibrarySourceFilter.device => Icons.phone_android,
      WzLibrarySourceFilter.downloads => Icons.download_done,
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
  const _LibrarySourceSummaryCard({
    required this.title,
    required this.detail,
    required this.status,
    required this.icon,
    required this.active,
  });

  final String title;
  final String detail;
  final String status;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: WzMotion.normal,
        curve: WzMotion.curve,
        constraints: const BoxConstraints(minWidth: 132, maxWidth: 220),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? WzColors.accentSoft : WzColors.surfaceMuted,
          borderRadius: BorderRadius.circular(WzRadius.lg),
          border: Border.all(color: active ? WzColors.accent.withOpacity(0.58) : WzColors.borderSoft),
          boxShadow: active
              ? [BoxShadow(color: WzColors.accent.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: active ? const Color(0xFF8D7CFF) : const Color(0xFF98A1B8)),
            const SizedBox(height: 8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              status,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
            ),
          ],
        ),
      );
}
