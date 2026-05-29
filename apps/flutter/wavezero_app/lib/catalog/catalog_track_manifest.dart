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

  static Map<String, Object?>? _readMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    return null;
  }

  static String? _readString(Object? value) {
    if (value is String) return value;
    return null;
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
