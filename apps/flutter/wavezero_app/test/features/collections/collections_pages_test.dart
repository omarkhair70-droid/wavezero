import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/collections/collections_pages.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';

void main() {
  testWidgets('Collections page keeps the Liked Tracks entry and create action', (tester) async {
    final collections = [WzCollection.liked(nowMs: 1)];
    await tester.pumpWidget(
      MaterialApp(
        home: WzCollectionsPage(
          collections: collections,
          onBack: () {},
          onOpen: (_) {},
          onCreate: () {},
          onRename: (_) {},
          onDelete: (_) {},
        ),
      ),
    );
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Liked Tracks'), findsWidgets);
    expect(find.textContaining('Create'), findsWidgets);
  });
}