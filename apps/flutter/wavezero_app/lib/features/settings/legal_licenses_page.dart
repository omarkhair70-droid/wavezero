import 'package:flutter/material.dart';

import '../../app/navigation/wavezero_navigation.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../shared/media/track_source.dart';

class WzLegalLicensesPage extends StatelessWidget {
  const WzLegalLicensesPage({required this.tracks, required this.appMode});

  final List<CatalogTrackSummary> tracks;
  final WzAppMode appMode;

  @override
  Widget build(BuildContext context) {
    final uniqueTracks = <String, CatalogTrackSummary>{};
    for (final track in tracks) {
      uniqueTracks.putIfAbsent(track.trackId, () => track);
    }

    return Scaffold(
      backgroundColor: WzColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: WzPageScaffold(
              children: [
                Row(
                  children: [
                    IconButton.outlined(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back)),
                    const SizedBox(width: WzSpacing.sm),
                    const Expanded(child: WzPageHeader(icon: Icons.policy, title: 'Legal / Licenses', subtitle: 'Credits, license status, and safe catalog source labels.')),
                  ],
                ),
                const SizedBox(height: WzSpacing.md),
                WzPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('WaveZero separates user device music, local dev audio, demo catalog tracks, and future licensed/artist uploads.', style: WzText.body),
                      SizedBox(height: WzSpacing.xs),
                      Text('Device Music belongs to the user/device context and is not uploaded by WaveZero.', style: WzText.caption),
                      SizedBox(height: WzSpacing.xs),
                      Text('Local/dev-only tracks are not production-safe until rights are verified. Beta builds do not claim commercial catalog rights.', style: WzText.caption),
                    ],
                  ),
                ),
                const SizedBox(height: WzSpacing.md),
                const WzSectionHeader(title: 'Status guide', subtitle: 'Badges are metadata labels, not automated legal verification.', icon: Icons.verified_user_outlined),
                WzPanel(
                  child: Wrap(
                    spacing: WzSpacing.xs,
                    runSpacing: WzSpacing.xs,
                    children: LicenseStatus.values.map((status) => WzStatusPill(label: status.label, active: status == LicenseStatus.verified || status == LicenseStatus.publicDomain || status == LicenseStatus.userDevice, warning: status == LicenseStatus.devOnly || status == LicenseStatus.licensePending || status == LicenseStatus.unknown, icon: Icons.label_outline)).toList(growable: false),
                  ),
                ),
                const SizedBox(height: WzSpacing.md),
                const WzSectionHeader(title: 'Catalog credits', subtitle: 'Current library entries and their available rights metadata.', icon: Icons.library_music),
                if (uniqueTracks.isEmpty)
                  const WzPanel(child: Text('No license entries yet. Load the Catalog or import Device music to review rights labels.', style: WzText.body))
                else
                  ...uniqueTracks.values.map((track) => _LegalTrackCard(track: track, developerMode: appMode == WzAppMode.developer)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalTrackCard extends StatelessWidget {
  const _LegalTrackCard({required this.track, required this.developerMode});

  final CatalogTrackSummary track;
  final bool developerMode;

  @override
  Widget build(BuildContext context) {
    final license = track.license;
    final source = license.sourceName ?? (isWzDeviceCatalogTrack(track) ? 'Device music' : isWzCachedCatalogTrack(track) ? 'Downloaded' : 'Catalog');
    return Padding(
      padding: const EdgeInsets.only(bottom: WzSpacing.sm),
      child: WzPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
            const SizedBox(height: WzSpacing.xs),
            Text(track.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
            const SizedBox(height: WzSpacing.sm),
            Wrap(
              spacing: WzSpacing.xs,
              runSpacing: WzSpacing.xs,
              children: [
                WzStatusPill(label: license.badgeLabel, active: !license.needsRightsWarning, warning: license.needsRightsWarning, icon: Icons.policy),
                WzStatusPill(label: source, active: isWzDeviceCatalogTrack(track), warning: license.status == LicenseStatus.devOnly, icon: Icons.source),
                if (license.attributionRequired) const WzStatusPill(label: 'Attribution required', active: true, icon: Icons.badge),
              ],
            ),
            if (license.attributionText != null && license.attributionText!.trim().isNotEmpty) ...[
              const SizedBox(height: WzSpacing.sm),
              Text(license.attributionText!, maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.body),
            ],
            if (license.licenseName != null || license.licenseUrl != null || license.sourceUrl != null) ...[
              const SizedBox(height: WzSpacing.xs),
              Text([license.licenseName, license.licenseUrl, license.sourceUrl].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
            ],
            if (license.needsRightsWarning) ...[
              const SizedBox(height: WzSpacing.xs),
              const Text('Not for production distribution until rights are verified.', style: WzText.caption),
            ],
            if (license.usageNotes != null && license.usageNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: WzSpacing.xs),
              Text(license.usageNotes!, maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.caption),
            ],
            if (developerMode) ...[
              const SizedBox(height: WzSpacing.xs),
              Text('Internal track id: ${track.trackId} • source: ${track.source}', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
            ],
          ],
        ),
      ),
    );
  }
}
