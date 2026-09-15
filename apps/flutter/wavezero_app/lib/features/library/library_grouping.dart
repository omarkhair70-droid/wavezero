import '../../catalog/catalog_track_manifest.dart';

enum WzLibraryGroupKind { artist, album }

class WzLibraryGroup {
  const WzLibraryGroup({
    required this.kind,
    required this.key,
    required this.title,
    required this.tracks,
    this.subtitle,
    this.artworkUrl,
  });

  final WzLibraryGroupKind kind;
  final String key;
  final String title;
  final String? subtitle;
  final String? artworkUrl;
  final List<CatalogTrackSummary> tracks;

  int get trackCount => tracks.length;
}

List<WzLibraryGroup> buildWzArtistGroups(
  List<CatalogTrackSummary> tracks,
) {
  final buckets = <String, _MutableLibraryGroup>{};
  for (final track in tracks) {
    final artist = _cleanLabel(track.artistName);
    if (artist == null) continue;
    final key = _normalizeLabel(artist);
    final bucket = buckets.putIfAbsent(
      key,
      () => _MutableLibraryGroup(title: artist),
    );
    bucket.tracks.add(track);
    bucket.artworkUrl ??= _cleanLabel(track.artworkUrl);
  }

  return _finalizeGroups(
    buckets,
    WzLibraryGroupKind.artist,
    subtitleFor: (bucket) => _trackCountLabel(bucket.tracks.length),
  );
}

List<WzLibraryGroup> buildWzAlbumGroups(
  List<CatalogTrackSummary> tracks,
) {
  final buckets = <String, _MutableLibraryGroup>{};
  for (final track in tracks) {
    final album = _cleanLabel(track.albumName);
    if (album == null) continue;
    final artist = _cleanLabel(track.artistName);
    final artistKey = artist == null ? '' : _normalizeLabel(artist);
    final key = '${_normalizeLabel(album)}::$artistKey';
    final bucket = buckets.putIfAbsent(
      key,
      () => _MutableLibraryGroup(title: album, artist: artist),
    );
    bucket.tracks.add(track);
    bucket.artworkUrl ??= _cleanLabel(track.artworkUrl);
    bucket.artist ??= artist;
  }

  return _finalizeGroups(
    buckets,
    WzLibraryGroupKind.album,
    subtitleFor: (bucket) {
      final count = _trackCountLabel(bucket.tracks.length);
      final artist = bucket.artist;
      return artist == null ? count : '$artist • $count';
    },
  );
}

List<WzLibraryGroup> _finalizeGroups(
  Map<String, _MutableLibraryGroup> buckets,
  WzLibraryGroupKind kind, {
  required String Function(_MutableLibraryGroup bucket) subtitleFor,
}) {
  final groups = buckets.entries
      .map(
        (entry) => WzLibraryGroup(
          kind: kind,
          key: entry.key,
          title: entry.value.title,
          subtitle: subtitleFor(entry.value),
          artworkUrl: entry.value.artworkUrl,
          tracks: List<CatalogTrackSummary>.unmodifiable(entry.value.tracks),
        ),
      )
      .toList(growable: false);

  groups.sort((left, right) {
    final byCount = right.trackCount.compareTo(left.trackCount);
    if (byCount != 0) return byCount;
    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  });
  return List<WzLibraryGroup>.unmodifiable(groups);
}

String _trackCountLabel(int count) => count == 1 ? '1 track' : '$count tracks';

String? _cleanLabel(String? value) {
  final cleaned = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}

String _normalizeLabel(String value) => _cleanLabel(value)!.toLowerCase();

class _MutableLibraryGroup {
  _MutableLibraryGroup({required this.title, this.artist});

  final String title;
  String? artist;
  String? artworkUrl;
  final List<CatalogTrackSummary> tracks = <CatalogTrackSummary>[];
}
