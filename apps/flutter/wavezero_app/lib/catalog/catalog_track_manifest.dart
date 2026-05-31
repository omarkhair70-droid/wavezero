class CatalogIndex {
  const CatalogIndex({required this.tracks, this.contentMode});

  final List<CatalogTrackSummary> tracks;
  final String? contentMode;

  factory CatalogIndex.fromJson(Map<String, Object?> json) {
    final rawTracks = json['tracks'];
    if (rawTracks is! List) {
      throw const FormatException('Catalog response is missing tracks list');
    }

    return CatalogIndex(
      tracks: rawTracks
          .map((track) => CatalogTrackSummary.fromJson(_readMap(track) ?? const <String, Object?>{}))
          .toList(growable: false),
      contentMode: _readString(json['contentMode'] ?? json['content_mode']),
    );
  }
}


class ContentStatus {
  const ContentStatus({
    required this.ok,
    this.contentMode,
    this.catalogLoaded = false,
    this.trackCount = 0,
    this.assetCount = 0,
    this.localFolderCatalogEnabled = false,
    this.productionSafeTrackCount = 0,
    this.serverVersion,
    this.errorMessage,
  });

  final bool ok;
  final String? contentMode;
  final bool catalogLoaded;
  final int trackCount;
  final int assetCount;
  final bool localFolderCatalogEnabled;
  final int productionSafeTrackCount;
  final String? serverVersion;
  final String? errorMessage;

  bool get available => ok && catalogLoaded;
  String? get message => errorMessage;

  factory ContentStatus.fromJson(Map<String, Object?> json) {
    final error = _readMap(json['error']);
    return ContentStatus(
      ok: _readBool(json['ok']) ?? _readBool(json['available']) ?? _readBool(json['ready']) ?? false,
      contentMode: _readString(json['contentMode'] ?? json['content_mode'] ?? json['mode']),
      catalogLoaded: _readBool(json['catalogLoaded'] ?? json['catalog_loaded']) ?? false,
      trackCount: _readInt(json['trackCount'] ?? json['track_count'] ?? json['tracks']) ?? 0,
      assetCount: _readInt(json['assetCount'] ?? json['asset_count']) ?? 0,
      localFolderCatalogEnabled: _readBool(json['localFolderCatalogEnabled'] ?? json['local_folder_catalog_enabled']) ?? false,
      productionSafeTrackCount: _readInt(json['productionSafeTrackCount'] ?? json['production_safe_track_count']) ?? 0,
      serverVersion: _readString(json['serverVersion'] ?? json['server_version']),
      errorMessage: _readString(error?['message']) ?? _readString(error?['error']) ?? _readString(json['message'] ?? json['status']),
    );
  }

  String get friendlyLabel {
    if (!ok || !catalogLoaded) return 'Catalog unavailable';
    return switch (contentMode) {
      'demo' => 'Demo catalog',
      'production' => 'Catalog ready',
      'dev' => localFolderCatalogEnabled ? 'Catalog ready (dev)' : 'Catalog ready',
      _ => 'Catalog ready',
    };
  }

  String get developerSummary {
    final mode = contentMode ?? 'unknown';
    final error = errorMessage;
    final base = '$friendlyLabel • mode $mode • $trackCount tracks • $assetCount assets • $productionSafeTrackCount production-safe';
    return error == null || error.isEmpty ? base : '$base • $error';
  }
}

enum LicenseStatus { verified, attributionRequired, publicDomain, devOnly, userDevice, licensePending, unknown }

class LicenseMetadata {
  const LicenseMetadata({
    this.status = LicenseStatus.unknown,
    this.licenseName,
    this.licenseUrl,
    this.sourceName,
    this.sourceUrl,
    this.artistUrl,
    this.attributionText,
    this.attributionRequired = false,
    this.commercialUseAllowed = false,
    this.redistributionAllowed = false,
    this.derivativesAllowed = false,
    this.usageNotes,
  });

  final LicenseStatus status;
  final String? licenseName;
  final String? licenseUrl;
  final String? sourceName;
  final String? sourceUrl;
  final String? artistUrl;
  final String? attributionText;
  final bool attributionRequired;
  final bool commercialUseAllowed;
  final bool redistributionAllowed;
  final bool derivativesAllowed;
  final String? usageNotes;

  static const unknown = LicenseMetadata();
  static const userDevice = LicenseMetadata(status: LicenseStatus.userDevice, sourceName: 'Device Music', usageNotes: 'User device music. WaveZero does not claim catalog rights for this file.');
  static const devOnly = LicenseMetadata(status: LicenseStatus.devOnly, sourceName: 'Local Dev Audio', usageNotes: 'Local development audio only. Do not ship as production catalog unless rights are verified.');

  factory LicenseMetadata.fromJson(Map<String, Object?> json, {LicenseStatus fallbackStatus = LicenseStatus.unknown}) {
    return LicenseMetadata(
      status: _readLicenseStatus(json['licenseStatus'] ?? json['license_status']) ?? fallbackStatus,
      licenseName: _readString(json['licenseName'] ?? json['license_name']),
      licenseUrl: _readString(json['licenseUrl'] ?? json['license_url']),
      sourceName: _readString(json['sourceName'] ?? json['source_name']),
      sourceUrl: _readString(json['sourceUrl'] ?? json['source_url']),
      artistUrl: _readString(json['artistUrl'] ?? json['artist_url']),
      attributionText: _readString(json['attributionText'] ?? json['attribution_text']),
      attributionRequired: _readBool(json['attributionRequired'] ?? json['attribution_required']) ?? false,
      commercialUseAllowed: _readBool(json['commercialUseAllowed'] ?? json['commercial_use_allowed']) ?? false,
      redistributionAllowed: _readBool(json['redistributionAllowed'] ?? json['redistribution_allowed']) ?? false,
      derivativesAllowed: _readBool(json['derivativesAllowed'] ?? json['derivatives_allowed']) ?? false,
      usageNotes: _readString(json['usageNotes'] ?? json['usage_notes']),
    );
  }

  Map<String, Object?> toJson() => {
        'licenseStatus': status.wireName,
        'licenseName': licenseName,
        'licenseUrl': licenseUrl,
        'sourceName': sourceName,
        'sourceUrl': sourceUrl,
        'artistUrl': artistUrl,
        'attributionText': attributionText,
        'attributionRequired': attributionRequired,
        'commercialUseAllowed': commercialUseAllowed,
        'redistributionAllowed': redistributionAllowed,
        'derivativesAllowed': derivativesAllowed,
        'usageNotes': usageNotes,
      };

  String get badgeLabel => status.label;
  bool get needsRightsWarning => status == LicenseStatus.devOnly || status == LicenseStatus.licensePending || status == LicenseStatus.unknown;
}

extension LicenseStatusLabels on LicenseStatus {
  String get wireName => switch (this) {
        LicenseStatus.verified => 'verified',
        LicenseStatus.attributionRequired => 'attribution_required',
        LicenseStatus.publicDomain => 'public_domain',
        LicenseStatus.devOnly => 'dev_only',
        LicenseStatus.userDevice => 'user_device',
        LicenseStatus.licensePending => 'license_pending',
        LicenseStatus.unknown => 'unknown',
      };

  String get label => switch (this) {
        LicenseStatus.verified => 'Verified',
        LicenseStatus.attributionRequired => 'Attribution required',
        LicenseStatus.publicDomain => 'Public domain',
        LicenseStatus.devOnly => 'Dev only',
        LicenseStatus.userDevice => 'Device music',
        LicenseStatus.licensePending => 'License pending',
        LicenseStatus.unknown => 'Unknown',
      };
}

class CatalogTrackSummary {
  const CatalogTrackSummary({
    required this.trackId,
    required this.title,
    this.artistId,
    this.artistName,
    this.durationMs,
    this.artworkUrl,
    this.albumName,
    this.displayName,
    this.source = 'api',
    this.productionSafe = false,
    this.license = LicenseMetadata.unknown,
    this.primaryAsset,
    this.assets = const [],
  });

  final String trackId;
  final String title;
  final String? artistId;
  final String? artistName;
  final int? durationMs;
  final String? artworkUrl;
  final String? albumName;
  final String? displayName;
  final String source;
  final bool productionSafe;
  final LicenseMetadata license;
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
      albumName: _readString(json['album_name']),
      displayName: _readString(json['display_name']),
      source: _readString(json['source']) ?? _readString(json['source_type']) ?? 'api',
      productionSafe: _readBool(json['production_safe']) ?? _readBool(json['productionSafe']) ?? false,
      license: LicenseMetadata.fromJson(json, fallbackStatus: _readString(json['source']) == 'device' ? LicenseStatus.userDevice : LicenseStatus.unknown),
      primaryAsset: primaryAsset,
      assets: assets.isEmpty && primaryAsset != null ? [primaryAsset] : assets,
    );
  }

  String get subtitle {
    final artist = artistName;
    if (artist != null && artist.trim().isNotEmpty) return artist;
    final album = albumName;
    if (album != null && album.trim().isNotEmpty) return album;
    return source == 'device' ? 'Device music' : 'WaveZero catalog track';
  }

  bool matchesQuery(String query) {
    final normalizedQuery = _normalizeSearch(query);
    if (normalizedQuery.isEmpty) return true;

    final searchableText = _normalizeSearch([
      title,
      subtitle,
      trackId,
      artistId ?? '',
      albumName ?? '',
      displayName ?? '',
      source,
      primaryAsset?.codec ?? '',
      primaryAsset?.qualityLabel ?? '',
      license.badgeLabel,
      license.sourceName ?? '',
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
    this.license = LicenseMetadata.unknown,
  });

  final String assetId;
  final String manifestUrl;
  final String? qualityLabel;
  final String? codec;
  final int? bitrateKbps;
  final int? sampleRateHz;
  final int? bitDepth;
  final int? fileSizeBytes;
  final LicenseMetadata license;

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
    this.license = LicenseMetadata.unknown,
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
  final LicenseMetadata license;

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
      license: track == null ? LicenseMetadata.unknown : LicenseMetadata.fromJson(track),
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

bool? _readBool(Object? value) {
  if (value is bool) return value;
  return null;
}

LicenseStatus? _readLicenseStatus(Object? value) {
  final normalized = _readString(value)?.trim().toLowerCase().replaceAll('-', '_');
  return switch (normalized) {
    'verified' => LicenseStatus.verified,
    'attribution_required' => LicenseStatus.attributionRequired,
    'public_domain' => LicenseStatus.publicDomain,
    'dev_only' => LicenseStatus.devOnly,
    'user_device' => LicenseStatus.userDevice,
    'license_pending' => LicenseStatus.licensePending,
    'unknown' => LicenseStatus.unknown,
    _ => null,
  };
}

String _normalizeSearch(String value) => value.trim().toLowerCase();
