import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/web/web_download_service.dart';

void main() {
  test('failed direct audio download is terminal and retryable', () {
    final task = WzWebDownloadTask.fromMap(<Object?, Object?>{
      'id': 44,
      'status': 'failed',
      'fileName': 'song.mp3',
      'downloadedBytes': 1024,
      'totalBytes': 4096,
    });

    expect(task.isTerminal, isTrue);
    expect(task.isSuccessful, isFalse);
    expect(task.canRetry, isTrue);
    expect(task.progress, closeTo(.25, .0001));
  });

  test('active and successful downloads do not expose retry', () {
    const running = WzWebDownloadTask(
      id: 1,
      status: 'running',
      fileName: 'running.mp3',
    );
    const successful = WzWebDownloadTask(
      id: 2,
      status: 'successful',
      fileName: 'done.mp3',
    );

    expect(running.isTerminal, isFalse);
    expect(running.canRetry, isFalse);
    expect(successful.isTerminal, isTrue);
    expect(successful.isSuccessful, isTrue);
    expect(successful.canRetry, isFalse);
  });

  test('missing DownloadManager record is retryable', () {
    const task = WzWebDownloadTask(
      id: 99,
      status: 'missing',
      fileName: 'missing.mp3',
    );

    expect(task.isTerminal, isTrue);
    expect(task.canRetry, isTrue);
  });
}
