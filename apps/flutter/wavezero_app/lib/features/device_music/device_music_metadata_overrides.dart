import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'device_music_track.dart';

const _wzDeviceMusicMetadataOverridesFileName =
    'wavezero_device_music_metadata_overrides.json';

class WzDeviceMusicMetadataOverride {
  const WzDeviceMusicMetadataOverride({
    required this.trackId,
    this.title,
    this.artistName,
    this.albumName,
    this.updatedAtMs = 0,
  });

  final String trackId;
  final String? title;
  final String? artistName;
  final String? albumName;
  final int updatedAtMs;

  bool get hasChanges =>
      _clean(title) != null ||
      _clean(artistName) != null ||
      _clean(albumName) != null;

  factory WzDeviceMusicMetadataOverride.fromJson(Map<String, Object?> json) {
    return WzDeviceMusicMetadataOverride(
      trackId: _clean(json['trackId']?.toString()) ?? '',
      title: _clean(json['title']?.toString()),
      artistName: _clean(json['artistName']?.toString()),
      albumName: _clean(json['albumName']?.toString()),
      updatedAtMs: _readInt(json['updatedAtMs']) ?? 0,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'trackId': trackId,
        if (_clean(title) != null) 'title': _clean(title),
        if (_clean(artistName) != null) 'artistName': _clean(artistName),
        if (_clean(albumName) != null) 'albumName': _clean(albumName),
        'updatedAtMs': updatedAtMs,
      };
}

Map<String, WzDeviceMusicMetadataOverride>
wzDeviceMusicMetadataOverridesFromJson(String source) {
  if (source.trim().isEmpty) {
    return const <String, WzDeviceMusicMetadataOverride>{};
  }
  final decoded = jsonDecode(source);
  if (decoded is! List) {
    return const <String, WzDeviceMusicMetadataOverride>{};
  }

  final result = <String, WzDeviceMusicMetadataOverride>{};
  for (final raw in decoded) {
    if (raw is! Map) continue;
    final override = WzDeviceMusicMetadataOverride.fromJson(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (override.trackId.isEmpty || !override.hasChanges) continue;
    final previous = result[override.trackId];
    if (previous == null || override.updatedAtMs >= previous.updatedAtMs) {
      result[override.trackId] = override;
    }
  }
  return result;
}

String wzDeviceMusicMetadataOverridesToJson(
  Map<String, WzDeviceMusicMetadataOverride> overrides,
) {
  final values = overrides.values.toList(growable: false)
    ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
  return jsonEncode(values.map((entry) => entry.toJson()).toList(growable: false));
}

DeviceMusicTrack wzApplyDeviceMusicMetadataOverride(
  DeviceMusicTrack track,
  WzDeviceMusicMetadataOverride? override,
) {
  if (override == null || override.trackId != track.trackId) return track;
  return DeviceMusicTrack(
    trackId: track.trackId,
    title: _clean(override.title) ?? track.title,
    artistName: _clean(override.artistName) ?? track.artistName,
    albumName: _clean(override.albumName) ?? track.albumName,
    durationMs: track.durationMs,
    sizeBytes: track.sizeBytes,
    mimeType: track.mimeType,
    contentUri: track.contentUri,
    dateAdded: track.dateAdded,
    dateModified: track.dateModified,
    displayName: track.displayName,
    qualityLabel: track.qualityLabel,
    codec: track.codec,
    bitrateKbps: track.bitrateKbps,
    artworkUri: track.artworkUri,
    source: track.source,
  );
}

List<DeviceMusicTrack> wzApplyDeviceMusicMetadataOverrides(
  List<DeviceMusicTrack> tracks,
  Map<String, WzDeviceMusicMetadataOverride> overrides,
) {
  if (tracks.isEmpty || overrides.isEmpty) return tracks;
  return tracks
      .map(
        (track) => wzApplyDeviceMusicMetadataOverride(
          track,
          overrides[track.trackId],
        ),
      )
      .toList(growable: false);
}

class WzDeviceMusicMetadataOverridesService {
  const WzDeviceMusicMetadataOverridesService();

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}$_wzDeviceMusicMetadataOverridesFileName',
    );
  }

  Future<Map<String, WzDeviceMusicMetadataOverride>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return const <String, WzDeviceMusicMetadataOverride>{};
      }
      return wzDeviceMusicMetadataOverridesFromJson(await file.readAsString());
    } catch (_) {
      return const <String, WzDeviceMusicMetadataOverride>{};
    }
  }

  Future<void> save(WzDeviceMusicMetadataOverride override) async {
    final trackId = override.trackId.trim();
    if (trackId.isEmpty) return;
    final current = Map<String, WzDeviceMusicMetadataOverride>.from(await load());
    if (override.hasChanges) {
      current[trackId] = override;
    } else {
      current.remove(trackId);
    }
    await _save(current);
  }

  Future<void> remove(String trackId) async {
    final normalized = trackId.trim();
    if (normalized.isEmpty) return;
    final current = Map<String, WzDeviceMusicMetadataOverride>.from(await load());
    if (current.remove(normalized) == null) return;
    await _save(current);
  }

  Future<void> _save(
    Map<String, WzDeviceMusicMetadataOverride> overrides,
  ) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      wzDeviceMusicMetadataOverridesToJson(overrides),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}

String? _clean(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
