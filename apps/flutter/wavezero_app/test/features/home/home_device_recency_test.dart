import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/device_music/device_music_track.dart';
import 'package:wavezero_app/features/home/home_device_recency.dart';

void main() {
  const track = DeviceMusicTrack(
    trackId: 'device-audio-7',
    title: 'Fresh song',
    artistName: 'Local artist',
    contentUri: 'content://media/7',
    dateAdded: 900,
  );

  testWidgets('fresh device shelf stays out of Home when there is no device music', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzHomeFreshDeviceSection(
            tracks: const [],
            onPlay: (_) {},
            onAddToQueue: (_) {},
            onOpenDeviceMusic: () {},
          ),
        ),
      ),
    );

    expect(find.text('Fresh on your device'), findsNothing);
  });

  testWidgets('fresh device shelf exposes play, queue, and see all actions', (tester) async {
    var played = false;
    var queued = false;
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzHomeFreshDeviceSection(
            tracks: const [track],
            onPlay: (_) => played = true,
            onAddToQueue: (_) => queued = true,
            onOpenDeviceMusic: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('Fresh on your device'), findsOneWidget);
    expect(find.text('Fresh song'), findsOneWidget);
    expect(find.text('Local artist'), findsOneWidget);

    await tester.tap(find.text('Fresh song'));
    expect(played, isTrue);

    await tester.tap(find.byTooltip('Add to Queue'));
    expect(queued, isTrue);

    await tester.tap(find.text('See all'));
    expect(opened, isTrue);
  });
}
