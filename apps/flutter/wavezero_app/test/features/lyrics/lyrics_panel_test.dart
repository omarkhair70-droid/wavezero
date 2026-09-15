import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/lyrics/lyrics_models.dart';
import 'package:wavezero_app/features/lyrics/lyrics_panel.dart';

void main() {
  testWidgets('empty lyrics offers a local add action for a playing track', (
    tester,
  ) async {
    var edited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzLyricsPanel(
            document: null,
            positionMs: 0,
            hasTrack: true,
            onEdit: () => edited = true,
          ),
        ),
      ),
    );

    expect(find.text('No lyrics saved yet'), findsOneWidget);
    await tester.tap(find.text('Add lyrics'));
    expect(edited, isTrue);
  });

  testWidgets('synced lyrics follow playback position', (tester) async {
    const document = WzLyricsDocument(
      trackId: 'track-a',
      rawText: '[00:01.00]First line\n[00:05.00]Second line\n[00:09.00]Third line',
      updatedAtMs: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WzLyricsPanel(
            document: document,
            positionMs: 6200,
            hasTrack: true,
            onEdit: null,
          ),
        ),
      ),
    );

    expect(find.text('Second line'), findsOneWidget);
    expect(find.textContaining('2/3'), findsOneWidget);
  });

  testWidgets('plain lyrics remain readable and selectable', (tester) async {
    const document = WzLyricsDocument(
      trackId: 'track-a',
      rawText: 'Line one\nLine two',
      updatedAtMs: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WzLyricsPanel(
            document: document,
            positionMs: 0,
            hasTrack: true,
            onEdit: null,
          ),
        ),
      ),
    );

    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.textContaining('Line one'), findsOneWidget);
  });
}
