import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/navigation/wavezero_navigation.dart';
import '../../catalog/audio_quality.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../downloads/downloads_presentation.dart';
import 'legal_licenses_page.dart';

class WzConsumerSettingsPage extends StatelessWidget {
  const WzConsumerSettingsPage({
    required this.preferredAudioQuality,
    required this.onQualityChanged,
    required this.smartDownloadsEnabled,
    required this.onSmartDownloadsChanged,
    required this.cachedTrackCount,
    required this.cacheBytes,
    required this.controlsDisabled,
    required this.onClearCache,
    required this.onManageStorage,
    required this.onClearRecentSearches,
    required this.onClearListeningHistory,
    required this.legalTracks,
  });

  final AudioQualityTier preferredAudioQuality;
  final ValueChanged<AudioQualityTier> onQualityChanged;
  final bool smartDownloadsEnabled;
  final ValueChanged<bool> onSmartDownloadsChanged;
  final int cachedTrackCount;
  final int cacheBytes;
  final bool controlsDisabled;
  final Future<void> Function() onClearCache;
  final VoidCallback onManageStorage;
  final VoidCallback? onClearRecentSearches;
  final VoidCallback? onClearListeningHistory;
  final List<CatalogTrackSummary> legalTracks;

  @override
  Widget build(BuildContext context) => WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.tune_rounded,
            title: 'Settings',
            subtitle: 'A few choices that belong to you.',
          ),
          const SizedBox(height: WzSpacing.lg),
          const WzSectionHeader(
            title: 'Audio',
            subtitle: 'Choose the quality WaveZero should prefer when more than one version is available.',
            icon: Icons.headphones_rounded,
          ),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preferred quality', style: WzText.sectionTitle),
                const SizedBox(height: WzSpacing.sm),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: [
                    AudioQualityTier.standard,
                    AudioQualityTier.high,
                    AudioQualityTier.original,
                  ]
                      .map(
                        (tier) => ChoiceChip(
                          label: Text(tier.label),
                          selected: preferredAudioQuality == tier,
                          onSelected: controlsDisabled ? null : (_) => onQualityChanged(tier),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.lg),
          const WzSectionHeader(
            title: 'Downloads & storage',
            subtitle: 'Keep music available when you are away from the network.',
            icon: Icons.download_done_rounded,
          ),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Smart Downloads'),
                  subtitle: const Text('Keep the current and next tracks ready offline.'),
                  value: smartDownloadsEnabled,
                  onChanged: onSmartDownloadsChanged,
                ),
                const SizedBox(height: WzSpacing.xs),
                Text(
                  cachedTrackCount == 0
                      ? 'Nothing saved offline yet.'
                      : '$cachedTrackCount saved offline • ${formatWzCacheBytes(cacheBytes)}',
                  style: WzText.caption,
                ),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzPrimaryAction(
                      label: 'Manage storage',
                      icon: Icons.storage_rounded,
                      onPressed: onManageStorage,
                    ),
                    OutlinedButton.icon(
                      onPressed: controlsDisabled || cachedTrackCount == 0 ? null : () => unawaited(onClearCache()),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove downloads'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.lg),
          const WzSectionHeader(
            title: 'Privacy',
            subtitle: 'Listening and search history stay on this device.',
            icon: Icons.lock_outline_rounded,
          ),
          WzPanel(
            child: Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: onClearRecentSearches,
                  icon: const Icon(Icons.search_off_rounded),
                  label: const Text('Clear recent searches'),
                ),
                OutlinedButton.icon(
                  onPressed: onClearListeningHistory,
                  icon: const Icon(Icons.history_toggle_off_rounded),
                  label: const Text('Clear listening history'),
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.lg),
          const WzSectionHeader(
            title: 'About',
            subtitle: 'WaveZero and the music available to you.',
            icon: Icons.info_outline_rounded,
          ),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('WaveZero', style: WzText.sectionTitle),
                const SizedBox(height: WzSpacing.xs),
                const Text('The music is with you.', style: WzText.caption),
                const SizedBox(height: WzSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WzLegalLicensesPage(
                        tracks: legalTracks,
                        appMode: WzAppMode.consumer,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Licenses & sources'),
                ),
              ],
            ),
          ),
        ],
      );
}
