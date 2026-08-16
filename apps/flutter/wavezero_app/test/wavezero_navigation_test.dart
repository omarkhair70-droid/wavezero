import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/app/navigation/wavezero_navigation.dart';

void main() {
  test('consumer shell keeps the five primary destinations in order', () {
    expect(
      wzConsumerShellDestinations.map((destination) => destination.tab).toList(),
      [
        WzAppTab.home,
        WzAppTab.library,
        WzAppTab.now,
        WzAppTab.queue,
        WzAppTab.downloads,
      ],
    );
    expect(
      wzConsumerShellDestinations.map((destination) => destination.label).toList(),
      ['Home', 'Library', 'Now', 'Queue', 'Downloads'],
    );
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
