import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/features/lyrics/local_lyrics_panel.dart';
import 'package:wavezero_app/features/lyrics/lyrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('local lyrics follow stable track identity when Now Playing changes', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final service = WzLyricsService(prefs: prefs);
    await service.save(trackId: 'track-one', rawText: 'Only for track one');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzLocalLyricsPanel(
            trackId: 'track-one',
            trackTitle: 'One',
            positionMs: 0,
            hasTrack: true,
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Only for track one'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzLocalLyricsPanel(
            trackId: 'track-two',
            trackTitle: 'Two',
            positionMs: 0,
            hasTrack: true,
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Only for track one'), findsNothing);
    expect(find.text('No lyrics saved yet'), findsOneWidget);
  });
}
