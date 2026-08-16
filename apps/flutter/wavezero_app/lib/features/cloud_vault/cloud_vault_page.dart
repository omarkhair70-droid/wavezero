import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../../shared/widgets/wavezero_empty_message.dart';
import 'cloud_vault_models.dart';

class WzCloudVaultPage extends StatelessWidget {
  const WzCloudVaultPage({
    required this.tracks,
    required this.developerMode,
    required this.titleController,
    required this.artistController,
    required this.playableUrlController,
    required this.providerLabelController,
    required this.onAddDeveloperTrack,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<CloudVaultTrack> tracks;
  final bool developerMode;
  final TextEditingController titleController;
  final TextEditingController artistController;
  final TextEditingController playableUrlController;
  final TextEditingController providerLabelController;
  final Future<void> Function() onAddDeveloperTrack;
  final ValueChanged<CloudVaultTrack> onPlay;
  final ValueChanged<CloudVaultTrack> onAddToQueue;
  final ValueChanged<CloudVaultTrack> onRemove;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cloud Vault')),
        body: WzPageScaffold(
          children: [
            const WzPageHeader(icon: Icons.cloud_done_outlined, title: 'Cloud Vault', subtitle: 'Your own music, from private cloud sources.'),
            const SizedBox(height: WzSpacing.md),
            const WzSectionHeader(title: 'Privacy-first foundation', subtitle: 'Source metadata stays local while provider connections are still being built.', icon: Icons.privacy_tip_outlined),
            const WzGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('WaveZero does not upload your cloud files to WaveZero servers.', style: WzText.body),
                  SizedBox(height: WzSpacing.xs),
                  Text('Only files you choose should appear here.', style: WzText.body),
                  SizedBox(height: WzSpacing.xs),
                  Text('Sharing copyrighted files with others is not supported.', style: WzText.body),
                ],
              ),
            ),
            const SizedBox(height: WzSpacing.md),
            const WzSectionHeader(title: 'Private source providers', subtitle: 'Provider connections are coming later; no OAuth tokens or account sync are present yet.', icon: Icons.cloud_queue_rounded),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth >= 360 ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
                final cards = <Widget>[
                  _CloudProviderCard(title: 'Google Drive', status: 'Coming soon', icon: Icons.add_to_drive),
                  _CloudProviderCard(title: 'Dropbox', status: 'Later', icon: Icons.cloud_outlined),
                  _CloudProviderCard(title: 'OneDrive', status: 'Later', icon: Icons.cloud_circle_outlined),
                  _CloudProviderCard(title: 'Nextcloud / self-hosted', status: 'Later', icon: Icons.dns_outlined),
                  if (developerMode) _CloudProviderCard(title: 'Manual private URL', status: 'Developer preview', icon: Icons.link_rounded),
                ];
                return Wrap(spacing: 10, runSpacing: 10, children: cards.map((card) => SizedBox(width: cardWidth, child: card)).toList(growable: false));
              },
            ),
            if (developerMode) ...[
              const SizedBox(height: WzSpacing.md),
              const WzSectionHeader(title: 'Developer preview', subtitle: 'Manual seed controls stay deliberately separate from the consumer experience.', icon: Icons.developer_mode_rounded),
              WzGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Add a private URL placeholder for local UI and playback-path testing. Do not add public copyrighted catalog links.', style: WzText.caption),
                    const SizedBox(height: WzSpacing.sm),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: WzSpacing.sm),
                    TextField(controller: artistController, decoration: const InputDecoration(labelText: 'Artist')),
                    const SizedBox(height: WzSpacing.sm),
                    TextField(controller: playableUrlController, decoration: const InputDecoration(labelText: 'Playable URL')),
                    const SizedBox(height: WzSpacing.sm),
                    TextField(controller: providerLabelController, decoration: const InputDecoration(labelText: 'Provider label')),
                    const SizedBox(height: WzSpacing.md),
                    Align(alignment: Alignment.centerLeft, child: WzPrimaryAction(label: 'Add developer preview track', icon: Icons.add_link_rounded, onPressed: () => unawaited(onAddDeveloperTrack()))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: WzSpacing.md),
            WzGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Cloud music entries', style: WzText.title)),
                      WzStatusPill(label: '${tracks.length} tracks', active: tracks.isNotEmpty, icon: Icons.cloud_done_outlined),
                    ],
                  ),
                  const SizedBox(height: WzSpacing.sm),
                  if (tracks.isEmpty) ...[
                    const WzEmptyCatalogMessage(message: 'No cloud music connected yet.\nYour device music and downloads still work offline.'),
                  ] else ...[
                    ...tracks.map((track) => _CloudVaultTrackRow(
                          track: track,
                          developerMode: developerMode,
                          onPlay: () => onPlay(track),
                          onAddToQueue: track.isResolvable ? () => onAddToQueue(track) : null,
                          onRemove: () => onRemove(track),
                        )),
                    const SizedBox(height: WzSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(onPressed: onClearAll, icon: const Icon(Icons.delete_sweep_rounded), label: const Text('Clear all Cloud Vault entries from this device')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

class _CloudProviderCard extends StatelessWidget {
  const _CloudProviderCard({required this.title, required this.status, required this.icon});

  final String title;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(WzSpacing.md),
        decoration: WzSurface.sculpted(),
        child: Row(
          children: [
            WzSculptedIcon(icon: icon, size: 44, iconSize: 19, color: WzColors.accent),
            const SizedBox(width: WzSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: WzText.sectionTitle),
                  const SizedBox(height: WzSpacing.xxs),
                  Text(status, style: WzText.caption),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CloudVaultTrackRow extends StatelessWidget {
  const _CloudVaultTrackRow({required this.track, required this.developerMode, required this.onPlay, required this.onAddToQueue, required this.onRemove});

  final CloudVaultTrack track;
  final bool developerMode;
  final VoidCallback onPlay;
  final VoidCallback? onAddToQueue;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: WzSpacing.sm),
        padding: const EdgeInsets.all(WzSpacing.sm),
        decoration: WzSurface.sculpted(selected: track.isResolvable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                WzSculptedIcon(icon: track.isResolvable ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 42, iconSize: 18, color: track.isResolvable ? WzColors.accent : WzColors.textSubtle),
                const SizedBox(width: WzSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                      Text('${track.subtitle} • ${track.provider.label}', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: WzSpacing.xs),
            Text(track.isResolvable ? 'Private placeholder is available through the existing playback path.' : 'Cloud playback is not connected yet.', style: WzText.caption),
            if (developerMode && track.playableUri?.trim().isNotEmpty == true) ...[
              const SizedBox(height: WzSpacing.xs),
              Text('Developer preview URL: ${track.playableUri}', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
            ],
            const SizedBox(height: WzSpacing.sm),
            Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                FilledButton.tonalIcon(onPressed: onPlay, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Play')),
                OutlinedButton.icon(onPressed: onAddToQueue, icon: const Icon(Icons.queue_music_rounded), label: const Text('Add to Queue')),
                OutlinedButton.icon(onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Remove from Vault')),
              ],
            ),
          ],
        ),
      );
}
