import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/imports/import_inbox_projection.dart';
import 'package:wavezero_app/features/imports/import_inbox_service.dart';

void main() {
  test('projects modern MediaStore inbox audio into a device catalog track', () {
    const entry = WzImportInboxEntry(
      id: 'inbox-1',
      kind: WzImportInboxKind.audio,
      title: 'My Track.m4a',
      subtitle: 'Shared to WaveZero',
      value: 'content://media/external/audio/media/42',
      mimeType: 'audio/mp4',
      trackId: 'device-audio-42',
      createdAtMs: 1234,
    );

    final track = wzCatalogTrackFromInboxEntry(entry);

    expect(track, isNotNull);
    expect(track!.trackId, 'device-audio-42');
    expect(track.title, 'My Track');
    expect(track.source, 'device');
    expect(track.primaryAsset?.manifestUrl, entry.value);
    expect(track.primaryAsset?.codec, 'm4a');
  });

  test('legacy or malformed inbox audio falls back to Device Music refresh', () {
    const legacy = WzImportInboxEntry(
      id: 'legacy',
      kind: WzImportInboxKind.audio,
      title: 'legacy.mp3',
      subtitle: 'Shared to WaveZero',
      value: 'file:///tmp/legacy.mp3',
      mimeType: 'audio/mpeg',
      createdAtMs: 1234,
    );

    expect(wzCatalogTrackFromInboxEntry(legacy), isNull);
  });
}
