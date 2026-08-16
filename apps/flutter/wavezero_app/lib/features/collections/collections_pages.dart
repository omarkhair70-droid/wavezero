import 'package:flutter/material.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import 'collections_service.dart';

class WzCollectionsPage extends StatelessWidget {
  const WzCollectionsPage({
    required this.collections,
    required this.onBack,
    required this.onOpen,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  final List<WzCollection> collections;
  final VoidCallback onBack;
  final ValueChanged<WzCollection> onOpen;
  final VoidCallback onCreate;
  final ValueChanged<WzCollection> onRename;
  final ValueChanged<WzCollection> onDelete;

  @override
  Widget build(BuildContext context) {
    final liked = collections.firstWhere((collection) => collection.type == WzCollectionType.liked, orElse: () => WzCollection.liked());
    final userCollections = collections.where((collection) => collection.type == WzCollectionType.user).toList(growable: false);
    return WzPageScaffold(
      children: [
        WzPageHeader(
          icon: Icons.playlist_play_rounded,
          title: 'Collections',
          subtitle: 'The music you chose to keep close.',
          trailing: Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              WzSculptedIconButton(tooltip: 'Back to Home', onPressed: onBack, icon: Icons.arrow_back_rounded, size: 42, iconSize: 18),
              WzPrimaryAction(label: 'Create', icon: Icons.add_rounded, onPressed: onCreate),
            ],
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        _CollectionCard(collection: liked, onOpen: () => onOpen(liked), onRename: null, onDelete: null),
        const SizedBox(height: WzSpacing.md),
        const WzSectionHeader(title: 'Your collections', subtitle: 'Local playlists stored on this device.', icon: Icons.queue_music_rounded),
        if (userCollections.isEmpty)
          const WzGlassCard(child: Text('No collections yet. Save tracks from Library, Search, or Now Playing.', style: WzText.body))
        else
          ...userCollections.map((collection) => Padding(
                padding: const EdgeInsets.only(bottom: WzSpacing.sm),
                child: _CollectionCard(
                  collection: collection,
                  onOpen: () => onOpen(collection),
                  onRename: () => onRename(collection),
                  onDelete: () => onDelete(collection),
                ),
              )),
        const SizedBox(height: WzSpacing.md),
        const WzGlassCard(
          child: Text('Collections only store lightweight metadata. Removing tracks or deleting a collection does not delete downloads, cache files, or device music.', style: WzText.caption),
        ),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, required this.onOpen, required this.onRename, required this.onDelete});

  final WzCollection collection;
  final VoidCallback onOpen;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = collection.tracks.isEmpty ? 'No tracks yet' : collection.tracks.first.title;
    return Container(
      padding: const EdgeInsets.all(WzSpacing.md),
      decoration: WzSurface.sculpted(selected: collection.type == WzCollectionType.liked),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(WzRadius.md), boxShadow: WzSurface.softShadows),
                child: WzArtwork(artworkUrl: collection.tracks.isEmpty ? null : collection.tracks.first.artworkUrl, size: 58),
              ),
              const SizedBox(width: WzSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(collection.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                  const SizedBox(height: WzSpacing.xxs),
                  Text('${collection.trackCount} ${collection.trackCount == 1 ? 'track' : 'tracks'} • Updated ${_friendlyUpdated(collection.updatedAtMs)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.body),
                ]),
              ),
            ],
          ),
          const SizedBox(height: WzSpacing.sm),
          Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.xs,
            children: [
              FilledButton.tonalIcon(onPressed: onOpen, icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open')),
              if (onRename != null) OutlinedButton.icon(onPressed: onRename, icon: const Icon(Icons.edit_rounded), label: const Text('Rename')),
              if (onDelete != null) OutlinedButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class WzCollectionDetailPage extends StatelessWidget {
  const WzCollectionDetailPage({
    required this.collection,
    required this.onBack,
    required this.onPlayFirst,
    required this.onAddAllToQueue,
    required this.onRename,
    required this.onDelete,
    required this.onPlayTrack,
    required this.onAddTrackToQueue,
    required this.onRemoveTrack,
    required this.resolver,
  });

  final WzCollection collection;
  final VoidCallback onBack;
  final ValueChanged<WzCollection> onPlayFirst;
  final ValueChanged<WzCollection> onAddAllToQueue;
  final ValueChanged<WzCollection> onRename;
  final ValueChanged<WzCollection> onDelete;
  final ValueChanged<WzCollectionTrackSnapshot> onPlayTrack;
  final ValueChanged<WzCollectionTrackSnapshot> onAddTrackToQueue;
  final void Function(WzCollection collection, WzCollectionTrackSnapshot track) onRemoveTrack;
  final CatalogTrackSummary? Function(WzCollectionTrackSnapshot track) resolver;

  @override
  Widget build(BuildContext context) => WzPageScaffold(
        children: [
          WzPageHeader(
            icon: collection.type == WzCollectionType.liked ? Icons.favorite_rounded : Icons.playlist_play_rounded,
            title: collection.name,
            subtitle: '${collection.trackCount} ${collection.trackCount == 1 ? 'track' : 'tracks'} saved locally on this device.',
            trailing: WzSculptedIconButton(tooltip: 'Back to Collections', onPressed: onBack, icon: Icons.arrow_back_rounded, size: 42, iconSize: 18),
          ),
          const SizedBox(height: WzSpacing.md),
          WzGlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
                WzStatusPill(label: collection.type == WzCollectionType.liked ? 'Liked' : 'Collection', active: true, icon: collection.type == WzCollectionType.liked ? Icons.favorite_rounded : Icons.playlist_play_rounded),
                WzStatusPill(label: '${collection.trackCount} tracks', icon: Icons.music_note_rounded),
                const WzStatusPill(label: 'Local only', icon: Icons.phone_android_rounded),
              ]),
              const SizedBox(height: WzSpacing.md),
              Wrap(spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
                FilledButton.tonalIcon(onPressed: collection.tracks.isEmpty ? null : () => onPlayFirst(collection), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Play first')),
                OutlinedButton.icon(onPressed: collection.tracks.isEmpty ? null : () => onAddAllToQueue(collection), icon: const Icon(Icons.queue_music_rounded), label: const Text('Add all to Queue')),
                if (collection.type == WzCollectionType.user) OutlinedButton.icon(onPressed: () => onRename(collection), icon: const Icon(Icons.edit_rounded), label: const Text('Rename')),
                if (collection.type == WzCollectionType.user) OutlinedButton.icon(onPressed: () => onDelete(collection), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Delete')),
              ]),
            ]),
          ),
          const SizedBox(height: WzSpacing.md),
          if (collection.tracks.isEmpty)
            const WzGlassCard(child: Text('This collection is empty. Save tracks from Library, Search, or Now Playing.', style: WzText.body))
          else
            ...collection.tracks.map((track) => Padding(
                  padding: const EdgeInsets.only(bottom: WzSpacing.sm),
                  child: _CollectionTrackRow(
                    track: track,
                    available: resolver(track) != null,
                    onPlay: () => onPlayTrack(track),
                    onAddToQueue: () => onAddTrackToQueue(track),
                    onRemove: () => onRemoveTrack(collection, track),
                  ),
                )),
        ],
      );
}

class _CollectionTrackRow extends StatelessWidget {
  const _CollectionTrackRow({required this.track, required this.available, required this.onPlay, required this.onAddToQueue, required this.onRemove});

  final WzCollectionTrackSnapshot track;
  final bool available;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(WzSpacing.sm),
        decoration: WzSurface.sculpted(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            WzArtwork(artworkUrl: track.artworkUrl, size: 48, trackId: track.trackId, title: track.title, artist: track.subtitle),
            const SizedBox(width: WzSpacing.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
              Text(track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
            ])),
          ]),
          const SizedBox(height: WzSpacing.xs),
          Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
            WzStatusPill(label: _collectionSourceLabel(track.source), active: track.source == WzCollectionTrackSource.device || track.source == WzCollectionTrackSource.cached, icon: Icons.source_rounded),
            if (track.qualityLabel != null) WzStatusPill(label: wzProductQualityLabel(track.qualityLabel!), icon: Icons.high_quality_rounded),
            WzStatusPill(label: track.source == WzCollectionTrackSource.device ? 'Your device' : track.license.badgeLabel, active: track.source == WzCollectionTrackSource.device || !track.license.needsRightsWarning, warning: track.license.needsRightsWarning && track.source != WzCollectionTrackSource.device, icon: Icons.policy_outlined),
            if (!available) const WzStatusPill(label: 'Track is not available right now', warning: true, icon: Icons.cloud_off_rounded),
          ]),
          const SizedBox(height: WzSpacing.xs),
          Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
            OutlinedButton.icon(onPressed: available ? onPlay : null, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Play')),
            OutlinedButton.icon(onPressed: available ? onAddToQueue : null, icon: const Icon(Icons.queue_music_rounded), label: const Text('Add to Queue')),
            OutlinedButton.icon(onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline_rounded), label: const Text('Remove')),
          ]),
        ]),
      );
}

String _collectionSourceLabel(WzCollectionTrackSource source) => switch (source) {
      WzCollectionTrackSource.api => 'Catalog',
      WzCollectionTrackSource.device => 'Device',
      WzCollectionTrackSource.cached => 'Downloaded',
      WzCollectionTrackSource.unknown => 'Unknown',
    };

String _friendlyUpdated(int updatedAtMs) {
  final age = DateTime.now().millisecondsSinceEpoch - updatedAtMs;
  if (age < 60000) return 'just now';
  final minutes = age ~/ 60000;
  if (minutes < 60) return '${minutes}m ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return '${hours}h ago';
  final days = hours ~/ 24;
  return '${days}d ago';
}
