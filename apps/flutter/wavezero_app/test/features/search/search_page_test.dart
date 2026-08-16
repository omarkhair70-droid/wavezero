import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/search/search_controls.dart';
import 'package:wavezero_app/features/search/search_page.dart';

void main() {
  testWidgets('empty Search page keeps filters and discovery shell', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: WzSearchPage(
          controller: controller,
          onBack: () {},
          filter: WzSearchFilter.all,
          results: const [],
          recentSearches: const [],
          history: const [],
          cachedTracks: const [],
          collections: const [],
          catalogTracks: const [],
          onQueryChanged: (_) {},
          onSubmitted: (_) {},
          onFilterChanged: (_) {},
          onRecent: (_) {},
          onClearRecent: () {},
          onPlayResult: (_) {},
          onAddResultToQueue: (_) {},
          onAddResultToCollection: (_) {},
          onOpenCollectionResult: (_) {},
          onDiscoveryTrack: (_) {},
          onDiscoveryCollection: (_) {},
        ),
      ),
    );
    expect(find.text('Search'), findsWidgets);
    expect(find.text('All'), findsWidgets);
  });
}
