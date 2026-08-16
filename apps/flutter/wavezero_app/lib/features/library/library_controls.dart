enum WzLibrarySourceFilter { all, api, device, downloads, cloud }

extension WzLibrarySourceFilterLabel on WzLibrarySourceFilter {
  String get label => switch (this) {
        WzLibrarySourceFilter.all => 'All',
        WzLibrarySourceFilter.api => 'Catalog',
        WzLibrarySourceFilter.device => 'Device music',
        WzLibrarySourceFilter.downloads => 'Downloaded',
        WzLibrarySourceFilter.cloud => 'Cloud',
      };
}

enum WzLibrarySortMode {
  recentlyAdded,
  titleAz,
  artistAz,
  longestDuration,
  shortestDuration,
  quality,
}

extension WzLibrarySortModeLabel on WzLibrarySortMode {
  String get label => switch (this) {
        WzLibrarySortMode.recentlyAdded => 'Recently added / imported',
        WzLibrarySortMode.titleAz => 'Title A-Z',
        WzLibrarySortMode.artistAz => 'Artist A-Z',
        WzLibrarySortMode.longestDuration => 'Longest duration',
        WzLibrarySortMode.shortestDuration => 'Shortest duration',
        WzLibrarySortMode.quality => 'Quality',
      };
}
