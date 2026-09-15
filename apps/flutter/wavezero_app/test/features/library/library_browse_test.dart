import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/catalog_track_manifest.dart';
import 'package:wavezero_app/features/library/library_browse.dart';

void main() {
  CatalogTrackSummary track(
    String id,
    String title, {
    String? artist,
    String? album,
  }) => CatalogTrackSummary(
    trackId: id,
    title: title,
    artistName: artist,
    albumName: album,
  );

  Widget subject(List<CatalogTrackSummary> tracks) => MaterialApp(
        home: Scaffold(
          body: WzLibraryBrowseSection(
            tracks: tracks,
            selectedTrackId: null,
            addToQueueDisabled: false,
            onSelectTrack: (_) {},
            onAddToQueue: (_) {},
            onToggleLike: (_) {},
            onAddToCollection: (_) {},
            isLiked: (_) => false,
            onCache: (_) {},
            onDeleteCachedTrack: (_) {},
          ),
        ),
      );

  testWidgets('browser stays hidden when artist and album metadata are absent', (
    tester,
  ) async {
    await tester.pumpWidget(subject([track('1', 'Untitled')]));

    expect(find.text('Browse your library'), findsNothing);
  });

  testWidgets('browser switches between artists and albums', (tester) async {
    await tester.pumpWidget(
      subject([
        track('1', 'One', artist: 'Nour', album: 'Night'),
        track('2', 'Two', artist: 'Nour', album: 'Night'),
        track('3', 'Three', artist: 'Youssef', album: 'Morning'),
      ]),
    );

    expect(find.text('Browse your library'), findsOneWidget);
    expect(find.text('Artists 2'), findsOneWidget);
    expect(find.text('Albums 2'), findsOneWidget);
    expect(find.text('Nour'), findsOneWidget);

    await tester.tap(find.text('Albums 2'));
    await tester.pumpAndSettle();

    expect(find.text('Night'), findsOneWidget);
    expect(find.text('Nour • 2 tracks'), findsOneWidget);
  });

  testWidgets('tapping a group opens its real track list', (tester) async {
    await tester.pumpWidget(
      subject([
        track('1', 'Track One', artist: 'Nour', album: 'Night'),
        track('2', 'Track Two', artist: 'Nour', album: 'Night'),
      ]),
    );

    await tester.tap(find.text('Nour'));
    await tester.pumpAndSettle();

    expect(find.text('Artist'), findsOneWidget);
    expect(find.text('Track One'), findsOneWidget);
    expect(find.text('Track Two'), findsOneWidget);
  });
}
