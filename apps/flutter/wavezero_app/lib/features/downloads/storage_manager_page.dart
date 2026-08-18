import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../../shared/widgets/wavezero_empty_message.dart';
import 'cache_service.dart';
import 'downloads_presentation.dart';

class WzStorageManagerPage extends StatelessWidget {
  const WzStorageManagerPage({
    required this.downloads,
    required this.onBack,
    required this.cacheBytes,
    required this.trackBytes,
    required this.manualDownloadedCount,
    required this.smartDownloadedCount,
    required this.offlineReadyCount,
    required this.smartDownloadsEnabled,
    required this.controlsDisabled,
    required this.onSmartDownloadsChanged,
    required this.onPlay,
    required this.onDelete,
    required this.onClearAll,
  });

  final List<CachedTrackMetadata> downloads;
  final VoidCallback onBack;
  final int cacheBytes;
  final Map<String, int> trackBytes;
  final int manualDownloadedCount;
  final int smartDownloadedCount;
  final int offlineReadyCount;
  final bool smartDownloadsEnabled;
  final bool controlsDisabled;
  final ValueChanged<bool> onSmartDownloadsChanged;
  final ValueChanged<CachedTrackMetadata> onPlay;
  final ValueChanged<CachedTrackMetadata> onDelete;
  final Future<void> Function() onClearAll;

  @override
  Widget build(BuildContext context) => WzPageScaffold(
        children: [
          Row(
            children: [
              WzSculptedIconButton(tooltip: 'Back to Settings', onPressed: onBack, icon: Icons.arrow_back_rounded, size: 44, iconSize: 19),
              const SizedBox(width: 13),
              Expanded(child: Text('Storage Manager', style: WzText.pageTitle.copyWith(fontSize: 28))),
            ],
          ),
          const SizedBox(height: 22),
          _StorageSummary(cacheBytes: cacheBytes, count: downloads.length),
          const SizedBox(height: 18),
          _SmartDownloadsRow(
            enabled: smartDownloadsEnabled,
            disabled: controlsDisabled,
            onChanged: onSmartDownloadsChanged,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Text('Downloaded music', style: WzText.title)),
              if (downloads.isNotEmpty)
                TextButton(
                  onPressed: controlsDisabled ? null : () => unawaited(onClearAll()),
                  child: const Text('Clear all'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (downloads.isEmpty)
            const WzEmptyCatalogMessage(message: 'No downloads yet. Download tracks from Library to listen offline.')
          else
            ...downloads.map(
              (track) => _StorageTrackRow(
                track: track,
                sizeBytes: trackBytes[track.trackId],
                disabled: controlsDisabled,
                onPlay: () => onPlay(track),
                onDelete: () => onDelete(track),
              ),
            ),
        ],
      );
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({required this.cacheBytes, required this.count});

  final int cacheBytes;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFCFFFFFF), Color(0xF0F6FAFC)],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(36),
            topRight: Radius.circular(48),
            bottomLeft: Radius.circular(44),
            bottomRight: Radius.circular(30),
          ),
          border: Border.all(color: const Color(0xF2FFFFFF)),
          boxShadow: WzSurface.softShadows,
        ),
        child: Row(
          children: [
            const WzSculptedIcon(icon: Icons.storage_rounded, size: 52, iconSize: 22, color: WzColors.accent),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatWzCacheBytes(cacheBytes), style: WzText.title.copyWith(fontSize: 24)),
                  const SizedBox(height: 3),
                  Text(count == 0 ? 'No downloads yet' : '$count ${count == 1 ? 'track' : 'tracks'} available offline', style: WzText.caption),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SmartDownloadsRow extends StatelessWidget {
  const _SmartDownloadsRow({required this.enabled, required this.disabled, required this.onChanged});

  final bool enabled;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: WzSurface.sculpted(selected: enabled),
        padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
        child: Row(
          children: [
            WzSculptedIcon(icon: Icons.auto_awesome_rounded, size: 44, iconSize: 19, color: enabled ? WzColors.accent : WzColors.textPrimary),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Smart Downloads', style: WzText.sectionTitle),
                  SizedBox(height: 3),
                  Text('Keep nearby music ready for offline listening.', style: WzText.caption),
                ],
              ),
            ),
            Switch.adaptive(value: enabled, onChanged: disabled ? null : onChanged),
          ],
        ),
      );
}

class _StorageTrackRow extends StatelessWidget {
  const _StorageTrackRow({required this.track, required this.sizeBytes, required this.disabled, required this.onPlay, required this.onDelete});

  final CachedTrackMetadata track;
  final int? sizeBytes;
  final bool disabled;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onPlay,
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
                      artist: track.artistName,
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
                        if (sizeBytes != null) ...[
                          const SizedBox(height: 3),
                          Text(formatWzCacheBytes(sizeBytes!), style: WzText.caption.copyWith(fontSize: 10.5, color: WzColors.accent)),
                        ],
                      ],
                    ),
                  ),
                  WzSculptedIconButton(tooltip: 'Play', icon: Icons.play_arrow_rounded, size: 38, iconSize: 19, onPressed: disabled ? null : onPlay),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_horiz_rounded, color: WzColors.textMuted),
                    onSelected: (value) {
                      if (value == 'remove') onDelete();
                    },
                    itemBuilder: (_) => [PopupMenuItem(enabled: !disabled, value: 'remove', child: const Text('Remove download'))],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
