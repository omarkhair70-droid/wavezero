import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/device_music/device_music_metadata_overrides.dart';
import 'package:wavezero_app/features/device_music/device_music_track.dart';

void main() {
  const track = DeviceMusicTrack(
    trackId: 'device-audio-42',
    title: 'Original title',
    artistName: 'Original artist',
    albumName: 'Original album',
    durationMs: 183000,
    sizeBytes: 7340032,
    mimeType: 'audio/mpeg',
    contentUri: 'content://media/external/audio/media/42',
    dateAdded: 100,
    dateModified: 200,
    displayName: 'original.mp3',
    qualityLabel: '320 kbps',
    codec: 'mp3',
    bitrateKbps: 320,
    artworkUri: 'content://media/external/audio/albumart/9',
    source: 'device',
  );

  test('applies local metadata while preserving playback identity and technical metadata', () {
    const override = WzDeviceMusicMetadataOverride(
      trackId: 'device-audio-42',
      title: 'Fixed title',
      artistName: 'Fixed artist',
      albumName: 'Fixed album',
      updatedAtMs: 500,
    );

    final resolved = wzApplyDeviceMusicMetadataOverride(track, override);

    expect(resolved.trackId, track.trackId);
    expect(resolved.contentUri, track.contentUri);
    expect(resolved.title, 'Fixed title');
    expect(resolved.artistName, 'Fixed artist');
    expect(resolved.albumName, 'Fixed album');
    expect(resolved.durationMs, track.durationMs);
    expect(resolved.sizeBytes, track.sizeBytes);
    expect(resolved.mimeType, track.mimeType);
    expect(resolved.codec, track.codec);
    expect(resolved.bitrateKbps, track.bitrateKbps);
    expect(resolved.artworkUri, track.artworkUri);
    expect(resolved.dateAdded, track.dateAdded);
    expect(resolved.dateModified, track.dateModified);
  });

  test('blank fields fall back to device metadata instead of erasing it', () {
    const override = WzDeviceMusicMetadataOverride(
      trackId: 'device-audio-42',
      title: '  Renamed  ',
      artistName: '   ',
      albumName: null,
      updatedAtMs: 500,
    );

    final resolved = wzApplyDeviceMusicMetadataOverride(track, override);

    expect(resolved.title, 'Renamed');
    expect(resolved.artistName, track.artistName);
    expect(resolved.albumName, track.albumName);
  });

  test('JSON parser keeps the newest override for each track and ignores empty entries', () {
    const source = '''
    [
      {"trackId":"device-audio-42","title":"Old title","updatedAtMs":100},
      {"trackId":"device-audio-42","title":"New title","artistName":"New artist","updatedAtMs":300},
      {"trackId":"device-audio-9","title":"   ","artistName":"","albumName":null,"updatedAtMs":400},
      {"trackId":"","title":"Invalid","updatedAtMs":500}
    ]
    ''';

    final overrides = wzDeviceMusicMetadataOverridesFromJson(source);

    expect(overrides, hasLength(1));
    expect(overrides['device-audio-42']?.title, 'New title');
    expect(overrides['device-audio-42']?.artistName, 'New artist');
    expect(overrides['device-audio-42']?.updatedAtMs, 300);
  });

  test('override map round-trips without losing fields', () {
    const original = <String, WzDeviceMusicMetadataOverride>{
      'device-audio-42': WzDeviceMusicMetadataOverride(
        trackId: 'device-audio-42',
        title: 'Fixed title',
        artistName: 'Fixed artist',
        albumName: 'Fixed album',
        updatedAtMs: 900,
      ),
    };

    final decoded = wzDeviceMusicMetadataOverridesFromJson(
      wzDeviceMusicMetadataOverridesToJson(original),
    );

    expect(decoded.keys, ['device-audio-42']);
    expect(decoded['device-audio-42']?.title, 'Fixed title');
    expect(decoded['device-audio-42']?.artistName, 'Fixed artist');
    expect(decoded['device-audio-42']?.albumName, 'Fixed album');
    expect(decoded['device-audio-42']?.updatedAtMs, 900);
  });
}
