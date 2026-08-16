import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/audio/audio_effects.dart';
import 'package:wavezero_app/features/playback/playback_modes.dart';
import 'package:wavezero_app/features/playback/player_presentation.dart';
import 'package:wavezero_app/playback/playback_metrics.dart';

void main() {
  test('player source labels preserve consumer precedence', () {
    expect(
      wzPlayerSourceLabel(isPlayingFromCache: true, offlineReady: true, hasTrack: true),
      'Downloaded',
    );
    expect(
      wzPlayerSourceLabel(isPlayingFromCache: false, offlineReady: true, hasTrack: true),
      'Catalog',
    );
    expect(
      wzPlayerSourceLabel(isPlayingFromCache: false, offlineReady: true, hasTrack: false),
      'Offline Ready',
    );
    expect(
      wzPlayerSourceLabel(isPlayingFromCache: false, offlineReady: false, hasTrack: false),
      'Not cached',
    );
  });

  test('audio effect status labels preserve player copy', () {
    expect(wzEffectStatusLabel(NativeAudioEffectStatus.applied), 'Applied');
    expect(wzEffectStatusLabel(NativeAudioEffectStatus.unsupported), 'Unsupported');
    expect(wzEffectStatusLabel(NativeAudioEffectStatus.pending), 'Pending');
    expect(wzEffectStatusLabel(NativeAudioEffectStatus.failed), 'Failed');
    expect(wzEffectStatusLabel(NativeAudioEffectStatus.off), 'Off');
  });

  testWidgets('extracted mini-player keeps the paused empty state interactive', (tester) async {
    var opened = false;
    var played = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzPremiumMiniPlayer(
            metrics: const PlaybackMetrics(),
            manifest: null,
            progressValue: 0,
            sourceLabel: 'Not cached',
            offlineReady: false,
            shuffleEnabled: false,
            repeatMode: WzRepeatMode.off,
            sleepTimerBadge: null,
            controlsDisabled: false,
            onTap: () => opened = true,
            onPlayPause: () => played = true,
          ),
        ),
      ),
    );

    expect(find.text('Current track'), findsOneWidget);
    expect(find.text('Paused in WaveZero'), findsOneWidget);
    expect(find.text('Not cached'), findsOneWidget);

    await tester.tap(find.byTooltip('Play'));
    expect(played, isTrue);

    await tester.tap(find.text('Current track'));
    expect(opened, isTrue);
  });
}
