import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/track_source.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import 'library_catalog_items.dart';
import 'library_grouping.dart';

class WzLibraryBrowseSection extends StatefulWidget {
  const WzLibraryBrowseSection({
    super.key,
    required this.tracks,
    required this.selectedTrackId,
    required this.addToQueueDisabled,
    required this.onSelectTrack,
    required this.onAddToQueue,
    required this.onToggleLike,
    required this.onAddToCollection,
    required this.isLiked,
    required this.onCache,
    required this.onDeleteCachedTrack,
  });

  final List<CatalogTrackSummary> tracks;
  final String? selectedTrackId;
  final bool addToQueueDisabled;
  final ValueChanged<CatalogTrackSummary> onSelectTrack;
  final ValueChanged<CatalogTrackSummary> onAddToQueue;
  final ValueChanged<CatalogTrackSummary> onToggleLike;
  final ValueChanged<CatalogTrackSummary> onAddToCollection;
  final bool Function(CatalogTrackSummary track) isLiked;
  final ValueChanged<CatalogTrackSummary> onCache;
  final ValueChanged<CatalogTrackSummary> onDeleteCachedTrack;

  @override
  State<WzLibraryBrowseSection> createState() => _WzLibraryBrowseSectionState();
}

class _WzLibraryBrowseSectionState extends State<WzLibraryBrowseSection> {
  WzLibraryGroupKind _kind = WzLibraryGroupKind.artist;

  @override
  Widget build(BuildContext context) {
    final artists = buildWzArtistGroups(widget.tracks);
    final albums = buildWzAlbumGroups(widget.tracks);
    if (artists.isEmpty && albums.isEmpty) return const SizedBox.shrink();

    final effectiveKind = _kind == WzLibraryGroupKind.artist && artists.isEmpty
        ? WzLibraryGroupKind.album
        : _kind == WzLibraryGroupKind.album && albums.isEmpty
            ? WzLibraryGroupKind.artist
            : _kind;
    final groups = effectiveKind == WzLibraryGroupKind.artist ? artists : albums;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Browse your library', style: WzText.title),
                  SizedBox(height: 3),
                  Text('WaveZero groups the metadata already on your music.', style: WzText.caption),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _BrowseKindChip(
              label: 'Artists',
              count: artists.length,
              selected: effectiveKind == WzLibraryGroupKind.artist,
              onTap: artists.isEmpty
                  ? null
                  : () => setState(() => _kind = WzLibraryGroupKind.artist),
            ),
            const SizedBox(width: 6),
            _BrowseKindChip(
              label: 'Albums',
              count: albums.length,
              selected: effectiveKind == WzLibraryGroupKind.album,
              onTap: albums.isEmpty
                  ? null
                  : () => setState(() => _kind = WzLibraryGroupKind.album),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: math.min(10, groups.length),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final group = groups[index];
              return _LibraryGroupCard(
                group: group,
                onTap: () => _openGroup(context, group),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openGroup(BuildContext context, WzLibraryGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WzLibraryGroupPage(
          group: group,
          selectedTrackId: widget.selectedTrackId,
          addToQueueDisabled: widget.addToQueueDisabled,
          onSelectTrack: widget.onSelectTrack,
          onAddToQueue: widget.onAddToQueue,
          onToggleLike: widget.onToggleLike,
          onAddToCollection: widget.onAddToCollection,
          isLiked: widget.isLiked,
          onCache: widget.onCache,
          onDeleteCachedTrack: widget.onDeleteCachedTrack,
        ),
      ),
    );
  }
}

class _BrowseKindChip extends StatelessWidget {
  const _BrowseKindChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: WzMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? WzColors.accentSoft : WzColors.surfaceMuted,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? WzColors.accent.withValues(alpha: .35) : WzColors.borderSoft,
            ),
          ),
          child: Text(
            '$label $count',
            style: WzText.caption.copyWith(
              color: selected ? WzColors.textPrimary : WzColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

class _LibraryGroupCard extends StatelessWidget {
  const _LibraryGroupCard({required this.group, required this.onTap});

  final WzLibraryGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final representative = group.tracks.first;
    return SizedBox(
      width: 218,
      child: WzPressableSurface(
        onTap: onTap,
        radius: 28,
        decoration: WzSurface.sculpted(),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: WzArtwork(
                artworkUrl: group.artworkUrl,
                size: 72,
                trackId: representative.trackId,
                title: group.title,
                artist: representative.artistName,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.sectionTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.subtitle ?? '${group.trackCount} tracks',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: WzColors.textSubtle),
          ],
        ),
      ),
    );
  }
}

class WzLibraryGroupPage extends StatelessWidget {
  const WzLibraryGroupPage({
    super.key,
    required this.group,
    required this.selectedTrackId,
    required this.addToQueueDisabled,
    required this.onSelectTrack,
    required this.onAddToQueue,
    required this.onToggleLike,
    required this.onAddToCollection,
    required this.isLiked,
    required this.onCache,
    required this.onDeleteCachedTrack,
  });

  final WzLibraryGroup group;
  final String? selectedTrackId;
  final bool addToQueueDisabled;
  final ValueChanged<CatalogTrackSummary> onSelectTrack;
  final ValueChanged<CatalogTrackSummary> onAddToQueue;
  final ValueChanged<CatalogTrackSummary> onToggleLike;
  final ValueChanged<CatalogTrackSummary> onAddToCollection;
  final bool Function(CatalogTrackSummary track) isLiked;
  final ValueChanged<CatalogTrackSummary> onCache;
  final ValueChanged<CatalogTrackSummary> onDeleteCachedTrack;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: WzColors.canvas,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(
            group.kind == WzLibraryGroupKind.artist ? 'Artist' : 'Album',
            style: WzText.sectionTitle,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            Text(group.title, style: WzText.pageTitle),
            const SizedBox(height: 5),
            Text(group.subtitle ?? '${group.trackCount} tracks', style: WzText.body),
            const SizedBox(height: 22),
            ...group.tracks.map((track) => _trackRow(track)),
          ],
        ),
      );

  Widget _trackRow(CatalogTrackSummary track) {
    final isDevice = isWzDeviceCatalogTrack(track);
    final isCached = isWzCachedCatalogTrack(track);
    final isCloud = track.source == 'cloud_vault';
    return WzLibraryCatalogRow(
      track: track,
      selected: track.trackId == selectedTrackId,
      addDisabled: addToQueueDisabled || (isCloud && track.primaryAsset == null),
      onTap: () => onSelectTrack(track),
      onAdd: () => onAddToQueue(track),
      onToggleLike: () => onToggleLike(track),
      onAddToCollection: () => onAddToCollection(track),
      liked: isLiked(track),
      onCache: isDevice || isCached || isCloud ? null : () => onCache(track),
      onDeleteCached: isCached ? () => onDeleteCachedTrack(track) : null,
    );
  }
}
