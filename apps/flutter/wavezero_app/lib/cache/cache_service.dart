import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TrackCacheStatus { notCached, caching, cached, failed }

class CacheService {
  CacheService._();

  static final CacheService _instance = CacheService._();

  factory CacheService() => _instance;

  late Directory _baseDir;
  late SharedPreferences _prefs;
  Future<void>? _initFuture;

  // key -> local file path
  final Map<String, String> _index = {};
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
    final raw = _prefs.getString('wz_cache_index');
    if (raw != null && raw.isNotEmpty) {
      try {
        final Map<String, dynamic> json = jsonDecode(raw);
        json.forEach((k, v) {
          if (v is String) {
            _index[k] = v;
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

  Future<bool> downloadAndCache(String trackId, String url) async {
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
      await _persistIndex();
      lastCacheResult = 'cached:${file.path}';
      return true;
    } catch (error) {
      _status[trackId] = TrackCacheStatus.failed;
      lastCacheResult = 'error:${error.toString()}';
      return false;
    }
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
    _status.clear();
    lastCacheResult = 'cleared';
    await _persistIndex();
  }

  int cachedTrackCount() {
    return _index.keys.where((k) => _status[k] == TrackCacheStatus.cached).length;
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
