import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/playback/consumer_player.dart';
import 'package:wavezero_app/shared/widgets/wavezero_artwork.dart';

void main() {
  testWidgets('Now Playing collapses after a deliberate downward drag from content', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WzConsumerNowPlayingPage(
          onClose: () => closeCount += 1,
          surfaceBuilder: (_) => const SizedBox(
            height: 650,
            child: Center(child: Text('player surface')),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('player surface')));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(closeCount, 1);
  });

  testWidgets('short downward movement snaps back instead of closing', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WzConsumerNowPlayingPage(
          onClose: () => closeCount += 1,
          surfaceBuilder: (_) => const SizedBox(
            height: 650,
            child: Center(child: Text('player surface')),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('player surface')));
    await gesture.moveBy(const Offset(0, 38));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 220));

    expect(closeCount, 0);
    expect(find.text('Now Playing'), findsOneWidget);
  });

  testWidgets('generated artwork is light abstract identity art without legacy text marks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WzArtwork(
            size: 240,
            trackId: 'device-audio-42',
            title: 'Aloomek',
            artist: 'Marwan Moussa',
          ),
        ),
      ),
    );

    expect(find.text('WZ'), findsNothing);
    expect(find.text('AM'), findsNothing);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
  });
}
