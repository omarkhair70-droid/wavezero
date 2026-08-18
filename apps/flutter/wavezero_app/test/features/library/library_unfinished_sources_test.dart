import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/library/library_controls.dart';
import 'package:wavezero_app/features/library/library_source_overview.dart';

void main() {
  Widget buildOverview({required bool showCloudSource}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzLibrarySourceOverview(
              apiTrackCount: 2,
              deviceTrackCount: 3,
              cachedTrackCount: 1,
              cloudTrackCount: 4,
              combinedTrackCount: showCloudSource ? 10 : 6,
              cacheBytes: 1024,
              status: 'Ready',
              loading: false,
              refreshDisabled: false,
              librarySourceFilter: WzLibrarySourceFilter.all,
              devicePermissionStatus: 'granted',
              deviceScanStatus: 'success',
              deviceLastError: null,
              onSourceFilterChanged: (_) {},
              onRefresh: () {},
              onImportDeviceMusic: () {},
              onOpenCollections: () {},
              onOpenFullSearch: () {},
              onOpenCloudVault: () {},
              showCloudSource: showCloudSource,
            ),
          ),
        ),
      );

  testWidgets('consumer Library hides unfinished Cloud source', (tester) async {
    await tester.pumpWidget(buildOverview(showCloudSource: false));

    expect(find.text('Cloud'), findsNothing);
    expect(find.text('Cloud preview'), findsNothing);
    expect(find.textContaining('developer entries'), findsNothing);
  });

  testWidgets('developer Library can expose Cloud preview source', (tester) async {
    await tester.pumpWidget(buildOverview(showCloudSource: true));

    expect(find.text('Cloud'), findsWidgets);
    expect(find.text('Cloud preview'), findsOneWidget);
    expect(find.text('4 developer entries'), findsOneWidget);
  });
}
