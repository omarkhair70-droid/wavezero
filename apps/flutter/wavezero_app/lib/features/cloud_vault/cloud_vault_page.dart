import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
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
            const WzPageHeader(
              icon: Icons.cloud_done_outlined,
              title: 'Cloud Vault',
              subtitle: 'Play music you own from your private cloud sources.',
            ),
            const SizedBox(height: WzSpacing.md),
            const WzSectionHeader(title: 'Privacy-first foundation', subtitle: 'Cloud Vault stores source metadata locally and does not add cloud auth yet.', icon: Icons.privacy_tip),
            const WzPanel(
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
            const WzSectionHeader(title: 'Private source providers', subtitle: 'Provider connections are intentionally coming-soon; no OAuth, tokens, uploads, or account sync are present.', icon: Icons.cloud_queue),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth >= 360 ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;
                final cards = <Widget>[
                  _CloudProviderCard(title: 'Google Drive', status: 'Coming soon', icon: Icons.add_to_drive),
                  _CloudProviderCard(title: 'Dropbox', status: 'Later', icon: Icons.cloud_outlined),
                  _CloudProviderCard(title: 'OneDrive', status: 'Later', icon: Icons.cloud_circle_outlined),
                  _CloudProviderCard(title: 'Nextcloud / self-hosted', status: 'Later', icon: Icons.dns_outlined),
                  if (developerMode) _CloudProviderCard(title: 'Manual private URL', status: 'Developer preview', icon: Icons.link),
                ];
                return Wrap(spacing: 10, runSpacing: 10, children: cards.map((card) => SizedBox(width: cardWidth, child: card)).toList(growable: false));
              },
            ),
            if (developerMode) ...[
              const SizedBox(height: WzSpacing.md),
              const WzSectionHeader(title: 'Developer preview', subtitle: 'Manual seed controls are only visible in Developer Mode and persist locally for test playback.', icon: Icons.developer_mode),
              WzPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Developer preview: add a private URL placeholder for local UI and playback-path testing. Do not add public copyrighted catalog links.', style: WzText.caption),
                    const SizedBox(height: WzSpacing.sm),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: WzSpacing.sm),
                    TextField(controller: artistController, decoration: const InputDecoration(labelText: 'Artist')),
                    const SizedBox(height: WzSpacing.sm),
                    TextField(controller: playableUrlController, decoration: const InputDecoration(labelText: 'Playable URL')),
                    const SizedBox(height: WzSpacing.sm),
                    TextField(controller: providerLabelController, decoration: const InputDecoration(labelText: 'Provider label')),
                    const SizedBox(height: WzSpacing.md),
                    Align(alignment: Alignment.centerLeft, child: WzPrimaryAction(label: 'Add developer preview track', icon: Icons.add_link, onPressed: () => unawaited(onAddDeveloperTrack()))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: WzSpacing.md),
            WzPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Cloud music entries', style: WzText.title)),
                      Text('${tracks.length} tracks', style: WzText.caption),
                    ],
                  ),
                  const SizedBox(height: WzSpacing.sm),
                  if (tracks.isEmpty) ...[
                    const WzEmptyCatalogMessage(message: 'No cloud music connected yet.\nYour device music and downloads still work offline.'),
                  ] else ...[
                    ...tracks.map((track) => _CloudVaultTrackRow(
                          track: track,
                          developerMode: developerMode,
                          onPlay: track.isResolvable ? () => onPlay(track) : () => onPlay(track),
                          onAddToQueue: track.isResolvable ? () => onAddToQueue(track) : null,
                          onRemove: () => onRemove(track),
                        )),
                    const SizedBox(height: WzSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: onClearAll,
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Clear all Cloud Vault entries from this device'),
                      ),
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
  Widget build(BuildContext context) => WzPanel(
        child: Row(
          children: [
            Icon(icon, color: WzColors.accentAlt),
            const SizedBox(width: WzSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: WzText.sectionTitle),
                  const SizedBox(height: WzSpacing.xs),
                  Text(status, style: WzText.caption),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CloudVaultTrackRow extends StatelessWidget {
  const _CloudVaultTrackRow({
    required this.track,
    required this.developerMode,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onRemove,
  });

  final CloudVaultTrack track;
  final bool developerMode;
  final VoidCallback onPlay;
  final VoidCallback? onAddToQueue;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: WzSpacing.sm),
        padding: const EdgeInsets.all(WzSpacing.sm),
        decoration: BoxDecoration(
          color: WzColors.surfaceMuted,
          borderRadius: BorderRadius.circular(WzRadius.md),
          border: Border.all(color: WzColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(track.isResolvable ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, color: track.isResolvable ? WzColors.accentAlt : WzColors.textSubtle),
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
                FilledButton.tonalIcon(onPressed: onPlay, icon: const Icon(Icons.play_arrow), label: const Text('Play')),
                OutlinedButton.icon(onPressed: onAddToQueue, icon: const Icon(Icons.queue_music), label: const Text('Add to Queue')),
                OutlinedButton.icon(onPressed: onRemove, icon: const Icon(Icons.delete_outline), label: const Text('Remove from Vault')),
              ],
            ),
          ],
        ),
      );
}
