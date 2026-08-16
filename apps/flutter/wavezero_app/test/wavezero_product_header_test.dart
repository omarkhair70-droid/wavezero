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

  testWidgets('consumer header is brand-only and does not expose runtime status', (tester) async {
    await tester.pumpWidget(buildHeader(mode: WzAppMode.consumer));

    expect(find.text('WaveZero'), findsOneWidget);
    expect(find.textContaining('Library'), findsNothing);
    expect(find.textContaining('Device music ready'), findsNothing);
    expect(find.text('Ready'), findsNothing);
    expect(find.textContaining('Developer'), findsNothing);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('developer header keeps diagnostics and settings remains interactive', (tester) async {
    var settingsTapped = false;
    await tester.pumpWidget(
      buildHeader(
        mode: WzAppMode.developer,
        selectedTabLabel: 'Queue',
        onOpenSettings: () => settingsTapped = true,
      ),
    );

    expect(find.text('WaveZero Developer'), findsOneWidget);
    expect(find.text('Queue • Instant Next on'), findsOneWidget);
    expect(find.text('Device music ready • Ready'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    expect(settingsTapped, isTrue);
  });
}
