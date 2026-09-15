import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/imports/import_inbox_service.dart';

void main() {
  test('parses, sorts, and deduplicates native import inbox entries', () {
    const source = '''
    [
      {"id":"older","kind":"audio","title":"older.mp3","subtitle":"Shared to WaveZero","value":"content://audio/1","trackId":"device-audio-1","mimeType":"audio/mpeg","createdAtMs":10},
      {"id":"newer","kind":"link","title":"example.com","subtitle":"Shared link","value":"https://example.com/song","mimeType":"text/plain","createdAtMs":30},
      {"id":"download","kind":"download","title":"song.mp3","subtitle":"Downloading to WaveZero","value":"https://cdn.example/song.mp3","downloadId":77,"createdAtMs":35},
      {"id":"duplicate-download","kind":"download","title":"song.mp3","subtitle":"Downloading to WaveZero","value":"https://cdn.example/song.mp3","downloadId":77,"createdAtMs":34},
      {"id":"duplicate-content","kind":"audio","title":"same.mp3","subtitle":"Already in WaveZero","value":"content://audio/1","trackId":"device-audio-1","createdAtMs":20},
      {"id":"older","kind":"audio","title":"duplicate-id","subtitle":"duplicate","value":"content://audio/2","createdAtMs":25},
      {"id":"","kind":"link","title":"invalid","value":"https://invalid.example","createdAtMs":40}
    ]
    ''';

    final entries = wzImportInboxEntriesFromJson(source);

    expect(entries, hasLength(3));
    expect(entries.first.id, 'download');
    expect(entries.first.kind, WzImportInboxKind.download);
    expect(entries.first.downloadId, 77);
    expect(entries.first.hasDownloadTask, isTrue);
    expect(entries[1].id, 'newer');
    expect(entries[1].kind, WzImportInboxKind.link);
    expect(entries.last.id, 'older');
    expect(entries.last.kind, WzImportInboxKind.audio);
    expect(entries.last.trackId, 'device-audio-1');
    expect(entries.last.hasResolvableDeviceTrack, isTrue);
  });

  test('round-trips inbox entries without losing media or download identity', () {
    const original = <WzImportInboxEntry>[
      WzImportInboxEntry(
        id: 'audio-1',
        kind: WzImportInboxKind.audio,
        title: 'track.m4a',
        subtitle: 'Already in WaveZero',
        value: 'content://media/external/audio/media/42',
        mimeType: 'audio/mp4',
        trackId: 'device-audio-42',
        duplicateOfExisting: true,
        createdAtMs: 1234,
      ),
      WzImportInboxEntry(
        id: 'download-1',
        kind: WzImportInboxKind.download,
        title: 'track.mp3',
        subtitle: 'Downloading to WaveZero',
        value: 'https://cdn.example/track.mp3',
        downloadId: 91,
        createdAtMs: 1220,
      ),
      WzImportInboxEntry(
        id: 'link-1',
        kind: WzImportInboxKind.link,
        title: 'example.com',
        subtitle: 'Shared link',
        value: 'https://example.com/music',
        mimeType: 'text/plain',
        createdAtMs: 1200,
      ),
    ];

    final decoded = wzImportInboxEntriesFromJson(wzImportInboxEntriesToJson(original));

    expect(decoded.map((entry) => entry.id), ['audio-1', 'download-1', 'link-1']);
    expect(decoded.first.value, original.first.value);
    expect(decoded.first.trackId, 'device-audio-42');
    expect(decoded.first.duplicateOfExisting, isTrue);
    expect(decoded[1].downloadId, 91);
    expect(decoded[1].kind, WzImportInboxKind.download);
    expect(decoded.last.value, original.last.value);
  });

  test('invalid or empty payload stays quiet', () {
    expect(wzImportInboxEntriesFromJson('[]'), isEmpty);
    expect(wzImportInboxEntriesFromJson(''), isEmpty);
    expect(wzImportInboxEntriesFromJson('{}'), isEmpty);
  });
}
