import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/downloads/cache_service.dart';
import 'package:wavezero_app/features/downloads/downloads_presentation.dart';

void main() {
  test('cache byte formatting preserves existing units', () {
    expect(formatWzCacheBytes(0), '0 B');
    expect(formatWzCacheBytes(1024), '1.0 KB');
    expect(formatWzCacheBytes(1024 * 1024), '1.0 MB');
  });

  test('cached track projection preserves identity and source URL', () {
    const cached = CachedTrackMetadata(
      trackId: 'track-1',
      title: 'Track One',
      artistName: 'Artist',
      localFilePath: '/tmp/track-1.mp3',
      originalRemoteUrl: 'https://example.test/track-1.mp3',
      cachedAt: 123,
      downloadSource: 'manual',
      qualityLabel: 'high',
      codec: 'mp3',
      bitrateKbps: 320,
    );
    final summary = wzCatalogSummaryFromCachedTrack(cached);
    expect(summary.trackId, cached.trackId);
    expect(summary.title, cached.title);
    expect(summary.source, 'cached');
    expect(summary.primaryAsset?.manifestUrl, cached.originalRemoteUrl);
  });
}
