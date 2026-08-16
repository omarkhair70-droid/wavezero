import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/developer/engine_diagnostics_page.dart';

void main() {
  testWidgets('developer status strip preserves playback summary copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WzDeveloperStatusStrip(
            status: 'Ready',
            detail: 'Playback bridge ready.',
            operation: 'Idle',
            refreshingMetrics: false,
          ),
        ),
      ),
    );

    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Playback bridge ready.'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
  });

  testWidgets('Smart Downloads diagnostics preserves toggle and counters', (tester) async {
    var enabled = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzSmartDownloadsDiagnosticsCard(
              enabled: enabled,
              lastTrackId: 'track-1',
              lastTitle: 'Track One',
              lastReason: 'up_next',
              lastResult: 'cached',
              startedCount: 2,
              completedCount: 1,
              failedCount: 0,
              skippedCount: 1,
              inFlight: 0,
              onToggle: (value) => enabled = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Smart Downloads'), findsOneWidget);
    expect(find.text('Track One'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(enabled, isFalse);
  });
}
