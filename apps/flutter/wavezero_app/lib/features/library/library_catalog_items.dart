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
          title: 'Featured from this demo',
          subtitle: 'A small curated shelf before the full catalog list.',
          icon: Icons.stars,
        ),
        const SizedBox(height: WzSpacing.sm),
        SizedBox(
          height: 104,
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
      width: 230,
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(WzRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(WzSpacing.sm),
          decoration: BoxDecoration(
            color: WzColors.surfaceMuted,
            borderRadius: BorderRadius.circular(WzRadius.lg),
            border: Border.all(color: WzColors.borderSoft),
          ),
          child: Row(
            children: [
              WzArtwork(
                artworkUrl: track.artworkUrl,
                size: 72,
                trackId: track.trackId,
                title: track.title,
                artist: track.artistName,
                mood: pick.pick.mood,
              ),
              const SizedBox(width: WzSpacing.sm),
              Expanded(child: _LibraryCuratedPickText(pick: pick, onPlay: onPlay)),
            ],
          ),
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
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: WzText.sectionTitle.copyWith(fontSize: 13),
        ),
        const SizedBox(height: WzSpacing.xxs),
        Text(track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
        const SizedBox(height: WzSpacing.xxs),
        Text(
          '${pick.pick.shelfLabel} • ${pick.pick.mood}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: WzText.caption,
        ),
        const Spacer(),
        SizedBox(
          height: 32,
          child: FilledButton.tonalIcon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Play'),
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
      TrackCacheStatus.caching => const Icon(Icons.downloading, color: Color(0xFF98A1B8)),
      TrackCacheStatus.cached => const Icon(Icons.check_circle, color: Color(0xFF38D996)),
      TrackCacheStatus.failed => const Icon(Icons.error, color: Color(0xFFFFC46B)),
      TrackCacheStatus.notCached => const Icon(Icons.download, color: Color(0xFF8D7CFF)),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WzRadius.lg),
      child: AnimatedContainer(
        duration: WzMotion.fast,
        curve: WzMotion.curve,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? WzColors.accentSoft : WzColors.surfaceMuted,
          borderRadius: BorderRadius.circular(WzRadius.lg),
          border: Border.all(color: selected ? WzColors.accent.withOpacity(0.65) : WzColors.borderSoft),
          boxShadow: selected
              ? [BoxShadow(color: WzColors.accent.withOpacity(0.14), blurRadius: 22, offset: const Offset(0, 10))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                WzArtwork(
                  artworkUrl: track.artworkUrl,
                  size: 54,
                  trackId: track.trackId,
                  title: track.title,
                  artist: track.artistName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              track.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _LibrarySourceBadge(label: sourceLabel, active: selected || isDevice || isCached),
                          _LibraryLicenseBadge(label: licenseLabel, warning: track.license.needsRightsWarning),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _trackSubtitle(track),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _captionStyle,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${asset?.qualityLabel ?? 'quality unknown'}${asset?.codec == null ? '' : ' • ${asset!.codec}'}${isDevice ? ' • Already local' : isCached ? ' • Cached locally' : ' • ${status.name}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _captionStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Text(_formatTime(track.durationMs), style: _timeStyle),
                if (status == TrackCacheStatus.cached && !isCached)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF173626), borderRadius: BorderRadius.circular(10)),
                    child: const Text(
                      'Cached',
                      style: TextStyle(color: Color(0xFF38D996), fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                IconButton(
                  tooltip: liked ? 'Unlike' : 'Like',
                  onPressed: onToggleLike,
                  icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? const Color(0xFFFF6B8A) : const Color(0xFF8D7CFF)),
                ),
                IconButton(
                  tooltip: 'Add to queue',
                  onPressed: addDisabled ? null : onAdd,
                  icon: const Icon(Icons.playlist_add, color: Color(0xFF8D7CFF)),
                ),
                IconButton(
                  tooltip: 'Add to collection',
                  onPressed: onAddToCollection,
                  icon: const Icon(Icons.library_add, color: Color(0xFF8D7CFF)),
                ),
                if (onCache != null) IconButton(tooltip: 'Cache/download', onPressed: onCache, icon: cacheIcon),
                if (onDeleteCached != null)
                  IconButton(
                    tooltip: 'Delete cached file',
                    onPressed: onDeleteCached,
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFFF8F8F)),
                  ),
                if (onCache == null && onDeleteCached == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      track.source == 'cloud_vault' ? Icons.cloud_done_outlined : Icons.phone_android,
                      color: const Color(0xFF38D996),
                    ),
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
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF172A36) : const Color(0xFF171B28),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF9EDBFF), fontSize: 10, fontWeight: FontWeight.w800),
        ),
      );
}

class _LibraryLicenseBadge extends StatelessWidget {
  const _LibraryLicenseBadge({required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: warning ? const Color(0xFF332613) : const Color(0xFF15251E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: warning ? const Color(0xFFFFC46B) : const Color(0x6638D996)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: warning ? const Color(0xFFFFC46B) : const Color(0xFF8FF0C0),
            fontSize: 10,
            fontWeight: FontWeight.w800,
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

const _captionStyle = TextStyle(color: Color(0xFF98A1B8), fontSize: 12);
const _timeStyle = TextStyle(color: Color(0xFF9BA3B4), fontSize: 12);
