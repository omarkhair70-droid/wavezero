import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/app/app_shell/wavezero_product_header.dart';
import 'package:wavezero_app/app/navigation/wavezero_navigation.dart';
import 'package:wavezero_app/app/theme/wavezero_theme.dart';

void main() {
  Widget buildHeader({
    required WzAppMode mode,
    String selectedTabLabel = 'Library',
    String libraryStatus = 'Device music ready',
    String engineSummary = 'Instant Next on',
    VoidCallback? onOpenSettings,
  }) {
    const theme = WzThemeConfig();
    return MaterialApp(
      theme: theme.toThemeData(),
      home: Scaffold(
        body: WaveZeroProductHeader(
          selectedTabLabel: selectedTabLabel,
          status: 'Ready',
          engineSummary: engineSummary,
          libraryStatus: libraryStatus,
          libraryStatusActive: true,
          libraryStatusWarning: false,
          appMode: mode,
          themeConfig: theme,
          onLogoLongPress: () {},
          onOpenSettings: onOpenSettings ?? () {},
        ),
      ),
    );
  }

  testWidgets('consumer Porcelain header keeps selected tab and truthful library status', (tester) async {
    await tester.pumpWidget(buildHeader(mode: WzAppMode.consumer));

    expect(find.text('WaveZero'), findsOneWidget);
    expect(find.text('Library • Device music ready'), findsOneWidget);
    expect(find.textContaining('Developer'), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('developer Porcelain header shows engine summary and settings remains interactive', (tester) async {
    var settingsTapped = false;
    await tester.pumpWidget(
      buildHeader(
        mode: WzAppMode.developer,
        selectedTabLabel: 'Queue',
        onOpenSettings: () => settingsTapped = true,
      ),
    );

    expect(find.text('Queue • Developer • Instant Next on'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    expect(settingsTapped, isTrue);
  });
}
