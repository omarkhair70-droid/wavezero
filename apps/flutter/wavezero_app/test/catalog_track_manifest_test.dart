import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';

void main() {
  test('CatalogTrackManifest parses track manifest API response', () {
    final manifest = CatalogTrackManifest.fromJson(<String, Object?>{
      'track': <String, Object?>{
        'id': 'track-apple-bipbop-hls',
        'artist_id': 'artist-wavezero-labs',
        'artist_name': 'WaveZero Labs',
        'title': 'Apple BipBop HLS Demo',
        'duration_ms': 1800000,
        'artwork_url': 'https://images.example.test/artwork.jpg',
        'primary_asset': <String, Object?>{
          'id': 'asset-apple-bipbop-aac',
          'track_id': 'track-apple-bipbop-hls',
          'manifest_url': 'https://example.test/stream.m3u8',
          'codec': 'aac_lc',
          'bitrate_kbps': 256,
        },
      },
      'asset': <String, Object?>{
        'id': 'asset-apple-bipbop-aac',
        'track_id': 'track-apple-bipbop-hls',
        'manifest_url': 'https://example.test/stream.m3u8',
        'codec': 'aac_lc',
        'bitrate_kbps': 256,
      },
      'stream_url': 'https://example.test/stream.m3u8',
    });

    expect(manifest.trackId, 'track-apple-bipbop-hls');
    expect(manifest.artistId, 'artist-wavezero-labs');
    expect(manifest.artistName, 'WaveZero Labs');
    expect(manifest.title, 'Apple BipBop HLS Demo');
    expect(manifest.durationMs, 1800000);
    expect(manifest.artworkUrl, 'https://images.example.test/artwork.jpg');
    expect(manifest.assetId, 'asset-apple-bipbop-aac');
    expect(manifest.codec, 'aac_lc');
    expect(manifest.bitrateKbps, 256);
    expect(manifest.streamUrl, 'https://example.test/stream.m3u8');
    expect(manifest.subtitle, 'WaveZero Labs');
  });

  test('CatalogTrackManifest falls back to primary asset manifest URL', () {
    final manifest = CatalogTrackManifest.fromJson(<String, Object?>{
      'track': <String, Object?>{
        'id': 'track-1',
        'title': 'Track 1',
        'primary_asset': <String, Object?>{
          'manifest_url': 'https://example.test/fallback.m3u8',
        },
      },
    });

    expect(manifest.streamUrl, 'https://example.test/fallback.m3u8');
    expect(manifest.subtitle, 'WaveZero catalog track');
  });

  test('CatalogTrackManifest rejects incomplete responses', () {
    expect(
      () => CatalogTrackManifest.fromJson(<String, Object?>{
        'track': <String, Object?>{'id': 'track-1'},
      }),
      throwsFormatException,
    );
  });
}
