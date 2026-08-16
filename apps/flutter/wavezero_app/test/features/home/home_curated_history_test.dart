import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/home/home_sections.dart';

void main() {
  testWidgets('empty curated Home section keeps WaveZero Picks fallback', (tester) async {
    var openedLibrary = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzHomeCuratedDemoSection(
            shelves: const [],
            onPlayPick: (_) {},
            onAddToQueue: (_) {},
            onOpenLibrary: () => openedLibrary = true,
          ),
        ),
      ),
    );

    expect(find.text('WaveZero Picks'), findsOneWidget);
    expect(find.text('Curated picks will appear when the demo catalog is loaded.'), findsNWidgets(2));

    await tester.tap(find.text('Open Library'));
    expect(openedLibrary, isTrue);
  });

  testWidgets('empty Home history keeps local-only listening copy', (tester) async {
    var viewedAll = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzHomeHistorySection(
            entries: const [],
            continueEntry: null,
            mostPlayedEntry: null,
            resolver: (_) => null,
            onPlay: (_) {},
            onAddToQueue: (_) {},
            onAddToCollection: (_) {},
            onRemove: (_) {},
            onViewAll: () => viewedAll = true,
          ),
        ),
      ),
    );

    expect(find.text('Continue Listening'), findsOneWidget);
    expect(find.text('Listening history stays on this device.'), findsOneWidget);
    expect(find.text('No listening history yet. Play a track from Library, Search, or Downloads to continue here.'), findsOneWidget);

    await tester.tap(find.text('View all'));
    expect(viewedAll, isTrue);
  });
}
