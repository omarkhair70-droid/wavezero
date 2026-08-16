import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/app/navigation/wavezero_navigation.dart';
import 'package:wavezero_app/app/theme/wavezero_theme.dart';
import 'package:wavezero_app/features/home/home_sections.dart';

void main() {
  testWidgets('Home hero preserves the WaveZero product copy', (tester) async {
    const themeConfig = WzThemeConfig();
    await tester.pumpWidget(
      MaterialApp(
        theme: themeConfig.toThemeData(),
        home: const Scaffold(
          body: WzHomeHero(themeConfig: themeConfig),
        ),
      ),
    );

    expect(find.text('WaveZero'), findsOneWidget);
    expect(find.text('A smart music experience engine.'), findsOneWidget);
    expect(find.text('Native playback'), findsOneWidget);
    expect(find.text('Music-first playback • offline-aware library'), findsOneWidget);
  });

  testWidgets('Home quick actions preserve navigation targets', (tester) async {
    WzAppTab? selectedTab;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WzHomeQuickActions(
            showDeveloperTools: true,
            onNavigate: (tab) => selectedTab = tab,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Library'));
    await tester.pump();
    expect(selectedTab, WzAppTab.library);

    await tester.tap(find.text('Engine'));
    await tester.pump();
    expect(selectedTab, WzAppTab.engine);
  });
}
