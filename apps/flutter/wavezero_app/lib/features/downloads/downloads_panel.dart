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
  Widget build(BuildContext context) => WzPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                const ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Downloads', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text(
                        'Cached tracks available for offline playback.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text('${downloads.length} • ${formatWzCacheBytes(cacheBytes)}', style: WzText.caption),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onManageStorage,
                      icon: const Icon(Icons.storage),
                      label: const Text('Manage Storage'),
                    ),
                    IconButton.outlined(
                      tooltip: 'Clear all downloads',
                      onPressed: downloads.isEmpty || controlsDisabled ? null : onClearAll,
                      icon: const Icon(Icons.clear_all),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (downloads.isEmpty)
              WzEmptyCatalogMessage(
                message: 'No downloads yet. Download tracks from Library to listen offline.',
              )
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
  const _DownloadRow({
    required this.track,
    required this.disabled,
    required this.onPlay,
    required this.onDelete,
  });

  final CachedTrackMetadata track;
  final bool disabled;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF20273A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                WzArtwork(
                  artworkUrl: track.artworkUrl,
                  size: 48,
                  trackId: track.trackId,
                  title: track.title,
                  artist: track.artistName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
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
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                IconButton(
                  tooltip: 'Play downloaded track',
                  onPressed: disabled ? null : onPlay,
                  icon: const Icon(Icons.play_arrow, color: Color(0xFF8D7CFF)),
                ),
                IconButton(
                  tooltip: 'Remove from device',
                  onPressed: disabled ? null : onDelete,
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFFF8F8F)),
                ),
              ],
            ),
          ],
        ),
      );
}