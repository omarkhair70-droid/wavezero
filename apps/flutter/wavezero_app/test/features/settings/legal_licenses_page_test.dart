import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/app/navigation/wavezero_navigation.dart';
import 'package:wavezero_app/features/settings/legal_licenses_page.dart';

void main() {
  testWidgets('empty Legal page keeps the release-safe rights copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WzLegalLicensesPage(
          tracks: [],
          appMode: WzAppMode.consumer,
        ),
      ),
    );
    expect(find.text('Legal & licenses'), findsOneWidget);
    expect(find.textContaining('Rights metadata'), findsOneWidget);
    expect(find.textContaining('No tracks are loaded yet.'), findsOneWidget);
  });
}
