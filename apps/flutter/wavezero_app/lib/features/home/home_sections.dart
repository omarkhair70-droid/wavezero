export 'home_curated_history.dart';

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
  Widget build(BuildContext context) => WzGlassCard(
        padding: const EdgeInsets.fromLTRB(WzSpacing.lg, WzSpacing.lg, WzSpacing.lg, WzSpacing.xl),
        gradient: themeConfig.shellGradient,
        child: Stack(
          children: [
            const Positioned(right: -18, top: -18, child: _HomePulseSculpture()),
            Padding(
              padding: const EdgeInsets.only(right: 112),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WaveZero', style: WzText.eyebrow),
                  const SizedBox(height: WzSpacing.sm),
                  Text(
                    'The voice is close.\nThe music is with you.',
                    style: WzText.display.copyWith(fontSize: 31, height: 1.08),
                  ),
                  const SizedBox(height: WzSpacing.sm),
                  Text(
                    'A light, personal place for the music already around you.',
                    style: WzText.body.copyWith(fontSize: 14),
                  ),
                ],
              ),
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
  Widget build(BuildContext context) => WzPressableSurface(
        onTap: onOpenNow,
        radius: WzRadius.sculpted,
        decoration: WzSurface.sculpted(selected: isPlaying),
        padding: const EdgeInsets.all(WzSpacing.md),
        child: Row(
          children: [
            WzSculptedIcon(
              icon: isPlaying ? Icons.graphic_eq_rounded : Icons.album_rounded,
              size: 54,
              iconSize: 23,
              color: isPlaying ? WzColors.accent : WzColors.textPrimary,
            ),
            const SizedBox(width: WzSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isPlaying ? 'With you now' : 'Ready when you are', style: WzText.eyebrow),
                  const SizedBox(height: 3),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                  const SizedBox(height: 2),
                  Text('$subtitle • $sourceLabel', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                ],
              ),
            ),
            const SizedBox(width: WzSpacing.sm),
            const Icon(Icons.arrow_forward_rounded, color: WzColors.textMuted, size: 20),
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
    return WzGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WzSectionHeader(
            title: 'Current listening',
            subtitle: 'Your music stays close, even when you move around the app.',
            icon: Icons.waves_rounded,
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final art = Container(
                padding: const EdgeInsets.all(5),
                decoration: WzSurface.sculpted(selected: metrics.isPlaying),
                child: WzArtwork(
                  artworkUrl: manifest?.artworkUrl,
                  size: compact ? 88 : 112,
                  trackId: manifest?.trackId,
                  title: manifest?.title,
                  artist: manifest?.artistName,
                ),
              );
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.title),
                  const SizedBox(height: WzSpacing.xs),
                  Text(
                    manifest?.subtitle ?? 'Choose something from Library and let it fill the space.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.body,
                  ),
                ],
              );
              if (compact) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [art, const SizedBox(height: WzSpacing.md), identity]);
              }
              return Row(children: [art, const SizedBox(width: WzSpacing.md), Expanded(child: identity)]);
            },
          ),
          const SizedBox(height: WzSpacing.md),
          Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              WzStatusPill(label: status, active: metrics.isPlaying, warning: status == 'Error', icon: metrics.isPlaying ? Icons.graphic_eq_rounded : Icons.pause_rounded),
              WzStatusPill(label: wzProductQualityLabel(qualityLabel), active: qualityLabel != 'unknown', icon: Icons.high_quality_rounded),
              if (devicePlayback) const WzStatusPill(label: 'On this device', active: true, icon: Icons.phone_android_rounded),
              if (playingFromCache) const WzStatusPill(label: 'Downloaded', active: true, icon: Icons.offline_pin_rounded),
              if (offlineReady) const WzStatusPill(label: 'Offline', active: true, icon: Icons.download_done_rounded),
              if (deviceTrackCount > 0) WzStatusPill(label: '$deviceTrackCount local tracks', active: true, icon: Icons.perm_media_rounded),
              if (devicePermissionStatus.contains('denied')) const WzStatusPill(label: 'Device access optional', warning: true, icon: Icons.privacy_tip_outlined),
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

    return WzGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WzSectionHeader(
            title: 'Yours',
            subtitle: 'The things you kept, liked, and made available offline.',
            icon: Icons.favorite_border_rounded,
          ),
          Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            children: [
              WzMiniMetric(label: 'Liked', value: '${liked.trackCount}', active: liked.trackCount > 0, icon: Icons.favorite_rounded),
              WzMiniMetric(label: 'Collections', value: '$userCollectionCount', active: userCollectionCount > 0, icon: Icons.playlist_play_rounded),
              WzMiniMetric(label: 'Offline', value: offlineTrackCount > 0 ? '$offlineTrackCount tracks' : 'None yet', active: offlineTrackCount > 0, icon: Icons.download_done_rounded),
              WzMiniMetric(label: 'Storage', value: formatWzCacheBytes(cacheBytes), active: cacheBytes > 0, icon: Icons.sd_storage_rounded),
            ],
          ),
          const SizedBox(height: WzSpacing.md),
          Row(
            children: [
              Expanded(child: _HomeLinkAction(label: 'Collections', icon: Icons.playlist_play_rounded, onTap: onOpenCollections)),
              const SizedBox(width: WzSpacing.sm),
              Expanded(child: _HomeLinkAction(label: 'Downloads', icon: Icons.download_done_rounded, onTap: onOpenDownloads)),
            ],
          ),
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
  Widget build(BuildContext context) => WzGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WzSectionHeader(
              title: 'Under the surface',
              subtitle: 'WaveZero quietly keeps playback ready without making the experience feel technical.',
              icon: Icons.auto_awesome_rounded,
            ),
            Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzMiniMetric(label: 'Smart downloads', value: smartDownloadsEnabled ? '$smartDownloadsCompleted ready' : 'Off', active: smartDownloadsEnabled, icon: Icons.download_for_offline_rounded),
                WzMiniMetric(label: 'Next track', value: prefetchEnabled ? (prefetchedTrackTitle ?? 'Ready') : 'Off', active: prefetchEnabled, icon: Icons.bolt_rounded),
                WzMiniMetric(label: 'Offline', value: offlineReady ? '$offlineTrackCount ready' : 'Empty', active: offlineReady, icon: Icons.offline_pin_rounded),
                WzMiniMetric(label: 'Quality', value: wzProductQualityLabel(qualityLabel), active: qualityLabel != 'unknown', icon: Icons.high_quality_rounded),
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
  Widget build(BuildContext context) {
    final actions = <({String label, IconData icon, WzAppTab tab})>[
      (label: 'Search', icon: Icons.search_rounded, tab: WzAppTab.search),
      (label: 'Library', icon: Icons.library_music_rounded, tab: WzAppTab.library),
      (label: 'Collections', icon: Icons.playlist_play_rounded, tab: WzAppTab.collections),
      (label: 'Now', icon: Icons.play_circle_outline_rounded, tab: WzAppTab.now),
      (label: 'Queue', icon: Icons.queue_music_rounded, tab: WzAppTab.queue),
      (label: 'Offline', icon: Icons.download_done_rounded, tab: WzAppTab.downloads),
      (label: 'Settings', icon: Icons.tune_rounded, tab: WzAppTab.settings),
      if (showDeveloperTools) (label: 'Engine', icon: Icons.engineering_rounded, tab: WzAppTab.engine),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WzSectionHeader(title: 'Move through WaveZero', subtitle: 'Everything is one soft step away.', icon: Icons.blur_on_rounded),
        Wrap(
          spacing: WzSpacing.sm,
          runSpacing: WzSpacing.sm,
          children: actions
              .map(
                (action) => SizedBox(
                  width: 132,
                  child: _HomeLinkAction(label: action.label, icon: action.icon, onTap: () => onNavigate(action.tab)),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _HomePulseSculpture extends StatelessWidget {
  const _HomePulseSculpture();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 128,
        height: 128,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: WzColors.accentGradient,
                border: Border.all(color: Colors.white),
                boxShadow: WzSurface.softShadows,
              ),
            ),
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.72)),
            ),
            const Icon(Icons.graphic_eq_rounded, color: WzColors.accent, size: 30),
          ],
        ),
      );
}

class _HomeLinkAction extends StatelessWidget {
  const _HomeLinkAction({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WzPressableSurface(
        onTap: onTap,
        radius: WzRadius.lg,
        decoration: WzSurface.sculpted(),
        padding: const EdgeInsets.symmetric(horizontal: WzSpacing.sm, vertical: WzSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: WzColors.textPrimary),
            const SizedBox(width: 8),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(color: WzColors.textPrimary, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
