import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../catalog/catalog_track_manifest.dart';

const String waveZeroListeningHistoryPreferenceKey = 'wavezero.listening_history.v1';

String? _readString(Object? value) => value is String ? value : null;
int? _readInt(Object? value) => value is int ? value : value is num ? value.toInt() : null;

Map<String, Object?>? _readMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  return null;
}

List<Object?> _readList(Object? value) => value is List ? value.cast<Object?>() : const <Object?>[];

enum WzListeningHistorySource { api, device, cached, unknown }

class WzListeningHistoryEntry {
  const WzListeningHistoryEntry({
    required this.trackId,
    required this.title,
    required this.subtitle,
    this.albumName,
    this.artworkUrl,
    required this.source,
    this.primaryUrl,
    this.qualityLabel,
    this.codec,
    this.license = LicenseMetadata.unknown,
    required this.lastPlayedAtMs,
    required this.firstPlayedAtMs,
    required this.playCount,
    this.lastPositionMs = 0,
    this.durationMs,
    this.completedCount = 0,
  });

  final String trackId;
  final String title;
  final String subtitle;
  final String? albumName;
  final String? artworkUrl;
  final WzListeningHistorySource source;
  final String? primaryUrl;
  final String? qualityLabel;
  final String? codec;
  final LicenseMetadata license;
  final int lastPlayedAtMs;
  final int firstPlayedAtMs;
  final int playCount;
  final int lastPositionMs;
  final int? durationMs;
  final int completedCount;

  WzListeningHistoryEntry copyWith({
    String? title,
    String? subtitle,
    String? albumName,
    String? artworkUrl,
    WzListeningHistorySource? source,
    String? primaryUrl,
    String? qualityLabel,
    String? codec,
    LicenseMetadata? license,
    int? lastPlayedAtMs,
    int? firstPlayedAtMs,
    int? playCount,
    int? lastPositionMs,
    int? durationMs,
    int? completedCount,
  }) =>
      WzListeningHistoryEntry(
        trackId: trackId,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        albumName: albumName ?? this.albumName,
        artworkUrl: artworkUrl ?? this.artworkUrl,
        source: source ?? this.source,
        primaryUrl: primaryUrl ?? this.primaryUrl,
        qualityLabel: qualityLabel ?? this.qualityLabel,
        codec: codec ?? this.codec,
        license: license ?? this.license,
        lastPlayedAtMs: lastPlayedAtMs ?? this.lastPlayedAtMs,
        firstPlayedAtMs: firstPlayedAtMs ?? this.firstPlayedAtMs,
        playCount: playCount ?? this.playCount,
        lastPositionMs: lastPositionMs ?? this.lastPositionMs,
        durationMs: durationMs ?? this.durationMs,
        completedCount: completedCount ?? this.completedCount,
      );

  Map<String, Object?> toJson() => {
        'trackId': trackId,
        'title': title,
        'subtitle': subtitle,
        'albumName': albumName,
        'artworkUrl': artworkUrl,
        'source': source.name,
        'primaryUrl': primaryUrl,
        'qualityLabel': qualityLabel,
        'codec': codec,
        'lastPlayedAtMs': lastPlayedAtMs,
        'firstPlayedAtMs': firstPlayedAtMs,
        'playCount': playCount,
        'lastPositionMs': lastPositionMs,
        'durationMs': durationMs,
        'completedCount': completedCount,
        ...license.toJson(),
      };

  factory WzListeningHistoryEntry.fromJson(Map<String, Object?> json) {
    final trackId = _readString(json['trackId']) ?? _readString(json['id']);
    final title = _readString(json['title']);
    if (trackId == null || trackId.isEmpty || title == null || title.isEmpty) {
      throw const FormatException('History entry missing track id or title');
    }
    final sourceName = _readString(json['source']) ?? 'unknown';
    final now = DateTime.now().millisecondsSinceEpoch;
    return WzListeningHistoryEntry(
      trackId: trackId,
      title: title,
      subtitle: _readString(json['subtitle']) ?? _readString(json['artistName']) ?? 'WaveZero track',
      albumName: _readString(json['albumName']),
      artworkUrl: _readString(json['artworkUrl']),
      source: WzListeningHistorySource.values.firstWhere(
        (source) => source.name == sourceName,
        orElse: () => WzListeningHistorySource.unknown,
      ),
      primaryUrl: _readString(json['primaryUrl']) ?? _readString(json['manifestUrl']) ?? _readString(json['contentUri']) ?? _readString(json['localFileUrl']),
      qualityLabel: _readString(json['qualityLabel']),
      codec: _readString(json['codec']),
      license: LicenseMetadata.fromJson(json, fallbackStatus: sourceName == 'device' ? LicenseStatus.userDevice : LicenseStatus.unknown),
      lastPlayedAtMs: _readInt(json['lastPlayedAtMs']) ?? now,
      firstPlayedAtMs: _readInt(json['firstPlayedAtMs']) ?? _readInt(json['lastPlayedAtMs']) ?? now,
      playCount: _readInt(json['playCount']) ?? 1,
      lastPositionMs: _readInt(json['lastPositionMs']) ?? 0,
      durationMs: _readInt(json['durationMs']),
      completedCount: _readInt(json['completedCount']) ?? 0,
    );
  }
}

class ListeningHistoryService {
  ListeningHistoryService({SharedPreferences? prefs, this.maxEntries = 200}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;
  final int maxEntries;

  Future<SharedPreferences> get _prefs async => _prefsOverride ?? await SharedPreferences.getInstance();

  Future<List<WzListeningHistoryEntry>> load() async {
    final prefs = await _prefs;
    final raw = prefs.getString(waveZeroListeningHistoryPreferenceKey);
    if (raw == null || raw.trim().isEmpty) return const <WzListeningHistoryEntry>[];
    try {
      final decoded = jsonDecode(raw);
      final root = _readMap(decoded) ?? const <String, Object?>{};
      final entries = _readList(root['entries'])
          .map(_readMap)
          .whereType<Map<String, Object?>>()
          .map(WzListeningHistoryEntry.fromJson)
          .toList(growable: false);
      return _sortedAndCapped(entries);
    } catch (_) {
      return const <WzListeningHistoryEntry>[];
    }
  }

  Future<List<WzListeningHistoryEntry>> recordPlay(WzListeningHistoryEntry snapshot) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = await load();
    WzListeningHistoryEntry? existing;
    for (final entry in entries) {
      if (entry.trackId == snapshot.trackId) {
        existing = entry;
        break;
      }
    }
    final nextEntry = (existing ?? snapshot).copyWith(
      title: snapshot.title,
      subtitle: snapshot.subtitle,
      albumName: snapshot.albumName,
      artworkUrl: snapshot.artworkUrl,
      source: snapshot.source,
      primaryUrl: snapshot.primaryUrl,
      qualityLabel: snapshot.qualityLabel,
      codec: snapshot.codec,
      license: snapshot.license,
      lastPlayedAtMs: now,
      firstPlayedAtMs: existing?.firstPlayedAtMs ?? snapshot.firstPlayedAtMs,
      playCount: (existing?.playCount ?? 0) + 1,
      lastPositionMs: snapshot.lastPositionMs,
      durationMs: snapshot.durationMs,
      completedCount: existing?.completedCount ?? snapshot.completedCount,
    );
    final next = _sortedAndCapped([
      nextEntry,
      ...entries.where((entry) => entry.trackId != snapshot.trackId),
    ]);
    await save(next);
    return next;
  }

  Future<List<WzListeningHistoryEntry>> updatePosition(String trackId, {required int positionMs, int? durationMs}) async {
    if (trackId.isEmpty) return load();
    final entries = await load();
    final next = entries
        .map((entry) => entry.trackId == trackId
            ? entry.copyWith(lastPositionMs: positionMs < 0 ? 0 : positionMs, durationMs: durationMs ?? entry.durationMs)
            : entry)
        .toList(growable: false);
    await save(next);
    return next;
  }

  Future<void> save(List<WzListeningHistoryEntry> entries) async {
    final prefs = await _prefs;
    await prefs.setString(
      waveZeroListeningHistoryPreferenceKey,
      jsonEncode(<String, Object?>{
        'version': 1,
        'entries': _sortedAndCapped(entries).map((entry) => entry.toJson()).toList(growable: false),
      }),
    );
  }

  Future<List<WzListeningHistoryEntry>> remove(String trackId) async {
    final next = (await load()).where((entry) => entry.trackId != trackId).toList(growable: false);
    await save(next);
    return next;
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(waveZeroListeningHistoryPreferenceKey);
  }

  List<WzListeningHistoryEntry> _sortedAndCapped(List<WzListeningHistoryEntry> entries) {
    final next = [...entries]..sort((a, b) => b.lastPlayedAtMs.compareTo(a.lastPlayedAtMs));
    return next.take(maxEntries).toList(growable: false);
  }
}
