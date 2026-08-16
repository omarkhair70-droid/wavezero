import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/search/search_controls.dart';
import 'package:wavezero_app/features/search/search_results.dart';

void main() {
  WzSearchResult result({
    String title = 'Hello World',
    String subtitle = 'Artist',
    WzSearchResultType type = WzSearchResultType.track,
    WzSearchSource source = WzSearchSource.apiCatalog,
    String? searchText,
  }) =>
      WzSearchResult(
        id: 'id',
        title: title,
        subtitle: subtitle,
        type: type,
        source: source,
        secondaryLabel: 'secondary',
        searchText: searchText ?? '$title $subtitle'.toLowerCase(),
      );

  test('source and type labels preserve consumer copy', () {
    expect(wzSearchSourceLabel(WzSearchSource.deviceMusic), 'Device music');
    expect(wzSearchTypeLabel(WzSearchResultType.downloadedTrack), 'Offline song');
  });

  test('filters preserve source/type semantics', () {
    final device = result(
      type: WzSearchResultType.deviceTrack,
      source: WzSearchSource.deviceMusic,
    );
    expect(wzSearchFilterAllows(WzSearchFilter.all, device), isTrue);
    expect(wzSearchFilterAllows(WzSearchFilter.songs, device), isTrue);
    expect(wzSearchFilterAllows(WzSearchFilter.device, device), isTrue);
    expect(wzSearchFilterAllows(WzSearchFilter.downloads, device), isFalse);
  });

  test('ranking prefers exact title then prefix then contained title', () {
    expect(wzSearchRank(result(title: 'hello'), 'hello'), 0);
    expect(wzSearchRank(result(title: 'hello world'), 'hello'), 10);
    expect(wzSearchRank(result(title: 'say hello'), 'hello'), 20);
  });

  test('ranking uses subtitle before source fallback', () {
    expect(wzSearchRank(result(subtitle: 'Special Artist'), 'special'), 30);
    expect(
      wzSearchRank(
        result(
          title: 'Nothing',
          subtitle: 'Else',
          type: WzSearchResultType.deviceTrack,
          source: WzSearchSource.deviceMusic,
        ),
        'unmatched',
      ),
      50,
    );
  });
}
