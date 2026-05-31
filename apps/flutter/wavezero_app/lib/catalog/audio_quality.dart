import 'catalog_track_manifest.dart';

enum AudioQualityTier {
  standard,
  high,
  original,
  unknown,
}

extension AudioQualityTierLabel on AudioQualityTier {
  String get label {
    switch (this) {
      case AudioQualityTier.standard:
        return 'standard';
      case AudioQualityTier.high:
        return 'high';
      case AudioQualityTier.original:
        return 'original';
      case AudioQualityTier.unknown:
        return 'unknown';
    }
  }

}

AudioQualityTier parseAudioQualityTier(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'standard':
    case 'low':
      return AudioQualityTier.standard;
    case 'high':
      return AudioQualityTier.high;
    case 'original':
    case 'lossless':
      return AudioQualityTier.original;
    default:
      return AudioQualityTier.unknown;
  }
}

class PreferredAssetSelection {
  const PreferredAssetSelection({
    required this.asset,
    required this.preferredQuality,
    required this.fallbackReason,
  });

  final CatalogTrackAssetSummary asset;
  final AudioQualityTier preferredQuality;
  final String fallbackReason;

  bool get usedPreferredQuality => parseAudioQualityTier(asset.qualityLabel) == preferredQuality;
}

PreferredAssetSelection? choosePreferredAsset(
  CatalogTrackSummary track,
  AudioQualityTier preferredAudioQuality,
) {
  final assets = track.assets.isNotEmpty
      ? track.assets
      : [
          if (track.primaryAsset != null) track.primaryAsset!,
        ];
  if (assets.isEmpty) return null;

  final fallbackOrder = _fallbackOrder(preferredAudioQuality);
  for (final quality in fallbackOrder) {
    final asset = assets.where((candidate) => parseAudioQualityTier(candidate.qualityLabel) == quality).firstOrNull;
    if (asset != null) {
      return PreferredAssetSelection(
        asset: asset,
        preferredQuality: preferredAudioQuality,
        fallbackReason: quality == preferredAudioQuality
            ? 'preferred ${preferredAudioQuality.label} asset selected'
            : 'preferred ${preferredAudioQuality.label} unavailable; using ${quality.label}',
      );
    }
  }

  final primary = track.primaryAsset;
  if (primary != null) {
    return PreferredAssetSelection(
      asset: primary,
      preferredQuality: preferredAudioQuality,
      fallbackReason: 'preferred ${preferredAudioQuality.label} unavailable; using primary asset',
    );
  }

  return PreferredAssetSelection(
    asset: assets.first,
    preferredQuality: preferredAudioQuality,
    fallbackReason: 'preferred ${preferredAudioQuality.label} unavailable; using first playable asset',
  );
}

List<AudioQualityTier> _fallbackOrder(AudioQualityTier preferred) {
  switch (preferred) {
    case AudioQualityTier.original:
      return const [AudioQualityTier.original, AudioQualityTier.high, AudioQualityTier.standard];
    case AudioQualityTier.high:
      return const [AudioQualityTier.high, AudioQualityTier.standard, AudioQualityTier.original];
    case AudioQualityTier.standard:
      return const [AudioQualityTier.standard, AudioQualityTier.high, AudioQualityTier.original];
    case AudioQualityTier.unknown:
      return const [AudioQualityTier.high, AudioQualityTier.standard, AudioQualityTier.original];
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
