import 'package:flutter/material.dart';

enum WzAppMode { consumer, developer }

enum WzAppTab {
  home,
  library,
  now,
  queue,
  search,
  collections,
  collectionDetail,
  downloads,
  storage,
  history,
  settings,
  engine,
}

class WzShellDestination {
  const WzShellDestination({
    required this.tab,
    required this.label,
    required this.icon,
  });

  final WzAppTab tab;
  final String label;
  final IconData icon;
}

const wzConsumerShellDestinations = <WzShellDestination>[
  WzShellDestination(tab: WzAppTab.home, label: 'Home', icon: Icons.home_filled),
  WzShellDestination(tab: WzAppTab.library, label: 'Library', icon: Icons.library_music),
  WzShellDestination(tab: WzAppTab.now, label: 'Now', icon: Icons.play_circle_fill),
  WzShellDestination(tab: WzAppTab.queue, label: 'Queue', icon: Icons.queue_music),
  WzShellDestination(tab: WzAppTab.downloads, label: 'Downloads', icon: Icons.download_done),
];

const wzDeveloperShellDestinations = <WzShellDestination>[
  ...wzConsumerShellDestinations,
  WzShellDestination(tab: WzAppTab.engine, label: 'Engine', icon: Icons.engineering),
];
