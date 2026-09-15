import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/lyrics/lyrics_models.dart';

void main() {
  test('LRC parser accepts centiseconds, milliseconds, and multiple timestamps', () {
    final lines = parseWzLrc('''
[00:01.20]First
[00:02.345]Second
[00:03.5][00:04.50]Echo
plain text
''');

    expect(lines.map((line) => line.timeMs).toList(), [1200, 2345, 3500, 4500]);
    expect(lines.map((line) => line.text).toList(), [
      'First',
      'Second',
      'Echo',
      'Echo',
    ]);
  });

  test('plain lyrics stay unsynced', () {
    const document = WzLyricsDocument(
      trackId: 'track-a',
      rawText: 'First line\nSecond line',
      updatedAtMs: 1,
    );

    expect(document.isSynced, isFalse);
    expect(document.activeLineIndex(10000), -1);
  });

  test('active line follows the latest timestamp not after playback position', () {
    const document = WzLyricsDocument(
      trackId: 'track-a',
      rawText: '[00:01.00]One\n[00:04.00]Two\n[00:08.00]Three',
      updatedAtMs: 1,
    );

    expect(document.activeLineIndex(500), -1);
    expect(document.activeLineIndex(1000), 0);
    expect(document.activeLineIndex(7999), 1);
    expect(document.activeLineIndex(9000), 2);
  });
}
