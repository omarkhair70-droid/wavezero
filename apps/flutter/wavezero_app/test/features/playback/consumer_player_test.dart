import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/playback/consumer_player.dart';
import 'package:wavezero_app/features/playback/playback_modes.dart';
import 'package:wavezero_app/playback/playback_metrics.dart';

void main() {
  testWidgets('consumer mini player opens and keeps play pause immediate', (tester) async {
    var opened = false;
    var toggled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzConsumerMiniPlayer(
            metrics: const PlaybackMetrics(trackTitle: 'Close voice', isPlaying: false),
            manifest: null,
            progressValue: .35,
            controlsDisabled: false,
            onTap: () => opened = true,
            onPlayPause: () => toggled = true,
          ),
        ),
      ),
    );

    expect(find.text('Close voice'), findsOneWidget);
    await tester.tap(find.byTooltip('Play'));
    expect(toggled, isTrue);

    await tester.tap(find.text('Close voice'));
    expect(opened, isTrue);
  });

  testWidgets('consumer player keeps like and queue interactions alive', (tester) async {
    var liked = false;
    var queueOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzConsumerPlayerSurface(
              metrics: const PlaybackMetrics(trackTitle: 'ولا عاش ولا كان', durationMs: 180000),
              manifest: null,
              nextTrack: null,
              progressValue: .25,
              displayedPositionMs: 45000,
              durationMs: 180000,
              controlsDisabled: false,
              canPlayPrevious: false,
              canPlayNext: false,
              onPlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeekChanged: (_) {},
              onSeekEnd: (_) {},
              canSaveTrack: true,
              liked: false,
              onToggleLike: () => liked = true,
              onAddToCollection: () {},
              onAddToQueue: () {},
              onOpenQueue: () => queueOpened = true,
              shuffleEnabled: false,
              repeatMode: WzRepeatMode.off,
              sleepTimerActive: false,
              onShuffleChanged: (_) {},
              onCycleRepeatMode: () {},
              onOpenSleepTimer: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('ولا عاش ولا كان'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    expect(liked, isTrue);

    final upNext = find.text('Up next');
    await tester.ensureVisible(upNext);
    await tester.pumpAndSettle();
    await tester.tap(upNext);
    expect(queueOpened, isTrue);
  });
}
