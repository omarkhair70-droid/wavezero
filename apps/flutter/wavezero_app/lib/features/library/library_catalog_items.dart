import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/curated_demo_picks.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/track_source.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../downloads/cache_service.dart';

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
        const Text('A few voices', style: WzText.title),
        const SizedBox(height: 4),
        const Text('Something to start with.', style: WzText.caption),
        const SizedBox(height: 10),
        SizedBox(
          height: 108,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemCount: math.min(8, picks.length),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final pick = picks[index];
              return _LibraryCuratedPickCard(
                pick: pick,
                onPlay: () => onPlayPick(pick),
              );
            },
          ),
        ),
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
      width: 225,
      child: WzPressableSurface(
        onTap: onPlay,
        radius: 30,
        decoration: WzSurface.sculpted(),
        padding: const EdgeInsets.all(9),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(27),
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(17),
              ),
              child: WzArtwork(
                artworkUrl: track.artworkUrl,
                size: 76,
                trackId: track.trackId,
                title: track.title,
                artist: track.artistName,
                mood: pick.pick.mood,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(track.artistName ?? track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: WzSculptedIconButton(
                      tooltip: 'Play',
                      icon: Icons.play_arrow_rounded,
                      size: 34,
                      iconSize: 18,
                      onPressed: onPlay,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    final cacheStatus = CacheService().statusForTrack(track.trackId);
    final isDevice = isWzDeviceCatalogTrack(track);
    final isCached = isWzCachedCatalogTrack(track);
    final subtitle = track.artistName ?? track.albumName ?? track.subtitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: WzPressableSurface(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius: 28,
        decoration: selected
            ? WzSurface.sculpted(selected: true)
            : BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(28),
              ),
        padding: const EdgeInsets.fromLTRB(7, 7, 5, 7),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(23),
                bottomRight: Radius.circular(15),
              ),
              child: WzArtwork(
                artworkUrl: track.artworkUrl,
                size: 58,
                trackId: track.trackId,
                title: track.title,
                artist: track.artistName,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.sectionTitle.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  if (isDevice || isCached) ...[
                    const SizedBox(height: 3),
                    Text(
                      isDevice ? 'On this device' : 'Available offline',
                      style: WzText.caption.copyWith(fontSize: 10.5, color: WzColors.accent),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            _HeartButton(liked: liked, onTap: onToggleLike),
            WzSculptedIconButton(
              tooltip: 'Add to queue',
              icon: Icons.queue_music_rounded,
              size: 38,
              iconSize: 17,
              onPressed: addDisabled ? null : onAdd,
            ),
            WzSculptedIconButton(
              tooltip: 'Add to collection',
              icon: Icons.playlist_add_rounded,
              size: 38,
              iconSize: 17,
              onPressed: onAddToCollection,
            ),
            if (onCache != null)
              WzSculptedIconButton(
                tooltip: cacheStatus == TrackCacheStatus.cached ? 'Downloaded' : 'Download',
                icon: cacheStatus == TrackCacheStatus.caching
                    ? Icons.downloading_rounded
                    : cacheStatus == TrackCacheStatus.cached
                        ? Icons.check_rounded
                        : Icons.download_rounded,
                selected: cacheStatus == TrackCacheStatus.cached,
                size: 38,
                iconSize: 17,
                onPressed: onCache,
              )
            else if (onDeleteCached != null)
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz_rounded, color: WzColors.textMuted),
                onSelected: (value) {
                  if (value == 'remove') onDeleteCached?.call();
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove download'))],
              )
            else
              const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.liked, required this.onTap});

  final bool liked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WzPressableSurface(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        radius: 19,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: liked ? const Color(0xFFFFF0F2) : Colors.transparent,
        ),
        padding: const EdgeInsets.all(9),
        child: Tooltip(
          message: liked ? 'Unlike' : 'Like',
          child: AnimatedSwitcher(
            duration: WzMotion.normal,
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(liked),
              size: 20,
              color: liked ? const Color(0xFFD85C6A) : WzColors.textMuted,
            ),
          ),
        ),
      );
}
