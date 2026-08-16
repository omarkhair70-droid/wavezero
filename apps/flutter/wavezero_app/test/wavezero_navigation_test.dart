import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/app/navigation/wavezero_navigation.dart';

void main() {
  test('consumer shell exposes only the three primary music destinations', () {
    expect(
      wzConsumerShellDestinations.map((destination) => destination.tab).toList(),
      [
        WzAppTab.home,
        WzAppTab.search,
        WzAppTab.library,
      ],
    );
    expect(
      wzConsumerShellDestinations.map((destination) => destination.label).toList(),
      ['Home', 'Search', 'Library'],
    );
  });

  test('secondary product routes stay available without occupying shell navigation', () {
    final primaryTabs = wzConsumerShellDestinations.map((destination) => destination.tab).toSet();
    expect(primaryTabs, isNot(contains(WzAppTab.now)));
    expect(primaryTabs, isNot(contains(WzAppTab.queue)));
    expect(primaryTabs, isNot(contains(WzAppTab.downloads)));
    expect(primaryTabs, isNot(contains(WzAppTab.storage)));
    expect(primaryTabs, isNot(contains(WzAppTab.history)));
    expect(primaryTabs, isNot(contains(WzAppTab.settings)));
  });

  test('developer shell only extends consumer navigation with Engine', () {
    expect(wzDeveloperShellDestinations.length, wzConsumerShellDestinations.length + 1);
    expect(
      wzDeveloperShellDestinations.take(wzConsumerShellDestinations.length).map((destination) => destination.tab).toList(),
      wzConsumerShellDestinations.map((destination) => destination.tab).toList(),
    );
    expect(wzDeveloperShellDestinations.last.tab, WzAppTab.engine);
    expect(wzDeveloperShellDestinations.last.label, 'Engine');
  });

  test('persisted app mode names remain stable', () {
    expect(WzAppMode.consumer.name, 'consumer');
    expect(WzAppMode.developer.name, 'developer');
  });
}
