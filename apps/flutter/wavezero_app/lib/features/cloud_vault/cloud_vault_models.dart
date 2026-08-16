import 'dart:convert';

import '../../catalog/catalog_track_manifest.dart';

enum CloudVaultProvider {
  googleDrive,
  dropbox,
  onedrive,
  nextcloud,
  manualUrl,
  unknown,
}

extension CloudVaultProviderWire on CloudVaultProvider {
  String get wireName => switch (this) {
        CloudVaultProvider.googleDrive => 'google_drive',
        CloudVaultProvider.dropbox => 'dropbox',
        CloudVaultProvider.onedrive => 'onedrive',
        CloudVaultProvider.nextcloud => 'nextcloud',
        CloudVaultProvider.manualUrl => 'manual_url',
        CloudVaultProvider.unknown => 'unknown',
      };

  String get label => switch (this) {
        CloudVaultProvider.googleDrive => 'Google Drive',
        CloudVaultProvider.dropbox => 'Dropbox',
        CloudVaultProvider.onedrive => 'OneDrive',
        CloudVaultProvider.nextcloud => 'Nextcloud',
        CloudVaultProvider.manualUrl => 'Manual private URL',
        CloudVaultProvider.unknown => 'Unknown provider',
      };

  static CloudVaultProvider fromWireName(Object? value) {
    final normalized = value is String ? value.trim().toLowerCase() : '';
    return CloudVaultProvider.values.firstWhere(
      (provider) => provider.wireName == normalized,
      orElse: () => CloudVaultProvider.unknown,
    );
  }
}

class CloudVaultTrack {
  const CloudVaultTrack({
    required this.cloudTrackId,
    required this.title,
    this.artistName,
    this.albumName,
    this.durationMs,
    this.artworkUrl,
    required this.provider,
    this.providerFileId,
    this.sourceUri,
    this.playableUri,
    this.mimeType,
    this.fileSizeBytes,
    required this.importedAtMs,
    this.lastPlayedAtMs,
    this.isAvailable = false,
    this.isLocalOnly = true,
    this.isPrivate = true,
    this.userOwned = true,
  });

  final String cloudTrackId;
  final String title;
  final String? artistName;
  final String? albumName;
  final int? durationMs;
  final String? artworkUrl;
  final CloudVaultProvider provider;
  final String? providerFileId;
  final String? sourceUri;
  final String? playableUri;
  final String? mimeType;
  final int? fileSizeBytes;
  final int importedAtMs;
  final int? lastPlayedAtMs;
  final bool isAvailable;
  final bool isLocalOnly;
  final bool isPrivate;
  final bool userOwned;

  bool get isResolvable => isAvailable && (playableUri?.trim().isNotEmpty ?? false);

  String get subtitle {
    final artist = artistName?.trim();
    if (artist != null && artist.isNotEmpty) return artist;
    final album = albumName?.trim();
    if (album != null && album.isNotEmpty) return album;
    return provider.label;
  }

  CloudVaultTrack copyWith({
    String? cloudTrackId,
    String? title,
    String? artistName,
    String? albumName,
    int? durationMs,
    String? artworkUrl,
    CloudVaultProvider? provider,
    String? providerFileId,
    String? sourceUri,
    String? playableUri,
    String? mimeType,
    int? fileSizeBytes,
    int? importedAtMs,
    int? lastPlayedAtMs,
    bool? isAvailable,
    bool? isLocalOnly,
    bool? isPrivate,
    bool? userOwned,
  }) {
    return CloudVaultTrack(
      cloudTrackId: cloudTrackId ?? this.cloudTrackId,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      albumName: albumName ?? this.albumName,
      durationMs: durationMs ?? this.durationMs,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      provider: provider ?? this.provider,
      providerFileId: providerFileId ?? this.providerFileId,
      sourceUri: sourceUri ?? this.sourceUri,
      playableUri: playableUri ?? this.playableUri,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      importedAtMs: importedAtMs ?? this.importedAtMs,
      lastPlayedAtMs: lastPlayedAtMs ?? this.lastPlayedAtMs,
      isAvailable: isAvailable ?? this.isAvailable,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
      isPrivate: isPrivate ?? this.isPrivate,
      userOwned: userOwned ?? this.userOwned,
    );
  }

  CatalogTrackSummary toCatalogSummary() {
    final playable = playableUri?.trim();
    return CatalogTrackSummary(
      trackId: cloudTrackId,
      title: title,
      artistName: artistName,
      albumName: albumName,
      durationMs: durationMs,
      artworkUrl: artworkUrl,
      source: 'cloud_vault',
      license: const LicenseMetadata(
        status: LicenseStatus.userDevice,
        sourceName: 'Cloud Vault',
        usageNotes: 'User-owned private cloud music. WaveZero does not claim catalog rights or support redistribution.',
      ),
      primaryAsset: playable == null || playable.isEmpty
          ? null
          : CatalogTrackAssetSummary(
              assetId: 'cloud-vault-$cloudTrackId',
              manifestUrl: playable,
              qualityLabel: 'Cloud',
              codec: mimeType,
              fileSizeBytes: fileSizeBytes,
            ),
    );
  }

  Map<String, Object?> toJson() => {
        'cloudTrackId': cloudTrackId,
        'title': title,
        'artistName': artistName,
        'albumName': albumName,
        'durationMs': durationMs,
        'artworkUrl': artworkUrl,
        'provider': provider.wireName,
        'providerFileId': providerFileId,
        'sourceUri': sourceUri,
        'playableUri': playableUri,
        'mimeType': mimeType,
        'fileSizeBytes': fileSizeBytes,
        'importedAtMs': importedAtMs,
        'lastPlayedAtMs': lastPlayedAtMs,
        'isAvailable': isAvailable,
        'isLocalOnly': isLocalOnly,
        'isPrivate': isPrivate,
        'userOwned': userOwned,
      };

  factory CloudVaultTrack.fromJson(Map<String, Object?> json) {
    final id = _readString(json['cloudTrackId'] ?? json['cloud_track_id']);
    final title = _readString(json['title']);
    if (id == null || id.isEmpty) throw const FormatException('Cloud Vault track is missing cloudTrackId');
    if (title == null || title.isEmpty) throw const FormatException('Cloud Vault track is missing title');
    return CloudVaultTrack(
      cloudTrackId: id,
      title: title,
      artistName: _readString(json['artistName'] ?? json['artist_name']),
      albumName: _readString(json['albumName'] ?? json['album_name']),
      durationMs: _readInt(json['durationMs'] ?? json['duration_ms']),
      artworkUrl: _readString(json['artworkUrl'] ?? json['artwork_url']),
      provider: CloudVaultProviderWire.fromWireName(json['provider']),
      providerFileId: _readString(json['providerFileId'] ?? json['provider_file_id']),
      sourceUri: _readString(json['sourceUri'] ?? json['source_uri']),
      playableUri: _readString(json['playableUri'] ?? json['playable_uri']),
      mimeType: _readString(json['mimeType'] ?? json['mime_type']),
      fileSizeBytes: _readInt(json['fileSizeBytes'] ?? json['file_size_bytes']),
      importedAtMs: _readInt(json['importedAtMs'] ?? json['imported_at_ms']) ?? DateTime.now().millisecondsSinceEpoch,
      lastPlayedAtMs: _readInt(json['lastPlayedAtMs'] ?? json['last_played_at_ms']),
      isAvailable: _readBool(json['isAvailable'] ?? json['is_available']) ?? false,
      isLocalOnly: _readBool(json['isLocalOnly'] ?? json['is_local_only']) ?? true,
      isPrivate: _readBool(json['isPrivate'] ?? json['is_private']) ?? true,
      userOwned: _readBool(json['userOwned'] ?? json['user_owned']) ?? true,
    );
  }

  static CloudVaultTrack? tryDecode(Object? value) {
    try {
      final map = value is Map<String, Object?> ? value : value is Map ? value.cast<String, Object?>() : null;
      return map == null ? null : CloudVaultTrack.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

String encodeCloudVaultTracks(List<CloudVaultTrack> tracks) => jsonEncode(tracks.map((track) => track.toJson()).toList(growable: false));

List<CloudVaultTrack> decodeCloudVaultTracks(String rawJson) {
  final decoded = jsonDecode(rawJson);
  if (decoded is! List) throw const FormatException('Cloud Vault payload is not a list');
  return decoded.map(CloudVaultTrack.tryDecode).whereType<CloudVaultTrack>().toList(growable: false);
}

String? _readString(Object? value) => value is String ? value : null;

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

bool? _readBool(Object? value) => value is bool ? value : null;
