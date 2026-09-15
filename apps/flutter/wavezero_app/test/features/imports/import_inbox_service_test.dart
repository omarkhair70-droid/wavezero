import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/imports/import_inbox_service.dart';

void main() {
  test('parses, sorts, and deduplicates native import inbox entries', () {
    const source = '''
    [
      {"id":"older","kind":"audio","title":"older.mp3","subtitle":"Shared to WaveZero","value":"content://audio/1","mimeType":"audio/mpeg","createdAtMs":10},
      {"id":"newer","kind":"link","title":"example.com","subtitle":"Shared link","value":"https://example.com/song","mimeType":"text/plain","createdAtMs":30},
      {"id":"older","kind":"audio","title":"duplicate","subtitle":"duplicate","value":"content://audio/2","createdAtMs":20},
      {"id":"","kind":"link","title":"invalid","value":"https://invalid.example","createdAtMs":40}
    ]
    ''';

    final entries = wzImportInboxEntriesFromJson(source);

    expect(entries, hasLength(2));
    expect(entries.first.id, 'newer');
    expect(entries.first.kind, WzImportInboxKind.link);
    expect(entries.last.id, 'older');
    expect(entries.last.kind, WzImportInboxKind.audio);
  });

  test('round-trips inbox entries without losing source data', () {
    const original = <WzImportInboxEntry>[
      WzImportInboxEntry(
        id: 'audio-1',
        kind: WzImportInboxKind.audio,
        title: 'track.m4a',
        subtitle: 'Shared to WaveZero',
        value: 'content://media/external/audio/media/42',
        mimeType: 'audio/mp4',
        createdAtMs: 1234,
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

    expect(decoded.map((entry) => entry.id), ['audio-1', 'link-1']);
    expect(decoded.first.value, original.first.value);
    expect(decoded.last.value, original.last.value);
  });

  test('invalid or empty payload stays quiet', () {
    expect(wzImportInboxEntriesFromJson('[]'), isEmpty);
    expect(wzImportInboxEntriesFromJson(''), isEmpty);
    expect(wzImportInboxEntriesFromJson('{}'), isEmpty);
  });
}
