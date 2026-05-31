import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/audio_quality.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';

void main() {
  test('choosePreferredAsset falls back from high to standard before original', () {
    const track = CatalogTrackSummary(
      trackId: 'track-1',
      title: 'Track 1',
      primaryAsset: CatalogTrackAssetSummary(
        assetId: 'standard',
        manifestUrl: 'https://example.test/standard.mp3',
        qualityLabel: 'standard',
      ),
      assets: [
        CatalogTrackAssetSummary(
          assetId: 'standard',
          manifestUrl: 'https://example.test/standard.mp3',
          qualityLabel: 'standard',
        ),
        CatalogTrackAssetSummary(
          assetId: 'original',
          manifestUrl: 'https://example.test/original.flac',
          qualityLabel: 'original',
        ),
      ],
    );

    final selection = choosePreferredAsset(track, AudioQualityTier.high);

    expect(selection?.asset.assetId, 'standard');
    expect(selection?.fallbackReason, contains('preferred high unavailable'));
  });

  test('choosePreferredAsset selects original when preferred and available', () {
    const track = CatalogTrackSummary(
      trackId: 'track-1',
      title: 'Track 1',
      assets: [
        CatalogTrackAssetSummary(
          assetId: 'high',
          manifestUrl: 'https://example.test/high.m4a',
          qualityLabel: 'high',
        ),
        CatalogTrackAssetSummary(
          assetId: 'original',
          manifestUrl: 'https://example.test/original.flac',
          qualityLabel: 'original',
        ),
      ],
    );

    final selection = choosePreferredAsset(track, AudioQualityTier.original);

    expect(selection?.asset.assetId, 'original');
    expect(selection?.usedPreferredQuality, isTrue);
  });
}
