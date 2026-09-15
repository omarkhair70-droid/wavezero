import 'package:flutter/services.dart';

class WzWebDownloadTask {
  const WzWebDownloadTask({
    required this.id,
    required this.status,
    required this.fileName,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.localUri,
    this.reason,
  });

  final int id;
  final String status;
  final String fileName;
  final int downloadedBytes;
  final int totalBytes;
  final String? localUri;
  final int? reason;

  bool get isTerminal => status == 'successful' || status == 'failed' || status == 'cancelled' || status == 'missing';
  bool get isSuccessful => status == 'successful';

  double? get progress {
    if (totalBytes <= 0) return null;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  factory WzWebDownloadTask.fromMap(Map<Object?, Object?> value) {
    int readInt(Object? raw) => raw is int ? raw : raw is num ? raw.toInt() : 0;
    final rawReason = value['reason'];
    return WzWebDownloadTask(
      id: readInt(value['id']),
      status: value['status']?.toString() ?? 'unknown',
      fileName: value['fileName']?.toString() ?? 'WaveZero download',
      downloadedBytes: readInt(value['downloadedBytes']),
      totalBytes: readInt(value['totalBytes']),
      localUri: value['localUri']?.toString(),
      reason: rawReason is num ? rawReason.toInt() : null,
    );
  }
}

class WzWebDownloadService {
  WzWebDownloadService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('wavezero/playback');

  final MethodChannel _channel;

  Future<WzWebDownloadTask> query(int id) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>('queryWebDownload', {'id': id});
    return WzWebDownloadTask.fromMap(raw ?? <Object?, Object?>{'id': id, 'status': 'missing'});
  }

  Future<void> cancel(int id) async {
    await _channel.invokeMethod<void>('cancelWebDownload', {'id': id});
  }
}
