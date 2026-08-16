class DeviceMusicTrack {
  const DeviceMusicTrack({
    required this.trackId,
    required this.title,
    this.artistName,
    this.albumName,
    this.durationMs,
    this.sizeBytes,
    this.mimeType,
    required this.contentUri,
    this.dateAdded,
    this.dateModified,
    this.displayName,
    this.qualityLabel,
    this.codec,
    this.bitrateKbps,
    this.artworkUri,
    this.source = 'device',
  });

  final String trackId;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? durationMs;
  final int? sizeBytes;
  final String? mimeType;
  final String contentUri;
  final int? dateAdded;
  final int? dateModified;
  final String? displayName;
  final String? qualityLabel;
  final String? codec;
  final int? bitrateKbps;
  final String? artworkUri;
  final String source;

  factory DeviceMusicTrack.fromJson(Map<Object?, Object?> json) {
    final trackId = _readString(json['trackId']);
    final title = _readString(json['title']) ?? _readString(json['displayName']);
    final contentUri = _readString(json['contentUri']);
    if (trackId == null || trackId.isEmpty) {
      throw const FormatException('Device music track is missing trackId');
    }
    if (title == null || title.isEmpty) {
      throw const FormatException('Device music track is missing title');
    }
    if (contentUri == null || contentUri.isEmpty) {
      throw const FormatException('Device music track is missing contentUri');
    }
    return DeviceMusicTrack(
      trackId: trackId,
      title: title,
      artistName: _readString(json['artistName']),
      albumName: _readString(json['albumName']),
      durationMs: _readInt(json['durationMs']),
      sizeBytes: _readInt(json['sizeBytes']),
      mimeType: _readString(json['mimeType']),
      contentUri: contentUri,
      dateAdded: _readInt(json['dateAdded']),
      dateModified: _readInt(json['dateModified']),
      displayName: _readString(json['displayName']),
      qualityLabel: _readString(json['qualityLabel']),
      codec: _readString(json['codec']),
      bitrateKbps: _readInt(json['bitrateKbps']),
      artworkUri: _readString(json['artworkUri']),
      source: _readString(json['source']) ?? 'device',
    );
  }

  String get subtitle {
    final parts = [artistName, albumName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList(growable: false);
    return parts.isEmpty ? 'Device music' : parts.join(' • ');
  }

  bool matchesQuery(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return [title, artistName, albumName, displayName, codec, mimeType]
        .whereType<String>()
        .join(' ')
        .toLowerCase()
        .contains(normalizedQuery);
  }
}

String? _readString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
