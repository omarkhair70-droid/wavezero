import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TrackCacheStatus { notCached, caching, cached, failed }

String? _readString(Object? value) {
  if (value is String) return value;
  return null;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

class CachedTrackMetadata {
  const CachedTrackMetadata({
    required this.trackId,
    required this.title,
    this.artistName,
    this.durationMs,
    this.artworkUrl,
    required this.localFilePath,
    required this.originalRemoteUrl,
    required this.cachedAt,
    this.downloadSource = 'unknown',
  });

  final String trackId;
  final String title;
  final String? artistName;
  final int? durationMs;
  final String? artworkUrl;
  final String localFilePath;
  final String originalRemoteUrl;
  final int cachedAt;
  final String downloadSource;

  String get localFileUrl => 'file://$localFilePath';

  String get subtitle {
    final artist = artistName;
    if (artist != null && artist.trim().isNotEmpty) return artist;
    return 'Offline cached track';
  }

  CachedTrackMetadata copyWith({
    String? trackId,
    String? title,
    String? artistName,
    int? durationMs,
    String? artworkUrl,
    String? localFilePath,
    String? originalRemoteUrl,
    int? cachedAt,
    String? downloadSource,
  }) {
    return CachedTrackMetadata(
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      durationMs: durationMs ?? this.durationMs,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      originalRemoteUrl: originalRemoteUrl ?? this.originalRemoteUrl,
      cachedAt: cachedAt ?? this.cachedAt,
      downloadSource: downloadSource ?? this.downloadSource,
    );
  }

  Map<String, Object?> toJson() => {
        'trackId': trackId,
        'title': title,
        'artistName': artistName,
        'durationMs': durationMs,
        'artworkUrl': artworkUrl,
        'localFilePath': localFilePath,
        'originalRemoteUrl': originalRemoteUrl,
        'cachedAt': cachedAt,
        'downloadSource': downloadSource,
      };

  factory CachedTrackMetadata.fromJson(Map<String, Object?> json) {
    final trackId = _readString(json['trackId']);
    final title = _readString(json['title']);
    final localFilePath = _readString(json['localFilePath']);
    final originalRemoteUrl = _readString(json['originalRemoteUrl']);
    if (trackId == null || title == null || localFilePath == null || originalRemoteUrl == null) {
      throw const FormatException('Cached track metadata is missing required fields');
    }
    return CachedTrackMetadata(
      trackId: trackId,
      title: title,
      artistName: _readString(json['artistName']),
      durationMs: _readInt(json['durationMs']),
      artworkUrl: _readString(json['artworkUrl']),
      localFilePath: localFilePath,
      originalRemoteUrl: originalRemoteUrl,
      cachedAt: _readInt(json['cachedAt']) ?? DateTime.now().millisecondsSinceEpoch,
      downloadSource: _readString(json['downloadSource']) ?? _readString(json['cacheSource']) ?? 'unknown',
    );
  }
}

class CacheService {
  CacheService._();

  static final CacheService _instance = CacheService._();

  factory CacheService() => _instance;

  late Directory _baseDir;
  late SharedPreferences _prefs;
  Future<void>? _initFuture;

  // key -> local file path
  final Map<String, String> _index = {};
  final Map<String, CachedTrackMetadata> _metadata = {};
  final Map<String, TrackCacheStatus> _status = {};

  String? lastCacheResult;

  Future<void> init() {
    if (_initFuture != null) return _initFuture!;
    _initFuture = _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    _prefs = await SharedPreferences.getInstance();
    _baseDir = await getApplicationDocumentsDirectory();
    final rawIndex = _prefs.getString('wz_cache_index');
    if (rawIndex != null && rawIndex.isNotEmpty) {
      try {
        final Map<String, dynamic> json = jsonDecode(rawIndex);
        json.forEach((k, v) {
          if (v is String) {
            _index[k] = v;
          }
        });
      } catch (_) {}
    }
    final rawMetadata = _prefs.getString('wz_cache_metadata');
    if (rawMetadata != null && rawMetadata.isNotEmpty) {
      try {
        final Map<String, dynamic> json = jsonDecode(rawMetadata);
        json.forEach((k, v) {
          if (v is Map) {
            try {
              _metadata[k] = CachedTrackMetadata.fromJson(Map<String, Object?>.from(v));
            } catch (_) {}
          }
        });
      } catch (_) {}
    }
    // populate statuses based on file existence
    for (final entry in _index.entries) {
      final f = File(entry.value);
      _status[entry.key] = f.existsSync() ? TrackCacheStatus.cached : TrackCacheStatus.notCached;
    }
  }

  Future<void> ensureInitialized() async {
    if (_initFuture == null) {
      _initFuture = _doInit();
    }
    return _initFuture!;
  }

  TrackCacheStatus statusForTrack(String trackId) => _status[trackId] ?? TrackCacheStatus.notCached;

  Future<CachedTrackMetadata?> cachedTrackById(String trackId) async {
    await ensureInitialized();
    return _metadata[trackId];
  }

  Future<bool> hasCachedTrack(String trackId) async {
    await ensureInitialized();
    return statusForTrack(trackId) == TrackCacheStatus.cached;
  }

  Future<List<CachedTrackMetadata>> cachedLibrary() async {
    await ensureInitialized();
    return _metadata.values.where((entry) => statusForTrack(entry.trackId) == TrackCacheStatus.cached).toList(growable: false);
  }

  Future<String> cachedOrRemoteUrl(String trackId, String remoteUrl) async {
    await ensureInitialized();
    final local = _index[trackId];
    if (local != null) {
      final f = File(local);
      if (await f.exists()) {
        return 'file://${f.path}';
      }
    }
    return remoteUrl;
  }

  Future<bool> downloadAndCache(String trackId, String url, {CachedTrackMetadata? metadata}) async {
    await ensureInitialized();
    _status[trackId] = TrackCacheStatus.caching;
    lastCacheResult = null;
    try {
      final uri = Uri.parse(url);
      final resp = await http.get(uri);
      if (resp.statusCode != 200) throw HttpException('HTTP ${resp.statusCode}');
      final ext = _guessExtFromUrl(url) ?? '.audio';
      final file = File('${_baseDir.path}/wz_cache_${_sanitize(trackId)}$ext');
      await file.writeAsBytes(resp.bodyBytes);
      _index[trackId] = file.path;
      _status[trackId] = TrackCacheStatus.cached;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (metadata != null) {
        _metadata[trackId] = metadata.copyWith(localFilePath: file.path, cachedAt: nowMs);
      } else {
        final existing = _metadata[trackId];
        if (existing != null) {
          _metadata[trackId] = existing.copyWith(localFilePath: file.path, cachedAt: nowMs);
        }
      }
      await _persistIndex();
      lastCacheResult = 'cached:${file.path}';
      return true;
    } catch (error) {
      _status[trackId] = TrackCacheStatus.failed;
      lastCacheResult = 'error:${error.toString()}';
      return false;
    }
  }

  Future<bool> deleteCachedTrack(String trackId) async {
    await ensureInitialized();
    final path = _index[trackId] ?? _metadata[trackId]?.localFilePath;
    var deletedFile = false;
    if (path != null && path.isNotEmpty) {
      try {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
          deletedFile = true;
        }
      } catch (error) {
        lastCacheResult = 'delete_error:$trackId:${error.toString()}';
        return false;
      }
    }
    _index.remove(trackId);
    _metadata.remove(trackId);
    _status[trackId] = TrackCacheStatus.notCached;
    await _persistIndex();
    lastCacheResult = deletedFile ? 'deleted:$trackId' : 'deleted_metadata:$trackId';
    return true;
  }

  Future<void> clearCache() async {
    await ensureInitialized();
    for (final path in _index.values) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    _index.clear();
    _metadata.clear();
    _status.clear();
    lastCacheResult = 'cleared';
    await _persistIndex();
  }

  int cachedTrackCount() {
    return _metadata.values.where((entry) => statusForTrack(entry.trackId) == TrackCacheStatus.cached).length;
  }

  Future<int> cacheBytes() async {
    await ensureInitialized();
    var total = 0;
    for (final path in _index.values) {
      try {
        final f = File(path);
        if (await f.exists()) total += await f.length();
      } catch (_) {}
    }
    return total;
  }

  Future<void> _persistIndex() async {
    await _prefs.setString('wz_cache_index', jsonEncode(_index));
    await _prefs.setString('wz_cache_metadata', jsonEncode(_metadata.map((key, value) => MapEntry(key, value.toJson()))));
  }

  String? _guessExtFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final dot = seg.lastIndexOf('.');
      if (dot >= 0 && dot < seg.length - 1) return seg.substring(dot);
    } catch (_) {}
    return null;
  }

  String _sanitize(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
}
