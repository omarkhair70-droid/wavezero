enum WzSearchFilter {
  all,
  songs,
  device,
  downloads,
  cloud,
  collections,
  history,
  legalDemo,
}

extension WzSearchFilterLabel on WzSearchFilter {
  String get label => switch (this) {
        WzSearchFilter.all => 'All',
        WzSearchFilter.songs => 'Songs',
        WzSearchFilter.device => 'Device',
        WzSearchFilter.downloads => 'Downloads',
        WzSearchFilter.cloud => 'Cloud',
        WzSearchFilter.collections => 'Collections',
        WzSearchFilter.history => 'History',
        WzSearchFilter.legalDemo => 'Legal / Demo',
      };
}
