import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/catalog/audio_quality.dart';
import 'package:wavezero_app/features/settings/consumer_settings_page.dart';

void main() {
  testWidgets('consumer settings only exposes product-level choices', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzConsumerSettingsPage(
            onBack: () {},
            preferredAudioQuality: AudioQualityTier.high,
            onQualityChanged: (_) {},
            smartDownloadsEnabled: true,
            onSmartDownloadsChanged: (_) {},
            cachedTrackCount: 2,
            cacheBytes: 2048,
            controlsDisabled: false,
            onClearCache: () async {},
            onManageStorage: () {},
            onClearRecentSearches: () {},
            onClearListeningHistory: () {},
            legalTracks: const [],
          ),
        ),
      ),
    );

    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Downloads & storage'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Storage'), findsOneWidget);
    expect(find.text('Licenses & sources'), findsOneWidget);

    expect(find.text('Search & Discovery'), findsNothing);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Shuffle'), findsNothing);
    expect(find.text('Repeat mode'), findsNothing);
    expect(find.textContaining('Cloud Vault'), findsNothing);
    expect(find.textContaining('Developer'), findsNothing);
    expect(find.text('Device music'), findsNothing);
  });
}
