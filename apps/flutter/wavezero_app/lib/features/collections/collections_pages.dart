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
    required this.onImportM3u,
    required this.onRename,
    required this.onDelete,
  });

  final List<WzCollection> collections;
  final VoidCallback onBack;
  final ValueChanged<WzCollection> onOpen;
  final VoidCallback onCreate;
  final VoidCallback onImportM3u;
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
            WzSculptedIconButton(tooltip: 'Import M3U playlist', onPressed: onImportM3u, icon: Icons.file_open_rounded, size: 44, iconSize: 20),
            const SizedBox(width: 7),
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
                Row(
                  children: [
                    Expanded(child: WzPrimaryAction(label: 'Create collection', icon: Icons.add_rounded, onPressed: onCreate)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onImportM3u,
                        icon: const Icon(Icons.file_open_rounded),
                        label: const Text('Import M3U'),
                      ),
                    ),
                  ],
                ),
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

class WzCollectionDetailPage extends StatefulWidget {
  const WzCollectionDetailPage({
    required this.collection,
    required this.collections,
    required this.onBack,
    required this.onPlayFirst,
    required this.onAddAllToQueue,
    required this.onRename,
    required this.onDelete,
    required this.onExportM3u,
    required this.onPlayTrack,
    required this.onAddTrackToQueue,
    required this.onRemoveTrack,
    required this.onReorderTrack,
    required this.onBulkAddToQueue,
    required this.onBulkRemove,
    required this.onBulkAddToCollection,
    required this.resolver,
  });

  final WzCollection collection;
  final List<WzCollection> collections;
  final VoidCallback onBack;
  final ValueChanged<WzCollection> onPlayFirst;
  final ValueChanged<WzCollection> onAddAllToQueue;
  final ValueChanged<WzCollection> onRename;
  final ValueChanged<WzCollection> onDelete;
  final ValueChanged<WzCollection> onExportM3u;
  final ValueChanged<WzCollectionTrackSnapshot> onPlayTrack;
  final ValueChanged<WzCollectionTrackSnapshot> onAddTrackToQueue;
  final void Function(WzCollection collection, WzCollectionTrackSnapshot track) onRemoveTrack;
  final void Function(WzCollection collection, int oldIndex, int newIndex) onReorderTrack;
  final void Function(WzCollection collection, List<WzCollectionTrackSnapshot> tracks) onBulkAddToQueue;
  final void Function(WzCollection collection, List<WzCollectionTrackSnapshot> tracks) onBulkRemove;
  final void Function(WzCollection source, WzCollection destination, List<WzCollectionTrackSnapshot> tracks) onBulkAddToCollection;
  final CatalogTrackSummary? Function(WzCollectionTrackSnapshot track) resolver;

  @override
  State<WzCollectionDetailPage> createState() => _WzCollectionDetailPageState();
}

class _WzCollectionDetailPageState extends State<WzCollectionDetailPage> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  List<WzCollectionTrackSnapshot> get _selectedTracks => widget.collection.tracks
      .where((track) => _selectedIds.contains(track.trackId))
      .toList(growable: false);

  @override
  void didUpdateWidget(covariant WzCollectionDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.collection.tracks.map((track) => track.trackId).toSet();
    _selectedIds.removeWhere((id) => !currentIds.contains(id));
    if (_selectionMode && widget.collection.tracks.isEmpty) _selectionMode = false;
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
    HapticFeedback.selectionClick();
  }

  void _toggleTrack(String trackId) {
    setState(() {
      if (!_selectedIds.add(trackId)) _selectedIds.remove(trackId);
    });
    HapticFeedback.selectionClick();
  }

  void _selectAllOrNone() {
    setState(() {
      if (_selectedIds.length == widget.collection.tracks.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(widget.collection.tracks.map((track) => track.trackId));
      }
    });
  }

  void _finishBulkAction() {
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _showBulkDestinationSheet() async {
    final selected = _selectedTracks;
    if (selected.isEmpty) return;
    final destinations = widget.collections
        .where((collection) => collection.id != widget.collection.id)
        .toList(growable: false);
    if (destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create another collection first.')),
      );
      return;
    }
    final destination = await showModalBottomSheet<WzCollection>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add ${selected.length} tracks to', style: WzText.title),
              const SizedBox(height: 10),
              ...destinations.map(
                (collection) => ListTile(
                  leading: Icon(collection.isLiked ? Icons.favorite_rounded : Icons.playlist_play_rounded),
                  title: Text(collection.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${collection.trackCount} tracks'),
                  onTap: () => Navigator.of(sheetContext).pop(collection),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (destination == null) return;
    widget.onBulkAddToCollection(widget.collection, destination, selected);
    _finishBulkAction();
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    final selected = _selectedTracks;
    return WzPageScaffold(
      children: [
        Row(
          children: [
            WzSculptedIconButton(
              tooltip: _selectionMode ? 'Done selecting' : 'Back to Collections',
              onPressed: _selectionMode ? _toggleSelectionMode : widget.onBack,
              icon: _selectionMode ? Icons.close_rounded : Icons.arrow_back_rounded,
              size: 44,
              iconSize: 19,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectionMode ? '${selected.length} selected' : collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.pageTitle.copyWith(fontSize: 27),
                  ),
                  const SizedBox(height: 3),
                  Text('${collection.trackCount} ${collection.trackCount == 1 ? 'track' : 'tracks'}', style: WzText.caption),
                ],
              ),
            ),
            if (!_selectionMode && collection.tracks.isNotEmpty)
              WzSculptedIconButton(
                tooltip: 'Select tracks',
                onPressed: _toggleSelectionMode,
                icon: Icons.checklist_rounded,
                size: 44,
                iconSize: 20,
              ),
            if (!_selectionMode)
              PopupMenuButton<String>(
                tooltip: 'Collection options',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  if (value == 'export') widget.onExportM3u(collection);
                  if (value == 'rename') widget.onRename(collection);
                  if (value == 'delete') widget.onDelete(collection);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'export', child: Text('Export M3U')),
                  if (collection.type == WzCollectionType.user) const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  if (collection.type == WzCollectionType.user) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (_selectionMode)
          _BulkSelectionBar(
            selectedCount: selected.length,
            allSelected: selected.length == collection.tracks.length && collection.tracks.isNotEmpty,
            onSelectAll: _selectAllOrNone,
            onQueue: selected.isEmpty
                ? null
                : () {
                    widget.onBulkAddToQueue(collection, selected);
                    _finishBulkAction();
                  },
            onAddToCollection: selected.isEmpty ? null : _showBulkDestinationSheet,
            onRemove: selected.isEmpty
                ? null
                : () {
                    widget.onBulkRemove(collection, selected);
                    _finishBulkAction();
                  },
          )
        else if (collection.tracks.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: WzPrimaryAction(
                  label: 'Play',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => widget.onPlayFirst(collection),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onAddAllToQueue(collection),
                  icon: const Icon(Icons.queue_music_rounded),
                  label: const Text('Queue all'),
                ),
              ),
            ],
          ),
        if (!_selectionMode && collection.tracks.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.drag_handle_rounded, size: 16, color: WzColors.textMuted),
              const SizedBox(width: 6),
              Text('Hold the handle to reorder', style: WzText.caption),
            ],
          ),
        ],
        const SizedBox(height: 18),
        if (collection.tracks.isEmpty)
          const WzGlassCard(child: Text('This collection is empty. Add something you want to keep close.', style: WzText.body))
        else if (_selectionMode)
          ...collection.tracks.map(
            (track) => Padding(
              key: ValueKey('collection-track-select-${track.trackId}'),
              padding: const EdgeInsets.only(bottom: 7),
              child: _CollectionTrackRow(
                track: track,
                available: widget.resolver(track) != null,
                selectionMode: true,
                selected: _selectedIds.contains(track.trackId),
                onToggleSelected: () => _toggleTrack(track.trackId),
                onPlay: () => widget.onPlayTrack(track),
                onAddToQueue: () => widget.onAddTrackToQueue(track),
                onRemove: () => widget.onRemoveTrack(collection, track),
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: collection.tracks.length,
            onReorder: (oldIndex, newIndex) {
              HapticFeedback.selectionClick();
              widget.onReorderTrack(collection, oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final track = collection.tracks[index];
              return Padding(
                key: ValueKey('collection-track-${track.trackId}'),
                padding: const EdgeInsets.only(bottom: 7),
                child: _CollectionTrackRow(
                  track: track,
                  available: widget.resolver(track) != null,
                  onPlay: () => widget.onPlayTrack(track),
                  onAddToQueue: () => widget.onAddTrackToQueue(track),
                  onRemove: () => widget.onRemoveTrack(collection, track),
                  dragHandle: ReorderableDelayedDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.drag_handle_rounded, size: 20, color: WzColors.textMuted),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _BulkSelectionBar extends StatelessWidget {
  const _BulkSelectionBar({
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onQueue,
    required this.onAddToCollection,
    required this.onRemove,
  });

  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback? onQueue;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => WzGlassCard(
        borderRadius: 26,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('$selectedCount selected', style: WzText.sectionTitle)),
                TextButton(
                  onPressed: onSelectAll,
                  child: Text(allSelected ? 'Select none' : 'Select all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onQueue,
                  icon: const Icon(Icons.queue_music_rounded),
                  label: const Text('Queue'),
                ),
                OutlinedButton.icon(
                  onPressed: onAddToCollection,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Add to'),
                ),
                OutlinedButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _CollectionTrackRow extends StatelessWidget {
  const _CollectionTrackRow({
    required this.track,
    required this.available,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onRemove,
    this.dragHandle,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
  });

  final WzCollectionTrackSnapshot track;
  final bool available;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;
  final VoidCallback onRemove;
  final Widget? dragHandle;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelected;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: selectionMode ? onToggleSelected : (available ? onPlay : null),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
            child: Row(
              children: [
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Checkbox(value: selected, onChanged: (_) => onToggleSelected?.call()),
                  )
                else if (dragHandle != null)
                  dragHandle!,
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
                if (!selectionMode) ...[
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
              ],
            ),
          ),
        ),
      );
}
