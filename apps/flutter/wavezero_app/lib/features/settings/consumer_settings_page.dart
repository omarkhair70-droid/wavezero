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
    required this.onBack,
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

  final VoidCallback onBack;
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
          Row(
            children: [
              WzSculptedIconButton(
                tooltip: 'Back',
                icon: Icons.arrow_back_rounded,
                size: 44,
                iconSize: 20,
                onPressed: onBack,
              ),
              const SizedBox(width: 13),
              Expanded(child: Text('Settings', style: WzText.pageTitle.copyWith(fontSize: 30))),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsGroup(
            title: 'Audio',
            children: [
              _SettingsChoiceRow(
                icon: Icons.headphones_rounded,
                title: 'Audio quality',
                subtitle: preferredAudioQuality.label,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
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
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'Downloads & storage',
            children: [
              _SettingsSwitchRow(
                icon: Icons.download_done_rounded,
                title: 'Smart Downloads',
                subtitle: 'Keep what you are listening to ready offline.',
                value: smartDownloadsEnabled,
                onChanged: onSmartDownloadsChanged,
              ),
              const _SettingsDivider(),
              _SettingsActionRow(
                icon: Icons.storage_rounded,
                title: 'Storage',
                subtitle: cachedTrackCount == 0
                    ? 'Nothing saved offline yet'
                    : '$cachedTrackCount saved • ${formatWzCacheBytes(cacheBytes)}',
                onTap: onManageStorage,
              ),
              if (cachedTrackCount > 0) ...[
                const _SettingsDivider(),
                _SettingsActionRow(
                  icon: Icons.delete_outline_rounded,
                  title: 'Remove downloads',
                  subtitle: 'Clear music saved for offline listening.',
                  destructive: true,
                  onTap: controlsDisabled ? null : () => unawaited(onClearCache()),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'Privacy',
            children: [
              _SettingsActionRow(
                icon: Icons.search_off_rounded,
                title: 'Clear recent searches',
                subtitle: 'Remove searches stored on this device.',
                onTap: onClearRecentSearches,
              ),
              const _SettingsDivider(),
              _SettingsActionRow(
                icon: Icons.history_toggle_off_rounded,
                title: 'Clear listening history',
                subtitle: 'Remove your local listening history.',
                onTap: onClearListeningHistory,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsGroup(
            title: 'About',
            children: [
              _SettingsActionRow(
                icon: Icons.info_outline_rounded,
                title: 'About WaveZero',
                subtitle: 'The voice is close. The music is with you.',
                onTap: null,
                showArrow: false,
              ),
              const _SettingsDivider(),
              _SettingsActionRow(
                icon: Icons.policy_outlined,
                title: 'Licenses & sources',
                subtitle: 'Information about music available in WaveZero.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WzLegalLicensesPage(
                      tracks: legalTracks,
                      appMode: WzAppMode.consumer,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 5, bottom: 9),
            child: Text(title, style: WzText.eyebrow),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFCFFFFFF), Color(0xF1F7FAFC)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(42),
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(28),
              ),
              border: Border.all(color: const Color(0xF2FFFFFF)),
              boxShadow: WzSurface.softShadows,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      );
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.showArrow = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showArrow;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 13, 13),
            child: Row(
              children: [
                WzSculptedIcon(
                  icon: icon,
                  size: 42,
                  iconSize: 18,
                  color: destructive ? WzColors.danger : WzColors.textPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: WzText.sectionTitle.copyWith(
                          fontSize: 14,
                          color: destructive ? WzColors.danger : WzColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
                    ],
                  ),
                ),
                if (showArrow && onTap != null)
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: WzColors.textSubtle),
              ],
            ),
          ),
        ),
      );
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
        child: Row(
          children: [
            WzSculptedIcon(icon: icon, size: 42, iconSize: 18, color: value ? WzColors.accent : WzColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: WzText.sectionTitle.copyWith(fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
                ],
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      );
}

class _SettingsChoiceRow extends StatelessWidget {
  const _SettingsChoiceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                WzSculptedIcon(icon: icon, size: 42, iconSize: 18, color: WzColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: WzText.sectionTitle.copyWith(fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: WzText.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            child,
          ],
        ),
      );
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: 68, endIndent: 14, color: WzColors.borderSoft);
}
