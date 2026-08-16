import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
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
        Row(
          children: [
            WzSculptedIconButton(tooltip: 'Back to Library', onPressed: onBack, icon: Icons.arrow_back_rounded, size: 44, iconSize: 19),
            const SizedBox(width: 13),
            Expanded(child: Text('Collections', style: WzText.pageTitle.copyWith(fontSize: 30))),
            WzSculptedIconButton(tooltip: 'Create collection', onPressed: onCreate, icon: Icons.add_rounded, size: 44, iconSize: 21),
          ],
        ),
        const SizedBox(height: 22),
        _CollectionCard(collection: liked, onOpen: () => onOpen(liked), onRename: null, onDelete: null),
        const SizedBox(height: 24),
        const Text('Your collections', style: WzText.title),
        const SizedBox(height: 4),
        const Text('Playlists that stay with you on this device.', style: WzText.caption),
        const SizedBox(height: 12),
        if (userCollections.isEmpty)
          WzGlassCard(
            borderRadius: 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nothing here yet', style: WzText.sectionTitle),
                const SizedBox(height: 5),
                const Text('Save tracks from Library, Search, or Now Playing.', style: WzText.body),
                const SizedBox(height: 14),
                WzPrimaryAction(label: 'Create collection', icon: Icons.add_rounded, onPressed: onCreate),
              ],
            ),
          )
        else
          ...userCollections.map(
            (collection) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _CollectionCard(
                collection: collection,
                onOpen: () => onOpen(collection),
                onRename: () => onRename(collection),
                onDelete: () => onDelete(collection),
              ),
            ),
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
    final first = collection.tracks.isEmpty ? null : collection.tracks.first;
    return WzPressableSurface(
      onTap: () {
        HapticFeedback.selectionClick();
        onOpen();
      },
      radius: 32,
      decoration: WzSurface.sculpted(selected: collection.type == WzCollectionType.liked),
      padding: const EdgeInsets.fromLTRB(11, 11, 8, 11),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(28),
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(17),
            ),
            child: WzArtwork(
              artworkUrl: first?.artworkUrl,
              size: 64,
              trackId: first?.trackId ?? collection.id,
              title: first?.title ?? collection.name,
              artist: first?.subtitle,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(collection.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                const SizedBox(height: 4),
                Text('${collection.trackCount} ${collection.trackCount == 1 ? 'track' : 'tracks'}', style: WzText.caption),
                if (first != null) ...[
                  const SizedBox(height: 3),
                  Text(first.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(color: WzColors.textMuted)),
                ],
              ],
            ),
          ),
          if (onRename != null || onDelete != null)
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_horiz_rounded, color: WzColors.textMuted),
              onSelected: (value) {
                if (value == 'rename') onRename?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                if (onRename != null) const PopupMenuItem(value: 'rename', child: Text('Rename')),
                if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )
          else
            const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: WzColors.textSubtle),
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
          Row(
            children: [
              WzSculptedIconButton(tooltip: 'Back to Collections', onPressed: onBack, icon: Icons.arrow_back_rounded, size: 44, iconSize: 19),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(collection.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.pageTitle.copyWith(fontSize: 27)),
                    const SizedBox(height: 3),
                    Text('${collection.trackCount} ${collection.trackCount == 1 ? 'track' : 'tracks'}', style: WzText.caption),
                  ],
                ),
              ),
              if (collection.type == WzCollectionType.user)
                PopupMenuButton<String>(
                  tooltip: 'Collection options',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (value) {
                    if (value == 'rename') onRename(collection);
                    if (value == 'delete') onDelete(collection);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (collection.tracks.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: WzPrimaryAction(
                    label: 'Play',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => onPlayFirst(collection),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAddAllToQueue(collection),
                    icon: const Icon(Icons.queue_music_rounded),
                    label: const Text('Queue all'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),
          if (collection.tracks.isEmpty)
            const WzGlassCard(child: Text('This collection is empty. Add something you want to keep close.', style: WzText.body))
          else
            ...collection.tracks.map(
              (track) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _CollectionTrackRow(
                  track: track,
                  available: resolver(track) != null,
                  onPlay: () => onPlayTrack(track),
                  onAddToQueue: () => onAddTrackToQueue(track),
                  onRemove: () => onRemoveTrack(collection, track),
                ),
              ),
            ),
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
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: available ? onPlay : null,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(17),
                    topRight: Radius.circular(23),
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(14),
                  ),
                  child: WzArtwork(
                    artworkUrl: track.artworkUrl,
                    size: 54,
                    trackId: track.trackId,
                    title: track.title,
                    artist: track.subtitle,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                      if (!available) Text('Unavailable right now', style: WzText.caption.copyWith(fontSize: 10.5, color: WzColors.warning)),
                    ],
                  ),
                ),
                WzSculptedIconButton(
                  tooltip: 'Play',
                  icon: Icons.play_arrow_rounded,
                  size: 38,
                  iconSize: 19,
                  onPressed: available ? onPlay : null,
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(Icons.more_horiz_rounded, color: WzColors.textMuted),
                  onSelected: (value) {
                    if (value == 'queue') onAddToQueue();
                    if (value == 'remove') onRemove();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(enabled: available, value: 'queue', child: const Text('Add to queue')),
                    const PopupMenuItem(value: 'remove', child: Text('Remove from collection')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
