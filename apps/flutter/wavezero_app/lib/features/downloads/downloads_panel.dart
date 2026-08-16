import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../../shared/widgets/wavezero_empty_message.dart';
import 'cache_service.dart';
import 'downloads_presentation.dart';

class WzDownloadsPanel extends StatelessWidget {
  const WzDownloadsPanel({
    super.key,
    required this.downloads,
    required this.cacheBytes,
    required this.controlsDisabled,
    required this.onPlay,
    required this.onDelete,
    required this.onClearAll,
    required this.onManageStorage,
  });

  final List<CachedTrackMetadata> downloads;
  final int cacheBytes;
  final bool controlsDisabled;
  final ValueChanged<CachedTrackMetadata> onPlay;
  final ValueChanged<CachedTrackMetadata> onDelete;
  final VoidCallback onClearAll;
  final VoidCallback onManageStorage;

  @override
  Widget build(BuildContext context) => WzGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Downloads', style: WzText.title),
                      SizedBox(height: 4),
                      Text('The music that is already here with you.', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.body),
                    ],
                  ),
                ),
                WzStatusPill(label: '${downloads.length} • ${formatWzCacheBytes(cacheBytes)}', active: downloads.isNotEmpty, icon: Icons.download_done_rounded),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(onPressed: onManageStorage, icon: const Icon(Icons.storage_rounded), label: const Text('Manage Storage')),
                    const SizedBox(width: WzSpacing.xs),
                    WzSculptedIconButton(
                      tooltip: 'Clear all downloads',
                      icon: Icons.clear_all,
                      size: 42,
                      iconSize: 19,
                      onPressed: downloads.isEmpty || controlsDisabled ? null : onClearAll,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: WzSpacing.md),
            if (downloads.isEmpty)
              const WzEmptyCatalogMessage(message: 'No downloads yet. Download tracks from Library to listen offline.')
            else
              ...downloads.map(
                (track) => _DownloadRow(
                  track: track,
                  disabled: controlsDisabled,
                  onPlay: () => onPlay(track),
                  onDelete: () => onDelete(track),
                ),
              ),
          ],
        ),
      );
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.track, required this.disabled, required this.onPlay, required this.onDelete});

  final CachedTrackMetadata track;
  final bool disabled;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(11),
        decoration: WzSurface.sculpted(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(WzRadius.md), boxShadow: WzSurface.softShadows),
              child: WzArtwork(
                artworkUrl: track.artworkUrl,
                size: 52,
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
                  const SizedBox(height: 4),
                  Text(
                    '${track.subtitle} • ${wzProductQualityLabel(track.qualityLabel)}${track.codec == null ? '' : ' • ${track.codec}'}${track.bitrateKbps == null ? '' : ' • ${track.bitrateKbps}kbps'} • ${wzDownloadSourceLabel(track.downloadSource)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: WzSpacing.sm),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WzSculptedIconButton(
                  tooltip: 'Play downloaded track',
                  icon: Icons.play_arrow_rounded,
                  size: 40,
                  iconSize: 19,
                  onPressed: disabled ? null : onPlay,
                ),
                const SizedBox(height: 6),
                WzSculptedIconButton(
                  tooltip: 'Remove from device',
                  icon: Icons.delete_outline_rounded,
                  size: 40,
                  iconSize: 18,
                  onPressed: disabled ? null : onDelete,
                ),
              ],
            ),
          ],
        ),
      );
}
