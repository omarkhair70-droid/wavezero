class CatalogIndex {
  const CatalogIndex({required this.tracks});

  final List<CatalogTrackSummary> tracks;

  factory CatalogIndex.fromJson(Map<String, Object?> json) {
    final rawTracks = json['tracks'];
    if (rawTracks is! List) {
      throw const FormatException('Catalog response is missing tracks list');
    }

    return CatalogIndex(
      tracks: rawTracks
          .map((track) => CatalogTrackSummary.fromJson(_readMap(track) ?? const <String, Object?>{}))
          .toList(growable: false),
    );
  }
}

class CatalogTrackSummary {
  const CatalogTrackSummary({
    required this.trackId,
    required this.title,
    this.artistId,
    this.artistName,
    this.durationMs,
    this.artworkUrl,
    this.primaryAsset,
  });

  final String trackId;
  final String title;
  final String? artistId;
  final String? artistName;
  final int? durationMs;
  final String? artworkUrl;
  final CatalogTrackAssetSummary? primaryAsset;

  factory CatalogTrackSummary.fromJson(Map<String, Object?> json) {
    final trackId = _readString(json['id']);
    final title = _readString(json['title']);
    if (trackId == null || trackId.isEmpty) {
      throw const FormatException('Catalog track is missing id');
    }
    if (title == null || title.isEmpty) {
      throw const FormatException('Catalog track is missing title');
    }

    final primaryAssetJson = _readMap(json['primary_asset']);
    return CatalogTrackSummary(
      trackId: trackId,
      title: title,
      artistId: _readString(json['artist_id']),
      artistName: _readString(json['artist_name']),
      durationMs: _readInt(json['duration_ms']),
      artworkUrl: _readString(json['artwork_url']),
      primaryAsset: primaryAssetJson == null
          ? null
          : CatalogTrackAssetSummary.fromJson(primaryAssetJson),
    );
  }

  String get subtitle {
    final artist = artistName;
    if (artist != null && artist.trim().isNotEmpty) return artist;
    return 'WaveZero catalog track';
  }

  bool matchesQuery(String query) {
    final normalizedQuery = _normalizeSearch(query);
    if (normalizedQuery.isEmpty) return true;

    final searchableText = _normalizeSearch([
      title,
      subtitle,
      trackId,
      artistId ?? '',
      primaryAsset?.codec ?? '',
    ].join(' '));

    return searchableText.contains(normalizedQuery);
  }
}

class CatalogTrackAssetSummary {
  const CatalogTrackAssetSummary({
    required this.assetId,
    required this.manifestUrl,
    this.codec,
    this.bitrateKbps,
  });

  final String assetId;
  final String manifestUrl;
  final String? codec;
  final int? bitrateKbps;

  factory CatalogTrackAssetSummary.fromJson(Map<String, Object?> json) {
    final assetId = _readString(json['id']);
    final manifestUrl = _readString(json['manifest_url']);
    if (assetId == null || assetId.isEmpty) {
      throw const FormatException('Catalog asset is missing id');
    }
    if (manifestUrl == null || manifestUrl.isEmpty) {
      throw const FormatException('Catalog asset is missing manifest_url');
    }

    return CatalogTrackAssetSummary(
      assetId: assetId,
      manifestUrl: manifestUrl,
      codec: _readString(json['codec']),
      bitrateKbps: _readInt(json['bitrate_kbps']),
    );
  }
}

class CatalogTrackManifest {
  const CatalogTrackManifest({
    required this.trackId,
    required this.title,
    required this.streamUrl,
    this.artistId,
    this.artistName,
    this.durationMs,
    this.artworkUrl,
    this.assetId,
    this.codec,
    this.bitrateKbps,
  });

  final String trackId;
  final String title;
  final String streamUrl;
  final String? artistId;
  final String? artistName;
  final int? durationMs;
  final String? artworkUrl;
  final String? assetId;
  final String? codec;
  final int? bitrateKbps;

  factory CatalogTrackManifest.fromJson(Map<String, Object?> json) {
    final track = _readMap(json['track']);
    final asset = _readMap(json['asset']) ?? _readMap(track?['primary_asset']);
    final streamUrl = _readString(json['stream_url']) ?? _readString(asset?['manifest_url']);
    final title = _readString(track?['title']);
    final trackId = _readString(track?['id']);

    if (trackId == null || trackId.isEmpty) {
      throw const FormatException('Catalog manifest is missing track.id');
    }
    if (title == null || title.isEmpty) {
      throw const FormatException('Catalog manifest is missing track.title');
    }
    if (streamUrl == null || streamUrl.isEmpty) {
      throw const FormatException('Catalog manifest is missing stream_url');
    }

    return CatalogTrackManifest(
      trackId: trackId,
      title: title,
      streamUrl: streamUrl,
      artistId: _readString(track?['artist_id']),
      artistName: _readString(track?['artist_name']),
      durationMs: _readInt(track?['duration_ms']),
      artworkUrl: _readString(track?['artwork_url']),
      assetId: _readString(asset?['id']),
      codec: _readString(asset?['codec']),
      bitrateKbps: _readInt(asset?['bitrate_kbps']),
    );
  }

  String get subtitle {
    final artist = artistName;
    if (artist != null && artist.trim().isNotEmpty) return artist;
    return 'WaveZero catalog track';
  }
}

Map<String, Object?>? _readMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  return null;
}

String? _readString(Object? value) {
  if (value is String) return value;
  return null;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

String _normalizeSearch(String value) => value.trim().toLowerCase();
