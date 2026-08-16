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
    this.showCloudSource = false,
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
  final bool showCloudSource;

  @override
  Widget build(BuildContext context) {
    final statusLower = status.toLowerCase();
    final catalogProblem = statusLower.contains('unavailable') || statusLower.contains('error') || statusLower.contains('failed');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Library', style: WzText.pageTitle.copyWith(fontSize: 30)),
                  const SizedBox(height: 5),
                  Text(
                    combinedTrackCount == 0 ? 'Your music will collect here.' : '$combinedTrackCount tracks, all in one place.',
                    style: WzText.body,
                  ),
                ],
              ),
            ),
            WzSculptedIconButton(
              tooltip: 'Search Library',
              onPressed: onOpenFullSearch,
              icon: Icons.search_rounded,
              size: 46,
              iconSize: 20,
            ),
            const SizedBox(width: 8),
            WzSculptedIconButton(
              tooltip: 'Refresh Library',
              onPressed: refreshDisabled ? null : onRefresh,
              icon: Icons.refresh_rounded,
              size: 46,
              iconSize: 19,
            ),
          ],
        ),
        if (loading) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(minHeight: 2),
          ),
        ],
        const SizedBox(height: 22),
        _PrimaryLibraryTile(
          icon: Icons.library_music_rounded,
          title: 'All music',
          subtitle: combinedTrackCount == 0 ? 'Nothing here yet' : '$combinedTrackCount tracks',
          selected: librarySourceFilter == WzLibrarySourceFilter.all,
          onTap: () => onSourceFilterChanged(WzLibrarySourceFilter.all),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _LibraryDestinationTile(
                icon: Icons.phone_android_rounded,
                title: 'Device Music',
                subtitle: deviceTrackCount == 0 ? 'Add music from this phone' : '$deviceTrackCount tracks',
                selected: librarySourceFilter == WzLibrarySourceFilter.device,
                onTap: deviceTrackCount == 0 ? onImportDeviceMusic : () => onSourceFilterChanged(WzLibrarySourceFilter.device),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LibraryDestinationTile(
                icon: Icons.download_done_rounded,
                title: 'Downloads',
                subtitle: cachedTrackCount == 0 ? 'Nothing saved yet' : '$cachedTrackCount offline',
                selected: librarySourceFilter == WzLibrarySourceFilter.downloads,
                onTap: () => onSourceFilterChanged(WzLibrarySourceFilter.downloads),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PrimaryLibraryTile(
          icon: Icons.playlist_play_rounded,
          title: 'Collections',
          subtitle: 'Liked tracks and playlists',
          selected: false,
          onTap: onOpenCollections,
        ),
        if (deviceTrackCount > 0) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: refreshDisabled ? null : onImportDeviceMusic,
              icon: const Icon(Icons.sync_rounded, size: 17),
              label: const Text('Rescan device music'),
            ),
          ),
        ],
        if (catalogProblem && apiTrackCount == 0 && deviceTrackCount == 0 && cachedTrackCount == 0) ...[
          const SizedBox(height: 8),
          Text('Online music is unavailable right now. Device Music still works.', style: WzText.caption.copyWith(color: WzColors.warning)),
        ],
        if (deviceLastError != null) ...[
          const SizedBox(height: 6),
          Text(deviceLastError!, style: WzText.caption.copyWith(color: WzColors.warning)),
        ],
        if (showCloudSource) ...[
          const SizedBox(height: 10),
          _PrimaryLibraryTile(
            icon: Icons.cloud_outlined,
            title: 'Cloud preview',
            subtitle: '$cloudTrackCount developer entries',
            selected: librarySourceFilter == WzLibrarySourceFilter.cloud,
            onTap: onOpenCloudVault,
          ),
        ],
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: WzLibrarySourceFilter.values
                .where((filter) => showCloudSource || filter != WzLibrarySourceFilter.cloud)
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(wzLibrarySourceFilterIcon(filter), size: 15),
                      label: Text(wzLibrarySourceFilterShortLabel(filter)),
                      selected: librarySourceFilter == filter,
                      onSelected: (_) => onSourceFilterChanged(filter),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

IconData wzLibrarySourceFilterIcon(WzLibrarySourceFilter filter) => switch (filter) {
      WzLibrarySourceFilter.all => Icons.library_music_rounded,
      WzLibrarySourceFilter.api => Icons.public_rounded,
      WzLibrarySourceFilter.device => Icons.phone_android_rounded,
      WzLibrarySourceFilter.downloads => Icons.download_done_rounded,
      WzLibrarySourceFilter.cloud => Icons.cloud_outlined,
    };

String wzLibrarySourceFilterShortLabel(WzLibrarySourceFilter filter) => switch (filter) {
      WzLibrarySourceFilter.all => 'All',
      WzLibrarySourceFilter.api => 'Online',
      WzLibrarySourceFilter.device => 'Device',
      WzLibrarySourceFilter.downloads => 'Downloads',
      WzLibrarySourceFilter.cloud => 'Cloud',
    };

class _PrimaryLibraryTile extends StatelessWidget {
  const _PrimaryLibraryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WzPressableSurface(
        onTap: onTap,
        radius: 30,
        decoration: WzSurface.sculpted(selected: selected),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Row(
          children: [
            WzSculptedIcon(icon: icon, size: 46, iconSize: 20, color: selected ? WzColors.accent : WzColors.textPrimary),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: WzText.sectionTitle),
                  const SizedBox(height: 3),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: WzColors.textSubtle),
          ],
        ),
      );
}

class _LibraryDestinationTile extends StatelessWidget {
  const _LibraryDestinationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WzPressableSurface(
        onTap: onTap,
        radius: 28,
        decoration: WzSurface.sculpted(selected: selected),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WzSculptedIcon(icon: icon, size: 42, iconSize: 18, color: selected ? WzColors.accent : WzColors.textPrimary),
            const SizedBox(height: 12),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 3),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          ],
        ),
      );
}
