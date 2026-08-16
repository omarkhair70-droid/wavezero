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
                (pick) => Padding(
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
                              pick.track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WzText.body,
                            ),
                            Text(
                              '${pick.track.subtitle} • ${pick.mood}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: WzText.caption,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Play curated pick',
                        onPressed: () => onPlay(pick),
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
