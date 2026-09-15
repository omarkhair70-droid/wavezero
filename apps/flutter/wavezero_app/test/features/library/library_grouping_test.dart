import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/library/library_grouping.dart';

void main() {
  CatalogTrackSummary track(
    String id,
    String title, {
    String? artist,
    String? album,
    String? artwork,
  }) => CatalogTrackSummary(
    trackId: id,
    title: title,
    artistName: artist,
    albumName: album,
    artworkUrl: artwork,
  );

  test('artist grouping normalizes case and whitespace but preserves display label', () {
    final groups = buildWzArtistGroups([
      track('1', 'One', artist: 'Marwan  Moussa'),
      track('2', 'Two', artist: '  marwan moussa '),
      track('3', 'Three'),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single.title, 'Marwan Moussa');
    expect(groups.single.trackCount, 2);
    expect(groups.single.tracks.map((item) => item.trackId), ['1', '2']);
  });

  test('album grouping keeps same album title separate across artists', () {
    final groups = buildWzAlbumGroups([
      track('1', 'One', artist: 'Artist A', album: 'Home'),
      track('2', 'Two', artist: 'Artist B', album: 'Home'),
      track('3', 'Three', artist: 'Artist A', album: 'Home'),
    ]);

    expect(groups, hasLength(2));
    expect(groups.first.title, 'Home');
    expect(groups.first.subtitle, 'Artist A • 2 tracks');
    expect(groups.first.tracks.map((item) => item.trackId), ['1', '3']);
    expect(groups.last.subtitle, 'Artist B • 1 track');
  });

  test('groups prefer populated groups then stable alphabetical names', () {
    final groups = buildWzArtistGroups([
      track('1', 'One', artist: 'Zulu'),
      track('2', 'Two', artist: 'Alpha'),
      track('3', 'Three', artist: 'Beta'),
      track('4', 'Four', artist: 'Beta'),
    ]);

    expect(groups.map((group) => group.title).toList(), ['Beta', 'Alpha', 'Zulu']);
  });

  test('group cover uses the first available artwork without reordering tracks', () {
    final groups = buildWzAlbumGroups([
      track('1', 'One', artist: 'A', album: 'Record'),
      track('2', 'Two', artist: 'A', album: 'Record', artwork: 'cover.jpg'),
    ]);

    expect(groups.single.artworkUrl, 'cover.jpg');
    expect(groups.single.tracks.map((item) => item.trackId), ['1', '2']);
  });
}
