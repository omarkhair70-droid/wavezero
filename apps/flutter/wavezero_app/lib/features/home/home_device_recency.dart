import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../device_music/device_music_track.dart';

class WzHomeFreshDeviceSection extends StatelessWidget {
  const WzHomeFreshDeviceSection({
    super.key,
    required this.tracks,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onOpenDeviceMusic,
  });

  final List<DeviceMusicTrack> tracks;
  final ValueChanged<DeviceMusicTrack> onPlay;
  final ValueChanged<DeviceMusicTrack> onAddToQueue;
  final VoidCallback onOpenDeviceMusic;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Fresh on your device', style: WzText.title),
            ),
            TextButton.icon(
              onPressed: onOpenDeviceMusic,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'The newest music Android can see on this phone.',
          style: WzText.caption,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 198,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 11),
            itemBuilder: (context, index) {
              final track = tracks[index];
              return _FreshDeviceCard(
                track: track,
                onPlay: () => onPlay(track),
                onAddToQueue: () => onAddToQueue(track),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FreshDeviceCard extends StatelessWidget {
  const _FreshDeviceCard({
    required this.track,
    required this.onPlay,
    required this.onAddToQueue,
  });

  final DeviceMusicTrack track;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 142,
        child: WzPressableSurface(
          onTap: onPlay,
          radius: 28,
          decoration: WzSurface.sculpted(),
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: WzArtwork(
                  artworkUrl: track.artworkUri,
                  size: 124,
                  trackId: track.trackId,
                  title: track.title,
                  artist: track.artistName,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WzText.sectionTitle.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      track.artistName?.trim().isNotEmpty == true
                          ? track.artistName!
                          : 'Device music',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WzText.caption,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Add to Queue',
                    onPressed: onAddToQueue,
                    icon: const Icon(Icons.queue_music_rounded, size: 17),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
