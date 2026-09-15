import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/web/web_browser_page.dart';
import 'package:wavezero_app/features/web/web_download_service.dart';

void main() {
  test('web location keeps full http and https URLs', () {
    expect(wzResolveWebLocation('https://example.com/music'), 'https://example.com/music');
    expect(wzResolveWebLocation('http://example.com/test.mp3'), 'http://example.com/test.mp3');
  });

  test('web location turns plain text into a Google search', () {
    final uri = Uri.parse(wzResolveWebLocation('Marwan Moussa music'));
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/search');
    expect(uri.queryParameters['q'], 'Marwan Moussa music');
  });

  test('download model exposes determinate progress and terminal state', () {
    final running = WzWebDownloadTask.fromMap(<Object?, Object?>{
      'id': 17,
      'status': 'running',
      'fileName': 'track.mp3',
      'downloadedBytes': 25,
      'totalBytes': 100,
    });
    expect(running.progress, 0.25);
    expect(running.isTerminal, isFalse);

    final done = WzWebDownloadTask.fromMap(<Object?, Object?>{
      'id': 17,
      'status': 'successful',
      'fileName': 'track.mp3',
      'downloadedBytes': 100,
      'totalBytes': 100,
    });
    expect(done.progress, 1.0);
    expect(done.isSuccessful, isTrue);
    expect(done.isTerminal, isTrue);
  });

  test('web transfer feedback formats bytes, rate, and ETA', () {
    expect(wzFormatWebTransferBytes(512), '512 B');
    expect(wzFormatWebTransferBytes(1536), '1.5 KB');
    expect(wzFormatWebTransferBytes(5 * 1024 * 1024), '5.0 MB');
    expect(wzFormatWebTransferRate(512 * 1024), '512 KB/s');
    expect(
      wzFormatWebTransferEta(
        downloadedBytes: 5 * 1024 * 1024,
        totalBytes: 10 * 1024 * 1024,
        bytesPerSecond: 1024 * 1024,
      ),
      '~5s left',
    );
  });
}
