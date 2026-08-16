import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/device_music/device_music_projection.dart';
import 'package:wavezero_app/features/device_music/device_music_track.dart';
import 'package:wavezero_app/features/history/listening_history_service.dart';

void main() {
  const deviceTrack = DeviceMusicTrack(
    trackId: 'device-audio-1',
    title: 'Local Song',
    artistName: 'Local Artist',
    durationMs: 180000,
    contentUri: 'content://media/external/audio/media/1',
    codec: 'mp3',
    bitrateKbps: 320,
  );

  test('device catalog projection preserves local identity and URI', () {
    final summary = wzCatalogSummaryFromDeviceTrack(deviceTrack);
    expect(summary.trackId, deviceTrack.trackId);
    expect(summary.source, 'device');
    expect(summary.primaryAsset?.manifestUrl, deviceTrack.contentUri);
  });

  test('device manifest uses the MediaStore content URI', () {
    final manifest = wzDeviceManifest(deviceTrack);
    expect(manifest.trackId, deviceTrack.trackId);
    expect(manifest.streamUrl, deviceTrack.contentUri);
  });

  test('device history entry can be rehydrated without a rescan', () {
    const entry = WzListeningHistoryEntry(
      trackId: 'device-audio-1',
      title: 'Local Song',
      subtitle: 'Local Artist',
      source: WzListeningHistorySource.device,
      primaryUrl: 'content://media/external/audio/media/1',
      lastPlayedAtMs: 20,
      firstPlayedAtMs: 10,
      playCount: 2,
      durationMs: 180000,
      codec: 'mp3',
    );
    final restored = wzDeviceTrackFromHistory(entry);
    expect(restored, isNotNull);
    expect(restored!.contentUri, entry.primaryUrl);
    expect(restored.artistName, 'Local Artist');
  });
}
