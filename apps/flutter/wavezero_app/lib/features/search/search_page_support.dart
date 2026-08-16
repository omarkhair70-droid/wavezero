import 'package:flutter/material.dart';

import '../../app/curated_demo_picks.dart';
import '../../design/wavezero_design_system.dart';
import 'search_results.dart';

IconData wzSearchResultIcon(WzSearchResult result) => switch (result.type) {
      WzSearchResultType.track => Icons.music_note,
      WzSearchResultType.deviceTrack => Icons.phone_android,
      WzSearchResultType.downloadedTrack => Icons.offline_pin,
      WzSearchResultType.cloudTrack => Icons.cloud_done_outlined,
      WzSearchResultType.collection => Icons.queue_music,
      WzSearchResultType.historyEntry => Icons.history,
      WzSearchResultType.artistLike => Icons.person,
      WzSearchResultType.unknown => Icons.search,
    };

class WzCuratedTryPicksPanel extends StatelessWidget {
  const WzCuratedTryPicksPanel({
    super.key,
    required this.picks,
    required this.onPlay,
  });

  final List<ResolvedCuratedDemoPick> picks;
  final ValueChanged<ResolvedCuratedDemoPick> onPlay;

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) return const SizedBox.shrink();
    return WzPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WzSectionHeader(
            title: 'Try these picks',
            subtitle: 'A few WaveZero-selected demo tracks to start exploring.',
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: WzSpacing.sm),
          ...picks.take(5).map(
                (resolved) => Padding(
                  padding: const EdgeInsets.only(bottom: WzSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note, size: 18),
                      const SizedBox(width: WzSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resolved.track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WzText.body,
                            ),
                            Text(
                              '${resolved.track.subtitle} • ${resolved.pick.mood}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WzText.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Play curated pick',
                        onPressed: () => onPlay(resolved),
                        icon: const Icon(Icons.play_arrow),
                      ),
                    ],
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
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
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
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: onTap,
      );
}