import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const _wzImportInboxFileName = 'wavezero_import_inbox.json';

enum WzImportInboxKind { audio, link, download }

class WzImportInboxEntry {
  const WzImportInboxEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.createdAtMs,
    this.mimeType,
    this.trackId,
    this.downloadId,
    this.duplicateOfExisting = false,
  });

  final String id;
  final WzImportInboxKind kind;
  final String title;
  final String subtitle;
  final String value;
  final String? mimeType;
  final String? trackId;
  final int? downloadId;
  final bool duplicateOfExisting;
  final int createdAtMs;

  bool get isAudio => kind == WzImportInboxKind.audio;
  bool get isLink => kind == WzImportInboxKind.link;
  bool get isDownload => kind == WzImportInboxKind.download;
  bool get hasResolvableDeviceTrack => isAudio && trackId != null && trackId!.trim().isNotEmpty;
  bool get hasDownloadTask => isDownload && downloadId != null && downloadId! > 0;

  factory WzImportInboxEntry.fromJson(Map<String, Object?> json) {
    final rawKind = json['kind']?.toString();
    final rawDownloadId = json['downloadId'];
    return WzImportInboxEntry(
      id: json['id']?.toString() ?? '',
      kind: switch (rawKind) {
        'audio' => WzImportInboxKind.audio,
        'download' => WzImportInboxKind.download,
        _ => WzImportInboxKind.link,
      },
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title']!.toString().trim()
          : 'WaveZero import',
      subtitle: json['subtitle']?.toString().trim().isNotEmpty == true
          ? json['subtitle']!.toString().trim()
          : 'Shared to WaveZero',
      value: json['value']?.toString() ?? '',
      mimeType: json['mimeType']?.toString(),
      trackId: json['trackId']?.toString().trim().isNotEmpty == true
          ? json['trackId']!.toString().trim()
          : null,
      downloadId: rawDownloadId is num ? rawDownloadId.toInt() : int.tryParse(rawDownloadId?.toString() ?? ''),
      duplicateOfExisting: json['duplicateOfExisting'] == true,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': switch (kind) {
          WzImportInboxKind.audio => 'audio',
          WzImportInboxKind.link => 'link',
          WzImportInboxKind.download => 'download',
        },
        'title': title,
        'subtitle': subtitle,
        'value': value,
        if (mimeType != null) 'mimeType': mimeType,
        if (trackId != null) 'trackId': trackId,
        if (downloadId != null) 'downloadId': downloadId,
        if (duplicateOfExisting) 'duplicateOfExisting': true,
        'createdAtMs': createdAtMs,
      };
}

List<WzImportInboxEntry> wzImportInboxEntriesFromJson(String source) {
  if (source.trim().isEmpty) return const <WzImportInboxEntry>[];
  final decoded = jsonDecode(source);
  if (decoded is! List) return const <WzImportInboxEntry>[];

  final entries = <WzImportInboxEntry>[];
  final seenIds = <String>{};
  final seenContent = <String>{};
  for (final item in decoded) {
    if (item is! Map) continue;
    final entry = WzImportInboxEntry.fromJson(
      item.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (entry.id.isEmpty || entry.value.isEmpty || !seenIds.add(entry.id)) continue;
    final contentKey = entry.trackId?.trim().isNotEmpty == true
        ? 'track:${entry.trackId}'
        : entry.downloadId != null
            ? 'download:${entry.downloadId}'
            : '${entry.kind.name}:${entry.value.trim()}';
    if (!seenContent.add(contentKey)) continue;
    entries.add(entry);
  }
  entries.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  return entries;
}

String wzImportInboxEntriesToJson(List<WzImportInboxEntry> entries) =>
    jsonEncode(entries.map((entry) => entry.toJson()).toList(growable: false));

class WzImportInboxService {
  const WzImportInboxService();

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_wzImportInboxFileName');
  }

  Future<List<WzImportInboxEntry>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const <WzImportInboxEntry>[];
      return wzImportInboxEntriesFromJson(await file.readAsString());
    } catch (_) {
      return const <WzImportInboxEntry>[];
    }
  }

  Future<List<WzImportInboxEntry>> dismiss(String id) async {
    final current = await load();
    final next = current.where((entry) => entry.id != id).toList(growable: false);
    await _save(next);
    return next;
  }

  Future<void> clear() => _save(const <WzImportInboxEntry>[]);

  Future<void> _save(List<WzImportInboxEntry> entries) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(wzImportInboxEntriesToJson(entries), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
