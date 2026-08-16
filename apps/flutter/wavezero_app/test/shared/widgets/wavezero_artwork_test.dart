import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/shared/widgets/wavezero_artwork.dart';

void main() {
  testWidgets('generated cover keeps the WZ identity and supplied initials', (tester) async {
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
    expect(find.text('WZ'), findsOneWidget);
    expect(find.text('ML'), findsOneWidget);
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
    expect(find.text('QR'), findsOneWidget);
  });
}
