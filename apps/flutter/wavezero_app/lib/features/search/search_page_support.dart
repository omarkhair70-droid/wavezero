import 'package:flutter/material.dart';

import '../../app/curated_demo_picks.dart';
import '../../design/wavezero_design_system.dart';
import 'search_results.dart';

IconData wzSearchResultIcon(WzSearchResult result) => switch (result.type) {
      WzSearchResultType.track => Icons.music_note_rounded,
      WzSearchResultType.deviceTrack => Icons.phone_android_rounded,
      WzSearchResultType.downloadedTrack => Icons.offline_pin_rounded,
      WzSearchResultType.cloudTrack => Icons.cloud_done_outlined,
      WzSearchResultType.collection => Icons.queue_music_rounded,
      WzSearchResultType.historyEntry => Icons.history_rounded,
      WzSearchResultType.artistLike => Icons.person_outline_rounded,
      WzSearchResultType.unknown => Icons.search_rounded,
    };

class WzCuratedTryPicksPanel extends StatelessWidget {
  const WzCuratedTryPicksPanel({super.key, required this.picks, required this.onPlay});

  final List<ResolvedCuratedDemoPick> picks;
  final ValueChanged<ResolvedCuratedDemoPick> onPlay;

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) return const SizedBox.shrink();
    return WzGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WzSectionHeader(
            title: 'Try these',
            subtitle: 'A few nearby starting points.',
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: WzSpacing.xs),
          ...picks.take(5).map(
                (resolved) => Padding(
                  padding: const EdgeInsets.only(bottom: WzSpacing.xs),
                  child: WzPressableSurface(
                    onTap: () => onPlay(resolved),
                    radius: WzRadius.md,
                    decoration: WzSurface.sculpted(),
                    padding: const EdgeInsets.symmetric(horizontal: WzSpacing.sm, vertical: 10),
                    child: Row(
                      children: [
                        const WzSculptedIcon(icon: Icons.music_note_rounded, size: 38, iconSize: 16, color: WzColors.accent),
                        const SizedBox(width: WzSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(resolved.track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('${resolved.track.subtitle} • ${resolved.pick.mood}', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                            ],
                          ),
                        ),
                        const SizedBox(width: WzSpacing.xs),
                        WzSculptedIconButton(
                          tooltip: 'Play curated pick',
                          icon: Icons.play_arrow_rounded,
                          size: 36,
                          iconSize: 18,
                          onPressed: () => onPlay(resolved),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class WzSearchDiscoveryPanel extends StatelessWidget {
  const WzSearchDiscoveryPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WzSectionHeader(title: title, subtitle: subtitle, icon: icon),
          WzGlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      );
}

class WzSearchDiscoveryButton extends StatelessWidget {
  const WzSearchDiscoveryButton({
    super.key,
    required this.label,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: WzPressableSurface(
          onTap: onTap,
          radius: WzRadius.md,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.46), borderRadius: BorderRadius.circular(WzRadius.md)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              WzSculptedIcon(icon: icon, size: 38, iconSize: 16, color: WzColors.accent),
              const SizedBox(width: WzSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 17, color: WzColors.textSubtle),
            ],
          ),
        ),
      );
}
