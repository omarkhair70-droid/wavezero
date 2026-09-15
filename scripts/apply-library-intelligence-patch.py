from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/features/library/library_catalog_panel.dart')
text = path.read_text(encoding='utf-8')

old_import = "import 'library_catalog_items.dart';\nimport 'library_controls.dart';"
new_import = "import 'library_browse.dart';\nimport 'library_catalog_items.dart';\nimport 'library_controls.dart';"
if text.count(old_import) != 1:
    raise SystemExit(f'expected one import anchor, found {text.count(old_import)}')
text = text.replace(old_import, new_import, 1)

old_query = """    final hasQuery = searchController.text.trim().isNotEmpty;
    final countLabel = filteredTrackCount == 1 ? '1 track' : '$filteredTrackCount tracks';
"""
new_query = """    final hasQuery = searchController.text.trim().isNotEmpty;
    final hasBrowseMetadata = !hasQuery && tracks.any(
      (track) =>
          (track.artistName?.trim().isNotEmpty ?? false) ||
          (track.albumName?.trim().isNotEmpty ?? false),
    );
    final countLabel = filteredTrackCount == 1 ? '1 track' : '$filteredTrackCount tracks';
"""
if text.count(old_query) != 1:
    raise SystemExit(f'expected one query anchor, found {text.count(old_query)}')
text = text.replace(old_query, new_query, 1)

old_anchor = """            showCloudSource: showCloudSource,
          ),
          const SizedBox(height: 24),
          WzGlassCard(
"""
new_anchor = """            showCloudSource: showCloudSource,
          ),
          if (hasBrowseMetadata) ...[
            const SizedBox(height: 24),
            WzLibraryBrowseSection(
              tracks: tracks,
              selectedTrackId: selectedTrackId,
              addToQueueDisabled: addToQueueDisabled,
              onSelectTrack: onSelectTrack,
              onAddToQueue: onAddToQueue,
              onToggleLike: onToggleLike,
              onAddToCollection: onAddToCollection,
              isLiked: isLiked,
              onCache: onCache,
              onDeleteCachedTrack: onDeleteCachedTrack,
            ),
          ],
          const SizedBox(height: 24),
          WzGlassCard(
"""
if text.count(old_anchor) != 1:
    raise SystemExit(f'expected one overview anchor, found {text.count(old_anchor)}')
text = text.replace(old_anchor, new_anchor, 1)

path.write_text(text, encoding='utf-8')
