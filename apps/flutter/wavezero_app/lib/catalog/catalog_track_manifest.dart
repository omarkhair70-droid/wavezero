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
    this.assets = const [],
  });

  final String trackId;
  final String title;
  final String? artistId;
  final String? artistName;
  final int? durationMs;
  final String? artworkUrl;
  final CatalogTrackAssetSummary? primaryAsset;
  final List<CatalogTrackAssetSummary> assets;

  factory CatalogTrackSummary.fromJson(Map<String, Object?> json) {
    final trackId = _readString(json['id']);
    final title = _readString(json['title']);
    if (trackId == null || trackId.isEmpty) {
      throw const FormatException('Catalog track is missing id');
    }
    if (title == null || title.isEmpty) {
      throw const FormatException('Catalog track is missing title');
    }

    final rawAssets = json['assets'];
    final assets = rawAssets is List
        ? rawAssets
            .map((asset) => CatalogTrackAssetSummary.fromJson(_readMap(asset) ?? const <String, Object?>{}))
            .toList(growable: false)
        : const <CatalogTrackAssetSummary>[];
    final primaryAssetJson = _readMap(json['primary_asset']);
    final primaryAsset = primaryAssetJson == null
        ? (assets.isEmpty ? null : assets.first)
        : CatalogTrackAssetSummary.fromJson(primaryAssetJson);

    return CatalogTrackSummary(
      trackId: trackId,
      title: title,
      artistId: _readString(json['artist_id']),
      artistName: _readString(json['artist_name']),
      durationMs: _readInt(json['duration_ms']),
      artworkUrl: _readString(json['artwork_url']),
      primaryAsset: primaryAsset,
      assets: assets.isEmpty && primaryAsset != null ? [primaryAsset] : assets,
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
      primaryAsset?.qualityLabel ?? '',
    ].join(' '));

    return searchableText.contains(normalizedQuery);
  }
}

class CatalogTrackAssetSummary {
  const CatalogTrackAssetSummary({
    required this.assetId,
    required this.manifestUrl,
    this.qualityLabel,
    this.codec,
    this.bitrateKbps,
    this.sampleRateHz,
    this.bitDepth,
    this.fileSizeBytes,
  });

  final String assetId;
  final String manifestUrl;
  final String? qualityLabel;
  final String? codec;
  final int? bitrateKbps;
  final int? sampleRateHz;
  final int? bitDepth;
  final int? fileSizeBytes;

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
      qualityLabel: _readString(json['quality_label']) ?? _readString(json['qualityTier']) ?? _readString(json['quality_tier']),
      codec: _readString(json['codec']),
      bitrateKbps: _readInt(json['bitrate_kbps']),
      sampleRateHz: _readInt(json['sample_rate_hz']),
      bitDepth: _readInt(json['bit_depth']),
      fileSizeBytes: _readInt(json['file_size_bytes']),
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
    this.qualityLabel,
    this.codec,
    this.bitrateKbps,
    this.sampleRateHz,
    this.bitDepth,
    this.fileSizeBytes,
  });

  final String trackId;
  final String title;
  final String streamUrl;
  final String? artistId;
  final String? artistName;
  final int? durationMs;
  final String? artworkUrl;
  final String? assetId;
  final String? qualityLabel;
  final String? codec;
  final int? bitrateKbps;
  final int? sampleRateHz;
  final int? bitDepth;
  final int? fileSizeBytes;

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
      qualityLabel: _readString(asset?['quality_label']) ?? _readString(asset?['qualityTier']) ?? _readString(asset?['quality_tier']),
      codec: _readString(asset?['codec']),
      bitrateKbps: _readInt(asset?['bitrate_kbps']),
      sampleRateHz: _readInt(asset?['sample_rate_hz']),
      bitDepth: _readInt(asset?['bit_depth']),
      fileSizeBytes: _readInt(asset?['file_size_bytes']),
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
