import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_config.dart';
import '../../app/navigation/wavezero_navigation.dart';
import '../../app/theme/wavezero_theme.dart';
import '../../audio/audio_effects.dart';
import '../../catalog/audio_quality.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../downloads/downloads_presentation.dart';
import '../playback/playback_modes.dart';
import 'legal_licenses_page.dart';

class WzSettingsPage extends StatelessWidget {
  const WzSettingsPage({
    required this.themeConfig,
    required this.onThemePresetChanged,
    required this.onAccentPresetChanged,
    required this.preferredAudioQuality,
    required this.onQualityChanged,
    required this.selectedAudioEffectProfile,
    required this.nativeAudioEffectStatus,
    required this.lastAudioEffectApplyResult,
    required this.onAudioEffectChanged,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerLabel,
    required this.sleepTimerActive,
    required this.onShuffleChanged,
    required this.onRepeatModeChanged,
    required this.onOpenSleepTimer,
    required this.smartDownloadsEnabled,
    required this.onSmartDownloadsChanged,
    required this.cachedTrackCount,
    required this.cacheBytes,
    required this.manualDownloadedCount,
    required this.smartDownloadedCount,
    required this.controlsDisabled,
    required this.onClearCache,
    required this.devicePermissionStatus,
    required this.devicePlatformSupported,
    required this.importedDeviceTrackCount,
    required this.deviceScanStatus,
    required this.deviceLastError,
    required this.onImportDeviceMusic,
    required this.notificationActive,
    required this.appConfig,
    required this.contentModeLabel,
    required this.catalogStatusLabel,
    required this.showDeveloperEntry,
    required this.appMode,
    required this.onDeveloperModeChanged,
    required this.onOpenEngine,
    required this.onManageStorage,
    required this.cloudVaultCount,
    required this.onOpenCloudVault,
    required this.onClearCloudVault,
    required this.listeningHistoryCount,
    required this.mostPlayedHistoryTitle,
    required this.onOpenHistory,
    required this.onOpenSearch,
    required this.onClearRecentSearches,
    required this.onClearListeningHistory,
    required this.legalTracks,
  });

  final WzThemeConfig themeConfig;
  final ValueChanged<WzThemePreset> onThemePresetChanged;
  final ValueChanged<WzAccentPreset> onAccentPresetChanged;
  final AudioQualityTier preferredAudioQuality;
  final ValueChanged<AudioQualityTier> onQualityChanged;
  final AudioEffectProfile selectedAudioEffectProfile;
  final NativeAudioEffectStatus nativeAudioEffectStatus;
  final String lastAudioEffectApplyResult;
  final ValueChanged<AudioEffectProfile> onAudioEffectChanged;
  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final String sleepTimerLabel;
  final bool sleepTimerActive;
  final ValueChanged<bool> onShuffleChanged;
  final ValueChanged<WzRepeatMode> onRepeatModeChanged;
  final VoidCallback onOpenSleepTimer;
  final bool smartDownloadsEnabled;
  final ValueChanged<bool> onSmartDownloadsChanged;
  final int cachedTrackCount;
  final int cacheBytes;
  final int manualDownloadedCount;
  final int smartDownloadedCount;
  final bool controlsDisabled;
  final Future<void> Function() onClearCache;
  final String devicePermissionStatus;
  final bool devicePlatformSupported;
  final int importedDeviceTrackCount;
  final String deviceScanStatus;
  final String? deviceLastError;
  final Future<void> Function() onImportDeviceMusic;
  final bool notificationActive;
  final WaveZeroAppConfig appConfig;
  final String contentModeLabel;
  final String catalogStatusLabel;
  final bool showDeveloperEntry;
  final WzAppMode appMode;
  final ValueChanged<bool> onDeveloperModeChanged;
  final VoidCallback? onOpenEngine;
  final VoidCallback onManageStorage;
  final int cloudVaultCount;
  final VoidCallback onOpenCloudVault;
  final VoidCallback? onClearCloudVault;
  final int listeningHistoryCount;
  final String? mostPlayedHistoryTitle;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenSearch;
  final VoidCallback? onClearRecentSearches;
  final VoidCallback? onClearListeningHistory;
  final List<CatalogTrackSummary> legalTracks;

  @override
  Widget build(BuildContext context) => WzPageScaffold(
        children: [
          const WzPageHeader(icon: Icons.settings, title: 'Settings', subtitle: 'A calm control center for appearance, playback, storage, device music, and app mode.'),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Search & Discovery', subtitle: WaveZeroReleaseCopy.searchLocal, icon: Icons.search),
          WzPanel(
            child: Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzPrimaryAction(label: 'View search', icon: Icons.search, onPressed: onOpenSearch),
                OutlinedButton.icon(onPressed: onClearRecentSearches, icon: const Icon(Icons.clear_all), label: const Text('Clear recent searches')),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Appearance', subtitle: 'Theme choices are persisted on this device.', icon: Icons.palette),
          WzPanel(
            gradient: themeConfig.shellGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: WzThemePreset.values
                      .map((preset) => ChoiceChip(label: Text(preset.label), selected: themeConfig.themePreset == preset, onSelected: (_) => onThemePresetChanged(preset)))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: WzAccentPreset.values
                      .map((preset) => ChoiceChip(
                            avatar: CircleAvatar(backgroundColor: WzThemeConfig(accentPreset: preset).accent, radius: 7),
                            label: Text(preset.label),
                            selected: themeConfig.accentPreset == preset,
                            onSelected: (_) => onAccentPresetChanged(preset),
                          ))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.md),
                Container(
                  padding: const EdgeInsets.all(WzSpacing.md),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(WzRadius.lg), border: Border.all(color: themeConfig.accent.withOpacity(0.55)), gradient: themeConfig.accentGradient),
                  child: const Text('Preview: selected theme and accent are applied to app controls, navigation, and the shell.', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Playback', subtitle: 'User-friendly playback, quality, and effect preferences.', icon: Icons.graphic_eq),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Shuffle'), subtitle: Text(shuffleEnabled ? 'Shuffle on' : 'Shuffle off'), value: shuffleEnabled, onChanged: controlsDisabled ? null : onShuffleChanged),
                const SizedBox(height: WzSpacing.xs),
                Text('Repeat mode', style: WzText.sectionTitle),
                const SizedBox(height: WzSpacing.xs),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: WzRepeatMode.values
                      .map((mode) => ChoiceChip(avatar: Icon(mode.icon, size: 18), label: Text(mode.label), selected: repeatMode == mode, onSelected: controlsDisabled ? null : (_) => onRepeatModeChanged(mode)))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    WzStatusPill(label: sleepTimerLabel, active: sleepTimerActive, icon: sleepTimerActive ? Icons.bedtime : Icons.timer_outlined),
                    OutlinedButton.icon(onPressed: controlsDisabled ? null : onOpenSleepTimer, icon: const Icon(Icons.timer_outlined), label: const Text('Sleep timer')),
                  ],
                ),
                const SizedBox(height: WzSpacing.md),
                Text('Preferred audio quality', style: WzText.sectionTitle),
                const SizedBox(height: WzSpacing.xs),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: [AudioQualityTier.standard, AudioQualityTier.high, AudioQualityTier.original]
                      .map((tier) => ChoiceChip(label: Text(wzProductQualityLabel(tier.label)), selected: preferredAudioQuality == tier, onSelected: controlsDisabled ? null : (_) => onQualityChanged(tier)))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.xs),
                Text('Current selected quality: ${wzProductQualityLabel(preferredAudioQuality.label)}. If a track does not include that asset, WaveZero chooses the closest available quality.', style: WzText.caption),
                const SizedBox(height: WzSpacing.md),
                Text('Audio effects profile', style: WzText.sectionTitle),
                const SizedBox(height: WzSpacing.xs),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: AudioEffectProfile.values
                      .map((profile) => ChoiceChip(label: Text(profile.shortLabel), selected: selectedAudioEffectProfile == profile, onSelected: controlsDisabled ? null : (_) => onAudioEffectChanged(profile)))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.xs),
                Text('Off / Original is the safest default. ${nativeAudioEffectStatus == NativeAudioEffectStatus.unsupported ? 'Effect profile saved. Native DSP support is still foundation-level.' : lastAudioEffectApplyResult}', maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.caption),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Downloads & Storage', subtitle: WaveZeroReleaseCopy.downloadsStayOnDevice, icon: Icons.offline_pin),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Smart Downloads'), subtitle: const Text('WaveZero can cache the current and up-next tracks for faster offline-ready playback.'), value: smartDownloadsEnabled, onChanged: onSmartDownloadsChanged),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzMiniMetric(label: 'Cached for offline', value: '$cachedTrackCount', active: cachedTrackCount > 0, icon: Icons.library_music),
                    WzMiniMetric(label: 'Device storage', value: formatWzCacheBytes(cacheBytes), active: cacheBytes > 0, icon: Icons.sd_storage),
                    WzMiniMetric(label: 'Manual', value: '$manualDownloadedCount', active: manualDownloadedCount > 0, icon: Icons.download_done),
                    WzMiniMetric(label: 'Smart', value: '$smartDownloadedCount', active: smartDownloadedCount > 0, icon: Icons.auto_awesome),
                  ],
                ),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzPrimaryAction(label: 'Manage storage', icon: Icons.storage, onPressed: onManageStorage),
                    OutlinedButton.icon(onPressed: controlsDisabled || cachedTrackCount == 0 ? null : () => unawaited(onClearCache()), icon: const Icon(Icons.clear_all), label: const Text('Clear all downloads')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Cloud Vault / Personal Cloud Music', subtitle: 'Private cloud sources stay local until future providers are connected.', icon: Icons.cloud_done_outlined),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzMiniMetric(label: 'Imported', value: '$cloudVaultCount', active: cloudVaultCount > 0, icon: Icons.library_music),
                    const WzMiniMetric(label: 'Privacy', value: 'Local only', active: true, icon: Icons.lock),
                    const WzMiniMetric(label: 'Sharing', value: 'Unsupported', active: true, icon: Icons.block),
                  ],
                ),
                const SizedBox(height: WzSpacing.sm),
                const Text('WaveZero does not upload your cloud files to WaveZero servers.', style: WzText.caption),
                const Text('Google Drive, Dropbox, OneDrive, and Nextcloud integrations are future provider work; no OAuth tokens or API credentials are stored here.', style: WzText.caption),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzPrimaryAction(label: 'Open Cloud Vault', icon: Icons.cloud_done_outlined, onPressed: onOpenCloudVault),
                    OutlinedButton.icon(onPressed: onClearCloudVault, icon: const Icon(Icons.delete_sweep), label: const Text('Clear Cloud Vault entries')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Listening History', subtitle: WaveZeroReleaseCopy.historyLocal, icon: Icons.history),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzMiniMetric(label: 'Recently played', value: '$listeningHistoryCount', active: listeningHistoryCount > 0, icon: Icons.history),
                    WzMiniMetric(label: 'Most played', value: mostPlayedHistoryTitle ?? 'None yet', active: mostPlayedHistoryTitle != null, icon: Icons.repeat),
                    const WzMiniMetric(label: 'Privacy', value: 'Device only', active: true, icon: Icons.lock),
                  ],
                ),
                const SizedBox(height: WzSpacing.sm),
                const Text('Clear listening history does not delete downloads, playlists, collections, or device music.', style: WzText.caption),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzPrimaryAction(label: 'View History', icon: Icons.history, onPressed: onOpenHistory),
                    OutlinedButton.icon(onPressed: onClearListeningHistory, icon: const Icon(Icons.delete_sweep), label: const Text('Clear listening history')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Device music', subtitle: WaveZeroReleaseCopy.deviceMusicPermission, icon: Icons.perm_media),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzStatusPill(label: devicePermissionStatus == 'granted' ? 'Device access ready' : 'Device access optional', active: devicePermissionStatus == 'granted', warning: devicePermissionStatus.contains('denied'), icon: Icons.privacy_tip),
                    WzStatusPill(label: devicePlatformSupported ? 'Platform supported' : 'Platform unavailable', active: devicePlatformSupported, warning: !devicePlatformSupported, icon: Icons.phone_android),
                    WzStatusPill(label: 'Scan: $deviceScanStatus', active: deviceScanStatus == 'success', warning: deviceScanStatus == 'error', icon: Icons.search),
                  ],
                ),
                const SizedBox(height: WzSpacing.sm),
                Text('Imported device tracks: $importedDeviceTrackCount', style: WzText.body),
                const Text(WaveZeroReleaseCopy.deviceMusicPrivacy, style: WzText.caption),
                if (deviceLastError != null) Text('Last message: $deviceLastError', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzPrimaryAction(label: 'Import Device music', icon: Icons.library_add, onPressed: controlsDisabled ? null : () => unawaited(onImportDeviceMusic())),
                    OutlinedButton.icon(onPressed: controlsDisabled ? null : () => unawaited(onImportDeviceMusic()), icon: const Icon(Icons.refresh), label: const Text('Rescan Device music')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Notifications & Lock Screen', subtitle: 'Playback session presentation.', icon: Icons.notifications_active),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
                  WzStatusPill(label: notificationActive ? 'Media notification active' : 'Media notification inactive', active: notificationActive, icon: Icons.notifications),
                  WzStatusPill(label: notificationActive ? 'Lock-screen controls ready' : 'Start playback to enable controls', active: notificationActive, icon: Icons.lock),
                ]),
                const SizedBox(height: WzSpacing.xs),
                const Text('Lock-screen controls use the current playback session and current track metadata when playback is active.', style: WzText.caption),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          if (showDeveloperEntry) ...[
            const WzSectionHeader(title: 'Developer', subtitle: 'Keep diagnostics separate from the consumer experience.', icon: Icons.developer_mode),
            WzPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Developer Mode'), subtitle: Text(appMode == WzAppMode.developer ? 'On — Engine diagnostics are available in the bottom navigation.' : 'Off — consumer navigation stays clean.'), value: appMode == WzAppMode.developer, onChanged: onDeveloperModeChanged),
                  if (appMode == WzAppMode.developer) ...[
                    const SizedBox(height: WzSpacing.xs),
                    const Text('Engine diagnostics remain in the Engine tab and are not shown as raw metrics on consumer Settings.', style: WzText.caption),
                    const SizedBox(height: WzSpacing.sm),
                    WzPrimaryAction(label: 'Open Engine diagnostics', icon: Icons.engineering, onPressed: onOpenEngine),
                  ],
                ],
              ),
            ),
            const SizedBox(height: WzSpacing.md),
          ],
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'About', subtitle: 'WaveZero app information.', icon: Icons.info_outline),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WaveZero', style: WzText.title),
                const SizedBox(height: WzSpacing.xs),
                const Text('A smart music experience engine for native playback, offline listening, queue intelligence, and premium now-playing UX.', style: WzText.body),
                const SizedBox(height: WzSpacing.xs),
                Text('Version/build: ${appConfig.displayVersion} • ${appConfig.buildLabel}', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                Text('App environment: ${appConfig.appEnvLabel}', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                Text('Content mode: $contentModeLabel', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                Text('Catalog status: $catalogStatusLabel', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                const Text('Local privacy: Device Music, downloads, collections, search history, and listening history stay on this device unless you choose otherwise.', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                const Text('Device Music belongs to your device context. WaveZero does not upload your device music.', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                const Text('Catalog tracks require explicit rights metadata. Dev-only tracks are not production-safe, and beta builds do not claim commercial catalog rights.', style: WzText.caption),
                const SizedBox(height: WzSpacing.sm),
                WzPrimaryAction(label: 'Open Legal / Licenses', icon: Icons.policy, onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WzLegalLicensesPage(tracks: legalTracks, appMode: appMode)))),
              ],
            ),
          ),
        ],
      );
}
