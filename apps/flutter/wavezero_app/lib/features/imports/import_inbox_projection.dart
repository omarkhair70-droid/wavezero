import '../../catalog/catalog_track_manifest.dart';
import '../device_music/device_music_projection.dart';
import '../device_music/device_music_track.dart';
import 'import_inbox_service.dart';

DeviceMusicTrack? wzDeviceTrackFromInboxEntry(WzImportInboxEntry entry) {
  if (!entry.hasResolvableDeviceTrack) return null;
  final contentUri = entry.value.trim();
  if (!contentUri.startsWith('content://')) return null;

  return DeviceMusicTrack(
    trackId: entry.trackId!,
    title: _titleFromDisplayName(entry.title),
    displayName: entry.title,
    mimeType: entry.mimeType,
    contentUri: contentUri,
    codec: _codecFromMime(entry.mimeType),
    source: 'device',
  );
}

CatalogTrackSummary? wzCatalogTrackFromInboxEntry(WzImportInboxEntry entry) {
  final deviceTrack = wzDeviceTrackFromInboxEntry(entry);
  return deviceTrack == null ? null : wzCatalogSummaryFromDeviceTrack(deviceTrack);
}

String _titleFromDisplayName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Imported track';
  final dot = trimmed.lastIndexOf('.');
  if (dot <= 0 || dot == trimmed.length - 1) return trimmed;
  final extension = trimmed.substring(dot + 1).toLowerCase();
  const audioExtensions = <String>{'mp3', 'm4a', 'aac', 'flac', 'wav', 'ogg', 'opus'};
  return audioExtensions.contains(extension) ? trimmed.substring(0, dot) : trimmed;
}

String? _codecFromMime(String? mimeType) => switch (mimeType?.toLowerCase()) {
      'audio/mpeg' || 'audio/mp3' => 'mp3',
      'audio/mp4' || 'audio/x-m4a' => 'm4a',
      'audio/aac' => 'aac',
      'audio/flac' || 'audio/x-flac' => 'flac',
      'audio/wav' || 'audio/x-wav' => 'wav',
      'audio/ogg' => 'ogg',
      'audio/opus' => 'opus',
      _ => null,
    };
