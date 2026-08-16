import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/downloads/cache_service.dart';
import 'package:wavezero_app/features/downloads/smart_download_policy.dart';

void main() {
  test('preflight preserves disabled, missing-url, and device reasons', () {
    expect(
      evaluateWzSmartDownloadPreflight(
        enabled: false,
        trackId: 'a',
        url: 'https://example.test/a.mp3',
        isDeviceTrack: false,
        isDeviceUrl: false,
      ).reason,
      'smart downloads disabled',
    );
    expect(
      evaluateWzSmartDownloadPreflight(
        enabled: true,
        trackId: 'a',
        url: '',
        isDeviceTrack: false,
        isDeviceUrl: false,
      ).reason,
      'no remote url',
    );
    expect(
      evaluateWzSmartDownloadPreflight(
        enabled: true,
        trackId: 'device:a',
        url: 'content://media/a',
        isDeviceTrack: true,
        isDeviceUrl: true,
      ).reason,
      'device local track already local',
    );
  });

  test('valid remote preflight is admitted', () {
    final result = evaluateWzSmartDownloadPreflight(
      enabled: true,
      trackId: 'a',
      url: 'https://example.test/a.mp3',
      isDeviceTrack: false,
      isDeviceUrl: false,
    );
    expect(result.allowed, isTrue);
    expect(result.reason, isNull);
  });

  test('cache state preserves cached, caching, in-flight, and limit reasons', () {
    expect(
      evaluateWzSmartDownloadCacheState(
        status: TrackCacheStatus.cached,
        alreadyInFlight: false,
        cachedTrackCount: 0,
        maxCachedTracks: 12,
      ).reason,
      'already cached',
    );
    expect(
      evaluateWzSmartDownloadCacheState(
        status: TrackCacheStatus.caching,
        alreadyInFlight: false,
        cachedTrackCount: 0,
        maxCachedTracks: 12,
      ).reason,
      'already caching',
    );
    expect(
      evaluateWzSmartDownloadCacheState(
        status: TrackCacheStatus.notCached,
        alreadyInFlight: true,
        cachedTrackCount: 0,
        maxCachedTracks: 12,
      ).reason,
      'already in-flight',
    );
    expect(
      evaluateWzSmartDownloadCacheState(
        status: TrackCacheStatus.notCached,
        alreadyInFlight: false,
        cachedTrackCount: 12,
        maxCachedTracks: 12,
      ).reason,
      'smart download cache limit reached',
    );
  });

  test('uncached state below the limit is admitted', () {
    final result = evaluateWzSmartDownloadCacheState(
      status: TrackCacheStatus.notCached,
      alreadyInFlight: false,
      cachedTrackCount: 3,
      maxCachedTracks: 12,
    );
    expect(result.allowed, isTrue);
    expect(result.reason, isNull);
  });
}
