import 'cache_service.dart';

class WzSmartDownloadAdmission {
  const WzSmartDownloadAdmission._({
    required this.allowed,
    this.reason,
  });

  const WzSmartDownloadAdmission.allow() : this._(allowed: true);
  const WzSmartDownloadAdmission.deny(String reason)
      : this._(allowed: false, reason: reason);

  final bool allowed;
  final String? reason;
}

WzSmartDownloadAdmission evaluateWzSmartDownloadPreflight({
  required bool enabled,
  required String trackId,
  required String? url,
  required bool isDeviceTrack,
  required bool isDeviceUrl,
}) {
  if (!enabled) {
    return const WzSmartDownloadAdmission.deny('smart downloads disabled');
  }
  if (url == null || url.isEmpty) {
    return const WzSmartDownloadAdmission.deny('no remote url');
  }
  if (isDeviceTrack || isDeviceUrl) {
    return const WzSmartDownloadAdmission.deny(
      'device local track already local',
    );
  }
  return const WzSmartDownloadAdmission.allow();
}

WzSmartDownloadAdmission evaluateWzSmartDownloadCacheState({
  required TrackCacheStatus status,
  required bool alreadyInFlight,
}) {
  if (status == TrackCacheStatus.cached) {
    return const WzSmartDownloadAdmission.deny('already cached');
  }
  if (status == TrackCacheStatus.caching) {
    return const WzSmartDownloadAdmission.deny('already caching');
  }
  if (alreadyInFlight) {
    return const WzSmartDownloadAdmission.deny('already in-flight');
  }
  return const WzSmartDownloadAdmission.allow();
}

WzSmartDownloadAdmission evaluateWzSmartDownloadCapacity({
  required int cachedTrackCount,
  required int maxCachedTracks,
}) {
  if (cachedTrackCount >= maxCachedTracks) {
    return const WzSmartDownloadAdmission.deny(
      'smart download cache limit reached',
    );
  }
  return const WzSmartDownloadAdmission.allow();
}
