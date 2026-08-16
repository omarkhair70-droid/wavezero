import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../catalog/catalog_track_manifest.dart';

const String waveZeroCollectionsPreferenceKey = 'wavezero.collections.v1';
const String likedTracksCollectionId = 'liked-tracks';

String? _readString(Object? value) => value is String ? value : null;
int? _readInt(Object? value) => value is int ? value : value is num ? value.toInt() : null;

Map<String, Object?>? _readMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  return null;
}

List<Object?> _readList(Object? value) => value is List ? value.cast<Object?>() : const <Object?>[];

enum WzCollectionType { liked, user }

enum WzCollectionTrackSource { api, device, cached, unknown }

class WzCollectionTrackSnapshot {
  const WzCollectionTrackSnapshot({
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
    required this.addedAtMs,
  });

  final String trackId;
  final String title;
  final String subtitle;
  final String? albumName;
  final String? artworkUrl;
  final WzCollectionTrackSource source;
  final String? primaryUrl;
  final String? qualityLabel;
  final String? codec;
  final LicenseMetadata license;
  final int addedAtMs;

  WzCollectionTrackSnapshot copyWith({int? addedAtMs}) => WzCollectionTrackSnapshot(
        trackId: trackId,
        title: title,
        subtitle: subtitle,
        albumName: albumName,
        artworkUrl: artworkUrl,
        source: source,
        primaryUrl: primaryUrl,
        qualityLabel: qualityLabel,
        codec: codec,
        license: license,
        addedAtMs: addedAtMs ?? this.addedAtMs,
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
        'addedAtMs': addedAtMs,
        ...license.toJson(),
      };

  factory WzCollectionTrackSnapshot.fromJson(Map<String, Object?> json) {
    final trackId = _readString(json['trackId']) ?? _readString(json['id']);
    final title = _readString(json['title']);
    if (trackId == null || trackId.isEmpty || title == null || title.isEmpty) {
      throw const FormatException('Collection track is missing required lightweight metadata');
    }
    final sourceName = _readString(json['source']) ?? 'unknown';
    return WzCollectionTrackSnapshot(
      trackId: trackId,
      title: title,
      subtitle: _readString(json['subtitle']) ?? _readString(json['artistName']) ?? 'WaveZero track',
      albumName: _readString(json['albumName']),
      artworkUrl: _readString(json['artworkUrl']),
      source: WzCollectionTrackSource.values.firstWhere(
        (source) => source.name == sourceName,
        orElse: () => WzCollectionTrackSource.unknown,
      ),
      primaryUrl: _readString(json['primaryUrl']) ?? _readString(json['manifestUrl']) ?? _readString(json['contentUri']) ?? _readString(json['localFileUrl']),
      qualityLabel: _readString(json['qualityLabel']),
      codec: _readString(json['codec']),
      license: LicenseMetadata.fromJson(json, fallbackStatus: sourceName == 'device' ? LicenseStatus.userDevice : LicenseStatus.unknown),
      addedAtMs: _readInt(json['addedAtMs']) ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class WzCollection {
  const WzCollection({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.tracks = const <WzCollectionTrackSnapshot>[],
  });

  final String id;
  final String name;
  final String? description;
  final WzCollectionType type;
  final int createdAtMs;
  final int updatedAtMs;
  final List<WzCollectionTrackSnapshot> tracks;

  int get trackCount => tracks.length;
  bool get isLiked => type == WzCollectionType.liked;

  WzCollection copyWith({
    String? name,
    String? description,
    int? updatedAtMs,
    List<WzCollectionTrackSnapshot>? tracks,
  }) =>
      WzCollection(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        type: type,
        createdAtMs: createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
        tracks: tracks ?? this.tracks,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type.name,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'tracks': tracks.map((track) => track.toJson()).toList(growable: false),
      };

  factory WzCollection.fromJson(Map<String, Object?> json) {
    final id = _readString(json['id']);
    final name = _readString(json['name']);
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      throw const FormatException('Collection is missing id or name');
    }
    final typeName = _readString(json['type']) ?? 'user';
    final type = WzCollectionType.values.firstWhere((value) => value.name == typeName, orElse: () => WzCollectionType.user);
    return WzCollection(
      id: id,
      name: name,
      description: _readString(json['description']),
      type: type,
      createdAtMs: _readInt(json['createdAtMs']) ?? DateTime.now().millisecondsSinceEpoch,
      updatedAtMs: _readInt(json['updatedAtMs']) ?? DateTime.now().millisecondsSinceEpoch,
      tracks: _readList(json['tracks'])
          .map(_readMap)
          .whereType<Map<String, Object?>>()
          .map(WzCollectionTrackSnapshot.fromJson)
          .toList(growable: false),
    );
  }

  static WzCollection liked({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return WzCollection(
      id: likedTracksCollectionId,
      name: 'Liked Tracks',
      description: 'Music you heart on this device.',
      type: WzCollectionType.liked,
      createdAtMs: now,
      updatedAtMs: now,
    );
  }
}

class CollectionsService {
  CollectionsService({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;

  Future<SharedPreferences> get _prefs async => _prefsOverride ?? await SharedPreferences.getInstance();

  Future<List<WzCollection>> load() async {
    final prefs = await _prefs;
    final raw = prefs.getString(waveZeroCollectionsPreferenceKey);
    if (raw == null || raw.trim().isEmpty) return <WzCollection>[WzCollection.liked()];
    try {
      final decoded = jsonDecode(raw);
      final root = _readMap(decoded) ?? const <String, Object?>{};
      final collections = _readList(root['collections'])
          .map(_readMap)
          .whereType<Map<String, Object?>>()
          .map(WzCollection.fromJson)
          .toList(growable: true);
      return _ensureLikedCollection(collections);
    } catch (_) {
      return <WzCollection>[WzCollection.liked()];
    }
  }

  Future<void> save(List<WzCollection> collections) async {
    final prefs = await _prefs;
    final safeCollections = _ensureLikedCollection(collections);
    await prefs.setString(
      waveZeroCollectionsPreferenceKey,
      jsonEncode(<String, Object?>{
        'version': 1,
        'collections': safeCollections.map((collection) => collection.toJson()).toList(growable: false),
      }),
    );
  }

  List<WzCollection> _ensureLikedCollection(List<WzCollection> collections) {
    final likedIndex = collections.indexWhere((collection) => collection.type == WzCollectionType.liked || collection.id == likedTracksCollectionId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalized = <WzCollection>[];
    if (likedIndex < 0) {
      normalized.add(WzCollection.liked(nowMs: now));
    } else {
      final liked = collections[likedIndex];
      normalized.add(liked.copyWith(name: 'Liked Tracks'));
    }
    normalized.addAll(collections.where((collection) => collection.type == WzCollectionType.user && collection.id != likedTracksCollectionId));
    return normalized;
  }
}

