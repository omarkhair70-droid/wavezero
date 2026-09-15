import 'device_music_track.dart';

int wzDeviceTrackAddedRank(DeviceMusicTrack track) {
  final addedSeconds = track.dateAdded;
  if (addedSeconds != null && addedSeconds > 0) return addedSeconds * 1000;
  final modifiedSeconds = track.dateModified;
  if (modifiedSeconds != null && modifiedSeconds > 0) return modifiedSeconds * 1000;
  return 0;
}

List<DeviceMusicTrack> wzFreshDeviceTracks(
  Iterable<DeviceMusicTrack> tracks, {
  int limit = 8,
}) {
  if (limit <= 0) return const <DeviceMusicTrack>[];
  final indexed = tracks.indexed.toList(growable: false);
  indexed.sort((a, b) {
    final byRecency = wzDeviceTrackAddedRank(b.$2).compareTo(wzDeviceTrackAddedRank(a.$2));
    if (byRecency != 0) return byRecency;
    return a.$1.compareTo(b.$1);
  });
  return indexed.take(limit).map((entry) => entry.$2).toList(growable: false);
}

DeviceMusicTrack? wzFindDeviceTrackById(
  Iterable<DeviceMusicTrack> tracks,
  String trackId,
) {
  for (final track in tracks) {
    if (track.trackId == trackId) return track;
  }
  return null;
}
