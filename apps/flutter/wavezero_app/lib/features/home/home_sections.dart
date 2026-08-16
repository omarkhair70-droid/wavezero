import 'package:flutter/material.dart';

import '../../app/navigation/wavezero_navigation.dart';
import '../../app/theme/wavezero_theme.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../features/collections/collections_service.dart';
import '../../features/downloads/downloads_presentation.dart';
import '../../playback/playback_metrics.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';

class WzHomeHero extends StatelessWidget {
  const WzHomeHero({super.key, required this.themeConfig});

  final WzThemeConfig themeConfig;

  @override
  Widget build(BuildContext context) => WzPanel(
        padding: const EdgeInsets.all(WzSpacing.md),
        gradient: themeConfig.shellGradient,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WaveZero', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: WzText.title),
            const SizedBox(height: WzSpacing.xs),
            const Text(
              'A smart music experience engine.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: WzColors.textMuted, height: 1.35),
            ),
            const SizedBox(height: WzSpacing.md),
            const Wrap(
              spacing: WzSpacing.xs,
              runSpacing: WzSpacing.xs,
              children: [
                WzStatusPill(label: 'Native playback', active: true, icon: Icons.phone_android),
                WzStatusPill(label: 'Music-first playback • offline-aware library', active: true, icon: Icons.auto_awesome),
              ],
            ),
          ],
        ),
      );
}

class WzHomeContinueListeningSummary extends StatelessWidget {
  const WzHomeContinueListeningSummary({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sourceLabel,
    required this.isPlaying,
    required this.onOpenNow,
  });

  final String title;
  final String subtitle;
  final String sourceLabel;
  final bool isPlaying;
  final VoidCallback onOpenNow;

  @override
  Widget build(BuildContext context) => WzPanel(
        padding: const EdgeInsets.all(WzSpacing.md),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: WzColors.accentGradient,
                borderRadius: BorderRadius.circular(WzRadius.lg),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 10))],
              ),
              child: Icon(isPlaying ? Icons.equalizer : Icons.album_rounded, color: Colors.white),
            ),
            const SizedBox(width: WzSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPlaying ? 'Continue listening' : 'Ready when you are',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.eyebrow,
                  ),
                  const SizedBox(height: WzSpacing.xxs),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                  Text('$subtitle • $sourceLabel', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                ],
              ),
            ),
            const SizedBox(width: WzSpacing.sm),
            IconButton.filledTonal(tooltip: 'Open Now', onPressed: onOpenNow, icon: const Icon(Icons.open_in_full)),
          ],
        ),
      );
}

class WzHomeCurrentListeningCard extends StatelessWidget {
  const WzHomeCurrentListeningCard({
    super.key,
    required this.metrics,
    required this.manifest,
    required this.qualityLabel,
    required this.playingFromCache,
    required this.devicePlayback,
    required this.offlineReady,
    required this.deviceTrackCount,
    required this.devicePermissionStatus,
    required this.status,
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final String qualityLabel;
  final bool playingFromCache;
  final bool devicePlayback;
  final bool offlineReady;
  final int deviceTrackCount;
  final String devicePermissionStatus;
  final String status;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? 'No track loaded';
    return WzPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WzSectionHeader(
            title: 'Current listening',
            subtitle: 'Pick up from the mini player or choose something from Library.',
            icon: Icons.album,
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;
              final art = WzArtwork(
                artworkUrl: manifest?.artworkUrl,
                size: compact ? 84 : 108,
                trackId: manifest?.trackId,
                title: manifest?.title,
                artist: manifest?.artistName,
              );
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.title),
                  const SizedBox(height: WzSpacing.xs),
                  Text(
                    manifest?.subtitle ?? 'Choose a track from Library to start listening.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.body,
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [art, const SizedBox(height: WzSpacing.sm), identity],
                );
              }
              return Row(children: [art, const SizedBox(width: WzSpacing.md), Expanded(child: identity)]);
            },
          ),
          const SizedBox(height: WzSpacing.md),
          Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              WzStatusPill(
                label: status,
                active: metrics.isPlaying,
                warning: status == 'Error',
                icon: metrics.isPlaying ? Icons.play_arrow : Icons.pause,
              ),
              WzStatusPill(
                label: 'Quality: ${wzProductQualityLabel(qualityLabel)}',
                active: qualityLabel != 'unknown',
                icon: Icons.high_quality,
              ),
              if (devicePlayback) const WzStatusPill(label: 'Device music', active: true, icon: Icons.phone_android),
              if (playingFromCache) const WzStatusPill(label: 'Downloaded', active: true, icon: Icons.offline_pin),
              if (offlineReady) const WzStatusPill(label: 'Offline Ready', active: true, icon: Icons.download_done),
              WzStatusPill(label: 'Device music: $deviceTrackCount', active: deviceTrackCount > 0, icon: Icons.perm_media),
              WzStatusPill(
                label: devicePermissionStatus == 'granted' ? 'Device access ready' : 'Device access optional',
                active: devicePermissionStatus == 'granted',
                warning: devicePermissionStatus.contains('denied'),
                icon: Icons.privacy_tip,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WzHomeCollectionsOfflineSection extends StatelessWidget {
  const WzHomeCollectionsOfflineSection({
    super.key,
    required this.collections,
    required this.offlineTrackCount,
    required this.cacheBytes,
    required this.onOpenCollections,
    required this.onOpenDownloads,
  });

  final List<WzCollection> collections;
  final int offlineTrackCount;
  final int cacheBytes;
  final VoidCallback onOpenCollections;
  final VoidCallback onOpenDownloads;

  @override
  Widget build(BuildContext context) {
    final userCollectionCount = collections.where((collection) => collection.type == WzCollectionType.user).length;
    final liked = collections.firstWhere(
      (collection) => collection.type == WzCollectionType.liked,
      orElse: () => WzCollection.liked(),
    );
    return WzPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WzSectionHeader(
            title: 'Collections & Offline Ready',
            subtitle: 'Saved music and downloads without duplicating the player.',
            icon: Icons.collections_bookmark,
          ),
          Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            children: [
              WzMiniMetric(label: 'Liked Tracks', value: '${liked.trackCount}', active: liked.trackCount > 0, icon: Icons.favorite),
              WzMiniMetric(label: 'Collections', value: '$userCollectionCount', active: userCollectionCount > 0, icon: Icons.playlist_play),
              WzMiniMetric(
                label: 'Offline Ready',
                value: offlineTrackCount > 0 ? '$offlineTrackCount tracks' : 'No downloads yet',
                active: offlineTrackCount > 0,
                icon: Icons.download_done,
              ),
              WzMiniMetric(label: 'Storage', value: formatWzCacheBytes(cacheBytes), active: cacheBytes > 0, icon: Icons.sd_storage),
            ],
          ),
          const SizedBox(height: WzSpacing.md),
          Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            children: [
              WzPrimaryAction(label: 'Open Collections', icon: Icons.playlist_play, onPressed: onOpenCollections),
              OutlinedButton.icon(onPressed: onOpenDownloads, icon: const Icon(Icons.download_done), label: const Text('Open Downloads')),
            ],
          ),
          if (userCollectionCount == 0 && liked.trackCount == 0) ...[
            const SizedBox(height: WzSpacing.sm),
            const Text('No collections yet. Save tracks from Library, Search, or Now Playing.', style: WzText.caption),
          ],
          if (offlineTrackCount == 0) ...[
            const SizedBox(height: WzSpacing.xs),
            const Text('No downloads yet. Download tracks from Library to listen offline.', style: WzText.caption),
          ],
        ],
      ),
    );
  }
}

class WzHomeSmartListeningCards extends StatelessWidget {
  const WzHomeSmartListeningCards({
    super.key,
    required this.smartDownloadsEnabled,
    required this.smartDownloadsCompleted,
    required this.prefetchEnabled,
    required this.prefetchedTrackTitle,
    required this.offlineReady,
    required this.offlineTrackCount,
    required this.qualityLabel,
  });

  final bool smartDownloadsEnabled;
  final int smartDownloadsCompleted;
  final bool prefetchEnabled;
  final String? prefetchedTrackTitle;
  final bool offlineReady;
  final int offlineTrackCount;
  final String qualityLabel;

  @override
  Widget build(BuildContext context) => WzPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WzSectionHeader(
              title: 'Smart listening',
              subtitle: 'Offline comfort, playback readiness, and quality at a glance.',
              icon: Icons.auto_awesome,
            ),
            Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzMiniMetric(
                  label: 'Smart Downloads',
                  value: smartDownloadsEnabled ? '$smartDownloadsCompleted cached' : 'Off',
                  active: smartDownloadsEnabled,
                  icon: Icons.download_for_offline,
                ),
                WzMiniMetric(
                  label: 'Next track ready',
                  value: prefetchEnabled ? (prefetchedTrackTitle ?? 'Ready') : 'Off',
                  active: prefetchEnabled,
                  icon: Icons.offline_bolt,
                ),
                WzMiniMetric(
                  label: 'Offline Ready',
                  value: offlineReady ? '$offlineTrackCount tracks' : 'No downloads yet',
                  active: offlineReady,
                  icon: Icons.offline_pin,
                ),
                WzMiniMetric(
                  label: 'Audio Quality',
                  value: wzProductQualityLabel(qualityLabel),
                  active: qualityLabel != 'unknown',
                  icon: Icons.high_quality,
                ),
              ],
            ),
          ],
        ),
      );
}

class WzHomeQuickActions extends StatelessWidget {
  const WzHomeQuickActions({super.key, required this.onNavigate, required this.showDeveloperTools});

  final ValueChanged<WzAppTab> onNavigate;
  final bool showDeveloperTools;

  @override
  Widget build(BuildContext context) => WzPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WzSectionHeader(
              title: 'Start here',
              subtitle: 'Find music, organize collections, or manage offline listening.',
              icon: Icons.bolt,
            ),
            Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzPrimaryAction(label: 'Search music', icon: Icons.search, onPressed: () => onNavigate(WzAppTab.search)),
                WzPrimaryAction(label: 'Library', icon: Icons.library_music, onPressed: () => onNavigate(WzAppTab.library)),
                WzPrimaryAction(label: 'Collections', icon: Icons.playlist_play, onPressed: () => onNavigate(WzAppTab.collections)),
                WzPrimaryAction(label: 'Now Playing', icon: Icons.play_circle_fill, onPressed: () => onNavigate(WzAppTab.now)),
                WzPrimaryAction(label: 'Queue', icon: Icons.queue_music, onPressed: () => onNavigate(WzAppTab.queue)),
                WzPrimaryAction(label: 'Downloads', icon: Icons.download_done, onPressed: () => onNavigate(WzAppTab.downloads)),
                WzPrimaryAction(label: 'Settings', icon: Icons.settings, onPressed: () => onNavigate(WzAppTab.settings)),
                if (showDeveloperTools) WzPrimaryAction(label: 'Engine', icon: Icons.engineering, onPressed: () => onNavigate(WzAppTab.engine)),
              ],
            ),
          ],
        ),
      );
}
