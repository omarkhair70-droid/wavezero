import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/shared/widgets/wavezero_artwork.dart';

void main() {
  testWidgets('generated cover uses abstract WaveZero identity without legacy text marks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          height: 120,
          child: WzWaveZeroCoverArt(
            trackId: 'track-1',
            title: 'Moon',
            artist: 'Light',
            size: 120,
          ),
        ),
      ),
    );

    expect(find.text('WZ'), findsNothing);
    expect(find.text('ML'), findsNothing);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
  });

  testWidgets('artwork without a URL uses the generated cover fallback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WzArtwork(
          trackId: 'track-2',
          title: 'Quiet',
          artist: 'Room',
          size: 48,
        ),
      ),
    );

    expect(find.byType(WzWaveZeroCoverArt), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    expect(find.text('QR'), findsNothing);
  });
}
