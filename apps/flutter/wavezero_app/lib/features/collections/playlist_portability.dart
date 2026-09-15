import 'package:flutter/services.dart';

import '../../catalog/catalog_track_manifest.dart';
import 'collections_service.dart';

const String wzPlaylistFileChannelName = 'wavezero/playlist_files';

class WzPlaylistFilePayload {
  const WzPlaylistFilePayload({
    required this.name,
    required this.content,
    this.uri,
  });

  final String name;
  final String content;
  final String? uri;
}

class WzPlaylistFileService {
  const WzPlaylistFileService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(wzPlaylistFileChannelName);

  final MethodChannel _channel;

  Future<WzPlaylistFilePayload?> importM3u() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('importM3u');
    if (raw == null) return null;
    final content = raw['content'];
    if (content is! String || content.trim().isEmpty) return null;
    return WzPlaylistFilePayload(
      name: (raw['name'] as String?)?.trim().isNotEmpty == true
          ? (raw['name'] as String).trim()
          : 'Imported playlist.m3u',
      content: content,
      uri: raw['uri'] as String?,
    );
  }

  Future<String?> exportM3u({
    required String fileName,
    required String content,
  }) async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'exportM3u',
      <String, Object?>{'fileName': fileName, 'content': content},
    );
    return raw?['uri'] as String?;
  }
}

class WzM3uEntry {
  const WzM3uEntry({
    required this.location,
    this.trackId,
    this.title,
    this.artist,
    this.durationSeconds,
  });

  final String location;
  final String? trackId;
  final String? title;
  final String? artist;
  final int? durationSeconds;
}

class WzM3uResolution {
  const WzM3uResolution({
    required this.matched,
    required this.unmatched,
  });

  final List<CatalogTrackSummary> matched;
  final List<WzM3uEntry> unmatched;
}

List<WzM3uEntry> wzParseM3u(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final result = <WzM3uEntry>[];
  String? pendingTrackId;
  String? pendingTitle;
  String? pendingArtist;
  int? pendingDuration;

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || line == '#EXTM3U') continue;
    if (line.startsWith('#WZ-TRACK-ID:')) {
      final value = line.substring('#WZ-TRACK-ID:'.length).trim();
      pendingTrackId = value.isEmpty ? null : value;
      continue;
    }
    if (line.startsWith('#EXTINF:')) {
      final payload = line.substring('#EXTINF:'.length);
      final comma = payload.indexOf(',');
      final durationRaw = comma < 0 ? payload : payload.substring(0, comma);
      pendingDuration = int.tryParse(durationRaw.trim());
      final label = comma < 0 ? '' : payload.substring(comma + 1).trim();
      if (label.isNotEmpty) {
        final separator = label.indexOf(' - ');
        if (separator > 0) {
          pendingArtist = label.substring(0, separator).trim();
          pendingTitle = label.substring(separator + 3).trim();
        } else {
          pendingTitle = label;
        }
      }
      continue;
    }
    if (line.startsWith('#')) continue;

    result.add(
      WzM3uEntry(
        location: line,
        trackId: pendingTrackId,
        title: pendingTitle,
        artist: pendingArtist,
        durationSeconds: pendingDuration,
      ),
    );
    pendingTrackId = null;
    pendingTitle = null;
    pendingArtist = null;
    pendingDuration = null;
  }
  return result;
}

String wzSerializeM3u(WzCollection collection) {
  final buffer = StringBuffer('#EXTM3U\n');
  for (final track in collection.tracks) {
    final location = track.primaryUrl?.trim();
    final resolvedLocation = location == null || location.isEmpty
        ? 'wavezero://track/${Uri.encodeComponent(track.trackId)}'
        : location;
    buffer.writeln('#WZ-TRACK-ID:${track.trackId}');
    final subtitle = track.subtitle.trim();
    final label = subtitle.isEmpty ? track.title : '$subtitle - ${track.title}';
    buffer.writeln('#EXTINF:-1,$label');
    buffer.writeln(resolvedLocation);
  }
  return buffer.toString();
}

WzM3uResolution wzResolveM3uEntries({
  required List<WzM3uEntry> entries,
  required List<CatalogTrackSummary> libraryTracks,
}) {
  final byId = <String, CatalogTrackSummary>{};
  final byLocation = <String, CatalogTrackSummary>{};
  final byDisplayName = <String, List<CatalogTrackSummary>>{};
  final byTitleArtist = <String, List<CatalogTrackSummary>>{};
  final byTitle = <String, List<CatalogTrackSummary>>{};

  for (final track in libraryTracks) {
    byId[track.trackId] = track;
    final location = track.primaryAsset?.manifestUrl.trim();
    if (location != null && location.isNotEmpty) {
      byLocation[_normalizeLocation(location)] = track;
      final base = _basename(location);
      if (base.isNotEmpty) {
        byDisplayName.putIfAbsent(base, () => <CatalogTrackSummary>[]).add(track);
      }
    }
    final displayName = track.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      byDisplayName
          .putIfAbsent(_normalize(displayName), () => <CatalogTrackSummary>[])
          .add(track);
    }
    final titleKey = _normalize(track.title);
    byTitle.putIfAbsent(titleKey, () => <CatalogTrackSummary>[]).add(track);
    final artist = _normalize(track.artistName ?? '');
    byTitleArtist
        .putIfAbsent('$titleKey|$artist', () => <CatalogTrackSummary>[])
        .add(track);
  }

  final matched = <CatalogTrackSummary>[];
  final unmatched = <WzM3uEntry>[];
  final seen = <String>{};

  for (final entry in entries) {
    CatalogTrackSummary? track;
    final id = entry.trackId?.trim();
    if (id != null && id.isNotEmpty) track = byId[id];

    track ??= byLocation[_normalizeLocation(entry.location)];

    if (track == null) {
      final base = _basename(entry.location);
      final candidates = byDisplayName[base];
      if (candidates != null && candidates.length == 1) track = candidates.single;
    }

    final title = _normalize(entry.title ?? _basenameWithoutExtension(entry.location));
    final artist = _normalize(entry.artist ?? '');
    if (track == null && title.isNotEmpty) {
      final exact = byTitleArtist['$title|$artist'];
      if (artist.isNotEmpty && exact != null && exact.length == 1) {
        track = exact.single;
      }
    }
    if (track == null && title.isNotEmpty) {
      final candidates = byTitle[title];
      if (candidates != null && candidates.length == 1) track = candidates.single;
    }

    if (track == null) {
      unmatched.add(entry);
    } else if (seen.add(track.trackId)) {
      matched.add(track);
    }
  }

  return WzM3uResolution(matched: matched, unmatched: unmatched);
}

String wzPlaylistFileName(String collectionName) {
  final cleaned = collectionName
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final base = cleaned.isEmpty ? 'WaveZero Playlist' : cleaned;
  return '$base.m3u';
}

String wzPlaylistNameFromFile(String fileName) {
  var value = fileName.trim();
  value = value.replaceFirst(RegExp(r'\.(m3u8?|txt)$', caseSensitive: false), '');
  value = value.replaceAll(RegExp(r'[_-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return value.isEmpty ? 'Imported Playlist' : value;
}

String _normalize(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _normalizeLocation(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('file://')) {
    final uri = Uri.tryParse(trimmed);
    if (uri != null) return _normalize(uri.toFilePath());
  }
  return _normalize(Uri.decodeComponent(trimmed));
}

String _basename(String value) => _normalize(_rawBasename(value));

String _basenameWithoutExtension(String value) {
  final base = _rawBasename(value);
  final dot = base.lastIndexOf('.');
  return _normalize(dot > 0 ? base.substring(0, dot) : base);
}

String _rawBasename(String value) {
  final decoded = Uri.decodeComponent(value.trim()).replaceAll('\\', '/');
  final withoutQuery = decoded.split('?').first.split('#').first;
  final segments = withoutQuery.split('/').where((part) => part.isNotEmpty).toList();
  return segments.isEmpty ? withoutQuery : segments.last;
}
