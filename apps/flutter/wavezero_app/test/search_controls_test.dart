import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/search/search_controls.dart';

void main() {
  test('search filter order and labels remain stable', () {
    expect(
      WzSearchFilter.values,
      const [
        WzSearchFilter.all,
        WzSearchFilter.songs,
        WzSearchFilter.device,
        WzSearchFilter.downloads,
        WzSearchFilter.cloud,
        WzSearchFilter.collections,
        WzSearchFilter.history,
        WzSearchFilter.legalDemo,
      ],
    );
    expect(WzSearchFilter.all.label, 'All');
    expect(WzSearchFilter.songs.label, 'Songs');
    expect(WzSearchFilter.device.label, 'Device');
    expect(WzSearchFilter.downloads.label, 'Downloads');
    expect(WzSearchFilter.cloud.label, 'Cloud');
    expect(WzSearchFilter.collections.label, 'Collections');
    expect(WzSearchFilter.history.label, 'History');
    expect(WzSearchFilter.legalDemo.label, 'Legal / Demo');
  });
}
