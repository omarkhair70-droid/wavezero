import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const _wzWebLibraryFileName = 'wavezero_web_library.json';
const _wzWebLibraryLimit = 80;

class WzWebPageRecord {
  const WzWebPageRecord({
    required this.url,
    required this.title,
    required this.updatedAtMs,
  });

  final String url;
  final String title;
  final int updatedAtMs;

  factory WzWebPageRecord.fromJson(Map<String, Object?> json) {
    return WzWebPageRecord(
      url: json['url']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? '',
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'url': url,
        'title': title,
        'updatedAtMs': updatedAtMs,
      };
}

class WzWebLibraryState {
  const WzWebLibraryState({
    this.bookmarks = const <WzWebPageRecord>[],
    this.history = const <WzWebPageRecord>[],
  });

  final List<WzWebPageRecord> bookmarks;
  final List<WzWebPageRecord> history;

  bool isBookmarked(String url) => bookmarks.any((item) => item.url == url);

  WzWebLibraryState recordVisit({
    required String url,
    required String title,
    required int visitedAtMs,
  }) {
    final normalizedUrl = url.trim();
    if (!_isHttpUrl(normalizedUrl)) return this;
    final next = <WzWebPageRecord>[
      WzWebPageRecord(
        url: normalizedUrl,
        title: _displayTitle(title, normalizedUrl),
        updatedAtMs: visitedAtMs,
      ),
      ...history.where((item) => item.url != normalizedUrl),
    ].take(_wzWebLibraryLimit).toList(growable: false);
    return WzWebLibraryState(bookmarks: bookmarks, history: next);
  }

  WzWebLibraryState toggleBookmark({
    required String url,
    required String title,
    required int updatedAtMs,
  }) {
    final normalizedUrl = url.trim();
    if (!_isHttpUrl(normalizedUrl)) return this;
    if (isBookmarked(normalizedUrl)) {
      return WzWebLibraryState(
        bookmarks: bookmarks.where((item) => item.url != normalizedUrl).toList(growable: false),
        history: history,
      );
    }
    final next = <WzWebPageRecord>[
      WzWebPageRecord(
        url: normalizedUrl,
        title: _displayTitle(title, normalizedUrl),
        updatedAtMs: updatedAtMs,
      ),
      ...bookmarks.where((item) => item.url != normalizedUrl),
    ].take(_wzWebLibraryLimit).toList(growable: false);
    return WzWebLibraryState(bookmarks: next, history: history);
  }

  WzWebLibraryState clearHistory() => WzWebLibraryState(bookmarks: bookmarks);

  Map<String, Object?> toJson() => <String, Object?>{
        'bookmarks': bookmarks.map((item) => item.toJson()).toList(growable: false),
        'history': history.map((item) => item.toJson()).toList(growable: false),
      };

  factory WzWebLibraryState.fromJson(Map<String, Object?> json) {
    List<WzWebPageRecord> readList(Object? raw) {
      if (raw is! List) return const <WzWebPageRecord>[];
      final result = <WzWebPageRecord>[];
      final seen = <String>{};
      for (final value in raw) {
        if (value is! Map) continue;
        final item = WzWebPageRecord.fromJson(
          value.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (!_isHttpUrl(item.url) || !seen.add(item.url)) continue;
        result.add(item);
        if (result.length >= _wzWebLibraryLimit) break;
      }
      result.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return result;
    }

    return WzWebLibraryState(
      bookmarks: readList(json['bookmarks']),
      history: readList(json['history']),
    );
  }
}

WzWebLibraryState wzWebLibraryStateFromJson(String source) {
  if (source.trim().isEmpty) return const WzWebLibraryState();
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map) return const WzWebLibraryState();
    return WzWebLibraryState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  } catch (_) {
    return const WzWebLibraryState();
  }
}

String wzWebLibraryStateToJson(WzWebLibraryState state) => jsonEncode(state.toJson());

class WzWebLibraryService {
  const WzWebLibraryService();

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_wzWebLibraryFileName');
  }

  Future<WzWebLibraryState> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const WzWebLibraryState();
      return wzWebLibraryStateFromJson(await file.readAsString());
    } catch (_) {
      return const WzWebLibraryState();
    }
  }

  Future<void> save(WzWebLibraryState state) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(wzWebLibraryStateToJson(state), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}

bool _isHttpUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

String _displayTitle(String title, String url) {
  final cleaned = title.trim();
  if (cleaned.isNotEmpty) return cleaned;
  final uri = Uri.tryParse(url);
  return uri?.host.isNotEmpty == true ? uri!.host : url;
}
