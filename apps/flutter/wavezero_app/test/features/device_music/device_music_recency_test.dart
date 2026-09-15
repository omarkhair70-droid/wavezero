import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/device_music/device_music_recency.dart';
import 'package:wavezero_app/features/device_music/device_music_track.dart';

void main() {
  const old = DeviceMusicTrack(
    trackId: 'device-audio-1',
    title: 'Old',
    contentUri: 'content://media/1',
    dateAdded: 100,
  );
  const fresh = DeviceMusicTrack(
    trackId: 'device-audio-2',
    title: 'Fresh',
    contentUri: 'content://media/2',
    dateAdded: 300,
  );
  const modifiedOnly = DeviceMusicTrack(
    trackId: 'device-audio-3',
    title: 'Modified',
    contentUri: 'content://media/3',
    dateModified: 200,
  );

  test('device added rank normalizes MediaStore seconds to milliseconds', () {
    expect(wzDeviceTrackAddedRank(fresh), 300000);
    expect(wzDeviceTrackAddedRank(modifiedOnly), 200000);
  });

  test('fresh device tracks are newest first and respect limit', () {
    final result = wzFreshDeviceTracks([old, fresh, modifiedOnly], limit: 2);
    expect(result.map((track) => track.trackId), [
      'device-audio-2',
      'device-audio-3',
    ]);
  });

  test('find device track resolves stable track identity', () {
    expect(wzFindDeviceTrackById([old, fresh], fresh.trackId), same(fresh));
    expect(wzFindDeviceTrackById([old], 'missing'), isNull);
  });
}
