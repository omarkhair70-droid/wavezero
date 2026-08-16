import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/collections/collections_pages.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';

void main() {
  testWidgets('Collections page keeps the Liked Tracks entry and create action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WzCollectionsPage(
          collections: [WzCollection.liked()],
          onBack: () {},
          onOpen: (_) {},
          onCreate: () {},
          onRename: (_, __) {},
          onDelete: (_) {},
        ),
      ),
    );
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Liked Tracks'), findsWidgets);
    expect(find.textContaining('Create'), findsWidgets);
  });
}
