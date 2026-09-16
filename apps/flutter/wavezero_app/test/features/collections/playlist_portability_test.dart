import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';
import 'package:wavezero_app/features/collections/playlist_portability.dart';

void main() {
  CatalogTrackSummary track({
    required String id,
    required String title,
    required String artist,
    required String url,
    String? displayName,
  }) =>
      CatalogTrackSummary(
        trackId: id,
        title: title,
        artistName: artist,
        displayName: displayName,
        source: 'device',
        primaryAsset: CatalogTrackAssetSummary(
          assetId: 'asset-$id',
          manifestUrl: url,
          qualityLabel: 'Local',
        ),
      );

  WzCollectionTrackSnapshot snapshot({
    required String id,
    required String title,
    required String artist,
    required String url,
  }) =>
      WzCollectionTrackSnapshot(
        trackId: id,
        title: title,
        subtitle: artist,
        source: WzCollectionTrackSource.device,
        primaryUrl: url,
        addedAtMs: 1,
      );

  test('parser reads EXTINF metadata and WaveZero stable ids', () {
    final entries = wzParseM3u('''#EXTM3U
#WZ-TRACK-ID:device-audio-7
#EXTINF:183,Artist Name - Song Name
content://media/external/audio/media/7
#EXTINF:-1,Loose Song
/storage/emulated/0/Music/Loose Song.mp3
''');

    expect(entries, hasLength(2));
    expect(entries.first.trackId, 'device-audio-7');
    expect(entries.first.artist, 'Artist Name');
    expect(entries.first.title, 'Song Name');
    expect(entries.first.durationSeconds, 183);
    expect(entries.last.title, 'Loose Song');
  });

  test('serializer keeps order, metadata, stable ids, and playable locations', () {
    final collection = WzCollection(
      id: 'c1',
      name: 'Night Drive',
      type: WzCollectionType.user,
      createdAtMs: 1,
      updatedAtMs: 1,
      tracks: [
        snapshot(id: 'a', title: 'First', artist: 'One', url: 'content://music/1'),
        snapshot(id: 'b', title: 'Second', artist: 'Two', url: 'content://music/2'),
      ],
    );

    final encoded = wzSerializeM3u(collection);
    final parsed = wzParseM3u(encoded);

    expect(encoded.startsWith('#EXTM3U'), isTrue);
    expect(parsed.map((entry) => entry.trackId), ['a', 'b']);
    expect(parsed.map((entry) => entry.location), ['content://music/1', 'content://music/2']);
    expect(parsed.map((entry) => entry.title), ['First', 'Second']);
  });

  test('resolver prefers stable id then URI, filename, and unique metadata', () {
    final library = [
      track(
        id: 'a',
        title: 'Exact Id',
        artist: 'Artist A',
        url: 'content://music/1',
        displayName: 'exact-id.mp3',
      ),
      track(
        id: 'b',
        title: 'By File',
        artist: 'Artist B',
        url: 'content://music/2',
        displayName: 'my-song.mp3',
      ),
      track(
        id: 'c',
        title: 'Metadata Song',
        artist: 'Artist C',
        url: 'content://music/3',
      ),
    ];

    final resolution = wzResolveM3uEntries(
      entries: const [
        WzM3uEntry(location: 'irrelevant', trackId: 'a'),
        WzM3uEntry(location: '/Music/my-song.mp3'),
        WzM3uEntry(location: '/unknown/path', title: 'Metadata Song', artist: 'Artist C'),
        WzM3uEntry(location: '/missing.mp3', title: 'Missing'),
      ],
      libraryTracks: library,
    );

    expect(resolution.matched.map((track) => track.trackId), ['a', 'b', 'c']);
    expect(resolution.unmatched, hasLength(1));
  });

  test('resolver handles Windows-style M3U paths by filename', () {
    final library = [
      track(
        id: 'win',
        title: 'Windows Song',
        artist: 'Artist',
        url: 'content://music/9',
        displayName: 'windows-song.flac',
      ),
    ];
    final resolution = wzResolveM3uEntries(
      entries: const [WzM3uEntry(location: r'C:\Users\Omar\Music\windows-song.flac')],
      libraryTracks: library,
    );
    expect(resolution.matched.single.trackId, 'win');
  });

  test('resolver deduplicates repeated entries by resolved track identity', () {
    final library = [
      track(id: 'a', title: 'Song', artist: 'Artist', url: 'content://music/1'),
    ];
    final resolution = wzResolveM3uEntries(
      entries: const [
        WzM3uEntry(location: 'content://music/1'),
        WzM3uEntry(location: 'content://music/1'),
      ],
      libraryTracks: library,
    );
    expect(resolution.matched, hasLength(1));
    expect(resolution.unmatched, isEmpty);
  });

  test('playlist filenames are filesystem-safe and imported names are readable', () {
    expect(wzPlaylistFileName('Mix: Night / 01'), 'Mix Night 01.m3u');
    expect(wzPlaylistNameFromFile('road_trip-2026.m3u8'), 'road trip 2026');
  });
}
