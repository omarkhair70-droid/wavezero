import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/curated_demo_picks.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../downloads/cache_service.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/media/track_source.dart';
import '../../shared/widgets/wavezero_artwork.dart';

class WzFeaturedDemoLibraryShelf extends StatelessWidget {
  const WzFeaturedDemoLibraryShelf({
    super.key,
    required this.picks,
    required this.onPlayPick,
  });

  final List<ResolvedCuratedDemoPick> picks;
  final ValueChanged<ResolvedCuratedDemoPick> onPlayPick;

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WzSectionHeader(
          title: 'A few voices to start with',
          subtitle: 'Small picks from the loaded demo, kept intentionally quiet.',
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: WzSpacing.xs),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: math.min(8, picks.length),
            separatorBuilder: (_, __) => const SizedBox(width: WzSpacing.sm),
            itemBuilder: (context, index) => _LibraryCuratedPickCard(
              pick: picks[index],
              onPlay: () => onPlayPick(picks[index]),
            ),
          ),
        ),
        const SizedBox(height: WzSpacing.xs),
        const Text(CuratedDemoPicks.consumerCopy, style: WzText.caption),
      ],
    );
  }
}

class _LibraryCuratedPickCard extends StatelessWidget {
  const _LibraryCuratedPickCard({required this.pick, required this.onPlay});

  final ResolvedCuratedDemoPick pick;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final track = pick.track;
    return SizedBox(
      width: 242,
      child: WzPressableSurface(
        onTap: onPlay,
        radius: WzRadius.lg,
        decoration: WzSurface.sculpted(),
        padding: const EdgeInsets.all(WzSpacing.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(WzRadius.md),
                boxShadow: WzSurface.softShadows,
              ),
              child: WzArtwork(
                artworkUrl: track.artworkUrl,
                size: 76,
                trackId: track.trackId,
                title: track.title,
                artist: track.artistName,
                mood: pick.pick.mood,
              ),
            ),
            const SizedBox(width: WzSpacing.sm),
            Expanded(child: _LibraryCuratedPickText(pick: pick, onPlay: onPlay)),
          ],
        ),
      ),
    );
  }
}

class _LibraryCuratedPickText extends StatelessWidget {
  const _LibraryCuratedPickText({required this.pick, required this.onPlay});

  final ResolvedCuratedDemoPick pick;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final track = pick.track;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 13)),
        const SizedBox(height: 3),
        Text(track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
        const SizedBox(height: 3),
        Text('${pick.pick.shelfLabel} • ${pick.pick.mood}', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(fontSize: 10.5)),
        const Spacer(),
        Align(
          alignment: Alignment.centerLeft,
          child: WzSculptedIconButton(
            tooltip: 'Play',
            icon: Icons.play_arrow_rounded,
            size: 36,
            iconSize: 18,
            onPressed: onPlay,
          ),
        ),
      ],
    );
  }
}

class WzLibraryCatalogRow extends StatelessWidget {
  const WzLibraryCatalogRow({
    super.key,
    required this.track,
    required this.selected,
    required this.addDisabled,
    required this.onTap,
    required this.onAdd,
    required this.onToggleLike,
    required this.onAddToCollection,
    required this.liked,
    required this.onCache,
    required this.onDeleteCached,
  });

  final CatalogTrackSummary track;
  final bool selected;
  final bool addDisabled;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onToggleLike;
  final VoidCallback onAddToCollection;
  final bool liked;
  final VoidCallback? onCache;
  final VoidCallback? onDeleteCached;

  @override
  Widget build(BuildContext context) {
    final status = CacheService().statusForTrack(track.trackId);
    final isDevice = isWzDeviceCatalogTrack(track);
    final isCached = isWzCachedCatalogTrack(track);
    final sourceLabel = isDevice
        ? 'Device'
        : isCached
            ? wzCachedSourceBadgeLabel(track.displayName)
            : (track.license.sourceName ?? 'Catalog');
    final licenseLabel = _licenseBadgeLabel(track);
    final asset = track.primaryAsset;

    final cacheIcon = switch (status) {
      TrackCacheStatus.caching => Icons.downloading_rounded,
      TrackCacheStatus.cached => Icons.check_circle_outline_rounded,
      TrackCacheStatus.failed => Icons.error_outline_rounded,
      TrackCacheStatus.notCached => Icons.download_rounded,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WzPressableSurface(
        onTap: onTap,
        radius: WzRadius.lg,
        decoration: WzSurface.sculpted(selected: selected),
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(WzRadius.md),
                    boxShadow: selected ? WzSurface.softShadows : null,
                  ),
                  child: WzArtwork(
                    artworkUrl: track.artworkUrl,
                    size: 58,
                    trackId: track.trackId,
                    title: track.title,
                    artist: track.artistName,
                  ),
                ),
                const SizedBox(width: WzSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          _LibrarySourceBadge(label: sourceLabel, active: selected || isDevice || isCached),
                          _LibraryLicenseBadge(label: licenseLabel, warning: track.license.needsRightsWarning),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(_trackSubtitle(track), maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
                      const SizedBox(height: 3),
                      Text(
                        '${asset?.qualityLabel ?? 'quality unknown'}${asset?.codec == null ? '' : ' • ${asset!.codec}'}${isDevice ? ' • Already local' : isCached ? ' • Cached locally' : ' • ${status.name}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WzText.caption.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: WzSpacing.sm),
            Row(
              children: [
                Text(_formatTime(track.durationMs), style: WzText.caption.copyWith(color: WzColors.textMuted)),
                if (status == TrackCacheStatus.cached && !isCached) ...[
                  const SizedBox(width: WzSpacing.xs),
                  const WzStatusPill(label: 'Cached', active: true, icon: Icons.download_done_rounded),
                ],
                const Spacer(),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  alignment: WrapAlignment.end,
                  children: [
                    WzSculptedIconButton(
                      tooltip: liked ? 'Unlike' : 'Like',
                      icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      selected: liked,
                      size: 38,
                      iconSize: 17,
                      onPressed: onToggleLike,
                    ),
                    WzSculptedIconButton(
                      tooltip: 'Add to queue',
                      icon: Icons.playlist_add_rounded,
                      size: 38,
                      iconSize: 18,
                      onPressed: addDisabled ? null : onAdd,
                    ),
                    WzSculptedIconButton(
                      tooltip: 'Add to collection',
                      icon: Icons.library_add_rounded,
                      size: 38,
                      iconSize: 17,
                      onPressed: onAddToCollection,
                    ),
                    if (onCache != null)
                      WzSculptedIconButton(
                        tooltip: 'Cache/download',
                        icon: cacheIcon,
                        selected: status == TrackCacheStatus.cached,
                        size: 38,
                        iconSize: 17,
                        onPressed: onCache,
                      ),
                    if (onDeleteCached != null)
                      WzSculptedIconButton(
                        tooltip: 'Delete cached file',
                        icon: Icons.delete_outline_rounded,
                        size: 38,
                        iconSize: 17,
                        onPressed: onDeleteCached,
                      ),
                    if (onCache == null && onDeleteCached == null)
                      WzSculptedIcon(
                        icon: track.source == 'cloud_vault' ? Icons.cloud_done_outlined : Icons.phone_android_rounded,
                        size: 38,
                        iconSize: 17,
                        color: WzColors.success,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LibrarySourceBadge extends StatelessWidget {
  const _LibrarySourceBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: active ? WzColors.accent.withValues(alpha: 0.10) : const Color(0xBFFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? WzColors.accent.withValues(alpha: 0.22) : WzColors.borderSoft),
        ),
        child: Text(label, style: WzText.caption.copyWith(fontSize: 10, color: WzColors.textMuted, fontWeight: FontWeight.w700)),
      );
}

class _LibraryLicenseBadge extends StatelessWidget {
  const _LibraryLicenseBadge({required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: warning ? WzColors.warningSoft : WzColors.successSoft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: (warning ? WzColors.warning : WzColors.success).withValues(alpha: 0.20)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: WzText.caption.copyWith(
            fontSize: 10,
            color: warning ? WzColors.warning : WzColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

String _licenseBadgeLabel(CatalogTrackSummary track) {
  if (isWzDeviceCatalogTrack(track)) return 'Device music';
  if (track.license.status == LicenseStatus.unknown && track.trackId.startsWith('track-local-')) return 'Dev only';
  return track.license.badgeLabel;
}

String _trackSubtitle(CatalogTrackSummary track) {
  final asset = track.primaryAsset;
  final parts = <String>[track.subtitle];
  if (asset?.qualityLabel != null) parts.add(asset!.qualityLabel!);
  if (asset?.codec != null) parts.add(asset!.codec!);
  if (asset?.bitrateKbps != null) parts.add('${asset!.bitrateKbps}kbps');
  parts.add(isWzDeviceCatalogTrack(track) ? 'Device music' : (track.license.sourceName ?? 'Catalog'));
  parts.add(track.license.badgeLabel);
  return parts.join(' • ');
}

String _formatTime(int? valueMs) {
  if (valueMs == null || valueMs < 0) return '—:—';
  final totalSeconds = (valueMs / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
