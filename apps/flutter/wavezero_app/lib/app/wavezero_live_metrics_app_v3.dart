import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_effects.dart';
import 'app_config.dart';
import '../catalog/audio_quality.dart';
import '../catalog/catalog_client.dart';
import '../catalog/catalog_track_manifest.dart';
import '../playback/playback_bridge.dart';
import '../playback/playback_metrics.dart';
import '../playback/test_track.dart';
import '../cache/cache_service.dart';
import '../design/wavezero_design_system.dart';
import '../device_music/device_music_service.dart';
import '../device_music/device_music_track.dart';
import 'collections_service.dart';
import 'listening_history_service.dart';
import 'player_operation_state.dart';
import 'queue_session_store.dart';
import 'smart_queue_policy.dart';

enum _AppMode { consumer, developer }

enum _AppTab { home, library, now, queue, search, collections, collectionDetail, downloads, storage, history, settings, engine }

enum WzRepeatMode { off, one, all }

enum _SleepTimerPreset { off, minutes15, minutes30, minutes45, minutes60 }

extension _WzRepeatModeLabel on WzRepeatMode {
  String get label => switch (this) {
        WzRepeatMode.off => 'Repeat off',
        WzRepeatMode.one => 'Repeat one',
        WzRepeatMode.all => 'Repeat all',
      };

  IconData get icon => switch (this) {
        WzRepeatMode.off => Icons.repeat,
        WzRepeatMode.one => Icons.repeat_one,
        WzRepeatMode.all => Icons.repeat,
      };

  WzRepeatMode get next => switch (this) {
        WzRepeatMode.off => WzRepeatMode.one,
        WzRepeatMode.one => WzRepeatMode.all,
        WzRepeatMode.all => WzRepeatMode.off,
      };
}

extension _SleepTimerPresetLabel on _SleepTimerPreset {
  String get label => switch (this) {
        _SleepTimerPreset.off => 'Off',
        _SleepTimerPreset.minutes15 => '15 minutes',
        _SleepTimerPreset.minutes30 => '30 minutes',
        _SleepTimerPreset.minutes45 => '45 minutes',
        _SleepTimerPreset.minutes60 => '60 minutes',
      };

  Duration? get duration => switch (this) {
        _SleepTimerPreset.off => null,
        _SleepTimerPreset.minutes15 => const Duration(minutes: 15),
        _SleepTimerPreset.minutes30 => const Duration(minutes: 30),
        _SleepTimerPreset.minutes45 => const Duration(minutes: 45),
        _SleepTimerPreset.minutes60 => const Duration(minutes: 60),
      };
}

class _ShellDestination {
  const _ShellDestination({required this.tab, required this.label, required this.icon});

  final _AppTab tab;
  final String label;
  final IconData icon;
}

const _consumerShellDestinations = <_ShellDestination>[
  _ShellDestination(tab: _AppTab.home, label: 'Home', icon: Icons.home_filled),
  _ShellDestination(tab: _AppTab.library, label: 'Library', icon: Icons.library_music),
  _ShellDestination(tab: _AppTab.now, label: 'Now', icon: Icons.play_circle_fill),
  _ShellDestination(tab: _AppTab.queue, label: 'Queue', icon: Icons.queue_music),
  _ShellDestination(tab: _AppTab.downloads, label: 'Downloads', icon: Icons.download_done),
];

const _developerShellDestinations = <_ShellDestination>[
  ..._consumerShellDestinations,
  _ShellDestination(tab: _AppTab.engine, label: 'Engine', icon: Icons.engineering),
];

enum WzThemePreset { midnight, oledDark, wavePurple }

enum WzAccentPreset { wavePurple, cyan, green, sunset }

class WzThemeConfig {
  const WzThemeConfig({
    this.themePreset = WzThemePreset.midnight,
    this.accentPreset = WzAccentPreset.wavePurple,
  });

  static const themePreferenceKey = 'wavezero.theme_preset';
  static const accentPreferenceKey = 'wavezero.accent_preset';

  final WzThemePreset themePreset;
  final WzAccentPreset accentPreset;

  WzThemeConfig copyWith({WzThemePreset? themePreset, WzAccentPreset? accentPreset}) => WzThemeConfig(
        themePreset: themePreset ?? this.themePreset,
        accentPreset: accentPreset ?? this.accentPreset,
      );

  Color get accent => switch (accentPreset) {
        WzAccentPreset.wavePurple => const Color(0xFF9A8CFF),
        WzAccentPreset.cyan => const Color(0xFF36D7FF),
        WzAccentPreset.green => const Color(0xFF38D996),
        WzAccentPreset.sunset => const Color(0xFFFFA85C),
      };

  Color get accentAlt => switch (accentPreset) {
        WzAccentPreset.wavePurple => const Color(0xFF36D7FF),
        WzAccentPreset.cyan => const Color(0xFF9A8CFF),
        WzAccentPreset.green => const Color(0xFF8DFFCB),
        WzAccentPreset.sunset => const Color(0xFFFF6B8A),
      };

  Color get canvas => switch (themePreset) {
        WzThemePreset.midnight => WzColors.canvas,
        WzThemePreset.oledDark => Colors.black,
        WzThemePreset.wavePurple => const Color(0xFF090615),
      };

  Color get surfaceMuted => switch (themePreset) {
        WzThemePreset.midnight => WzColors.surfaceMuted,
        WzThemePreset.oledDark => const Color(0xFF050505),
        WzThemePreset.wavePurple => const Color(0xFF110D22),
      };

  LinearGradient get shellGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: switch (themePreset) {
          WzThemePreset.midnight => [const Color(0xFF1A2140), WzColors.surfaceMuted, accent.withOpacity(0.18)],
          WzThemePreset.oledDark => [Colors.black, const Color(0xFF050505), accent.withOpacity(0.16)],
          WzThemePreset.wavePurple => [const Color(0xFF261846), const Color(0xFF110D22), accent.withOpacity(0.24)],
        },
      );

  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, accentAlt],
      );

  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark).copyWith(
      primary: accent,
      secondary: accentAlt,
      surface: WzColors.surface,
      surfaceContainerHighest: surfaceMuted,
    );
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: canvas,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? accent : null),
        trackColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? accent.withOpacity(0.42) : null),
      ),
      chipTheme: ChipThemeData(
        selectedColor: accent.withOpacity(0.26),
        labelStyle: const TextStyle(color: WzColors.textPrimary),
        side: BorderSide(color: accent.withOpacity(0.34)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_WzTokens.radiusMd),
          borderSide: const BorderSide(color: _WzTokens.border),
        ),
      ),
      useMaterial3: true,
    );
  }

  static WzThemeConfig fromPrefs(SharedPreferences prefs) => WzThemeConfig(
        themePreset: WzThemePreset.values.firstWhere(
          (preset) => preset.name == prefs.getString(themePreferenceKey),
          orElse: () => WzThemePreset.midnight,
        ),
        accentPreset: WzAccentPreset.values.firstWhere(
          (preset) => preset.name == prefs.getString(accentPreferenceKey),
          orElse: () => WzAccentPreset.wavePurple,
        ),
      );
}

extension WzThemePresetLabel on WzThemePreset {
  String get label => switch (this) {
        WzThemePreset.midnight => 'Midnight',
        WzThemePreset.oledDark => 'OLED Dark',
        WzThemePreset.wavePurple => 'Wave Purple',
      };
}

extension WzAccentPresetLabel on WzAccentPreset {
  String get label => switch (this) {
        WzAccentPreset.wavePurple => 'Wave Purple',
        WzAccentPreset.cyan => 'Cyan',
        WzAccentPreset.green => 'Green',
        WzAccentPreset.sunset => 'Amber / Sunset',
      };
}


String _catalogModeLabel(String? contentMode, int trackCount) {
  return switch (contentMode) {
    'demo' => 'Demo catalog',
    'production' => 'Catalog ready',
    'dev' => 'Catalog ready',
    _ => trackCount > 0 ? 'Catalog ready' : 'Catalog unavailable',
  };
}

String _friendlyLoadError(String error) {
  final normalized = error.toLowerCase();
  if (normalized.contains('permission')) return WaveZeroReleaseCopy.deviceMusicPermission;
  if (normalized.contains('socketexception') || normalized.contains('connection') || normalized.contains('http')) {
    return '${WaveZeroReleaseCopy.catalogUnavailable} ${WaveZeroReleaseCopy.catalogTryAgain}';
  }
  return WaveZeroReleaseCopy.playbackCouldNotStart;
}

String _consumerCatalogStatus(String status) {
  final normalized = status.toLowerCase();

  if (normalized.contains('demo catalog')) return 'Demo catalog';
  if (normalized.contains('catalog ready')) return 'Catalog ready';
  if (normalized.contains('catalog unavailable') ||
      normalized.contains('unavailable') ||
      normalized.contains('error') ||
      normalized.contains('exception') ||
      normalized.contains('failed')) {
    return '${WaveZeroReleaseCopy.catalogUnavailable} ${WaveZeroReleaseCopy.catalogTryAgain} ${WaveZeroReleaseCopy.catalogLocalFallback}';
  if (normalized.contains('demo catalog')) return 'Demo catalog';
  if (normalized.contains('catalog ready')) return 'Catalog ready';
  if (normalized.contains('catalog unavailable')) return 'Catalog unavailable';
  if (normalized.contains('error') || normalized.contains('exception') || normalized.contains('failed')) {
    return 'Couldn’t load music right now. Check your connection and try again.';
  }
  if (normalized.contains('permission')) return WaveZeroReleaseCopy.deviceMusicPermission;
  if (normalized.contains('loaded') || normalized.contains('imported')) return status;
  if (normalized.contains('offline')) return status;
  return 'Choose music from your library.';
}

String _catalogModeLabel(String? contentMode, int trackCount) {
  final normalized = contentMode?.trim().toLowerCase().replaceAll('-', '_');
  if (normalized == 'demo' || normalized == 'demo_catalog' || normalized == 'legal_demo') return 'Demo catalog';
  if (normalized == 'production' || normalized == 'prod' || normalized == 'catalog_ready') return 'Catalog ready';
  if (trackCount > 0) return 'Catalog ready';
  return 'Catalog unavailable';
}

String? _consumerDeviceError(String? error) {
  if (error == null || error.isEmpty) return null;
  return _friendlyLoadError(error);
}

class WaveZeroLiveMetricsApp extends StatefulWidget {
  const WaveZeroLiveMetricsApp({super.key, PlaybackBridge? playbackBridge, QueueSessionStore? sessionStore})
      : _playbackBridge = playbackBridge,
        _sessionStore = sessionStore;

  final PlaybackBridge? _playbackBridge;
  final QueueSessionStore? _sessionStore;

  @override
  State<WaveZeroLiveMetricsApp> createState() => _WaveZeroLiveMetricsAppState();
}

class _WaveZeroLiveMetricsAppState extends State<WaveZeroLiveMetricsApp> {
  WzThemeConfig _themeConfig = const WzThemeConfig();

  @override
  void initState() {
    super.initState();
    unawaited(_loadThemeConfig());
  }

  Future<void> _loadThemeConfig() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _themeConfig = WzThemeConfig.fromPrefs(prefs));
  }

  Future<void> _setThemeConfig(WzThemeConfig config) async {
    setState(() => _themeConfig = config);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WzThemeConfig.themePreferenceKey, config.themePreset.name);
    await prefs.setString(WzThemeConfig.accentPreferenceKey, config.accentPreset.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaveZero',
      debugShowCheckedModeBanner: false,
      theme: _themeConfig.toThemeData(),
      home: _PlayerScreen(
        playbackBridge: widget._playbackBridge ?? _defaultBridge(),
        sessionStore: widget._sessionStore ?? QueueSessionStore(),
        appConfig: WaveZeroAppConfig.current,
        themeConfig: _themeConfig,
        onThemeConfigChanged: _setThemeConfig,
      ),
    );
  }

  PlaybackBridge _defaultBridge() {
    if (defaultTargetPlatform == TargetPlatform.android) return PlatformChannelPlaybackBridge();
    return MockPlaybackBridge();
  }
}

class _PlayerScreen extends StatefulWidget {
  const _PlayerScreen({
    required this.playbackBridge,
    required this.sessionStore,
    required this.appConfig,
    required this.themeConfig,
    required this.onThemeConfigChanged,
  });

  final PlaybackBridge playbackBridge;
  final QueueSessionStore sessionStore;
  final WaveZeroAppConfig appConfig;
  final WzThemeConfig themeConfig;
  final ValueChanged<WzThemeConfig> onThemeConfigChanged;

  @override
  State<_PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<_PlayerScreen> {
  static const _refreshInterval = Duration(milliseconds: 500);
  static const _autoAdvanceThresholdMs = 1200;
  static const _audioEffectPreferenceKey = 'wavezero.selected_audio_effect_profile';
  static const _appModePreferenceKey = 'wavezero.app_mode';
  static const _recentSearchesPreferenceKey = 'wavezero.recent_searches.v1';
  static const _shufflePreferenceKey = 'wavezero.shuffle_enabled';
  static const _repeatModePreferenceKey = 'wavezero.repeat_mode';
  static const _sleepTimerPresetPreferenceKey = 'wavezero.sleep_timer_preset';

  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _searchController;
  late final TextEditingController _fullSearchController;

  Timer? _poller;
  Timer? _sleepTimer;
  PlaybackMetrics _metrics = const PlaybackMetrics();
  CatalogTrackManifest? _manifest;
  List<CatalogTrackSummary> _catalog = const [];
  List<CatalogTrackSummary> _queue = const [];
  final DeviceMusicService _deviceMusicService = DeviceMusicService();
  DeviceMusicPermissionStatus _deviceMusicPermissionStatus = const DeviceMusicPermissionStatus(status: 'unknown');
  String _deviceMusicScanStatus = 'not_scanned';
  List<DeviceMusicTrack> _deviceMusicTracks = const [];
  int _deviceMusicLastScanCount = 0;
  String? _deviceMusicLastError;
  int? _deviceMusicImportedAtMs;
  _LibrarySourceFilter _librarySourceFilter = _LibrarySourceFilter.all;
  _LibrarySortMode _librarySortMode = _LibrarySortMode.recentlyAdded;

  PlayerOperation _operation = PlayerOperation.idle;
  bool _refreshingMetrics = false;
  bool _showMetrics = false;
  _AppMode _appMode = _AppMode.consumer;
  _AppTab _selectedTab = _AppTab.home;
  bool _autoAdvanceEnabled = true;
  bool _shuffleEnabled = false;
  WzRepeatMode _repeatMode = WzRepeatMode.off;
  _SleepTimerPreset _sleepTimerPreset = _SleepTimerPreset.off;
  DateTime? _sleepTimerDeadline;
  bool _sessionRestored = false;
  int _autoAdvanceCount = 0;
  int _prefetchGeneration = 0;
  int _prefetchHitCount = 0;
  int _prefetchMissCount = 0;
  int? _nextTapStartedAtMs;
  int? _nextTapToAudioMs;
  int? _lastStopAtMs;
  int? _stopRecoveryPlayStartedAtMs;
  int? _stopToPlayRecoveryMs;
  int? _sessionRecoveryStartedAtMs;
  int? _sessionRecoveryMs;
  double? _dragPositionMs;

  bool _prefetchEnabled = true;
  bool _prefetchInFlight = false;
  bool? _lastPrefetchHit;
  bool _manifestPrefetched = false;
  bool _audioPreparedBeforeNext = false;
  bool _nextPreparedBeforePlay = false;

  // Smart downloads (predictive auto-cache) state
  bool _smartDownloadsEnabled = true;
  AudioQualityTier _preferredAudioQuality = AudioQualityTier.high;
  String _lastQualityFallbackReason = 'No catalog asset selected yet.';
  AudioEffectProfile _selectedAudioEffectProfile = AudioEffectProfile.off;
  NativeAudioEffectStatus _nativeAudioEffectStatus = NativeAudioEffectStatus.off;
  String _lastAudioEffectApplyResult = 'Audio effects are off; original playback is preserved.';
  String? _currentAssetUrl;
  String? _currentCachedQuality;
  final Set<String> _autoCacheInFlight = <String>{};
  String? _lastSmartDownloadTrackId;
  String? _lastSmartDownloadTitle;
  String? _lastSmartDownloadReason;
  String? _lastSmartDownloadResult;
  int _smartDownloadStartedCount = 0;
  int _smartDownloadCompletedCount = 0;
  int _smartDownloadFailedCount = 0;
  int _smartDownloadSkippedCount = 0;
  static const int _maxSmartDownloadCachedTracks = 10;

  // Cache service and diagnostics
  final CacheService _cacheService = CacheService();
  int _cachedTrackCount = 0;
  int _cacheBytes = 0;
  List<CachedTrackMetadata> _cachedLibrary = const [];
  Map<String, int> _cachedTrackBytes = const {};
  String? _lastCacheResult;
  String? _lastCacheDeleteResult;
  int _manualDownloadedCount = 0;
  int _smartDownloadedCount = 0;
  int _offlineCachedTrackCount = 0;
  bool _offlineLibraryAvailable = false;
  bool _offlineLibraryMode = false;
  String _lastOfflineLibraryStatus = 'Offline library not initialized.';

  String? _selectedTrackId;
  String? _queueCurrentTrackId;
  String? _lastAutoAdvanceTrackId;
  String? _lastError;
  String? _prefetchedTrackId;
  String? _prefetchedTrackTitle;
  String? _smartQueueCandidateTrackId;
  String _smartQueueReason = SmartQueueReason.queueEmpty;
  CatalogTrackManifest? _prefetchedManifest;
  ContentStatus? _contentStatus;
  String _catalogQuery = '';
  String _catalogStatus = 'Catalog not loaded yet.';
  ContentStatus? _contentStatus;
  _SearchFilter _searchFilter = _SearchFilter.all;
  List<String> _recentSearches = const <String>[];
  String _queueStatus = 'Queue is ready.';
  String _sessionStatus = 'Session recovery pending.';

  final CollectionsService _collectionsService = CollectionsService();
  List<WzCollection> _collections = <WzCollection>[WzCollection.liked()];
  String? _selectedCollectionId = likedTracksCollectionId;

  final ListeningHistoryService _listeningHistoryService = ListeningHistoryService();
  List<WzListeningHistoryEntry> _listeningHistory = const <WzListeningHistoryEntry>[];

  WzCollection get _likedCollection => _collections.firstWhere(
        (collection) => collection.type == WzCollectionType.liked,
        orElse: () => WzCollection.liked(),
      );

  List<WzCollection> get _userCollections => _collections.where((collection) => collection.type == WzCollectionType.user).toList(growable: false);

  WzListeningHistoryEntry? get _continueListeningEntry => _listeningHistory.isEmpty ? null : _listeningHistory.first;

  WzListeningHistoryEntry? get _mostPlayedHistoryEntry {
    if (_listeningHistory.isEmpty) return null;
    final entries = [..._listeningHistory]..sort((a, b) {
        final byPlays = b.playCount.compareTo(a.playCount);
        return byPlays == 0 ? b.lastPlayedAtMs.compareTo(a.lastPlayedAtMs) : byPlays;
      });
    return entries.first;
  }

  WzCollection? get _selectedCollection {
    final id = _selectedCollectionId;
    if (id == null) return null;
    for (final collection in _collections) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  CatalogTrackSummary? get _currentKnownTrack {
    final id = _manifest?.trackId ?? _metrics.currentTrackId ?? _queueCurrentTrackId ?? _selectedTrackId;
    if (id == null) return null;
    final snapshot = WzCollectionTrackSnapshot(
      trackId: id,
      title: _manifest?.title ?? _metrics.trackTitle ?? 'Current track',
      subtitle: _manifest?.subtitle ?? 'WaveZero track',
      source: WzCollectionTrackSource.unknown,
      qualityLabel: _manifest?.qualityLabel,
      codec: _manifest?.codec,
      license: _manifest?.license ?? LicenseMetadata.unknown,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    return _resolveCollectionTrack(snapshot);
  }

  List<CatalogTrackSummary> get _deviceCatalogTracks =>
      _deviceMusicTracks.map(_catalogSummaryFromDeviceTrack).toList(growable: false);

  List<CatalogTrackSummary> get _cachedCatalogTracks =>
      _cachedLibrary.map(_catalogSummaryFromCachedTrack).toList(growable: false);

  List<CatalogTrackSummary> get _libraryTracks {
    return switch (_librarySourceFilter) {
      _LibrarySourceFilter.all => [..._catalog, ..._deviceCatalogTracks, ..._cachedCatalogTracks],
      _LibrarySourceFilter.api => _catalog,
      _LibrarySourceFilter.device => _deviceCatalogTracks,
      _LibrarySourceFilter.downloads => _cachedCatalogTracks,
    };
  }

  int get _libraryTotalTrackCount => _libraryTracks.length;

  int get _libraryCombinedTrackCount => _catalog.length + _deviceMusicTracks.length + _cachedLibrary.length;

  List<CatalogTrackSummary> get _filteredCatalog =>
      _sortLibraryTracks(_libraryTracks.where((track) => track.matchesQuery(_catalogQuery)).toList(growable: false));

  List<WzSearchResult> get _allSearchResults {
    final results = <WzSearchResult>[];
    WzSearchResult resultForTrack(CatalogTrackSummary track, WzSearchResultType type, WzSearchSource source, String secondary) {
      final asset = track.primaryAsset;
      final label = _searchSourceLabel(source);
      return WzSearchResult(
        id: '${source.name}:${track.trackId}',
        title: track.title,
        subtitle: track.subtitle,
        type: type,
        source: source,
        artworkUrl: track.artworkUrl,
        trackId: track.trackId,
        qualityLabel: asset?.qualityLabel,
        codec: asset?.codec,
        license: _isDeviceCatalogTrack(track) ? LicenseMetadata.userDevice : track.license,
        available: asset?.manifestUrl.trim().isNotEmpty == true,
        secondaryLabel: secondary,
        searchText: _normalizeWzSearch([
          track.title,
          track.subtitle,
          track.artistName ?? '',
          track.albumName ?? '',
          track.displayName ?? '',
          label,
          secondary,
          asset?.qualityLabel ?? '',
          asset?.codec ?? '',
          track.license.badgeLabel,
          track.license.sourceName ?? '',
          track.license.usageNotes ?? '',
        ].join(' ')),
        track: track,
      );
    }

    for (final track in _catalog) {
      final source = track.license.needsRightsWarning || track.license.sourceName?.toLowerCase().contains('demo') == true
          ? WzSearchSource.legalDemo
          : WzSearchSource.apiCatalog;
      results.add(resultForTrack(track, WzSearchResultType.track, source, source == WzSearchSource.legalDemo ? 'Legal demo catalog' : 'Catalog'));
    }
    for (final track in _deviceCatalogTracks) {
      results.add(resultForTrack(track, WzSearchResultType.deviceTrack, WzSearchSource.deviceMusic, 'Your device music'));
    }
    for (final track in _cachedCatalogTracks) {
      results.add(resultForTrack(track, WzSearchResultType.downloadedTrack, WzSearchSource.downloads, 'Offline Ready download'));
    }

    for (final collection in _collections) {
      results.add(WzSearchResult(
        id: 'collection:${collection.id}',
        title: collection.name,
        subtitle: collection.type == WzCollectionType.liked ? '${collection.trackCount} liked tracks' : '${collection.trackCount} collection tracks',
        type: WzSearchResultType.collection,
        source: WzSearchSource.collections,
        collectionId: collection.id,
        available: true,
        secondaryLabel: collection.type == WzCollectionType.liked ? 'Liked Tracks' : 'Collection',
        searchText: _normalizeWzSearch([
          collection.name,
          collection.description ?? '',
          'Collections',
          collection.type == WzCollectionType.liked ? 'Liked Tracks' : 'Playlist',
          ...collection.tracks.expand((track) => [track.title, track.subtitle, track.albumName ?? '', track.license.badgeLabel, track.license.sourceName ?? '']),
        ].join(' ')),
        collection: collection,
      ));
    }

    for (final entry in _listeningHistory) {
      final resolved = _resolveHistoryEntry(entry);
      results.add(WzSearchResult(
        id: 'history:${entry.trackId}',
        title: entry.title,
        subtitle: entry.subtitle,
        type: WzSearchResultType.historyEntry,
        source: WzSearchSource.history,
        artworkUrl: entry.artworkUrl,
        trackId: resolved?.trackId,
        historyTrackId: entry.trackId,
        qualityLabel: entry.qualityLabel,
        codec: entry.codec,
        license: entry.license,
        available: resolved != null,
        secondaryLabel: 'Recently played • ${entry.playCount} play${entry.playCount == 1 ? '' : 's'}',
        searchText: _normalizeWzSearch([
          entry.title,
          entry.subtitle,
          entry.albumName ?? '',
          'History Recently Played Continue Listening',
          _historySourceLabel(entry.source),
          entry.qualityLabel ?? '',
          entry.codec ?? '',
          entry.license.badgeLabel,
          entry.license.sourceName ?? '',
        ].join(' ')),
        track: resolved,
        historyEntry: entry,
      ));
    }

    return results;
  }

  List<WzSearchResult> get _filteredSearchResults {
    final query = _fullSearchController.text;
    final normalized = _normalizeWzSearch(query);
    if (normalized.isEmpty) return const <WzSearchResult>[];
    final matches = _allSearchResults
        .where((result) => _searchFilterAllows(_searchFilter, result) && result.searchText.contains(normalized))
        .toList(growable: false);
    final indexed = matches.indexed.toList(growable: false);
    indexed.sort((a, b) {
      final rank = _searchRank(a.$2, query).compareTo(_searchRank(b.$2, query));
      if (rank != 0) return rank;
      final title = _normalizeWzSearch(a.$2.title).compareTo(_normalizeWzSearch(b.$2.title));
      if (title != 0) return title;
      return a.$1.compareTo(b.$1);
    });
    return indexed.map((item) => item.$2).toList(growable: false);
  }


  int get _queueIndex {
    final id = _queueCurrentTrackId ?? _selectedTrackId;
    if (id == null) return -1;
    return _queue.indexWhere((track) => track.trackId == id);
  }

  CatalogTrackSummary? get _currentQueueTrack {
    final index = _queueIndex;
    if (index < 0 || index >= _queue.length) return null;
    return _queue[index];
  }

  CatalogTrackSummary? get _upNextQueueTrack {
    final index = _queueIndex;
    if (index < 0 || index >= _queue.length - 1) return null;
    return _queue[index + 1];
  }

  SmartQueueDecision _smartQueueDecision() => decideSmartQueueCandidate(
        smartPreloadEnabled: _prefetchEnabled,
        queue: _queue,
        catalogTrackIds: _catalog.map((track) => track.trackId).toSet(),
        currentTrackId: _queueCurrentTrackId,
        selectedTrackId: _selectedTrackId,
        previousCandidateTrackId: _smartQueueCandidateTrackId ?? _prefetchedTrackId,
        manifestPrefetched: _manifestPrefetched,
        metrics: _metrics,
      );

  bool get _canPrevious => _queueIndex > 0;
  bool get _canNext => _queueIndex >= 0 && _queueIndex < _queue.length - 1;
  bool get _canShuffleNext => _shuffleEnabled && _queue.length > 1 && _queueIndex >= 0;
  bool get _canPlayNextControl => _canNext || _canShuffleNext;

  String get _sleepTimerStatusLabel {
    final deadline = _sleepTimerDeadline;
    if (deadline == null) return 'Sleep timer';
    final remaining = deadline.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 'Sleep timer ending';
    final minutes = remaining.inMinutes + (remaining.inSeconds % 60 == 0 ? 0 : 1);
    return 'Sleep in ${minutes}m';
  }

  String get _sleepTimerSettingsLabel => _sleepTimerDeadline == null ? 'Sleep timer off' : _sleepTimerStatusLabel;
  bool get _playerDisabled => _operation.disablesPlayerControls;
  bool get _catalogRefreshDisabled => _operation.disablesCatalogRefresh;
  bool get _queueDisabled => _operation.disablesQueueControls;
  bool get _manualDisabled => _operation.disablesManualTrackControls;
  bool get _developerMode => _appMode == _AppMode.developer;
  bool get _showDeveloperControls => widget.appConfig.showDeveloperEntry || _developerMode;
  bool get _allowManualApiSetup => widget.appConfig.allowManualApiSetup && _developerMode;

  String get _statusText {
    if ((_lastError ?? _metrics.playbackError) != null) return 'Error';
    if (_operation != PlayerOperation.idle) return _operation.displayName;
    if (_metrics.isPlaying) return 'Playing';
    if (_manifest != null || _metrics.trackTitle != null) return 'Paused / Ready';
    return 'Ready';
  }

  String get _statusDetail {
    final error = _lastError ?? _metrics.playbackError;
    if (error != null && error.isNotEmpty) return _developerMode ? error : _friendlyLoadError(error);
    if (_refreshingMetrics) {
      return _developerMode ? 'Metrics refresh is running without blocking controls.' : 'Updating playback status.';
    }
    if (_upNextQueueTrack != null) return 'Up next: ${_upNextQueueTrack!.title}';
    return _queueStatus;
  }

  @override
  void initState() {
    super.initState();
    _sessionRecoveryStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    _titleController = TextEditingController(text: waveZeroTestTrack.title);
    _urlController = TextEditingController(text: waveZeroTestTrack.url);
    _apiBaseUrlController = TextEditingController(text: widget.appConfig.apiBaseUrl);
    _searchController = TextEditingController();
    _fullSearchController = TextEditingController();
    _searchController.addListener(() {
      if (mounted) setState(() => _catalogQuery = _searchController.text);
    });
    _fullSearchController.addListener(() {
      if (mounted) setState(() {});
    });
    _poller = Timer.periodic(_refreshInterval, (_) => _refreshMetrics());
    _loadCatalog(fallbackToDemo: true);
    unawaited(_initCache());
    unawaited(_initAudioEffects());
    unawaited(_refreshDeviceMusicPermissionStatus());
    unawaited(_loadAppMode());
    unawaited(_loadCollections());
    unawaited(_loadListeningHistory());
    unawaited(_loadRecentSearches());
    unawaited(_loadPlaybackModePrefs());
  }

  Future<void> _loadListeningHistory() async {
    final entries = await _listeningHistoryService.load();
    if (!mounted) return;
    setState(() => _listeningHistory = entries);
  }

  Future<void> _loadPlaybackModePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final repeatName = prefs.getString(_repeatModePreferenceKey);
    final presetName = prefs.getString(_sleepTimerPresetPreferenceKey);
    setState(() {
      _shuffleEnabled = prefs.getBool(_shufflePreferenceKey) ?? false;
      _repeatMode = WzRepeatMode.values.firstWhere((mode) => mode.name == repeatName, orElse: () => WzRepeatMode.off);
      _sleepTimerPreset = _SleepTimerPreset.values.firstWhere((preset) => preset.name == presetName, orElse: () => _SleepTimerPreset.off);
      _sleepTimerDeadline = null;
    });
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList(_recentSearchesPreferenceKey) ?? const <String>[];
    if (!mounted) return;
    setState(() => _recentSearches = searches.take(10).toList(growable: false));
  }

  Future<void> _rememberSearchQuery(String query) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return;
    final next = <String>[normalized, ..._recentSearches.where((item) => _normalizeWzSearch(item) != _normalizeWzSearch(normalized))].take(10).toList(growable: false);
    setState(() => _recentSearches = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesPreferenceKey, next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = const <String>[]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesPreferenceKey);
  }

  void _openSearch({String? query}) {
    if (query != null) _fullSearchController.text = query;
    setState(() => _selectedTab = _AppTab.search);
  }

  Future<void> _loadCollections() async {
    final collections = await _collectionsService.load();
    if (!mounted) return;
    setState(() {
      _collections = collections;
      _selectedCollectionId ??= _likedCollection.id;
    });
  }

  Future<void> _persistCollections(List<WzCollection> collections) async {
    setState(() => _collections = collections);
    await _collectionsService.save(collections);
  }

  Future<void> _saveCollections() => _collectionsService.save(_collections);

  bool _isLiked(String trackId) => _likedCollection.tracks.any((track) => track.trackId == trackId);

  WzCollectionTrackSnapshot _snapshotForTrack(CatalogTrackSummary track) {
    final source = _isDeviceCatalogTrack(track)
        ? WzCollectionTrackSource.device
        : _isCachedCatalogTrack(track)
            ? WzCollectionTrackSource.cached
            : track.source == 'api'
                ? WzCollectionTrackSource.api
                : WzCollectionTrackSource.unknown;
    return WzCollectionTrackSnapshot(
      trackId: track.trackId,
      title: track.title,
      subtitle: track.subtitle,
      albumName: track.albumName,
      artworkUrl: track.artworkUrl,
      source: source,
      primaryUrl: track.primaryAsset?.manifestUrl,
      qualityLabel: track.primaryAsset?.qualityLabel,
      codec: track.primaryAsset?.codec,
      license: _isDeviceCatalogTrack(track) ? LicenseMetadata.userDevice : track.license,
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  CatalogTrackSummary _summaryFromSnapshot(WzCollectionTrackSnapshot snapshot) => CatalogTrackSummary(
        trackId: snapshot.trackId,
        title: snapshot.title,
        artistName: snapshot.subtitle,
        albumName: snapshot.albumName,
        artworkUrl: snapshot.artworkUrl,
        source: snapshot.source.name,
        license: snapshot.source == WzCollectionTrackSource.device ? LicenseMetadata.userDevice : snapshot.license,
        primaryAsset: snapshot.primaryUrl == null
            ? null
            : CatalogTrackAssetSummary(
                assetId: '${snapshot.source.name}-${snapshot.trackId}',
                manifestUrl: snapshot.primaryUrl!,
                qualityLabel: snapshot.qualityLabel,
                codec: snapshot.codec,
              ),
      );

  CatalogTrackSummary? _resolveCollectionTrack(WzCollectionTrackSnapshot snapshot) {
    for (final track in _libraryTracks) {
      if (track.trackId == snapshot.trackId) return track;
    }
    return null;
  }

  CatalogTrackSummary? _resolveHistoryEntry(WzListeningHistoryEntry entry) {
    for (final track in _libraryTracks) {
      if (track.trackId == entry.trackId) return track;
    }
    return null;
  }

  WzListeningHistoryEntry _historySnapshotForManifest(
    CatalogTrackManifest manifest, {
    required WzListeningHistorySource source,
    required String? playableUrl,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return WzListeningHistoryEntry(
      trackId: manifest.trackId,
      title: manifest.title,
      subtitle: manifest.subtitle,
      artworkUrl: manifest.artworkUrl,
      source: source,
      primaryUrl: playableUrl ?? manifest.streamUrl,
      qualityLabel: manifest.qualityLabel,
      codec: manifest.codec,
      license: source == WzListeningHistorySource.device ? LicenseMetadata.userDevice : manifest.license,
      lastPlayedAtMs: now,
      firstPlayedAtMs: now,
      playCount: 1,
      lastPositionMs: 0,
      durationMs: manifest.durationMs,
    );
  }

  Future<void> _recordListeningHistory(WzListeningHistoryEntry snapshot) async {
    final next = await _listeningHistoryService.recordPlay(snapshot);
    if (!mounted) return;
    setState(() => _listeningHistory = next);
  }

  Future<void> _saveCurrentHistoryPosition() async {
    final trackId = _manifest?.trackId ?? _metrics.currentTrackId ?? _selectedTrackId;
    if (trackId == null || trackId.isEmpty) return;
    final position = (_dragPositionMs ?? _metrics.currentPositionMs.toDouble()).round();
    final duration = _metrics.durationMs ?? _manifest?.durationMs;
    final next = await _listeningHistoryService.updatePosition(trackId, positionMs: position, durationMs: duration);
    if (!mounted) return;
    setState(() => _listeningHistory = next);
  }

  Future<void> _playHistoryEntry(WzListeningHistoryEntry entry, {bool autoPlay = true}) async {
    final resolved = _resolveHistoryEntry(entry);
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track is not available right now.')));
      return;
    }
    await _loadCatalogTrack(trackId: resolved.trackId, autoPlay: autoPlay, status: 'Loaded from listening history: ${resolved.title}');
    if (entry.lastPositionMs > 0) {
      await _seekTo(entry.lastPositionMs.toDouble());
    }
  }

  Future<void> _addHistoryEntryToQueue(WzListeningHistoryEntry entry) async {
    final resolved = _resolveHistoryEntry(entry);
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track is not available right now.')));
      return;
    }
    _addToQueue(resolved);
  }

  CatalogTrackSummary? _trackForSearchResult(WzSearchResult result) => result.track ?? (result.historyEntry == null ? null : _resolveHistoryEntry(result.historyEntry!));

  Future<void> _playSearchResult(WzSearchResult result) async {
    await _rememberSearchQuery(_fullSearchController.text);
    if (result.historyEntry != null) {
      await _playHistoryEntry(result.historyEntry!);
      return;
    }
    final track = _trackForSearchResult(result);
    if (track == null || !result.available) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track is not available right now.')));
      return;
    }
    await _loadCatalogTrack(trackId: track.trackId, autoPlay: true, status: 'Loaded from search: ${track.title}');
  }

  Future<void> _queueSearchResult(WzSearchResult result) async {
    await _rememberSearchQuery(_fullSearchController.text);
    if (result.historyEntry != null) {
      await _addHistoryEntryToQueue(result.historyEntry!);
      return;
    }
    final track = _trackForSearchResult(result);
    if (track == null || !result.available) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track is not available right now.')));
      return;
    }
    _addToQueue(track);
  }

  Future<void> _collectSearchResult(WzSearchResult result) async {
    await _rememberSearchQuery(_fullSearchController.text);
    if (result.historyEntry != null) {
      await _addHistoryEntryToCollection(result.historyEntry!);
      return;
    }
    final track = _trackForSearchResult(result);
    if (track == null || !result.available) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track is not available right now.')));
      return;
    }
    await _showAddToCollectionSheet(track);
  }

  Future<void> _openSearchCollection(WzSearchResult result) async {
    await _rememberSearchQuery(_fullSearchController.text);
    final collection = result.collection;
    if (collection != null) _openCollection(collection);
  }

  Future<void> _addHistoryEntryToCollection(WzListeningHistoryEntry entry) async {
    final resolved = _resolveHistoryEntry(entry);
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track is not available right now.')));
      return;
    }
    await _showAddToCollectionSheet(resolved);
  }

  Future<void> _removeHistoryEntry(WzListeningHistoryEntry entry) async {
    final next = await _listeningHistoryService.remove(entry.trackId);
    if (!mounted) return;
    setState(() => _listeningHistory = next);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Listening History')));
  }

  Future<void> _clearListeningHistory() async {
    await _listeningHistoryService.clear();
    if (!mounted) return;
    setState(() => _listeningHistory = const <WzListeningHistoryEntry>[]);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listening history cleared')));
  }

  Future<void> _toggleLikedTrack(CatalogTrackSummary track) async {
    final liked = _likedCollection;
    final exists = liked.tracks.any((entry) => entry.trackId == track.trackId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextTracks = exists
        ? liked.tracks.where((entry) => entry.trackId != track.trackId).toList(growable: false)
        : [...liked.tracks.where((entry) => entry.trackId != track.trackId), _snapshotForTrack(track)];
    final nextCollections = _collections
        .map((collection) => collection.id == liked.id ? collection.copyWith(updatedAtMs: now, tracks: nextTracks) : collection)
        .toList(growable: false);
    await _persistCollections(nextCollections);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exists ? 'Removed from Liked Tracks' : 'Added to Collection')));
  }

  Future<WzCollection> _createCollection({String name = 'New Collection'}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final collection = WzCollection(
      id: 'collection-$now',
      name: name.trim().isEmpty ? 'New Collection' : name.trim(),
      type: WzCollectionType.user,
      createdAtMs: now,
      updatedAtMs: now,
    );
    await _persistCollections([..._collections, collection]);
    return collection;
  }

  Future<void> _addTrackToCollection(WzCollection collection, CatalogTrackSummary track) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snapshot = _snapshotForTrack(track);
    final next = collection.tracks.where((entry) => entry.trackId != track.trackId).toList(growable: true)..add(snapshot);
    final nextCollections = _collections
        .map((item) => item.id == collection.id ? item.copyWith(updatedAtMs: now, tracks: next) : item)
        .toList(growable: false);
    await _persistCollections(nextCollections);
  }

  Future<void> _removeTrackFromCollection(WzCollection collection, WzCollectionTrackSnapshot track) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextCollections = _collections
        .map((item) => item.id == collection.id ? item.copyWith(updatedAtMs: now, tracks: item.tracks.where((entry) => entry.trackId != track.trackId).toList(growable: false)) : item)
        .toList(growable: false);
    await _persistCollections(nextCollections);
  }

  Future<void> _renameCollection(WzCollection collection, String name) async {
    if (collection.type == WzCollectionType.liked) return;
    final trimmed = name.trim().isEmpty ? 'My Collection' : name.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _persistCollections(_collections.map((item) => item.id == collection.id ? item.copyWith(name: trimmed, updatedAtMs: now) : item).toList(growable: false));
  }

  Future<void> _deleteCollection(WzCollection collection) async {
    if (collection.type == WzCollectionType.liked) return;
    await _persistCollections(_collections.where((item) => item.id != collection.id).toList(growable: false));
    if (!mounted) return;
    setState(() => _selectedCollectionId = likedTracksCollectionId);
  }

  Future<void> _showRenameCollectionDialog(WzCollection collection) async {
    final controller = TextEditingController(text: collection.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename collection'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Collection name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await _renameCollection(collection, name);
  }

  Future<void> _showDeleteCollectionDialog(WzCollection collection) async {
    if (collection.type == WzCollectionType.liked) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${collection.name}?'),
        content: const Text('This removes the collection only. Downloads, cache files, and device music stay on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await _deleteCollection(collection);
  }

  Future<void> _showAddToCollectionSheet(CatalogTrackSummary track) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add to collection', style: WzText.title),
              const SizedBox(height: WzSpacing.xs),
              Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.body),
              const SizedBox(height: WzSpacing.md),
              ..._collections.map((collection) => ListTile(
                    leading: Icon(collection.type == WzCollectionType.liked ? Icons.favorite : Icons.playlist_play),
                    title: Text(collection.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${collection.trackCount} tracks'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _addTrackToCollection(collection, track);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${collection.name}')));
                    },
                  )),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create New Collection'),
                subtitle: const Text('Creates “New Collection” and adds this track.'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final collection = await _createCollection();
                  await _addTrackToCollection(collection, track);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Collection')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createCollectionFromPage() async {
    final collection = await _createCollection(name: _userCollections.isEmpty ? 'My Collection' : 'New Collection');
    if (!mounted) return;
    setState(() {
      _selectedCollectionId = collection.id;
      _selectedTab = _AppTab.collectionDetail;
    });
  }

  void _openCollection(WzCollection collection) {
    setState(() {
      _selectedCollectionId = collection.id;
      _selectedTab = _AppTab.collectionDetail;
    });
  }

  Future<void> _playCollectionSnapshot(WzCollectionTrackSnapshot snapshot, {bool autoPlay = true}) async {
    final resolved = _resolveCollectionTrack(snapshot);
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track is not available right now.')));
      return;
    }
    await _loadCatalogTrack(trackId: resolved.trackId, autoPlay: autoPlay, status: 'Loaded from collection: ${resolved.title}');
  }

  Future<void> _addCollectionSnapshotToQueue(WzCollectionTrackSnapshot snapshot) async {
    final resolved = _resolveCollectionTrack(snapshot);
    if (resolved == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track is not available right now.')));
      return;
    }
    _addToQueue(resolved);
  }

  Future<void> _addCollectionToQueue(WzCollection collection) async {
    var added = 0;
    var unavailable = 0;
    for (final snapshot in collection.tracks) {
      final resolved = _resolveCollectionTrack(snapshot);
      if (resolved == null) {
        unavailable += 1;
      } else {
        final exists = _queue.any((item) => item.trackId == resolved.trackId);
        if (!exists) {
          _queue = [..._queue, resolved];
          added += 1;
        }
      }
    }
    if (added > 0) {
      setState(() {
        _queueCurrentTrackId ??= (_queue.isEmpty ? null : _queue.first.trackId);
        _queueStatus = 'Added $added tracks. $unavailable unavailable.';
        _sessionStatus = 'Session saved.';
      });
      unawaited(_saveSession());
      unawaited(_pushNotificationQueueSnapshot());
      unawaited(_updatePredictivePreloadCandidate());
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $added tracks. $unavailable unavailable.')));
  }

  Future<void> _loadAppMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_appModePreferenceKey);
    if (!mounted) return;
    setState(() {
      _appMode = savedMode == _AppMode.developer.name && widget.appConfig.showDeveloperEntry ? _AppMode.developer : _AppMode.consumer;
      if (_appMode == _AppMode.consumer && _selectedTab == _AppTab.engine) {
        _selectedTab = _AppTab.home;
      }
    });
  }

  Future<void> _setAppMode(_AppMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appModePreferenceKey, mode.name);
    if (!mounted) return;
    setState(() {
      _appMode = mode;
      if (mode == _AppMode.consumer && _selectedTab == _AppTab.engine) {
        _selectedTab = _AppTab.home;
      }
    });
    messenger.showSnackBar(
      SnackBar(content: Text(mode == _AppMode.developer ? 'Developer mode enabled' : 'Consumer mode enabled')),
    );
  }

  Future<void> _toggleAppMode() {
    return _setAppMode(_developerMode ? _AppMode.consumer : _AppMode.developer);
  }

  Future<void> _setShuffleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shufflePreferenceKey, enabled);
    if (!mounted) return;
    setState(() {
      _shuffleEnabled = enabled;
      _queueStatus = enabled ? 'Shuffle on.' : 'Shuffle off.';
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enabled ? 'Shuffle on' : 'Shuffle off')));
    unawaited(_updatePredictivePreloadCandidate());
  }

  Future<void> _cycleRepeatMode() => _setRepeatMode(_repeatMode.next);

  Future<void> _setRepeatMode(WzRepeatMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_repeatModePreferenceKey, mode.name);
    if (!mounted) return;
    setState(() {
      _repeatMode = mode;
      _queueStatus = mode.label;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mode.label)));
  }

  Future<void> _showSleepTimerPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: WzColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(WzSpacing.md, 0, WzSpacing.md, WzSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Sleep timer', style: WzText.title),
              const SizedBox(height: WzSpacing.xs),
              Text(_sleepTimerDeadline == null ? 'Pause playback after a selected time.' : _sleepTimerStatusLabel, style: WzText.caption),
              const SizedBox(height: WzSpacing.md),
              ..._SleepTimerPreset.values.map((preset) => ListTile(
                    leading: Icon(preset == _SleepTimerPreset.off ? Icons.timer_off : Icons.bedtime),
                    title: Text(preset == _SleepTimerPreset.off ? 'Sleep timer off' : preset.label),
                    trailing: _sleepTimerPreset == preset && (preset == _SleepTimerPreset.off || _sleepTimerDeadline != null) ? const Icon(Icons.check) : null,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_setSleepTimerPreset(preset));
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setSleepTimerPreset(_SleepTimerPreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sleepTimerPresetPreferenceKey, preset.name);
    _sleepTimer?.cancel();
    final duration = preset.duration;
    if (!mounted) return;
    if (duration == null) {
      setState(() {
        _sleepTimerPreset = _SleepTimerPreset.off;
        _sleepTimerDeadline = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sleep timer off')));
      return;
    }
    final deadline = DateTime.now().add(duration);
    setState(() {
      _sleepTimerPreset = preset;
      _sleepTimerDeadline = deadline;
    });
    _sleepTimer = Timer(duration, () => unawaited(_handleSleepTimerEnded()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sleep in ${duration.inMinutes}m')));
  }

  Future<void> _handleSleepTimerEnded() async {
    if (!mounted) return;
    setState(() {
      _sleepTimerPreset = _SleepTimerPreset.off;
      _sleepTimerDeadline = null;
      _queueStatus = 'Sleep timer ended.';
    });
    if (_metrics.isPlaying) {
      await widget.playbackBridge.pause();
      unawaited(_saveCurrentHistoryPosition());
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sleep timer ended')));
  }

  void _navigateTo(_AppTab tab) {
    if (tab == _AppTab.engine && !_developerMode) return;
    setState(() => _selectedTab = tab);
  }

  Future<void> _refreshDeviceMusicPermissionStatus() async {
    final status = await _deviceMusicService.getPermissionStatus();
    if (!mounted) return;
    setState(() {
      _deviceMusicPermissionStatus = status;
      if (status.message != null) _deviceMusicLastError = status.message;
    });
  }

  Future<void> _importDeviceMusic() async {
    if (_operation != PlayerOperation.idle) return;
    setState(() {
      _operation = PlayerOperation.loadingCatalog;
      _deviceMusicScanStatus = 'checking_permission';
      _deviceMusicLastError = null;
    });
    try {
      var permission = await _deviceMusicService.getPermissionStatus();
      if (!permission.isGranted) permission = await _deviceMusicService.requestPermission();
      if (!mounted) return;
      _deviceMusicPermissionStatus = permission;
      if (!permission.isGranted) {
        setState(() {
          _deviceMusicScanStatus = 'permission_denied';
          _deviceMusicLastError = permission.message ?? 'Audio permission is ${permission.status}.';
        });
        return;
      }

      setState(() => _deviceMusicScanStatus = 'scanning');
      final scan = await _deviceMusicService.scanDeviceAudioLibrary();
      if (!mounted) return;
      setState(() {
        _deviceMusicScanStatus = scan.status;
        _deviceMusicTracks = scan.tracks;
        _deviceMusicLastScanCount = scan.count;
        _deviceMusicLastError = scan.error;
        _deviceMusicImportedAtMs = scan.scannedAtMs ?? DateTime.now().millisecondsSinceEpoch;
        if (scan.tracks.isNotEmpty) _librarySourceFilter = _LibrarySourceFilter.device;
        _catalogStatus = scan.status == 'success'
            ? 'Imported ${scan.tracks.length} device music tracks from Android MediaStore.'
            : 'Device music scan ${scan.status}${scan.error == null ? '' : ': ${scan.error}'}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deviceMusicScanStatus = 'error';
        _deviceMusicLastError = error.toString();
      });
    } finally {
      if (mounted) setState(() => _operation = PlayerOperation.idle);
    }
  }

  Future<void> _initCache() async {
    try {
      await _cacheService.init();
      await _refreshCacheStats();
    } catch (_) {}
  }

  Future<void> _initAudioEffects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedProfile = parseAudioEffectProfile(prefs.getString(_audioEffectPreferenceKey));
      if (!mounted) return;
      setState(() {
        _selectedAudioEffectProfile = storedProfile;
        _nativeAudioEffectStatus = storedProfile == AudioEffectProfile.off
            ? NativeAudioEffectStatus.off
            : NativeAudioEffectStatus.pending;
        _lastAudioEffectApplyResult = storedProfile == AudioEffectProfile.off
            ? 'Audio effects are off; original playback is preserved.'
            : 'Restored ${storedProfile.label}; applying to native playback bridge.';
      });
      await _applyAudioEffectProfile(storedProfile, persist: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _nativeAudioEffectStatus = NativeAudioEffectStatus.failed;
        _lastAudioEffectApplyResult = 'Could not load audio effect preference: $error';
      });
    }
  }

  Future<void> _setAudioEffectProfile(AudioEffectProfile profile) async {
    if (_selectedAudioEffectProfile == profile && _nativeAudioEffectStatus != NativeAudioEffectStatus.failed) return;
    await _applyAudioEffectProfile(profile, persist: true);
  }

  Future<void> _applyAudioEffectProfile(AudioEffectProfile profile, {required bool persist}) async {
    if (!mounted) return;
    setState(() {
      _selectedAudioEffectProfile = profile;
      _nativeAudioEffectStatus = profile == AudioEffectProfile.off
          ? NativeAudioEffectStatus.off
          : NativeAudioEffectStatus.pending;
      _lastAudioEffectApplyResult = profile == AudioEffectProfile.off
          ? 'Turning audio effects off to preserve original playback.'
          : 'Applying ${profile.label} to native playback bridge...';
    });

    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_audioEffectPreferenceKey, profile.id);
      } catch (error) {
        if (mounted) {
          setState(() => _lastAudioEffectApplyResult = 'Effect selected but preference was not persisted: $error');
        }
      }
    }

    final applyResult = await widget.playbackBridge.setAudioEffectProfile(profile);
    if (!mounted) return;
    setState(() {
      _nativeAudioEffectStatus = applyResult.status;
      _lastAudioEffectApplyResult = applyResult.message;
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _sleepTimer?.cancel();
    _titleController.dispose();
    _urlController.dispose();
    _apiBaseUrlController.dispose();
    _searchController.dispose();
    _fullSearchController.dispose();
    super.dispose();
  }

  Future<void> _runOperation(PlayerOperation operation, Future<void> Function() body, {bool refreshAfter = true}) async {
    if (_operation != PlayerOperation.idle) return;
    setState(() {
      _operation = operation;
      _lastError = null;
    });
    try {
      await body();
      if (refreshAfter) await _refreshMetrics(allowAutoAdvance: false);
    } catch (error) {
      if (mounted) setState(() => _lastError = error.toString());
    } finally {
      if (mounted) setState(() => _operation = PlayerOperation.idle);
    }
  }

  Future<void> _refreshMetrics({bool allowAutoAdvance = true}) async {
    if (_refreshingMetrics) return;
    _refreshingMetrics = true;
    try {
      final next = await widget.playbackBridge.metricsSnapshot();
      if (!mounted) return;
      setState(() {
        _metrics = next;
        _capturePlaybackBaselineMetrics(next);
        _alignQueueWithNativeNotificationAction(next);
      });
      if (allowAutoAdvance) await _maybeAutoAdvance(next);
    } finally {
      _refreshingMetrics = false;
    }
  }

  void _alignQueueWithNativeNotificationAction(PlaybackMetrics metrics) {
    final trackId = metrics.currentTrackId ?? metrics.lastNotificationActionTrackId;
    if (trackId == null || trackId.isEmpty) return;
    final existsInQueue = _queue.any((track) => track.trackId == trackId);
    final existsInLibrary = _catalog.any((track) => track.trackId == trackId) || _cachedLibrary.any((track) => track.trackId == trackId) || _deviceMusicTracks.any((track) => track.trackId == trackId);
    if (!existsInQueue && !existsInLibrary) return;
    _selectedTrackId = trackId;
    if (existsInQueue) _queueCurrentTrackId = trackId;
    if (metrics.lastNotificationAction == 'next' || metrics.lastNotificationAction == 'previous') {
      _queueStatus = 'Notification ${metrics.lastNotificationAction} selected native track $trackId.';
    }
  }

  Future<void> _pushNotificationMetadata(CatalogTrackManifest manifest, {required String url, required String source}) async {
    await widget.playbackBridge.updateMediaNotificationMetadata(
      NotificationTrackSnapshot.fromManifest(manifest, url: url, source: source),
    );
    await _pushNotificationQueueSnapshot();
  }

  Future<void> _pushNotificationQueueSnapshot() {
    return widget.playbackBridge.updateNotificationQueueSnapshot(
      _queue.map(_notificationSnapshotForQueueTrack).where((track) => track.url.isNotEmpty).toList(growable: false),
    );
  }

  NotificationTrackSnapshot _notificationSnapshotForQueueTrack(CatalogTrackSummary track) {
    CachedTrackMetadata? cached;
    for (final entry in _cachedLibrary) {
      if (entry.trackId == track.trackId) {
        cached = entry;
        break;
      }
    }
    if (cached != null) {
      return NotificationTrackSnapshot(
        trackId: cached.trackId,
        title: cached.title,
        artistName: cached.artistName,
        url: cached.localFileUrl,
        artworkUrl: cached.artworkUrl,
        durationMs: cached.durationMs,
        source: 'cached',
        qualityLabel: cached.qualityLabel,
        codec: cached.codec,
      );
    }
    return NotificationTrackSnapshot.fromSummary(track);
  }

  Future<void> _refreshCacheStats() async {
    try {
      final bytes = await _cacheService.cacheBytes();
      final cachedLibrary = await _cacheService.cachedLibrary();
      if (!mounted) return;
      setState(() {
        _cachedTrackCount = _cacheService.cachedTrackCount();
        _cacheBytes = bytes;
        _cachedLibrary = cachedLibrary;
        _cachedTrackBytes = _cachedTrackSizeMap(cachedLibrary);
        _manualDownloadedCount = cachedLibrary.where((entry) => entry.downloadSource == 'manual').length;
        _smartDownloadedCount = cachedLibrary.where((entry) => entry.downloadSource.startsWith('smart_')).length;
        _offlineCachedTrackCount = cachedLibrary.length;
        _offlineLibraryAvailable = cachedLibrary.isNotEmpty;
        _lastCacheResult = _cacheService.lastCacheResult;
        _lastOfflineLibraryStatus = cachedLibrary.isNotEmpty
            ? 'Offline cached library ready with ${cachedLibrary.length} tracks.'
            : 'Offline library is empty.';
      });
    } catch (_) {}
  }

  bool get _isOfflineLibraryMode => _offlineLibraryMode;

  void _capturePlaybackBaselineMetrics(PlaybackMetrics metrics) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hasAudioSignal = metrics.isPlaying &&
        (metrics.tapToFirstAudioMs != null ||
            metrics.tapToPositionAdvanceMs != null ||
            metrics.currentPositionMs > 0);
    if (_nextTapStartedAtMs != null && _nextTapToAudioMs == null && hasAudioSignal) {
      _nextTapToAudioMs = now - _nextTapStartedAtMs!;
    }
    if (_stopRecoveryPlayStartedAtMs != null && _stopToPlayRecoveryMs == null && hasAudioSignal) {
      _stopToPlayRecoveryMs = now - _stopRecoveryPlayStartedAtMs!;
      _stopRecoveryPlayStartedAtMs = null;
      _lastStopAtMs = null;
    }
    _audioPreparedBeforeNext = _prefetchEnabled &&
        _prefetchedTrackId != null &&
        metrics.nativePrebufferTrackId == _prefetchedTrackId &&
        metrics.nativePrebufferReady;
    _nextPreparedBeforePlay = metrics.nextPreparedBeforePlay;
  }

  Future<void> _maybeAutoAdvance(PlaybackMetrics metrics) async {
    if (!_autoAdvanceEnabled || _operation != PlayerOperation.idle) return;
    final durationMs = metrics.durationMs ?? _manifest?.durationMs;
    if (durationMs == null || durationMs <= 0) return;
    final remainingMs = durationMs - metrics.currentPositionMs;
    final nearEnd = metrics.currentPositionMs > 0 && remainingMs <= _autoAdvanceThresholdMs;
    final ended = metrics.lastEvent == 'ended' || metrics.lastEvent == 'playback_ended';
    if (!nearEnd && !ended) {
      if (metrics.currentPositionMs < durationMs - (_autoAdvanceThresholdMs * 2)) _lastAutoAdvanceTrackId = null;
      return;
    }
    final id = _currentQueueTrack?.trackId ?? _queueCurrentTrackId ?? _selectedTrackId;
    if (id == null || id == _lastAutoAdvanceTrackId) return;
    _lastAutoAdvanceTrackId = id;

    if (_repeatMode == WzRepeatMode.one) {
      setState(() => _queueStatus = 'Repeat one: replaying current track.');
      await _seekTo(0);
      await widget.playbackBridge.play();
      return;
    }
    if (_shuffleEnabled && await _playRandomQueueTrack(autoStart: true, source: QueueAdvanceSource.auto)) return;
    if (_canNext) {
      await _playNext(autoStart: true, source: QueueAdvanceSource.auto, allowShuffle: false);
      return;
    }
    if (_repeatMode == WzRepeatMode.all && _queue.isNotEmpty) {
      await _playQueueTrack(_queue.first, autoStart: true, source: QueueAdvanceSource.auto);
    }
  }

  // Predictive Smart Downloads helpers
  Future<bool> _canAutoCacheTrack({required String trackId, required String? url}) async {
    if (!_smartDownloadsEnabled) {
      _lastSmartDownloadReason = 'smart downloads disabled';
      return false;
    }
    if (url == null || url.isEmpty) {
      _lastSmartDownloadReason = 'no remote url';
      return false;
    }
    if (_isDeviceTrackId(trackId) || _isDeviceUrl(url)) {
      _lastSmartDownloadReason = 'device local track already local';
      return false;
    }
    await _cacheService.ensureInitialized();
    final status = _cacheService.statusForTrack(trackId);
    if (status == TrackCacheStatus.cached) {
      _lastSmartDownloadReason = 'already cached';
      return false;
    }
    if (status == TrackCacheStatus.caching) {
      _lastSmartDownloadReason = 'already caching';
      return false;
    }
    if (_autoCacheInFlight.contains(trackId)) {
      _lastSmartDownloadReason = 'already in-flight';
      return false;
    }
    final cachedLibrary = await _cacheService.cachedLibrary();
    if (cachedLibrary.length >= _maxSmartDownloadCachedTracks) {
      _lastSmartDownloadReason = 'smart download cache limit reached';
      return false;
    }
    return true;
  }

  Future<void> _autoCacheTrack({required String trackId, required String url, required String title, String? artistName, int? durationMs, String? artworkUrl, String reason = 'auto', String downloadSource = 'unknown', String qualityLabel = 'unknown', String? codec, int? bitrateKbps}) async {
    // Gatekeeper checks: do not early-return before updating diagnostics.
    if (!_smartDownloadsEnabled) {
      _lastSmartDownloadReason = 'smart downloads disabled';
      if (mounted) setState(() => _smartDownloadSkippedCount += 1);
      return;
    }
    if (url.isEmpty) {
      _lastSmartDownloadReason = 'no remote url';
      if (mounted) setState(() => _smartDownloadSkippedCount += 1);
      return;
    }
    if (_isDeviceTrackId(trackId) || _isDeviceUrl(url)) {
      _lastSmartDownloadReason = 'device local track already local';
      if (mounted) setState(() => _smartDownloadSkippedCount += 1);
      return;
    }
    await _cacheService.ensureInitialized();
    final status = _cacheService.statusForTrack(trackId);
    if (status == TrackCacheStatus.cached) {
      _lastSmartDownloadReason = 'already cached';
      if (mounted) setState(() => _smartDownloadSkippedCount += 1);
      return;
    }
    if (status == TrackCacheStatus.caching) {
      _lastSmartDownloadReason = 'already caching';
      if (mounted) setState(() => _smartDownloadSkippedCount += 1);
      return;
    }
    if (_autoCacheInFlight.contains(trackId)) {
      _lastSmartDownloadReason = 'already in-flight';
      if (mounted) setState(() => _smartDownloadSkippedCount += 1);
      return;
    }
    final cachedLibrary = await _cacheService.cachedLibrary();
    if (cachedLibrary.length >= _maxSmartDownloadCachedTracks) {
      _lastSmartDownloadReason = 'smart download cache limit reached';
      if (mounted) setState(() => _smartDownloadSkippedCount += 1);
      return;
    }
    _autoCacheInFlight.add(trackId);
    _smartDownloadStartedCount += 1;
    _lastSmartDownloadTrackId = trackId;
    _lastSmartDownloadTitle = title;
    _lastSmartDownloadReason = reason;
    if (mounted) setState(() {});
    try {
      final ok = await _cacheService.downloadAndCache(
        trackId,
        url,
        metadata: CachedTrackMetadata(
          trackId: trackId,
          title: title,
          artistName: artistName,
          durationMs: durationMs,
          artworkUrl: artworkUrl,
          localFilePath: '',
          originalRemoteUrl: url,
          cachedAt: DateTime.now().millisecondsSinceEpoch,
          downloadSource: downloadSource,
          qualityLabel: qualityLabel,
          codec: codec,
          bitrateKbps: bitrateKbps,
        ),
      );
      _lastSmartDownloadResult = ok ? 'cached' : 'error';
      if (ok) {
        _smartDownloadCompletedCount += 1;
      } else {
        _smartDownloadFailedCount += 1;
      }
    } catch (error) {
      _lastSmartDownloadResult = 'error:${error.toString()}';
      _smartDownloadFailedCount += 1;
    } finally {
      _autoCacheInFlight.remove(trackId);
      unawaited(_refreshCacheStats());
      if (mounted) setState(() {});
    }
  }

  Future<void> _maybeAutoCacheCurrentTrack(CatalogTrackManifest manifest) async {
    if (manifest.trackId.isEmpty) return;
    if (_isDeviceTrackId(manifest.trackId) || _isDeviceUrl(manifest.streamUrl)) {
      _lastSmartDownloadReason = 'device local track already local';
      if (mounted) setState(() => _smartDownloadSkippedCount += 1);
      return;
    }
    unawaited(_autoCacheTrack(
      trackId: manifest.trackId,
      url: manifest.streamUrl,
      title: manifest.title,
      artistName: manifest.artistName,
      durationMs: manifest.durationMs,
      artworkUrl: manifest.artworkUrl,
      qualityLabel: manifest.qualityLabel ?? 'unknown',
      codec: manifest.codec,
      bitrateKbps: manifest.bitrateKbps,
      reason: 'current_played',
      downloadSource: 'smart_current',
    ));
  }

  Future<void> _maybeAutoCacheNextQueuedTrack() async {
    final next = _upNextQueueTrack;
    if (next == null) return;
    if (_isDeviceCatalogTrack(next)) {
      _lastSmartDownloadReason = 'device local track already local';
      if (mounted) setState(() => _smartDownloadSkippedCount += 1);
      return;
    }
    final selection = choosePreferredAsset(next, _preferredAudioQuality);
    final selectedAsset = selection?.asset;
    final assetUrl = selectedAsset?.manifestUrl;
    if (assetUrl != null && assetUrl.isNotEmpty) {
      unawaited(_autoCacheTrack(
        trackId: next.trackId,
        url: assetUrl,
        title: next.title,
        artistName: next.artistName,
        durationMs: next.durationMs,
        artworkUrl: next.artworkUrl,
        reason: 'up_next: ${selection?.fallbackReason ?? 'quality unknown'}',
        downloadSource: 'smart_up_next',
        qualityLabel: selectedAsset?.qualityLabel ?? 'unknown',
        codec: selectedAsset?.codec,
        bitrateKbps: selectedAsset?.bitrateKbps,
      ));
      return;
    }
    // fallback: try to fetch manifest to find a streamUrl
    final client = CatalogClient(baseUrl: _apiBaseUrlController.text);
    try {
      final manifest = await client.fetchTrackManifest(trackId: next.trackId);
      final url2 = manifest.streamUrl;
      if (url2 != null && url2.isNotEmpty) {
        unawaited(_autoCacheTrack(trackId: manifest.trackId, url: url2, title: manifest.title, artistName: manifest.artistName, durationMs: manifest.durationMs, artworkUrl: manifest.artworkUrl, reason: 'up_next_fetched', downloadSource: 'smart_up_next', qualityLabel: manifest.qualityLabel ?? 'unknown', codec: manifest.codec, bitrateKbps: manifest.bitrateKbps));
      }
    } catch (_) {
      // manifest fetch failed — mark skip reason once
      _lastSmartDownloadReason = 'up-next manifest unavailable';
      if (mounted) setState(() => _smartDownloadSkippedCount += 1);
    } finally {
      client.close();
    }
  }

  CatalogTrackManifest? _qualityAwareManifestForTrack(String trackId, String fallbackReasonPrefix) {
    final track = _findTrack(_catalog, trackId);
    if (track == null) return null;
    final selection = choosePreferredAsset(track, _preferredAudioQuality);
    if (selection == null) return null;
    _lastQualityFallbackReason = '$fallbackReasonPrefix: ${selection.fallbackReason}';
    return CatalogTrackManifest(
      trackId: track.trackId,
      title: track.title,
      streamUrl: selection.asset.manifestUrl,
      artistId: track.artistId,
      artistName: track.artistName,
      durationMs: track.durationMs,
      artworkUrl: track.artworkUrl,
      assetId: selection.asset.assetId,
      qualityLabel: selection.asset.qualityLabel,
      codec: selection.asset.codec,
      bitrateKbps: selection.asset.bitrateKbps,
      sampleRateHz: selection.asset.sampleRateHz,
      bitDepth: selection.asset.bitDepth,
      fileSizeBytes: selection.asset.fileSizeBytes,
    );
  }

  Future<void> _loadCatalog({bool fallbackToDemo = false}) {
    return _runOperation(PlayerOperation.loadingCatalog, () async {
      final client = CatalogClient(baseUrl: _apiBaseUrlController.text);
      try {
        setState(() => _catalogStatus = 'Loading catalog...');
        ContentStatus? contentStatus;
        try {
          contentStatus = await client.fetchContentStatus();
        } catch (_) {
          contentStatus = null;
        }
        final catalog = await client.fetchCatalog();
        ContentStatus? contentStatus;
        try {
          contentStatus = await client.fetchContentStatus();
        } catch (_) {
          contentStatus = null;
        }
        final restored = await _restoreSession(catalog.tracks);
        final preferred = _findTrack(catalog.tracks, restored?.currentTrackId) ??
            _findTrack(catalog.tracks, restored?.selectedTrackId) ??
            _findTrack(catalog.tracks, _selectedTrackId) ??
            (catalog.tracks.isEmpty ? null : catalog.tracks.first);
        if (!mounted) return;
        setState(() {
          _catalog = catalog.tracks;
          _queue = restored == null ? (_queue.isEmpty ? catalog.tracks : _queue) : _queueFromSnapshot(catalog.tracks, restored);
          if (_queue.isEmpty) _queue = catalog.tracks;
          _selectedTrackId = preferred?.trackId;
          _queueCurrentTrackId = restored?.currentTrackId ?? preferred?.trackId;
          _autoAdvanceEnabled = restored?.autoAdvanceEnabled ?? _autoAdvanceEnabled;
          _contentStatus = contentStatus;
          _catalogStatus = catalog.tracks.isEmpty
              ? 'Catalog is empty.'
              ? 'Catalog unavailable'
              : contentStatus?.friendlyLabel ?? _catalogModeLabel(catalog.contentMode, catalog.tracks.length);
          _queueStatus = restored == null ? 'Queue synced with catalog.' : 'Queue restored from previous session.';
          _sessionStatus = restored == null ? 'No saved queue yet.' : 'Recovered ${_queue.length} queued tracks.';
          _offlineLibraryMode = false;
        });
        if (preferred == null) throw const FormatException('Catalog API returned no playable tracks');
        await _loadManifestAndNativeTrack(preferred.trackId, client: client);
        unawaited(_saveSession());
      } catch (error) {
        if (!mounted) return;
        final offlineLibrary = await _cacheService.cachedLibrary();
        if (offlineLibrary.isNotEmpty) {
          final offlineTracks = offlineLibrary
              .map((entry) => CatalogTrackSummary(
                    trackId: entry.trackId,
                    title: entry.title,
                    artistId: null,
                    artistName: entry.artistName,
                    durationMs: entry.durationMs,
                    artworkUrl: entry.artworkUrl,
                    primaryAsset: CatalogTrackAssetSummary(
                      assetId: 'cached-${entry.trackId}',
                      manifestUrl: entry.originalRemoteUrl,
                      qualityLabel: entry.qualityLabel,
                      codec: entry.codec,
                      bitrateKbps: entry.bitrateKbps,
                    ),
                  ))
              .toList(growable: false);
          setState(() {
            _lastError = error.toString();
            _contentStatus = null;
            _catalog = offlineTracks;
            _queue = offlineTracks;
            _selectedTrackId = offlineTracks.first.trackId;
            _queueCurrentTrackId = offlineTracks.first.trackId;
            _catalogStatus = 'Catalog unavailable. Showing offline cached library.';
            _queueStatus = 'Offline cache available. Choose a cached track to play.';
            _sessionStatus = '${offlineTracks.length} cached tracks available offline.';
            _offlineCachedTrackCount = offlineLibrary.length;
            _offlineLibraryAvailable = true;
            _offlineLibraryMode = true;
            _lastOfflineLibraryStatus = 'Offline cached library loaded.';
            _contentStatus = null;
          });
        } else {
          setState(() {
            _lastError = error.toString();
            _catalogStatus = fallbackToDemo ? 'Catalog unavailable. Using local demo track.' : WaveZeroReleaseCopy.catalogUnavailable;
            _contentStatus = null;
            _catalogStatus = fallbackToDemo ? 'Catalog unavailable. Using local demo track. $error' : 'Catalog load failed. $error';
            _offlineCachedTrackCount = 0;
            _offlineLibraryAvailable = false;
            _offlineLibraryMode = false;
            _lastOfflineLibraryStatus = 'Offline library empty.';
            _contentStatus = null;
          });
          if (fallbackToDemo) {
            await widget.playbackBridge.loadTrack(title: waveZeroTestTrack.title, url: waveZeroTestTrack.url);
            await widget.playbackBridge.updateMediaNotificationMetadata(
              NotificationTrackSnapshot(title: waveZeroTestTrack.title, artistName: 'WaveZero', url: waveZeroTestTrack.url, source: 'manual'),
            );
          }
        }
      } finally {
        client.close();
      }
    });
  }

  Future<QueueSessionSnapshot?> _restoreSession(List<CatalogTrackSummary> catalogTracks) async {
    if (_sessionRestored) return null;
    _sessionRestored = true;
    final snapshot = await widget.sessionStore.load();
    _sessionRecoveryMs ??= _elapsedSince(_sessionRecoveryStartedAtMs);
    if (snapshot == null) return null;
    final validIds = catalogTracks.map((track) => track.trackId).toSet();
    final restoredIds = snapshot.queueTrackIds.where(validIds.contains).toList(growable: false);
    if (restoredIds.isEmpty && snapshot.currentTrackId == null && snapshot.selectedTrackId == null) return null;
    return QueueSessionSnapshot(
      queueTrackIds: restoredIds,
      currentTrackId: validIds.contains(snapshot.currentTrackId) ? snapshot.currentTrackId : null,
      selectedTrackId: validIds.contains(snapshot.selectedTrackId) ? snapshot.selectedTrackId : null,
      autoAdvanceEnabled: snapshot.autoAdvanceEnabled,
    );
  }

  int? _elapsedSince(int? startedAtMs) {
    if (startedAtMs == null) return null;
    return DateTime.now().millisecondsSinceEpoch - startedAtMs;
  }

  List<CatalogTrackSummary> _queueFromSnapshot(List<CatalogTrackSummary> catalogTracks, QueueSessionSnapshot snapshot) {
    final byId = {for (final track in catalogTracks) track.trackId: track};
    return snapshot.queueTrackIds.map((id) => byId[id]).whereType<CatalogTrackSummary>().toList(growable: false);
  }

  List<CatalogTrackSummary> _sortLibraryTracks(List<CatalogTrackSummary> tracks) {
    final indexed = tracks.indexed.toList(growable: false);
    int compareNullableString(String? a, String? b) {
      final left = (a == null || a.trim().isEmpty) ? '~' : a.trim().toLowerCase();
      final right = (b == null || b.trim().isEmpty) ? '~' : b.trim().toLowerCase();
      return left.compareTo(right);
    }

    int compareNullableDuration(int? a, int? b, {required bool longestFirst}) {
      final left = a ?? (longestFirst ? -1 : 1 << 30);
      final right = b ?? (longestFirst ? -1 : 1 << 30);
      return longestFirst ? right.compareTo(left) : left.compareTo(right);
    }

    int addedRank(CatalogTrackSummary track) {
      final cached = _cachedMetadataForTrack(track);
      if (cached != null) return cached.cachedAt;
      if (_isDeviceCatalogTrack(track)) return _deviceMusicImportedAtMs ?? 0;
      return 0;
    }

    int compare((int, CatalogTrackSummary) a, (int, CatalogTrackSummary) b) {
      final left = a.$2;
      final right = b.$2;
      final result = switch (_librarySortMode) {
        _LibrarySortMode.recentlyAdded => addedRank(right).compareTo(addedRank(left)),
        _LibrarySortMode.titleAz => compareNullableString(left.title, right.title),
        _LibrarySortMode.artistAz => compareNullableString(left.artistName ?? left.albumName, right.artistName ?? right.albumName),
        _LibrarySortMode.longestDuration => compareNullableDuration(left.durationMs, right.durationMs, longestFirst: true),
        _LibrarySortMode.shortestDuration => compareNullableDuration(left.durationMs, right.durationMs, longestFirst: false),
        _LibrarySortMode.quality => compareNullableString(left.primaryAsset?.qualityLabel, right.primaryAsset?.qualityLabel),
      };
      return result == 0 ? a.$1.compareTo(b.$1) : result;
    }

    indexed.sort(compare);
    return indexed.map((entry) => entry.$2).toList(growable: false);
  }

  CachedTrackMetadata? _cachedMetadataForTrack(CatalogTrackSummary track) {
    for (final entry in _cachedLibrary) {
      if (entry.trackId == track.trackId) return entry;
    }
    return null;
  }

  Future<void> _saveSession() {
    return widget.sessionStore.save(
      QueueSessionSnapshot(
        queueTrackIds: _queue.map((track) => track.trackId).toList(growable: false),
        currentTrackId: _queueCurrentTrackId,
        selectedTrackId: _selectedTrackId,
        autoAdvanceEnabled: _autoAdvanceEnabled,
      ),
    );
  }

  DeviceMusicTrack? _findDeviceTrack(String? trackId) {
    if (trackId == null) return null;
    for (final track in _deviceMusicTracks) {
      if (track.trackId == trackId) return track;
    }
    return null;
  }

  CatalogTrackManifest _deviceManifest(DeviceMusicTrack track) {
    return CatalogTrackManifest(
      trackId: track.trackId,
      title: track.title,
      streamUrl: track.contentUri,
      artistId: null,
      artistName: track.artistName,
      durationMs: track.durationMs,
      artworkUrl: track.artworkUri,
      assetId: 'device-${track.trackId}',
      qualityLabel: track.qualityLabel ?? 'unknown',
      codec: track.codec,
      bitrateKbps: track.bitrateKbps,
      fileSizeBytes: track.sizeBytes,
    );
  }

  Future<void> _loadDeviceMusicTrack(DeviceMusicTrack track, {bool autoPlay = false, PlayerOperation operation = PlayerOperation.loadingTrack, String? status}) {
    return _runOperation(operation, () async {
      await _clearNativeNextPrebuffer();
      if (!mounted) return;
      final manifest = _deviceManifest(track);
      _titleController.text = manifest.title;
      _urlController.text = manifest.streamUrl;
      setState(() {
        _manifest = manifest;
        _selectedTrackId = manifest.trackId;
        _queueCurrentTrackId = manifest.trackId;
        _lastAutoAdvanceTrackId = manifest.trackId;
        _currentAssetUrl = manifest.streamUrl;
        _currentCachedQuality = null;
        _catalogStatus = status ?? 'Loaded device music track: ${manifest.title}';
        _lastQualityFallbackReason = 'device music: using MediaStore ${manifest.qualityLabel ?? 'unknown'} metadata';
        _lastSmartDownloadReason = 'device local track already local';
      });
      await widget.playbackBridge.loadTrack(title: manifest.title, url: manifest.streamUrl);
      await _pushNotificationMetadata(manifest, url: manifest.streamUrl, source: 'device');
      unawaited(_recordListeningHistory(_historySnapshotForManifest(
        manifest,
        source: WzListeningHistorySource.device,
        playableUrl: manifest.streamUrl,
      )));
      if (autoPlay) await widget.playbackBridge.play();
      unawaited(_saveSession());
      unawaited(_updatePredictivePreloadCandidate());
      unawaited(_maybeAutoCacheNextQueuedTrack());
    });
  }

  Future<void> _loadCatalogTrack({String? trackId, bool autoPlay = false, PlayerOperation operation = PlayerOperation.loadingTrack, String? status, CatalogTrackManifest? prefetchedManifest}) {
    unawaited(_saveCurrentHistoryPosition());
    final id = trackId ?? _selectedTrackId ?? (_catalog.isNotEmpty ? _catalog.first.trackId : null);
    if (id == null) return Future<void>.value();
    final deviceTrack = _findDeviceTrack(id);
    if (deviceTrack != null) {
      return _loadDeviceMusicTrack(deviceTrack, autoPlay: autoPlay, operation: operation, status: status);
    }
    return _runOperation(operation, () async {
      final client = CatalogClient(baseUrl: _apiBaseUrlController.text);
      try {
        await _loadManifestAndNativeTrack(id, client: client, autoPlay: autoPlay, status: status, prefetchedManifest: prefetchedManifest);
        unawaited(_saveSession());
      } finally {
        client.close();
      }
    });
  }

  Future<void> _loadManifestAndNativeTrack(String trackId, {required CatalogClient client, bool autoPlay = false, String? status, CatalogTrackManifest? prefetchedManifest}) async {
    if (!mounted) return;
    await _clearNativeNextPrebuffer();
    if (!mounted) return;
    setState(() {
      _catalogStatus = 'Loading catalog manifest...';
      _selectedTrackId = trackId;
      _queueCurrentTrackId = trackId;
      _lastAutoAdvanceTrackId = trackId;
    });
    CatalogTrackManifest manifest;
    final qualityAwareManifest = _qualityAwareManifestForTrack(trackId, 'playback');
    if (prefetchedManifest?.trackId == trackId) {
      manifest = prefetchedManifest!;
      _lastQualityFallbackReason = 'playback: using prefetched ${manifest.qualityLabel ?? 'unknown'} asset';
    } else if (qualityAwareManifest != null) {
      manifest = qualityAwareManifest;
    } else {
      final cachedMetadata = await _cacheService.cachedTrackById(trackId);
      if (_isOfflineLibraryMode && cachedMetadata != null) {
        manifest = CatalogTrackManifest(
          trackId: cachedMetadata.trackId,
          title: cachedMetadata.title,
          streamUrl: cachedMetadata.originalRemoteUrl,
          artistId: null,
          artistName: cachedMetadata.artistName,
          durationMs: cachedMetadata.durationMs,
          artworkUrl: cachedMetadata.artworkUrl,
          qualityLabel: cachedMetadata.qualityLabel,
          codec: cachedMetadata.codec,
          bitrateKbps: cachedMetadata.bitrateKbps,
        );
        _lastQualityFallbackReason = 'offline cache: using remembered ${cachedMetadata.qualityLabel} quality';
        if (mounted) {
          setState(() {
            _catalogStatus = 'Loaded offline cached track: ${manifest.title}';
          });
        }
      } else {
        try {
          manifest = await client.fetchTrackManifest(trackId: trackId);
          _lastQualityFallbackReason = 'catalog manifest: API primary asset used';
        } catch (error) {
          if (cachedMetadata != null) {
            manifest = CatalogTrackManifest(
              trackId: cachedMetadata.trackId,
              title: cachedMetadata.title,
              streamUrl: cachedMetadata.originalRemoteUrl,
              artistId: null,
              artistName: cachedMetadata.artistName,
              durationMs: cachedMetadata.durationMs,
              artworkUrl: cachedMetadata.artworkUrl,
              qualityLabel: cachedMetadata.qualityLabel,
              codec: cachedMetadata.codec,
              bitrateKbps: cachedMetadata.bitrateKbps,
            );
            _lastQualityFallbackReason = 'offline cache fallback: using remembered ${cachedMetadata.qualityLabel} quality';
            if (mounted) {
              setState(() {
                _catalogStatus = 'Loaded offline cached track: ${manifest.title}';
              });
            }
          } else {
            rethrow;
          }
        }
      }
    }
    if (!mounted) return;
    _titleController.text = manifest.title;
    _urlController.text = manifest.streamUrl;
    setState(() {
      _manifest = manifest;
      _selectedTrackId = manifest.trackId;
      _queueCurrentTrackId = manifest.trackId;
      _currentAssetUrl = manifest.streamUrl;
      _currentCachedQuality = null;
      _catalogStatus = status ?? (_catalogStatus.startsWith('Loaded offline') ? _catalogStatus : 'Loaded from catalog API: ${manifest.title}');
    });
    final cachedMetadata = await _cacheService.cachedTrackById(manifest.trackId);
    final resolvedUrl = await _cacheService.cachedOrRemoteUrlForAsset(
      trackId: manifest.trackId,
      remoteUrl: manifest.streamUrl,
      qualityLabel: manifest.qualityLabel,
    );
    if (mounted && resolvedUrl.startsWith('file://')) {
      setState(() => _currentCachedQuality = cachedMetadata?.qualityLabel ?? 'unknown');
    }
    await widget.playbackBridge.loadTrack(title: manifest.title, url: resolvedUrl);
    final historySource = resolvedUrl.startsWith('file://') ? WzListeningHistorySource.cached : WzListeningHistorySource.api;
    await _pushNotificationMetadata(manifest, url: resolvedUrl, source: historySource.name);
    unawaited(_recordListeningHistory(_historySnapshotForManifest(
      manifest,
      source: historySource,
      playableUrl: resolvedUrl,
    )));
    unawaited(_refreshCacheStats());
    if (autoPlay) await widget.playbackBridge.play();
    if (_nextTapStartedAtMs != null && _queueCurrentTrackId == manifest.trackId) {
      setState(() {
        _nextTapToAudioMs = null;
        _nextPreparedBeforePlay = false;
      });
    }
    unawaited(_updatePredictivePreloadCandidate());
    // Schedule smart downloads for current and next queued tracks
    unawaited(_maybeAutoCacheCurrentTrack(manifest));
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }

  void _clearNextPlaybackAttemptMetrics() {
    _nextTapStartedAtMs = null;
    _nextTapToAudioMs = null;
    _nextPreparedBeforePlay = false;
  }

  void _clearFlutterPrebufferState({bool invalidateInFlight = true}) {
    if (invalidateInFlight) _prefetchGeneration++;
    _prefetchedTrackId = null;
    _prefetchedTrackTitle = null;
    _prefetchedManifest = null;
    _prefetchInFlight = false;
    _manifestPrefetched = false;
    _smartQueueCandidateTrackId = null;
    _smartQueueReason = SmartQueueReason.queueEmpty;
    _audioPreparedBeforeNext = false;
    _nextPreparedBeforePlay = false;
  }

  Future<void> _clearNativeNextPrebuffer({bool clearFlutterState = true}) async {
    await widget.playbackBridge.clearNextTrackPrebuffer();
    if (!mounted || !clearFlutterState) return;
    setState(() => _clearFlutterPrebufferState());
  }

  void _setPrefetchEnabled(bool value) {
    setState(() {
      _prefetchEnabled = value;
      if (!value) {
        _clearFlutterPrebufferState();
        _smartQueueReason = SmartQueueReason.smartPreloadOff;
      }
      _queueStatus = value ? 'Smart preload enabled.' : 'Smart preload disabled.';
    });
    if (value) {
      unawaited(_updatePredictivePreloadCandidate());
    } else {
      unawaited(_clearNativeNextPrebuffer().then((_) {
        if (mounted) setState(() => _smartQueueReason = SmartQueueReason.smartPreloadOff);
      }));
    }
  }

  Future<void> _updatePredictivePreloadCandidate() async {
    final decision = _smartQueueDecision();
    final candidate = decision.candidate;
    if (!mounted) return;
    setState(() {
      _smartQueueCandidateTrackId = candidate?.trackId;
      _smartQueueReason = decision.reason;
    });

    if (candidate == null) {
      await _clearNativeNextPrebuffer();
      if (!mounted) return;
      setState(() {
        _smartQueueCandidateTrackId = null;
        _smartQueueReason = decision.reason;
      });
      return;
    }

    final nativeCandidateId = _metrics.nativePrebufferTrackId;
    final sameFlutterCandidate = _prefetchedTrackId == candidate.trackId;
    final sameNativeCandidate = nativeCandidateId == candidate.trackId;
    if (decision.reason == SmartQueueReason.alreadyPrepared ||
        (sameFlutterCandidate && (_prefetchInFlight || (_prefetchedManifest != null && sameNativeCandidate)))) {
      return;
    }

    final previousNativeCandidateId = nativeCandidateId ?? _prefetchedTrackId;
    if (previousNativeCandidateId != null && previousNativeCandidateId != candidate.trackId) {
      await _clearNativeNextPrebuffer();
      final nextDecision = _smartQueueDecision();
      if (!mounted || !nextDecision.hasCandidate || nextDecision.candidateTrackId != candidate.trackId) return;
      setState(() {
        _smartQueueCandidateTrackId = candidate.trackId;
        _smartQueueReason = SmartQueueReason.candidateChanged;
      });
    }

    final generation = ++_prefetchGeneration;
    setState(() {
      _prefetchInFlight = true;
      _prefetchedTrackId = candidate.trackId;
      _prefetchedTrackTitle = candidate.title;
      _prefetchedManifest = null;
      _manifestPrefetched = false;
      _smartQueueCandidateTrackId = candidate.trackId;
      _audioPreparedBeforeNext = false;
    });

    final client = CatalogClient(baseUrl: _apiBaseUrlController.text);
    try {
      final manifest = _qualityAwareManifestForTrack(candidate.trackId, 'preload') ?? await client.fetchTrackManifest(trackId: candidate.trackId);
      final latestDecision = _smartQueueDecision();
      if (!mounted || generation != _prefetchGeneration || !latestDecision.hasCandidate || latestDecision.candidateTrackId != candidate.trackId) return;
      setState(() {
        _prefetchedTrackId = manifest.trackId;
        _prefetchedTrackTitle = manifest.title;
        _prefetchedManifest = manifest;
        _prefetchInFlight = false;
        _manifestPrefetched = true;
        _smartQueueCandidateTrackId = manifest.trackId;
        _smartQueueReason = latestDecision.reason;
        _audioPreparedBeforeNext = false;
      });
      try {
        await widget.playbackBridge.prepareNextTrack(
          trackId: manifest.trackId,
          title: manifest.title,
          url: manifest.streamUrl,
        );
      } catch (error) {
        if (!mounted || generation != _prefetchGeneration) return;
        await _clearNativeNextPrebuffer();
      }
    } catch (error) {
      if (!mounted || generation != _prefetchGeneration) return;
      setState(() {
        _prefetchInFlight = false;
        _manifestPrefetched = false;
        _audioPreparedBeforeNext = false;
      });
      await _clearNativeNextPrebuffer();
    } finally {
      client.close();
    }
  }

  Future<void> _loadManualTrack() {
    return _runOperation(PlayerOperation.loadingManualTrack, () async {
      await _clearNativeNextPrebuffer();
      final title = _titleController.text.trim().isEmpty ? waveZeroTestTrack.title : _titleController.text.trim();
      final url = _urlController.text.trim();
      await widget.playbackBridge.loadTrack(title: title, url: url);
      await widget.playbackBridge.updateMediaNotificationMetadata(
        NotificationTrackSnapshot(title: title, artistName: 'WaveZero', url: url, source: 'manual'),
      );
      if (mounted) setState(() => _catalogStatus = 'Manual track loaded.');
    });
  }

  Future<void> _playPause() {
    return _runOperation(PlayerOperation.playbackCommand, () async {
      if (_metrics.isPlaying) {
        await _saveCurrentHistoryPosition();
        await widget.playbackBridge.pause();
      } else {
        if (_lastStopAtMs != null) {
          setState(() {
            _stopRecoveryPlayStartedAtMs = DateTime.now().millisecondsSinceEpoch;
            _stopToPlayRecoveryMs = null;
          });
        }
        await widget.playbackBridge.play();
      }
    });
  }

  Future<void> _stop() => _runOperation(PlayerOperation.playbackCommand, () async {
        await _saveCurrentHistoryPosition();
        await widget.playbackBridge.stop();
        if (!mounted) return;
        setState(() {
          _lastStopAtMs = DateTime.now().millisecondsSinceEpoch;
          _stopRecoveryPlayStartedAtMs = null;
          _stopToPlayRecoveryMs = null;
          _clearNextPlaybackAttemptMetrics();
          _clearFlutterPrebufferState();
        });
      });

  Future<void> _retry() => _runOperation(PlayerOperation.playbackCommand, () async {
        await widget.playbackBridge.retry();
        if (!mounted) return;
        setState(() => _clearFlutterPrebufferState());
      });
  Future<void> _seekTo(double positionMs) => _runOperation(PlayerOperation.seeking, () async {
        final target = positionMs.round();
        await widget.playbackBridge.seekTo(target);
        final trackId = _manifest?.trackId ?? _metrics.currentTrackId ?? _selectedTrackId;
        if (trackId != null && trackId.isNotEmpty) {
          final next = await _listeningHistoryService.updatePosition(trackId, positionMs: target, durationMs: _metrics.durationMs ?? _manifest?.durationMs);
          if (mounted) setState(() => _listeningHistory = next);
        }
      });

  Future<void> _copyMetrics() {
    return _runOperation(PlayerOperation.copyingMetrics, () async {
      final latest = await widget.playbackBridge.metricsSnapshot();
      if (!mounted) return;
      setState(() => _metrics = latest);
      await Clipboard.setData(ClipboardData(text: latest.toDisplayText()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Metrics copied')));
    }, refreshAfter: false);
  }

  Future<void> _toggleCache(CatalogTrackSummary track) async {
    if (_operation != PlayerOperation.idle) return;
    final selection = choosePreferredAsset(track, _preferredAudioQuality);
    final selectedAsset = selection?.asset;
    final assetUrl = selectedAsset?.manifestUrl;
    if (assetUrl == null || assetUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Track is not available right now')));
      return;
    }
    setState(() => _operation = PlayerOperation.loadingTrack);
    try {
      final ok = await _cacheService.downloadAndCache(
        track.trackId,
        assetUrl,
        metadata: CachedTrackMetadata(
          trackId: track.trackId,
          title: track.title,
          artistName: track.artistName,
          durationMs: track.durationMs,
          artworkUrl: track.artworkUrl,
          localFilePath: '',
          originalRemoteUrl: assetUrl,
          cachedAt: DateTime.now().millisecondsSinceEpoch,
          downloadSource: 'manual',
          qualityLabel: selectedAsset?.qualityLabel ?? 'unknown',
          codec: selectedAsset?.codec,
          bitrateKbps: selectedAsset?.bitrateKbps,
          license: track.license,
        ),
      );
      await _refreshCacheStats();
      if (!mounted) return;
      _lastQualityFallbackReason = 'manual cache: ${selection?.fallbackReason ?? 'quality unknown'}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Downloaded ${track.title} (${_productQualityLabel(selectedAsset?.qualityLabel ?? 'unknown')})' : 'Download failed for ${track.title}')));
    } finally {
      if (mounted) setState(() => _operation = PlayerOperation.idle);
    }
  }

  Future<void> _deleteCachedTrack(CachedTrackMetadata track) async {
    if (_operation != PlayerOperation.idle) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _operation = PlayerOperation.loadingCatalog);
    try {
      final ok = await _cacheService.deleteCachedTrack(track.trackId);
      _lastCacheDeleteResult = ok ? 'removed:${track.trackId}' : 'remove failed:${track.trackId}';
      await _refreshCacheStats();
      _refreshOfflineLibraryIfNeeded();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(ok ? 'Removed from downloads' : 'Could not remove ${track.title}')),
      );
    } finally {
      if (mounted) setState(() => _operation = PlayerOperation.idle);
    }
  }

  void _refreshOfflineLibraryIfNeeded() {
    if (!_offlineLibraryMode) return;
    final offlineTracks = _cachedLibrary
        .map((entry) => CatalogTrackSummary(
              trackId: entry.trackId,
              title: entry.title,
              artistId: null,
              artistName: entry.artistName,
              durationMs: entry.durationMs,
              artworkUrl: entry.artworkUrl,
              primaryAsset: CatalogTrackAssetSummary(
                assetId: 'cached-${entry.trackId}',
                manifestUrl: entry.originalRemoteUrl,
                qualityLabel: entry.qualityLabel,
                codec: entry.codec,
                bitrateKbps: entry.bitrateKbps,
              ),
              license: entry.license,
            ))
        .toList(growable: false);
    if (!mounted) return;
    setState(() {
      _catalog = offlineTracks;
      _queue = offlineTracks;
      if (!offlineTracks.any((track) => track.trackId == _selectedTrackId)) {
        _selectedTrackId = offlineTracks.isEmpty ? null : offlineTracks.first.trackId;
      }
      if (!offlineTracks.any((track) => track.trackId == _queueCurrentTrackId)) {
        _queueCurrentTrackId = _selectedTrackId;
      }
      _catalogStatus = offlineTracks.isEmpty ? 'Offline library is empty.' : 'Offline cached library refreshed.';
      _queueStatus = offlineTracks.isEmpty ? 'Queue cleared.' : 'Offline cache available. Choose a cached track to play.';
    });
  }

  Future<void> _clearCache() async {
    if (_operation != PlayerOperation.idle) return;
    setState(() => _operation = PlayerOperation.loadingCatalog);
    try {
      await _cacheService.clearCache();
      _lastCacheDeleteResult = 'storage is clear';
      await _refreshCacheStats();
      _refreshOfflineLibraryIfNeeded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloads cleared')));
    } finally {
      if (mounted) setState(() => _operation = PlayerOperation.idle);
    }
  }

  Future<void> _resetMetrics() => _runOperation(PlayerOperation.resettingMetrics, widget.playbackBridge.resetMetrics);

  void _addToQueue(CatalogTrackSummary track) {
    final exists = _queue.any((item) => item.trackId == track.trackId);
    setState(() {
      if (!exists) _queue = [..._queue, track];
      _queueCurrentTrackId ??= track.trackId;
      _queueStatus = exists ? '${track.title} is already in queue.' : '${track.title} added to queue.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exists ? 'Already in Queue' : 'Added to Queue')));
  }

  void _moveQueueTrack(CatalogTrackSummary track, int delta) {
    if (_queueDisabled) return;
    final index = _queue.indexWhere((item) => item.trackId == track.trackId);
    if (index < 0) return;
    final target = (index + delta).clamp(0, _queue.length - 1).toInt();
    if (target == index) return;
    final nextQueue = [..._queue];
    final moved = nextQueue.removeAt(index);
    nextQueue.insert(target, moved);
    setState(() {
      _queue = nextQueue;
      _queueStatus = '${track.title} moved ${delta < 0 ? 'up' : 'down'}.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }

  void _playTrackNext(CatalogTrackSummary track) {
    if (_queueDisabled) return;
    final currentIndex = _queueIndex;
    final sourceIndex = _queue.indexWhere((item) => item.trackId == track.trackId);
    if (currentIndex < 0 || sourceIndex < 0 || sourceIndex == currentIndex) return;
    final nextQueue = [..._queue];
    final moved = nextQueue.removeAt(sourceIndex);
    final adjustedCurrentIndex = nextQueue.indexWhere((item) => item.trackId == _queueCurrentTrackId);
    final insertIndex = (adjustedCurrentIndex + 1).clamp(0, nextQueue.length).toInt();
    nextQueue.insert(insertIndex, moved);
    setState(() {
      _queue = nextQueue;
      _queueStatus = '${track.title} will play next.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }

  void _removeFromQueue(CatalogTrackSummary track) {
    if (_queueDisabled) return;
    setState(() {
      final index = _queue.indexWhere((item) => item.trackId == track.trackId);
      final wasCurrent = track.trackId == _queueCurrentTrackId;
      _queue = _queue.where((item) => item.trackId != track.trackId).toList(growable: false);
      if (_queue.isEmpty) {
        _queueCurrentTrackId = null;
        _queueStatus = 'Queue cleared.';
      } else if (wasCurrent) {
        final nextIndex = index.clamp(0, _queue.length - 1).toInt();
        _queueCurrentTrackId = _queue[nextIndex].trackId;
        _queueStatus = 'Removed current track. Queue moved to ${_queue[nextIndex].title}.';
      } else {
        _queueStatus = '${track.title} removed from queue.';
      }
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }

  void _clearQueue() {
    if (_queueDisabled) return;
    setState(() {
      _queue = const [];
      _queueCurrentTrackId = null;
      _lastAutoAdvanceTrackId = null;
      _queueStatus = 'Queue cleared.';
      _sessionStatus = 'Session cleared.';
    });
    unawaited(widget.sessionStore.clear());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }

  Future<void> _playQueueTrack(CatalogTrackSummary track, {bool autoStart = false, QueueAdvanceSource source = QueueAdvanceSource.manual}) async {
    final operation = source == QueueAdvanceSource.auto ? PlayerOperation.autoAdvance : PlayerOperation.queueAdvance;
    final prefetchHit = _prefetchEnabled && _prefetchedTrackId == track.trackId && _prefetchedManifest != null;
    final prefetchedManifest = prefetchHit ? _prefetchedManifest : null;
    final status = switch (source) {
      QueueAdvanceSource.auto => 'Auto-advanced to ${track.title}.',
      QueueAdvanceSource.next => prefetchHit ? 'Instant Next manifest hit: ${track.title}.' : 'Skipped to next: ${track.title}.',
      QueueAdvanceSource.previous => 'Returned to previous: ${track.title}.',
      QueueAdvanceSource.shuffle => 'Shuffle picked: ${track.title}.',
      QueueAdvanceSource.manual => 'Queue selected: ${track.title}.',
    };
    if (source == QueueAdvanceSource.auto) setState(() => _autoAdvanceCount += 1);
    if (source == QueueAdvanceSource.next || source == QueueAdvanceSource.auto) {
      setState(() {
        _lastPrefetchHit = prefetchHit;
        if (prefetchHit) {
          _prefetchHitCount += 1;
        } else {
          _prefetchMissCount += 1;
        }
        _nextTapStartedAtMs = autoStart ? DateTime.now().millisecondsSinceEpoch : null;
        _nextTapToAudioMs = null;
        _audioPreparedBeforeNext = _metrics.nativePrebufferTrackId == track.trackId && _metrics.nativePrebufferReady;
        _nextPreparedBeforePlay = false;
      });
    }
    setState(() {
      _queueCurrentTrackId = track.trackId;
      _queueStatus = status;
      _sessionStatus = 'Session saved.';
    });
    if (source == QueueAdvanceSource.next || source == QueueAdvanceSource.auto) {
      final preparedManifest = prefetchedManifest;
      final canAttemptPreparedHandoff = autoStart &&
          _prefetchEnabled &&
          preparedManifest != null &&
          _metrics.nativePrebufferReady &&
          _metrics.nativePrebufferTrackId == track.trackId;
      if (canAttemptPreparedHandoff) {
        final usedPreparedPath = source == QueueAdvanceSource.auto
            ? await widget.playbackBridge.playPreparedAutoAdvanceTrackIfReady(
                trackId: preparedManifest.trackId,
                title: preparedManifest.title,
                url: preparedManifest.streamUrl,
              )
            : await widget.playbackBridge.playPreparedNextTrackIfReady(
                trackId: preparedManifest.trackId,
                title: preparedManifest.title,
                url: preparedManifest.streamUrl,
              );
        if (usedPreparedPath) {
          await _finishPreparedQueueHandoff(
            manifest: preparedManifest,
            status: source == QueueAdvanceSource.auto
                ? 'Prepared auto-advance handoff: ${preparedManifest.title}.'
                : 'Prepared Next handoff: ${preparedManifest.title}.',
          );
          return;
        }
      } else if (source == QueueAdvanceSource.auto) {
        await widget.playbackBridge.recordAutoAdvancePreparedFallback(trackId: track.trackId);
      } else {
        await widget.playbackBridge.recordNextTrackPrebufferOutcome(
          trackId: track.trackId,
          usedPreparedPath: false,
        );
      }
    }
    await _loadCatalogTrack(trackId: track.trackId, autoPlay: autoStart, operation: operation, status: status, prefetchedManifest: prefetchedManifest);
  }


  Future<void> _finishPreparedQueueHandoff({required CatalogTrackManifest manifest, required String status}) async {
    if (!mounted) return;
    _titleController.text = manifest.title;
    _urlController.text = manifest.streamUrl;
    setState(() {
      _manifest = manifest;
      _selectedTrackId = manifest.trackId;
      _queueCurrentTrackId = manifest.trackId;
      _queueStatus = status;
      _prefetchedTrackId = null;
      _prefetchedTrackTitle = null;
      _prefetchedManifest = null;
      _manifestPrefetched = false;
      _audioPreparedBeforeNext = false;
      _nextPreparedBeforePlay = true;
    });
    final historySource = manifest.streamUrl.startsWith('file://') ? WzListeningHistorySource.cached : WzListeningHistorySource.api;
    await _pushNotificationMetadata(manifest, url: manifest.streamUrl, source: historySource.name);
    unawaited(_recordListeningHistory(_historySnapshotForManifest(
      manifest,
      source: historySource,
      playableUrl: manifest.streamUrl,
    )));
    await _refreshMetrics(allowAutoAdvance: false);
    unawaited(_saveSession());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheCurrentTrack(manifest));
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }

  Future<bool> _playRandomQueueTrack({bool autoStart = false, QueueAdvanceSource source = QueueAdvanceSource.shuffle}) async {
    if (_queue.length <= 1) return false;
    final currentId = _currentQueueTrack?.trackId ?? _queueCurrentTrackId ?? _selectedTrackId;
    final candidates = _queue.where((track) => track.trackId != currentId).toList(growable: false);
    if (candidates.isEmpty) return false;
    final track = candidates[math.Random().nextInt(candidates.length)];
    await _playQueueTrack(track, autoStart: autoStart, source: source);
    if (mounted && source == QueueAdvanceSource.shuffle) setState(() => _queueStatus = 'Shuffle picked: ${track.title}.');
    return true;
  }

  Future<void> _playNext({bool autoStart = false, QueueAdvanceSource source = QueueAdvanceSource.next, bool allowShuffle = true}) async {
    if (allowShuffle && _shuffleEnabled && await _playRandomQueueTrack(autoStart: autoStart, source: QueueAdvanceSource.shuffle)) return;
    final index = _queueIndex;
    if (index < 0 || index >= _queue.length - 1) return;
    await _playQueueTrack(_queue[index + 1], autoStart: autoStart, source: source);
  }

  Future<void> _playPrevious({bool autoStart = false}) async {
    final index = _queueIndex;
    if (index <= 0) return;
    await _playQueueTrack(_queue[index - 1], autoStart: autoStart, source: QueueAdvanceSource.previous);
  }

  Future<void> _showPremiumPlayerSheet() async {
    if (_manifest == null && _metrics.trackTitle == null) return;
    final durationMs = _metrics.durationMs ?? _manifest?.durationMs;
    final displayedPositionMs = (_dragPositionMs ?? _metrics.currentPositionMs.toDouble()).round();
    final progress = durationMs == null || durationMs <= 0 ? 0.0 : (displayedPositionMs / durationMs).clamp(0.0, 1.0).toDouble();
    final hasPlayerTrack = _manifest != null || _metrics.trackTitle != null;
    final qualityLabel = hasPlayerTrack ? (_manifest?.qualityLabel ?? _currentCachedQuality ?? _preferredAudioQuality.label) : 'unknown';
    final isDevicePlayback = _isDeviceTrackId(_manifest?.trackId) || _isDeviceUrl(_currentAssetUrl);
    final isPlayingFromCache = !isDevicePlayback && (_currentCachedQuality != null || (_currentAssetUrl?.startsWith('file://') ?? false));
    final effectsSummary = _selectedAudioEffectProfile == AudioEffectProfile.off ? 'Off' : _effectStatusLabel(_nativeAudioEffectStatus);
    final sourceLabel = isDevicePlayback ? 'Device' : _playerSourceLabel(isPlayingFromCache: isPlayingFromCache, offlineReady: _offlineLibraryAvailable, hasTrack: hasPlayerTrack);
    final currentTrack = _currentKnownTrack;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.62),
      builder: (sheetContext) => _PremiumPlayerSheet(
        child: _PremiumPlayerSurface(
          metrics: _metrics,
          manifest: _manifest,
          nextTrack: _upNextQueueTrack,
          qualityLabel: qualityLabel,
          effectsSummary: effectsSummary,
          sourceLabel: sourceLabel,
          progressValue: progress,
          displayedPositionMs: displayedPositionMs,
          durationMs: durationMs,
          controlsDisabled: _playerDisabled,
          canPlayPrevious: _canPrevious,
          canPlayNext: _canPlayNextControl,
          offlineReady: _offlineLibraryAvailable,
          shuffleEnabled: _shuffleEnabled,
          repeatMode: _repeatMode,
          sleepTimerLabel: _sleepTimerStatusLabel,
          sleepTimerActive: _sleepTimerDeadline != null,
          onShuffleChanged: _setShuffleEnabled,
          onCycleRepeatMode: _cycleRepeatMode,
          onOpenSleepTimer: _showSleepTimerPicker,
          onPlayPause: _playPause,
          onStop: _stop,
          onRetry: _retry,
          onPrevious: () => _playPrevious(autoStart: _metrics.isPlaying),
          onNext: () => _playNext(autoStart: _metrics.isPlaying),
          onSeekChanged: durationMs == null || durationMs <= 0 || _operation == PlayerOperation.seeking ? null : (value) => setState(() => _dragPositionMs = value * durationMs),
          onSeekEnd: durationMs == null || durationMs <= 0 || _operation == PlayerOperation.seeking
              ? null
              : (value) async {
                  final target = value * durationMs;
                  setState(() => _dragPositionMs = null);
                  await _seekTo(target);
                },
          canSaveTrack: currentTrack != null,
          liked: currentTrack == null ? false : _isLiked(currentTrack.trackId),
          onToggleLike: currentTrack == null ? null : () => _toggleLikedTrack(currentTrack),
          onAddToCollection: currentTrack == null ? null : () => _showAddToCollectionSheet(currentTrack),
          onAddToQueue: currentTrack == null ? null : () => _addToQueue(currentTrack),
          onOpenQueue: () {
            Navigator.of(sheetContext).maybePop();
            _navigateTo(_AppTab.queue);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = _metrics.durationMs ?? _manifest?.durationMs;
    final displayedPositionMs = (_dragPositionMs ?? _metrics.currentPositionMs.toDouble()).round();
    final progress = durationMs == null || durationMs <= 0 ? 0.0 : (displayedPositionMs / durationMs).clamp(0.0, 1.0).toDouble();

    final hasPlayerTrack = _manifest != null || _metrics.trackTitle != null;
    final qualityLabel = _manifest?.qualityLabel ?? _currentCachedQuality ?? _preferredAudioQuality.label;
    final nowQualityLabel = hasPlayerTrack ? qualityLabel : 'unknown';
    final isDevicePlayback = _isDeviceTrackId(_manifest?.trackId) || _isDeviceUrl(_currentAssetUrl);
    final isPlayingFromCache = !isDevicePlayback && (_currentCachedQuality != null || (_currentAssetUrl?.startsWith('file://') ?? false));
    final effectsSummary = _selectedAudioEffectProfile == AudioEffectProfile.off ? 'Off' : _effectStatusLabel(_nativeAudioEffectStatus);
    final engineSummary = '${_smartDownloadsEnabled ? 'Smart Downloads on' : 'Smart Downloads off'} • '
        '${_prefetchEnabled ? 'Instant Next on' : 'Instant Next off'} • '
        '${_offlineLibraryAvailable ? 'Offline Ready' : 'Offline empty'} • '
        'Library $_libraryCombinedTrackCount • Device ${_deviceMusicTracks.length} • Cached ${_cachedLibrary.length}';

    // Build per-tab pages using existing widgets — keep behavior unchanged.
    final pages = <Widget>[
      WzPageScaffold(
        children: [
          _HomeHero(engineSummary: engineSummary, themeConfig: widget.themeConfig),
          const SizedBox(height: WzSpacing.md),
          if (hasPlayerTrack)
            _HomeContinueListeningSummary(
              title: _metrics.trackTitle ?? _manifest?.title ?? 'Current track',
              subtitle: _manifest?.subtitle ?? 'Playback continues in the mini player.',
              sourceLabel: isDevicePlayback ? 'Device music' : _playerSourceLabel(isPlayingFromCache: isPlayingFromCache, offlineReady: _offlineLibraryAvailable, hasTrack: hasPlayerTrack),
              isPlaying: _metrics.isPlaying,
              onOpenNow: () => _navigateTo(_AppTab.now),
            )
          else
            _CurrentListeningCard(
              metrics: _metrics,
              manifest: _manifest,
              qualityLabel: qualityLabel,
              playingFromCache: isPlayingFromCache,
              devicePlayback: isDevicePlayback,
              offlineReady: _offlineLibraryAvailable,
              deviceTrackCount: _deviceMusicTracks.length,
              devicePermissionStatus: _deviceMusicPermissionStatus.status,
              status: _statusText,
            ),
          const SizedBox(height: WzSpacing.md),
          _HomeHistorySection(
            entries: _listeningHistory,
            continueEntry: _continueListeningEntry,
            mostPlayedEntry: _mostPlayedHistoryEntry,
            resolver: _resolveHistoryEntry,
            onPlay: (entry) => unawaited(_playHistoryEntry(entry)),
            onAddToQueue: (entry) => unawaited(_addHistoryEntryToQueue(entry)),
            onAddToCollection: (entry) => unawaited(_addHistoryEntryToCollection(entry)),
            onRemove: (entry) => unawaited(_removeHistoryEntry(entry)),
            onViewAll: () => _navigateTo(_AppTab.history),
          ),
          const SizedBox(height: WzSpacing.md),
          _HomeCollectionsOfflineSection(
            collections: _collections,
            offlineTrackCount: _offlineCachedTrackCount,
            cacheBytes: _cacheBytes,
            onOpenCollections: () => _navigateTo(_AppTab.collections),
            onOpenDownloads: () => _navigateTo(_AppTab.downloads),
          ),
          const SizedBox(height: WzSpacing.md),
          _SmartEngineCards(
            smartDownloadsEnabled: _smartDownloadsEnabled,
            smartDownloadsCompleted: _smartDownloadCompletedCount,
            prefetchEnabled: _prefetchEnabled,
            prefetchedTrackTitle: _prefetchedTrackTitle,
            offlineReady: _offlineLibraryAvailable,
            offlineTrackCount: _offlineCachedTrackCount,
            qualityLabel: qualityLabel,
          ),
          const SizedBox(height: WzSpacing.md),
          _HomeQuickActions(onNavigate: _navigateTo, showDeveloperTools: _developerMode),
          const SizedBox(height: WzSpacing.md),
          if (_developerMode) ...[
            _StatusStrip(status: _statusText, detail: _statusDetail, operation: _operation.label, refreshingMetrics: _refreshingMetrics),
            const SizedBox(height: WzSpacing.sm),
            _SessionStrip(status: _sessionStatus),
          ],
        ],
      ),
      WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.play_circle_fill,
            title: 'Now Playing',
            subtitle: 'Your focused player for the current track and queue.',
          ),
          const SizedBox(height: WzSpacing.md),
          _PremiumPlayerSurface(
            metrics: _metrics,
            manifest: _manifest,
            nextTrack: _upNextQueueTrack,
            qualityLabel: nowQualityLabel,
            effectsSummary: effectsSummary,
            sourceLabel: isDevicePlayback ? 'Device music' : _playerSourceLabel(isPlayingFromCache: isPlayingFromCache, offlineReady: _offlineLibraryAvailable, hasTrack: hasPlayerTrack),
            progressValue: progress,
            displayedPositionMs: displayedPositionMs,
            durationMs: durationMs,
            controlsDisabled: _playerDisabled,
            canPlayPrevious: _canPrevious,
            canPlayNext: _canPlayNextControl,
            onPlayPause: _playPause,
            onStop: _stop,
            onRetry: _retry,
            onPrevious: () => _playPrevious(autoStart: _metrics.isPlaying),
            onNext: () => _playNext(autoStart: _metrics.isPlaying),
            onSeekChanged: durationMs == null || durationMs <= 0 || _operation == PlayerOperation.seeking ? null : (value) => setState(() => _dragPositionMs = value * durationMs),
            onSeekEnd: durationMs == null || durationMs <= 0 || _operation == PlayerOperation.seeking
                ? null
                : (value) async {
                    final target = value * durationMs;
                    setState(() => _dragPositionMs = null);
                    await _seekTo(target);
                  },
            canSaveTrack: _currentKnownTrack != null,
            liked: _currentKnownTrack == null ? false : _isLiked(_currentKnownTrack!.trackId),
            onToggleLike: _currentKnownTrack == null ? null : () => _toggleLikedTrack(_currentKnownTrack!),
            onAddToCollection: _currentKnownTrack == null ? null : () => _showAddToCollectionSheet(_currentKnownTrack!),
            onAddToQueue: _currentKnownTrack == null ? null : () => _addToQueue(_currentKnownTrack!),
            onOpenQueue: () => _navigateTo(_AppTab.queue),
            offlineReady: _offlineLibraryAvailable,
            shuffleEnabled: _shuffleEnabled,
            repeatMode: _repeatMode,
            sleepTimerLabel: _sleepTimerStatusLabel,
            sleepTimerActive: _sleepTimerDeadline != null,
            onShuffleChanged: _setShuffleEnabled,
            onCycleRepeatMode: _cycleRepeatMode,
            onOpenSleepTimer: _showSleepTimerPicker,
          ),
          const SizedBox(height: WzSpacing.md),
          _NowContextPanel(
            qualityLabel: nowQualityLabel,
            effectsSummary: effectsSummary,
            playingFromCache: isPlayingFromCache,
            devicePlayback: isDevicePlayback,
            offlineReady: _offlineLibraryAvailable,
            nextTrack: _upNextQueueTrack,
            manifest: _manifest,
            selectedEffectProfile: _selectedAudioEffectProfile,
            nativeAudioEffectStatus: _nativeAudioEffectStatus,
            queueIndex: _queueIndex,
            queueLength: _queue.length,
          ),
          const SizedBox(height: WzSpacing.md),
          if (_developerMode) ...[
            _MetricsToggle(showMetrics: _showMetrics, operationBusy: _operation != PlayerOperation.idle, onToggle: () => setState(() => _showMetrics = !_showMetrics), onCopyMetrics: _copyMetrics, onResetMetrics: _resetMetrics),
            if (_showMetrics) ...[const SizedBox(height: WzSpacing.md), _MetricsPanel(metrics: _metrics)],
          ],
        ],
      ),
      WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.queue_music,
            title: 'Queue',
            subtitle: 'Queue Engine v2 stays intact with cleaner product hierarchy.',
          ),
          const SizedBox(height: WzSpacing.md),
          _QueueCard(
            queue: _queue,
            currentTrackId: _queueCurrentTrackId,
            currentIndex: _queueIndex,
            status: _queueStatus,
            controlsDisabled: _queueDisabled,
            autoAdvanceEnabled: _autoAdvanceEnabled,
            autoAdvanceCount: _autoAdvanceCount,
            smartQueueCandidateTrackId: _smartQueueCandidateTrackId,
            smartQueueReason: _smartQueueReason,
            showDeveloperDetails: _developerMode,
            onToggleAutoAdvance: (value) {
              setState(() {
                _autoAdvanceEnabled = value;
                _queueStatus = value ? 'Auto-advance enabled.' : 'Auto-advance disabled.';
                _sessionStatus = 'Session saved.';
              });
              unawaited(_saveSession());
              unawaited(_updatePredictivePreloadCandidate());
            },
            onPlayTrack: (track) => _playQueueTrack(track, autoStart: _metrics.isPlaying),
            onMoveUp: (track) => _moveQueueTrack(track, -1),
            onMoveDown: (track) => _moveQueueTrack(track, 1),
            onPlayNext: _playTrackNext,
            onRemoveTrack: _removeFromQueue,
            onClearQueue: _clearQueue,
          ),
          if (_developerMode) ...[
            const SizedBox(height: WzSpacing.md),
            _SmartPreloadCard(
              metrics: _metrics,
              enabled: _prefetchEnabled,
              prefetchedTrackId: _prefetchedTrackId,
              prefetchedTrackTitle: _prefetchedTrackTitle,
              prefetchInFlight: _prefetchInFlight,
              manifestPrefetched: _manifestPrefetched,
              audioPreparedBeforeNext: _audioPreparedBeforeNext,
              lastPrefetchHit: _lastPrefetchHit,
              prefetchHitCount: _prefetchHitCount,
              prefetchMissCount: _prefetchMissCount,
              nextTapToAudioMs: _nextTapToAudioMs,
              nextPreparedBeforePlay: _nextPreparedBeforePlay,
              smartQueueCandidateTrackId: _smartQueueCandidateTrackId,
              smartQueueReason: _smartQueueReason,
              controlsDisabled: _queueDisabled,
              onToggle: _setPrefetchEnabled,
            ),
            const SizedBox(height: WzSpacing.sm),
            _SmartDownloadsCard(
              enabled: _smartDownloadsEnabled,
              lastTrackId: _lastSmartDownloadTrackId,
              lastTitle: _lastSmartDownloadTitle,
              lastReason: _lastSmartDownloadReason,
              lastResult: _lastSmartDownloadResult,
              startedCount: _smartDownloadStartedCount,
              completedCount: _smartDownloadCompletedCount,
              failedCount: _smartDownloadFailedCount,
              skippedCount: _smartDownloadSkippedCount,
              inFlight: _autoCacheInFlight.length,
              onToggle: (v) => setState(() {
                _smartDownloadsEnabled = v;
              }),
            ),
          ],
        ],
      ),
      WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.library_music,
            title: 'Library',
            subtitle: 'Browse Catalog, Device music, and Downloaded tracks.',
          ),
          const SizedBox(height: WzSpacing.md),
          _CatalogListCard(
            tracks: _filteredCatalog,
            totalTrackCount: _libraryTotalTrackCount,
            apiTrackCount: _catalog.length,
            deviceTrackCount: _deviceMusicTracks.length,
            cachedTrackCount: _cachedLibrary.length,
            combinedTrackCount: _libraryCombinedTrackCount,
            cacheBytes: _cacheBytes,
            selectedTrackId: _selectedTrackId,
            status: _developerMode ? _catalogStatus : _consumerCatalogStatus(_catalogStatus),
            loading: _operation == PlayerOperation.loadingCatalog,
            refreshDisabled: _catalogRefreshDisabled,
            addToQueueDisabled: _operation.isTrackLoading || _operation.isQueueAdvancing,
            searchController: _searchController,
            librarySourceFilter: _librarySourceFilter,
            librarySortMode: _librarySortMode,
            devicePermissionStatus: _deviceMusicPermissionStatus.status,
            deviceScanStatus: _deviceMusicScanStatus,
            deviceLastError: _developerMode ? _deviceMusicLastError : _consumerDeviceError(_deviceMusicLastError),
            onSourceFilterChanged: (filter) => setState(() => _librarySourceFilter = filter),
            onSortModeChanged: (mode) => setState(() => _librarySortMode = mode),
            onClearSearch: () => _searchController.clear(),
            onOpenFullSearch: () => _openSearch(query: _searchController.text),
            onRefresh: () => _loadCatalog(),
            onImportDeviceMusic: _importDeviceMusic,
            onSelectTrack: (track) => _loadCatalogTrack(trackId: track.trackId),
            onAddToQueue: _addToQueue,
            onToggleLike: _toggleLikedTrack,
            onAddToCollection: _showAddToCollectionSheet,
            isLiked: (track) => _isLiked(track.trackId),
            onOpenCollections: () => _navigateTo(_AppTab.collections),
            onCache: (track) => _toggleCache(track),
            onDeleteCachedTrack: (track) {
              final cached = _cachedMetadataForTrack(track);
              if (cached != null) _deleteCachedTrack(cached);
            },
            offlineMode: _catalogStatus.toLowerCase().contains('offline'),
          ),
          if (_allowManualApiSetup) ...[
            const SizedBox(height: WzSpacing.md),
            _TrackSetupCard(titleController: _titleController, urlController: _urlController, apiBaseUrlController: _apiBaseUrlController, catalogStatus: _catalogStatus, loading: _manualDisabled, onLoadCatalog: () => _loadCatalogTrack(), onLoadTrack: _loadManualTrack),
          ],
        ],
      ),
      _CollectionsPage(
        collections: _collections,
        onBack: () => _navigateTo(_AppTab.home),
        onOpen: _openCollection,
        onCreate: _createCollectionFromPage,
        onRename: _showRenameCollectionDialog,
        onDelete: _showDeleteCollectionDialog,
      ),
      _CollectionDetailPage(
        collection: _selectedCollection ?? _likedCollection,
        onBack: () => _navigateTo(_AppTab.collections),
        onPlayFirst: (collection) {
          if (collection.tracks.isNotEmpty) unawaited(_playCollectionSnapshot(collection.tracks.first));
        },
        onAddAllToQueue: (collection) => unawaited(_addCollectionToQueue(collection)),
        onRename: _showRenameCollectionDialog,
        onDelete: _showDeleteCollectionDialog,
        onPlayTrack: (snapshot) => unawaited(_playCollectionSnapshot(snapshot)),
        onAddTrackToQueue: (snapshot) => unawaited(_addCollectionSnapshotToQueue(snapshot)),
        onRemoveTrack: (collection, snapshot) => unawaited(_removeTrackFromCollection(collection, snapshot)),
        resolver: _resolveCollectionTrack,
      ),
      WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.download_done,
            title: 'Downloads',
            subtitle: 'Offline Ready library with manual and smart cached tracks.',
          ),
          const SizedBox(height: WzSpacing.md),
          _DownloadsCard(
            downloads: _cachedLibrary,
            cacheBytes: _cacheBytes,
            controlsDisabled: _queueDisabled,
            onPlay: (track) => _loadCatalogTrack(trackId: track.trackId, autoPlay: true),
            onDelete: _deleteCachedTrack,
            onClearAll: _clearCache,
            onManageStorage: () => _navigateTo(_AppTab.storage),
          ),
        ],
      ),
      _StorageManagerPage(
        downloads: _cachedLibrary,
        onBack: () => _navigateTo(_AppTab.downloads),
        cacheBytes: _cacheBytes,
        trackBytes: _cachedTrackBytes,
        manualDownloadedCount: _manualDownloadedCount,
        smartDownloadedCount: _smartDownloadedCount,
        offlineReadyCount: _offlineCachedTrackCount,
        smartDownloadsEnabled: _smartDownloadsEnabled,
        controlsDisabled: _queueDisabled,
        onSmartDownloadsChanged: (value) => setState(() => _smartDownloadsEnabled = value),
        onPlay: (track) => _loadCatalogTrack(trackId: track.trackId, autoPlay: true),
        onDelete: _deleteCachedTrack,
        onClearAll: _clearCache,
      ),
      _SearchPage(
        controller: _fullSearchController,
        onBack: () => _navigateTo(_AppTab.home),
        filter: _searchFilter,
        results: _filteredSearchResults,
        allResultCount: _allSearchResults.length,
        recentSearches: _recentSearches,
        history: _listeningHistory,
        cachedTracks: _cachedCatalogTracks,
        collections: _collections,
        catalogTracks: _catalog,
        onFilterChanged: (filter) => setState(() => _searchFilter = filter),
        onClearQuery: () => _fullSearchController.clear(),
        onRecentSearch: (query) => _fullSearchController.text = query,
        onClearRecentSearches: _recentSearches.isEmpty ? null : () => unawaited(_clearRecentSearches()),
        onSubmitted: (query) => unawaited(_rememberSearchQuery(query)),
        onPlay: (result) => unawaited(_playSearchResult(result)),
        onAddToQueue: (result) => unawaited(_queueSearchResult(result)),
        onAddToCollection: (result) => unawaited(_collectSearchResult(result)),
        onOpenCollection: (result) => unawaited(_openSearchCollection(result)),
        onImportDeviceMusic: _importDeviceMusic,
        onLoadCatalog: () => _loadCatalog(),
      ),
      _ListeningHistoryPage(
        entries: _listeningHistory,
        onBack: () => _navigateTo(_AppTab.home),
        mostPlayedEntry: _mostPlayedHistoryEntry,
        resolver: _resolveHistoryEntry,
        onPlay: (entry) => unawaited(_playHistoryEntry(entry)),
        onAddToQueue: (entry) => unawaited(_addHistoryEntryToQueue(entry)),
        onAddToCollection: (entry) => unawaited(_addHistoryEntryToCollection(entry)),
        onRemove: (entry) => unawaited(_removeHistoryEntry(entry)),
        onClearAll: _listeningHistory.isEmpty ? null : () => unawaited(_clearListeningHistory()),
      ),
      WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.engineering,
            title: 'Engine diagnostics',
            subtitle: 'Advanced playback, preload, cache, quality, and effects diagnostics remain available.',
          ),
          const SizedBox(height: WzSpacing.md),
          _DeveloperModePanel(enabled: _developerMode, onChanged: (enabled) => _setAppMode(enabled ? _AppMode.developer : _AppMode.consumer)),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Content Server', subtitle: 'Developer-only catalog and content status.', icon: Icons.cloud_queue),
          _ContentServerDiagnosticsPanel(
            contentStatus: _contentStatus,
            catalogStatus: _catalogStatus,
            apiBaseUrl: _apiBaseUrlController.text,
            configuredContentModeLabel: widget.appConfig.contentModeLabel,
            catalogTrackCount: _catalog.length,
            cachedTrackCount: _cachedLibrary.length,
          const WzSectionHeader(title: 'Content server', subtitle: 'Catalog mode, API endpoint, and content safety status.', icon: Icons.cloud_queue),
          _ContentServerDiagnosticsPanel(
            apiBaseUrl: _apiBaseUrlController.text,
            status: _contentStatus,
            catalogStatus: _catalogStatus,
            catalogTrackCount: _catalog.length,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Playback Engine', subtitle: 'Current player state and operation summary.', icon: Icons.graphic_eq),
          _StatusStrip(status: _statusText, detail: _statusDetail, operation: _operation.label, refreshingMetrics: _refreshingMetrics),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Smart Preload', subtitle: 'Instant Next readiness and preload hit/miss telemetry.', icon: Icons.offline_bolt),
          _SmartPreloadCard(
            metrics: _metrics,
            enabled: _prefetchEnabled,
            prefetchedTrackId: _prefetchedTrackId,
            prefetchedTrackTitle: _prefetchedTrackTitle,
            prefetchInFlight: _prefetchInFlight,
            manifestPrefetched: _manifestPrefetched,
            audioPreparedBeforeNext: _audioPreparedBeforeNext,
            lastPrefetchHit: _lastPrefetchHit,
            prefetchHitCount: _prefetchHitCount,
            prefetchMissCount: _prefetchMissCount,
            nextTapToAudioMs: _nextTapToAudioMs,
            nextPreparedBeforePlay: _nextPreparedBeforePlay,
            smartQueueCandidateTrackId: _smartQueueCandidateTrackId,
            smartQueueReason: _smartQueueReason,
            controlsDisabled: _queueDisabled,
            onToggle: _setPrefetchEnabled,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Smart Downloads', subtitle: 'Predictive cache activity and counters.', icon: Icons.download_for_offline),
          _SmartDownloadsCard(
            enabled: _smartDownloadsEnabled,
            lastTrackId: _lastSmartDownloadTrackId,
            lastTitle: _lastSmartDownloadTitle,
            lastReason: _lastSmartDownloadReason,
            lastResult: _lastSmartDownloadResult,
            startedCount: _smartDownloadStartedCount,
            completedCount: _smartDownloadCompletedCount,
            failedCount: _smartDownloadFailedCount,
            skippedCount: _smartDownloadSkippedCount,
            inFlight: _autoCacheInFlight.length,
            onToggle: (v) => setState(() { _smartDownloadsEnabled = v; }),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Audio Quality', subtitle: 'Preferred and currently selected audio asset quality.', icon: Icons.high_quality),
          _AudioQualityPanel(
            preferredAudioQuality: _preferredAudioQuality,
            manifest: _manifest,
            currentAssetUrl: _currentAssetUrl,
            currentCachedQuality: _currentCachedQuality,
            lastQualityFallbackReason: _lastQualityFallbackReason,
            controlsDisabled: _queueDisabled,
            onSelected: (values) => setState(() {
              _preferredAudioQuality = values.first;
              _lastQualityFallbackReason = 'preferred quality set to ${values.first.label}';
            }),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Audio Effects', subtitle: 'Effect profile bridge status and diagnostics.', icon: Icons.tune),
          _AudioEffectsPanel(
            selectedProfile: _selectedAudioEffectProfile,
            nativeStatus: _nativeAudioEffectStatus,
            lastApplyResult: _lastAudioEffectApplyResult,
            preferredAudioQuality: _preferredAudioQuality,
            controlsDisabled: _queueDisabled,
            onSelected: _setAudioEffectProfile,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Cache / Offline', subtitle: 'Manual downloads, smart downloads, and offline library counters.', icon: Icons.offline_pin),
          _CacheDiagnosticsPanel(
            cachedTrackCount: _cachedTrackCount,
            cacheBytes: _cacheBytes,
            offlineLibraryAvailable: _offlineLibraryAvailable,
            offlineCachedTrackCount: _offlineCachedTrackCount,
            manualDownloadedCount: _manualDownloadedCount,
            smartDownloadedCount: _smartDownloadedCount,
            lastOfflineLibraryStatus: _lastOfflineLibraryStatus,
            lastCacheResult: _lastCacheResult,
            lastCacheDeleteResult: _lastCacheDeleteResult,
            controlsDisabled: _queueDisabled,
            onClearCache: _clearCache,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Device music', subtitle: 'Android MediaStore import diagnostics.', icon: Icons.perm_media),
          _DeviceMusicDiagnosticsPanel(
            permissionStatus: _deviceMusicPermissionStatus.status,
            platformSupported: _deviceMusicPermissionStatus.platformSupported,
            importedCount: _deviceMusicTracks.length,
            lastScanStatus: _deviceMusicScanStatus,
            lastError: _deviceMusicLastError,
            importedAtMs: _deviceMusicImportedAtMs,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Library v2', subtitle: 'Unified library filter, search, and source diagnostics.', icon: Icons.library_music),
          _LibraryDiagnosticsPanel(
            selectedSource: _librarySourceFilter.label,
            filteredResultCount: _filteredCatalog.length,
            sortMode: _librarySortMode.label,
            deviceImportCount: _deviceMusicTracks.length,
            cachedLibraryCount: _cachedLibrary.length,
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Raw Metrics', subtitle: 'Complete developer telemetry keeps original metric names.', icon: Icons.data_object),
          _PerformanceBaselinePanel(
            metrics: _metrics,
            nextTapToAudioMs: _nextTapToAudioMs,
            prefetchHitCount: _prefetchHitCount,
            prefetchMissCount: _prefetchMissCount,
            stopToPlayRecoveryMs: _stopToPlayRecoveryMs,
            sessionRecoveryMs: _sessionRecoveryMs,
            audioPreparedBeforeNext: _audioPreparedBeforeNext,
            nextPreparedBeforePlay: _nextPreparedBeforePlay,
          ),
          const SizedBox(height: WzSpacing.md),
          _MetricsToggle(showMetrics: _showMetrics, operationBusy: _operation != PlayerOperation.idle, onToggle: () => setState(() => _showMetrics = !_showMetrics), onCopyMetrics: _copyMetrics, onResetMetrics: _resetMetrics),
          if (_showMetrics) ...[const SizedBox(height: WzSpacing.md), _MetricsPanel(metrics: _metrics)],
        ],
      ),
    ];

    final settingsPage = _SettingsPage(
      themeConfig: widget.themeConfig,
      onThemePresetChanged: (preset) => widget.onThemeConfigChanged(widget.themeConfig.copyWith(themePreset: preset)),
      onAccentPresetChanged: (preset) => widget.onThemeConfigChanged(widget.themeConfig.copyWith(accentPreset: preset)),
      preferredAudioQuality: _preferredAudioQuality,
      onQualityChanged: (quality) => setState(() {
        _preferredAudioQuality = quality;
        _lastQualityFallbackReason = 'preferred quality set to ${quality.label}';
      }),
      selectedAudioEffectProfile: _selectedAudioEffectProfile,
      nativeAudioEffectStatus: _nativeAudioEffectStatus,
      lastAudioEffectApplyResult: _lastAudioEffectApplyResult,
      onAudioEffectChanged: _setAudioEffectProfile,
      shuffleEnabled: _shuffleEnabled,
      repeatMode: _repeatMode,
      sleepTimerLabel: _sleepTimerSettingsLabel,
      sleepTimerActive: _sleepTimerDeadline != null,
      onShuffleChanged: _setShuffleEnabled,
      onRepeatModeChanged: _setRepeatMode,
      onOpenSleepTimer: _showSleepTimerPicker,
      smartDownloadsEnabled: _smartDownloadsEnabled,
      onSmartDownloadsChanged: (value) => setState(() => _smartDownloadsEnabled = value),
      cachedTrackCount: _cachedTrackCount,
      cacheBytes: _cacheBytes,
      manualDownloadedCount: _manualDownloadedCount,
      smartDownloadedCount: _smartDownloadedCount,
      controlsDisabled: _queueDisabled,
      onClearCache: _clearCache,
      devicePermissionStatus: _deviceMusicPermissionStatus.status,
      devicePlatformSupported: _deviceMusicPermissionStatus.platformSupported,
      importedDeviceTrackCount: _deviceMusicTracks.length,
      deviceScanStatus: _deviceMusicScanStatus,
      deviceLastError: _consumerDeviceError(_deviceMusicLastError),
      onImportDeviceMusic: _importDeviceMusic,
      notificationActive: _metrics.isPlaying || (_metrics.trackTitle?.isNotEmpty ?? false),
      appConfig: widget.appConfig,
      contentModeLabel: _contentStatus?.friendlyLabel ?? widget.appConfig.contentModeLabel,
      catalogStatusLabel: _developerMode ? _catalogStatus : _consumerCatalogStatus(_catalogStatus),
      showDeveloperEntry: _showDeveloperControls,
      appMode: _appMode,
      onDeveloperModeChanged: (enabled) => _setAppMode(enabled ? _AppMode.developer : _AppMode.consumer),
      onOpenEngine: _developerMode ? () => _navigateTo(_AppTab.engine) : null,
      onManageStorage: () => _navigateTo(_AppTab.storage),
      listeningHistoryCount: _listeningHistory.length,
      mostPlayedHistoryTitle: _mostPlayedHistoryEntry?.title,
      onOpenHistory: () => _navigateTo(_AppTab.history),
      onOpenSearch: () => _openSearch(),
      onClearRecentSearches: _recentSearches.isEmpty ? null : () => unawaited(_clearRecentSearches()),
      onClearListeningHistory: _listeningHistory.isEmpty ? null : () => unawaited(_clearListeningHistory()),
      legalTracks: _libraryTracks,
    );

    final destinations = _developerMode ? _developerShellDestinations : _consumerShellDestinations;
    final currentTab = _selectedTab == _AppTab.engine && !_developerMode ? _AppTab.home : _selectedTab;
    final currentIndex = destinations.indexWhere((destination) => destination.tab == currentTab);
    final selectedDestination = destinations[currentIndex < 0 ? 0 : currentIndex];
    final selectedTabLabel = switch (_selectedTab) {
      _AppTab.settings => 'Settings',
      _AppTab.storage => 'Storage Manager',
      _AppTab.history => 'Listening History',
      _AppTab.search => 'Search',
      _AppTab.collections => 'Collections',
      _AppTab.collectionDetail => _selectedCollection?.name ?? 'Collection',
      _ => selectedDestination.label,
    };
    final currentPage = switch (currentTab) {
      _AppTab.home => pages[0],
      _AppTab.now => pages[1],
      _AppTab.queue => pages[2],
      _AppTab.library => pages[3],
      _AppTab.collections => pages[4],
      _AppTab.collectionDetail => pages[5],
      _AppTab.search => pages[8],
      _AppTab.downloads => pages[6],
      _AppTab.storage => pages[7],
      _AppTab.history => pages[9],
      _AppTab.settings => settingsPage,
      _AppTab.engine => pages[10],
    };

    return Scaffold(
      backgroundColor: widget.themeConfig.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _ProductShellHeader(
                  selectedTabLabel: selectedTabLabel,
                  status: _statusText,
                  engineSummary: engineSummary,
                  offlineReady: _offlineLibraryAvailable,
                  appMode: _appMode,
                  themeConfig: widget.themeConfig,
                  onLogoLongPress: _toggleAppMode,
                  onOpenSettings: () => _navigateTo(_AppTab.settings),
                ),
                Expanded(child: currentPage),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: widget.themeConfig.surfaceMuted,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPlayerTrack) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: _PremiumMiniPlayer(
                  metrics: _metrics,
                  manifest: _manifest,
                  progressValue: progress,
                  sourceLabel: isDevicePlayback ? 'Device music' : _playerSourceLabel(isPlayingFromCache: isPlayingFromCache, offlineReady: _offlineLibraryAvailable, hasTrack: hasPlayerTrack),
                  offlineReady: _offlineLibraryAvailable,
                  shuffleEnabled: _shuffleEnabled,
                  repeatMode: _repeatMode,
                  sleepTimerBadge: _sleepTimerDeadline == null ? null : _sleepTimerStatusLabel,
                  controlsDisabled: _playerDisabled,
                  onTap: _showPremiumPlayerSheet,
                  onPlayPause: _playPause,
                ),
              ),
              const Divider(height: 1, color: _WzTokens.border),
            ],
            BottomNavigationBar(
              currentIndex: currentIndex < 0 ? 0 : currentIndex,
              onTap: (i) => _navigateTo(destinations[i].tab),
              backgroundColor: widget.themeConfig.surfaceMuted,
              selectedItemColor: currentIndex < 0 ? _WzTokens.textMuted : widget.themeConfig.accent,
              unselectedItemColor: _WzTokens.textMuted,
              type: BottomNavigationBarType.fixed,
              items: destinations
                  .map((destination) => BottomNavigationBarItem(
                        icon: Icon(destination.icon),
                        label: destination.label,
                      ))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

enum QueueAdvanceSource { manual, next, previous, auto, shuffle }

enum _LibrarySourceFilter { all, api, device, downloads }

extension _LibrarySourceFilterLabel on _LibrarySourceFilter {
  String get label => switch (this) {
        _LibrarySourceFilter.all => 'All',
        _LibrarySourceFilter.api => 'Catalog',
        _LibrarySourceFilter.device => 'Device music',
        _LibrarySourceFilter.downloads => 'Downloaded',
      };
}


enum WzSearchResultType { track, deviceTrack, downloadedTrack, collection, historyEntry, artistLike, unknown }

enum WzSearchSource { apiCatalog, deviceMusic, downloads, collections, history, legalDemo }

enum _SearchFilter { all, songs, device, downloads, collections, history, legalDemo }

extension _SearchFilterLabel on _SearchFilter {
  String get label => switch (this) {
        _SearchFilter.all => 'All',
        _SearchFilter.songs => 'Songs',
        _SearchFilter.device => 'Device',
        _SearchFilter.downloads => 'Downloads',
        _SearchFilter.collections => 'Collections',
        _SearchFilter.history => 'History',
        _SearchFilter.legalDemo => 'Legal / Demo',
      };
}

class WzSearchResult {
  const WzSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.source,
    this.artworkUrl,
    this.trackId,
    this.collectionId,
    this.historyTrackId,
    this.qualityLabel,
    this.codec,
    this.license,
    this.available = true,
    required this.secondaryLabel,
    required this.searchText,
    this.track,
    this.collection,
    this.historyEntry,
  });

  final String id;
  final String title;
  final String subtitle;
  final WzSearchResultType type;
  final WzSearchSource source;
  final String? artworkUrl;
  final String? trackId;
  final String? collectionId;
  final String? historyTrackId;
  final String? qualityLabel;
  final String? codec;
  final LicenseMetadata? license;
  final bool available;
  final String secondaryLabel;
  final String searchText;
  final CatalogTrackSummary? track;
  final WzCollection? collection;
  final WzListeningHistoryEntry? historyEntry;

  bool get isTrackLike => track != null || historyEntry != null;
}

String _normalizeWzSearch(String value) {
  final withoutDiacritics = value
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp('[إأآا]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  return withoutDiacritics.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _searchSourceLabel(WzSearchSource source) => switch (source) {
      WzSearchSource.apiCatalog => 'Catalog',
      WzSearchSource.deviceMusic => 'Device music',
      WzSearchSource.downloads => 'Downloads',
      WzSearchSource.collections => 'Collections',
      WzSearchSource.history => 'History',
      WzSearchSource.legalDemo => 'Legal demo catalog',
    };

String _searchTypeLabel(WzSearchResultType type) => switch (type) {
      WzSearchResultType.track => 'Song',
      WzSearchResultType.deviceTrack => 'Device song',
      WzSearchResultType.downloadedTrack => 'Offline song',
      WzSearchResultType.collection => 'Collection',
      WzSearchResultType.historyEntry => 'Recent play',
      WzSearchResultType.artistLike => 'Artist',
      WzSearchResultType.unknown => 'Result',
    };

IconData _searchResultIcon(WzSearchResult result) => switch (result.type) {
      WzSearchResultType.deviceTrack => Icons.phone_android,
      WzSearchResultType.downloadedTrack => Icons.download_done,
      WzSearchResultType.collection => Icons.playlist_play,
      WzSearchResultType.historyEntry => Icons.history,
      WzSearchResultType.artistLike => Icons.person,
      WzSearchResultType.track || WzSearchResultType.unknown => Icons.music_note,
    };

bool _searchFilterAllows(_SearchFilter filter, WzSearchResult result) => switch (filter) {
      _SearchFilter.all => true,
      _SearchFilter.songs => result.type == WzSearchResultType.track || result.type == WzSearchResultType.deviceTrack || result.type == WzSearchResultType.downloadedTrack,
      _SearchFilter.device => result.source == WzSearchSource.deviceMusic,
      _SearchFilter.downloads => result.source == WzSearchSource.downloads,
      _SearchFilter.collections => result.type == WzSearchResultType.collection || result.source == WzSearchSource.collections,
      _SearchFilter.history => result.source == WzSearchSource.history,
      _SearchFilter.legalDemo => result.source == WzSearchSource.legalDemo || result.license?.needsRightsWarning == true,
    };

int _searchRank(WzSearchResult result, String query) {
  final q = _normalizeWzSearch(query);
  final title = _normalizeWzSearch(result.title);
  final subtitle = _normalizeWzSearch(result.subtitle);
  final source = _normalizeWzSearch(_searchSourceLabel(result.source));
  final license = _normalizeWzSearch(result.license?.badgeLabel ?? '');
  if (title == q) return 0;
  if (title.startsWith(q)) return 10;
  if (title.contains(q)) return 20;
  if (subtitle.contains(q)) return 30;
  if (result.type == WzSearchResultType.collection && result.searchText.contains(q)) return 40;
  if (result.source == WzSearchSource.history || result.source == WzSearchSource.downloads || result.source == WzSearchSource.deviceMusic) return 50;
  if (source.contains(q) || license.contains(q)) return 60;
  return 80;
}

enum _LibrarySortMode { recentlyAdded, titleAz, artistAz, longestDuration, shortestDuration, quality }

extension _LibrarySortModeLabel on _LibrarySortMode {
  String get label => switch (this) {
        _LibrarySortMode.recentlyAdded => 'Recently added / imported',
        _LibrarySortMode.titleAz => 'Title A-Z',
        _LibrarySortMode.artistAz => 'Artist A-Z',
        _LibrarySortMode.longestDuration => 'Longest duration',
        _LibrarySortMode.shortestDuration => 'Shortest duration',
        _LibrarySortMode.quality => 'Quality',
      };
}

CatalogTrackSummary _catalogSummaryFromCachedTrack(CachedTrackMetadata track) {
  return CatalogTrackSummary(
    trackId: track.trackId,
    title: track.title,
    artistId: null,
    artistName: track.artistName,
    durationMs: track.durationMs,
    artworkUrl: track.artworkUrl,
    displayName: '${track.downloadSource} cached download ${track.qualityLabel} ${track.codec ?? ''}',
    source: 'cached',
    license: track.license,
    primaryAsset: CatalogTrackAssetSummary(
      assetId: 'cached-${track.trackId}',
      manifestUrl: track.originalRemoteUrl,
      qualityLabel: track.qualityLabel,
      codec: track.codec,
      bitrateKbps: track.bitrateKbps,
    ),
  );
}

CatalogTrackSummary _catalogSummaryFromDeviceTrack(DeviceMusicTrack track) {
  return CatalogTrackSummary(
    trackId: track.trackId,
    title: track.title,
    artistId: null,
    artistName: track.artistName,
    albumName: track.albumName,
    displayName: track.displayName,
    durationMs: track.durationMs,
    artworkUrl: track.artworkUri,
    source: 'device',
    license: LicenseMetadata.userDevice,
    primaryAsset: CatalogTrackAssetSummary(
      assetId: 'device-${track.trackId}',
      manifestUrl: track.contentUri,
      qualityLabel: track.qualityLabel,
      codec: track.codec,
      bitrateKbps: track.bitrateKbps,
      fileSizeBytes: track.sizeBytes,
    ),
  );
}

bool _isDeviceTrackId(String? trackId) => trackId != null && trackId.startsWith('device-audio-');

bool _isDeviceUrl(String? url) => url != null && url.startsWith('content://');

bool _isDeviceCatalogTrack(CatalogTrackSummary track) => track.source == 'device' || _isDeviceTrackId(track.trackId) || _isDeviceUrl(track.primaryAsset?.manifestUrl);

bool _isCachedCatalogTrack(CatalogTrackSummary track) => track.source == 'cached' || track.primaryAsset?.assetId.startsWith('cached-') == true;


String _historySourceLabel(WzListeningHistorySource source) => switch (source) {
      WzListeningHistorySource.api => 'Catalog',
      WzListeningHistorySource.device => 'Device music',
      WzListeningHistorySource.cached => 'Downloaded',
      WzListeningHistorySource.unknown => 'Unknown',
    };

String _friendlyHistoryTime(int timestampMs) {
  final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestampMs));
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return '${DateTime.fromMillisecondsSinceEpoch(timestampMs).month}/${DateTime.fromMillisecondsSinceEpoch(timestampMs).day}';
}

String _historyPositionLabel(WzListeningHistoryEntry entry) {
  if (entry.lastPositionMs <= 0) return entry.durationMs == null ? 'Ready to play' : 'Start from beginning';
  final total = entry.durationMs;
  final position = _formatDuration(entry.lastPositionMs);
  if (total == null || total <= 0) return 'Resume at $position';
  return 'Resume at $position of ${_formatDuration(total)}';
}

String _formatDuration(int ms) {
  final totalSeconds = (ms / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _HomeHistorySection extends StatelessWidget {
  const _HomeHistorySection({
    required this.entries,
    required this.continueEntry,
    required this.mostPlayedEntry,
    required this.resolver,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onAddToCollection,
    required this.onRemove,
    required this.onViewAll,
  });

  final List<WzListeningHistoryEntry> entries;
  final WzListeningHistoryEntry? continueEntry;
  final WzListeningHistoryEntry? mostPlayedEntry;
  final CatalogTrackSummary? Function(WzListeningHistoryEntry entry) resolver;
  final ValueChanged<WzListeningHistoryEntry> onPlay;
  final ValueChanged<WzListeningHistoryEntry> onAddToQueue;
  final ValueChanged<WzListeningHistoryEntry> onAddToCollection;
  final ValueChanged<WzListeningHistoryEntry> onRemove;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final recent = entries.take(6).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WzSectionHeader(
          title: 'Continue Listening',
          subtitle: 'Listening history stays on this device.',
          icon: Icons.history,
        ),
        WzPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (continueEntry == null)
                const Text('No listening history yet. Play a track from Library, Search, or Downloads to continue here.', style: WzText.body)
              else
                _ContinueListeningCard(entry: continueEntry!, available: resolver(continueEntry!) != null, onPlay: () => onPlay(continueEntry!)),
              const SizedBox(height: WzSpacing.md),
              Wrap(
                spacing: WzSpacing.sm,
                runSpacing: WzSpacing.sm,
                children: [
                  WzMiniMetric(label: 'History count', value: '${entries.length}', active: entries.isNotEmpty, icon: Icons.history),
                  WzMiniMetric(label: 'Most played', value: mostPlayedEntry?.title ?? 'None yet', active: mostPlayedEntry != null, icon: Icons.repeat),
                  const WzMiniMetric(label: 'Privacy', value: 'Device only', active: true, icon: Icons.lock),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        WzSectionHeader(
          title: 'Recently Played',
          subtitle: recent.isEmpty ? 'Your latest plays will show up here.' : 'Last ${recent.length} tracks saved locally.',
          icon: Icons.schedule,
        ),
        WzPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recent.isEmpty)
                const Text('No listening history yet. Play a track to start.', style: WzText.body)
              else
                ...recent.map((entry) => _HistoryEntryTile(
                      entry: entry,
                      available: resolver(entry) != null,
                      compact: true,
                      onPlay: () => onPlay(entry),
                      onAddToQueue: () => onAddToQueue(entry),
                      onAddToCollection: () => onAddToCollection(entry),
                      onRemove: () => onRemove(entry),
                    )),
              const SizedBox(height: WzSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(onPressed: onViewAll, icon: const Icon(Icons.open_in_full), label: const Text('View all')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContinueListeningCard extends StatelessWidget {
  const _ContinueListeningCard({required this.entry, required this.available, required this.onPlay});

  final WzListeningHistoryEntry entry;
  final bool available;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
            WzStatusPill(label: _historySourceLabel(entry.source), active: available, warning: !available, icon: Icons.album),
            WzStatusPill(label: entry.license.badgeLabel, warning: entry.license.needsRightsWarning, icon: Icons.policy),
            if (entry.qualityLabel != null) WzStatusPill(label: _productQualityLabel(entry.qualityLabel!), icon: Icons.high_quality),
          ]),
          const SizedBox(height: WzSpacing.sm),
          Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.title),
          const SizedBox(height: WzSpacing.xxs),
          Text('${entry.subtitle} • ${_historyPositionLabel(entry)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.body),
          if (!available) ...[
            const SizedBox(height: WzSpacing.xs),
            const Text('Track is not available right now.', style: WzText.caption),
          ],
          const SizedBox(height: WzSpacing.md),
          WzPrimaryAction(label: entry.lastPositionMs > 0 ? 'Continue' : 'Play', icon: Icons.play_arrow, onPressed: available ? onPlay : null),
        ],
      );
}


class _SearchPage extends StatelessWidget {
  const _SearchPage({
    required this.controller,
    required this.onBack,
    required this.filter,
    required this.results,
    required this.allResultCount,
    required this.recentSearches,
    required this.history,
    required this.cachedTracks,
    required this.collections,
    required this.catalogTracks,
    required this.onFilterChanged,
    required this.onClearQuery,
    required this.onRecentSearch,
    required this.onClearRecentSearches,
    required this.onSubmitted,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onAddToCollection,
    required this.onOpenCollection,
    required this.onImportDeviceMusic,
    required this.onLoadCatalog,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final _SearchFilter filter;
  final List<WzSearchResult> results;
  final int allResultCount;
  final List<String> recentSearches;
  final List<WzListeningHistoryEntry> history;
  final List<CatalogTrackSummary> cachedTracks;
  final List<WzCollection> collections;
  final List<CatalogTrackSummary> catalogTracks;
  final ValueChanged<_SearchFilter> onFilterChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onRecentSearch;
  final VoidCallback? onClearRecentSearches;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<WzSearchResult> onPlay;
  final ValueChanged<WzSearchResult> onAddToQueue;
  final ValueChanged<WzSearchResult> onAddToCollection;
  final ValueChanged<WzSearchResult> onOpenCollection;
  final VoidCallback onImportDeviceMusic;
  final VoidCallback onLoadCatalog;

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim();
    final hasQuery = query.isNotEmpty;
    return WzPageScaffold(
      children: [
        WzPageHeader(
          icon: Icons.search,
          title: 'Search',
          subtitle: 'Find tracks, downloads, collections, and recent plays on this device.',
          trailing: IconButton.outlined(tooltip: 'Back to Home', onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        ),
        const SizedBox(height: WzSpacing.md),
        WzPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  labelText: 'Search music',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: hasQuery ? IconButton(onPressed: onClearQuery, icon: const Icon(Icons.close)) : null,
                ),
              ),
              const SizedBox(height: WzSpacing.sm),
              Wrap(
                spacing: WzSpacing.xs,
                runSpacing: WzSpacing.xs,
                children: _SearchFilter.values
                    .map((item) => ChoiceChip(
                          label: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                          selected: filter == item,
                          onSelected: (_) => onFilterChanged(item),
                        ))
                    .toList(growable: false),
              ),
              const SizedBox(height: WzSpacing.sm),
              Text(
                hasQuery ? '$query • ${filter.label} • ${results.length} result${results.length == 1 ? '' : 's'}' : 'Search is local-only across $allResultCount available items.',
                style: WzText.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        if (!hasQuery) ...[
          if (recentSearches.isNotEmpty) ...[
            const WzSectionHeader(title: 'Recent searches', subtitle: 'Stored on this device only.', icon: Icons.manage_search),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: onClearRecentSearches, child: const Text('Clear'))),
            WzPanel(child: Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: recentSearches.map((query) => ActionChip(label: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis), onPressed: () => onRecentSearch(query))).toList(growable: false))),
            const SizedBox(height: WzSpacing.md),
          ],
          _SearchDiscoverySections(
            history: history,
            cachedTracks: cachedTracks,
            collections: collections,
            catalogTracks: catalogTracks,
            onRecent: (entry) => onRecentSearch(entry.title),
            onTrack: (track) => onRecentSearch(track.title),
            onCollection: (collection) => onRecentSearch(collection.name),
          ),
        ] else if (results.isEmpty) ...[
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No search results found on this device.', style: WzText.title),
                const SizedBox(height: WzSpacing.xs),
                const Text('Import Device music or load the Catalog to search more.', style: WzText.body),
                const SizedBox(height: WzSpacing.md),
                Wrap(spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
                  WzPrimaryAction(label: 'Import Device music', icon: Icons.perm_media, onPressed: onImportDeviceMusic),
                  OutlinedButton.icon(onPressed: onLoadCatalog, icon: const Icon(Icons.refresh), label: const Text('Load catalog')),
                ]),
              ],
            ),
          ),
        ] else ...[
          ...results.map((result) => Padding(
                padding: const EdgeInsets.only(bottom: WzSpacing.sm),
                child: _SearchResultCard(
                  result: result,
                  onPlay: () => onPlay(result),
                  onAddToQueue: () => onAddToQueue(result),
                  onAddToCollection: () => onAddToCollection(result),
                  onOpenCollection: result.type == WzSearchResultType.collection ? () => onOpenCollection(result) : null,
                ),
              )),
        ],
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result, required this.onPlay, required this.onAddToQueue, required this.onAddToCollection, required this.onOpenCollection});

  final WzSearchResult result;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;
  final VoidCallback onAddToCollection;
  final VoidCallback? onOpenCollection;

  @override
  Widget build(BuildContext context) => WzPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFF20283A), child: Icon(_searchResultIcon(result), color: WzColors.textPrimary)),
                const SizedBox(width: WzSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.title),
                      const SizedBox(height: WzSpacing.xxs),
                      Text(result.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: WzSpacing.sm),
            Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
              WzStatusPill(label: _searchSourceLabel(result.source), active: true, icon: Icons.label_outline),
              WzStatusPill(label: _searchTypeLabel(result.type), icon: _searchResultIcon(result)),
              if (result.qualityLabel != null) WzStatusPill(label: _productQualityLabel(result.qualityLabel!), icon: Icons.high_quality),
              if (result.codec != null) WzStatusPill(label: result.codec!, icon: Icons.settings_input_component),
              if (result.license != null) WzStatusPill(label: result.license!.badgeLabel, warning: result.license!.needsRightsWarning, icon: Icons.policy),
              if (!result.available) const WzStatusPill(label: 'Unavailable', warning: true, icon: Icons.block),
            ]),
            const SizedBox(height: WzSpacing.xs),
            Text(result.secondaryLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
            const SizedBox(height: WzSpacing.sm),
            Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
              if (onOpenCollection != null)
                WzPrimaryAction(label: 'Open Collection', icon: Icons.open_in_full, onPressed: onOpenCollection)
              else ...[
                WzPrimaryAction(label: 'Play', icon: Icons.play_arrow, onPressed: result.available ? onPlay : null),
                OutlinedButton.icon(onPressed: result.available ? onAddToQueue : null, icon: const Icon(Icons.queue_music), label: const Text('Add to Queue')),
                OutlinedButton.icon(onPressed: result.available ? onAddToCollection : null, icon: const Icon(Icons.playlist_add), label: const Text('Add to Collection')),
              ],
            ]),
          ],
        ),
      );
}

class _SearchDiscoverySections extends StatelessWidget {
  const _SearchDiscoverySections({required this.history, required this.cachedTracks, required this.collections, required this.catalogTracks, required this.onRecent, required this.onTrack, required this.onCollection});

  final List<WzListeningHistoryEntry> history;
  final List<CatalogTrackSummary> cachedTracks;
  final List<WzCollection> collections;
  final List<CatalogTrackSummary> catalogTracks;
  final ValueChanged<WzListeningHistoryEntry> onRecent;
  final ValueChanged<CatalogTrackSummary> onTrack;
  final ValueChanged<WzCollection> onCollection;

  @override
  Widget build(BuildContext context) {
    final visibleCollections = collections.where((collection) => collection.trackCount > 0 || collection.type == WzCollectionType.liked).take(5).toList(growable: false);
    final sections = <Widget>[];
    if (history.isNotEmpty) {
      sections.add(_DiscoveryPanel(title: 'Continue Listening', subtitle: 'Latest saved play.', icon: Icons.play_circle, children: [_DiscoveryButton(label: history.first.title, detail: history.first.subtitle, icon: Icons.history, onTap: () => onRecent(history.first))]));
      sections.add(_DiscoveryPanel(title: 'Recently Played', subtitle: 'Local listening history.', icon: Icons.schedule, children: history.take(5).map((entry) => _DiscoveryButton(label: entry.title, detail: entry.subtitle, icon: Icons.history, onTap: () => onRecent(entry))).toList(growable: false)));
    }
    if (cachedTracks.isNotEmpty) sections.add(_DiscoveryPanel(title: 'Downloaded / Offline Ready', subtitle: 'Cached tracks available locally.', icon: Icons.download_done, children: cachedTracks.take(5).map((track) => _DiscoveryButton(label: track.title, detail: track.subtitle, icon: Icons.download_done, onTap: () => onTrack(track))).toList(growable: false)));
    if (visibleCollections.isNotEmpty) sections.add(_DiscoveryPanel(title: 'Collections', subtitle: 'Liked Tracks and local playlists.', icon: Icons.playlist_play, children: visibleCollections.map((collection) => _DiscoveryButton(label: collection.name, detail: '${collection.trackCount} tracks', icon: collection.type == WzCollectionType.liked ? Icons.favorite : Icons.playlist_play, onTap: () => onCollection(collection))).toList(growable: false)));
    if (catalogTracks.isNotEmpty) sections.add(_DiscoveryPanel(title: 'Legal demo catalog', subtitle: 'Loaded catalog tracks with license labels.', icon: Icons.cloud_queue, children: catalogTracks.take(5).map((track) => _DiscoveryButton(label: track.title, detail: '${track.subtitle} • ${track.license.badgeLabel}', icon: Icons.music_note, onTap: () => onTrack(track))).toList(growable: false)));
    if (sections.isEmpty) return const WzPanel(child: Text('Import Device music or load the Catalog to search more.', style: WzText.body));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections.expand((section) => [section, const SizedBox(height: WzSpacing.md)]).toList(growable: false));
  }
}

class _DiscoveryPanel extends StatelessWidget {
  const _DiscoveryPanel({required this.title, required this.subtitle, required this.icon, required this.children});
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [WzSectionHeader(title: title, subtitle: subtitle, icon: icon), WzPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))]);
}

class _DiscoveryButton extends StatelessWidget {
  const _DiscoveryButton({required this.label, required this.detail, required this.icon, required this.onTap});
  final String label;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon), title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: onTap);
}

class _ListeningHistoryPage extends StatelessWidget {
  const _ListeningHistoryPage({
    required this.entries,
    required this.onBack,
    required this.mostPlayedEntry,
    required this.resolver,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onAddToCollection,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<WzListeningHistoryEntry> entries;
  final VoidCallback onBack;
  final WzListeningHistoryEntry? mostPlayedEntry;
  final CatalogTrackSummary? Function(WzListeningHistoryEntry entry) resolver;
  final ValueChanged<WzListeningHistoryEntry> onPlay;
  final ValueChanged<WzListeningHistoryEntry> onAddToQueue;
  final ValueChanged<WzListeningHistoryEntry> onAddToCollection;
  final ValueChanged<WzListeningHistoryEntry> onRemove;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) => WzPageScaffold(
        children: [
          WzPageHeader(
            icon: Icons.history,
            title: 'Listening History',
            subtitle: 'Recently played tracks saved locally on this device.',
            trailing: Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [IconButton.outlined(tooltip: 'Back to Home', onPressed: onBack, icon: const Icon(Icons.arrow_back)), OutlinedButton.icon(onPressed: onClearAll, icon: const Icon(Icons.delete_sweep), label: const Text('Clear'))]),
          ),
          const SizedBox(height: WzSpacing.md),
          WzPanel(
            child: Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzMiniMetric(label: 'Recently played', value: '${entries.length}', active: entries.isNotEmpty, icon: Icons.history),
                WzMiniMetric(label: 'Most played', value: mostPlayedEntry?.title ?? 'None yet', active: mostPlayedEntry != null, icon: Icons.repeat),
                const WzMiniMetric(label: 'Privacy', value: 'Local only', active: true, icon: Icons.lock),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (entries.isEmpty)
                  const Text('No listening history yet. Play a track to start.', style: WzText.body)
                else
                  ...entries.map((entry) => _HistoryEntryTile(
                        entry: entry,
                        available: resolver(entry) != null,
                        onPlay: () => onPlay(entry),
                        onAddToQueue: () => onAddToQueue(entry),
                        onAddToCollection: () => onAddToCollection(entry),
                        onRemove: () => onRemove(entry),
                      )),
                const SizedBox(height: WzSpacing.sm),
                const Text('Removing history does not unlike tracks, delete collections, or remove downloads/cache.', style: WzText.caption),
              ],
            ),
          ),
        ],
      );
}

class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({
    required this.entry,
    required this.available,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onAddToCollection,
    required this.onRemove,
    this.compact = false,
  });

  final WzListeningHistoryEntry entry;
  final bool available;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;
  final VoidCallback onAddToCollection;
  final VoidCallback onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: WzSpacing.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: WzColors.surfaceElevated,
            borderRadius: BorderRadius.circular(WzRadius.lg),
            border: Border.all(color: WzColors.borderSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(WzSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle)),
                    const SizedBox(width: WzSpacing.xs),
                    Text(_friendlyHistoryTime(entry.lastPlayedAtMs), style: WzText.caption),
                  ],
                ),
                const SizedBox(height: WzSpacing.xxs),
                Text(entry.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.body),
                const SizedBox(height: WzSpacing.xs),
                Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
                  WzStatusPill(label: _historySourceLabel(entry.source), active: available, warning: !available, icon: Icons.album),
                  WzStatusPill(label: '${entry.playCount} play${entry.playCount == 1 ? '' : 's'}', icon: Icons.repeat),
                  if (entry.qualityLabel != null) WzStatusPill(label: _productQualityLabel(entry.qualityLabel!), icon: Icons.high_quality),
                  WzStatusPill(label: entry.license.badgeLabel, warning: entry.license.needsRightsWarning, icon: Icons.policy),
                ]),
                if (!available) ...[
                  const SizedBox(height: WzSpacing.xs),
                  const Text('Track is not available right now.', style: WzText.caption),
                ],
                const SizedBox(height: WzSpacing.sm),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: [
                    FilledButton.icon(onPressed: available ? onPlay : null, icon: const Icon(Icons.play_arrow), label: Text(compact ? 'Play' : 'Play / Continue')),
                    OutlinedButton.icon(onPressed: available ? onAddToQueue : null, icon: const Icon(Icons.queue_music), label: const Text('Queue')),
                    OutlinedButton.icon(onPressed: available ? onAddToCollection : null, icon: const Icon(Icons.playlist_add), label: const Text('Collection')),
                    TextButton.icon(onPressed: onRemove, icon: const Icon(Icons.close), label: const Text('Remove')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}


class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.themeConfig,
    required this.onThemePresetChanged,
    required this.onAccentPresetChanged,
    required this.preferredAudioQuality,
    required this.onQualityChanged,
    required this.selectedAudioEffectProfile,
    required this.nativeAudioEffectStatus,
    required this.lastAudioEffectApplyResult,
    required this.onAudioEffectChanged,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerLabel,
    required this.sleepTimerActive,
    required this.onShuffleChanged,
    required this.onRepeatModeChanged,
    required this.onOpenSleepTimer,
    required this.smartDownloadsEnabled,
    required this.onSmartDownloadsChanged,
    required this.cachedTrackCount,
    required this.cacheBytes,
    required this.manualDownloadedCount,
    required this.smartDownloadedCount,
    required this.controlsDisabled,
    required this.onClearCache,
    required this.devicePermissionStatus,
    required this.devicePlatformSupported,
    required this.importedDeviceTrackCount,
    required this.deviceScanStatus,
    required this.deviceLastError,
    required this.onImportDeviceMusic,
    required this.notificationActive,
    required this.appConfig,
    required this.contentModeLabel,
    required this.catalogStatusLabel,
    required this.showDeveloperEntry,
    required this.appMode,
    required this.onDeveloperModeChanged,
    required this.onOpenEngine,
    required this.onManageStorage,
    required this.listeningHistoryCount,
    required this.mostPlayedHistoryTitle,
    required this.onOpenHistory,
    required this.onOpenSearch,
    required this.onClearRecentSearches,
    required this.onClearListeningHistory,
    required this.legalTracks,
  });

  final WzThemeConfig themeConfig;
  final ValueChanged<WzThemePreset> onThemePresetChanged;
  final ValueChanged<WzAccentPreset> onAccentPresetChanged;
  final AudioQualityTier preferredAudioQuality;
  final ValueChanged<AudioQualityTier> onQualityChanged;
  final AudioEffectProfile selectedAudioEffectProfile;
  final NativeAudioEffectStatus nativeAudioEffectStatus;
  final String lastAudioEffectApplyResult;
  final ValueChanged<AudioEffectProfile> onAudioEffectChanged;
  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final String sleepTimerLabel;
  final bool sleepTimerActive;
  final ValueChanged<bool> onShuffleChanged;
  final ValueChanged<WzRepeatMode> onRepeatModeChanged;
  final VoidCallback onOpenSleepTimer;
  final bool smartDownloadsEnabled;
  final ValueChanged<bool> onSmartDownloadsChanged;
  final int cachedTrackCount;
  final int cacheBytes;
  final int manualDownloadedCount;
  final int smartDownloadedCount;
  final bool controlsDisabled;
  final Future<void> Function() onClearCache;
  final String devicePermissionStatus;
  final bool devicePlatformSupported;
  final int importedDeviceTrackCount;
  final String deviceScanStatus;
  final String? deviceLastError;
  final Future<void> Function() onImportDeviceMusic;
  final bool notificationActive;
  final WaveZeroAppConfig appConfig;
  final String contentModeLabel;
  final String catalogStatusLabel;
  final bool showDeveloperEntry;
  final _AppMode appMode;
  final ValueChanged<bool> onDeveloperModeChanged;
  final VoidCallback? onOpenEngine;
  final VoidCallback onManageStorage;
  final int listeningHistoryCount;
  final String? mostPlayedHistoryTitle;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenSearch;
  final VoidCallback? onClearRecentSearches;
  final VoidCallback? onClearListeningHistory;
  final List<CatalogTrackSummary> legalTracks;

  @override
  Widget build(BuildContext context) => WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'A calm control center for appearance, playback, storage, device music, and app mode.',
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Search & Discovery', subtitle: WaveZeroReleaseCopy.searchLocal, icon: Icons.search),
          WzPanel(
            child: Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzPrimaryAction(label: 'View search', icon: Icons.search, onPressed: onOpenSearch),
                OutlinedButton.icon(onPressed: onClearRecentSearches, icon: const Icon(Icons.clear_all), label: const Text('Clear recent searches')),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Appearance', subtitle: 'Theme choices are persisted on this device.', icon: Icons.palette),
          WzPanel(
            gradient: themeConfig.shellGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: WzThemePreset.values
                      .map((preset) => ChoiceChip(
                            label: Text(preset.label),
                            selected: themeConfig.themePreset == preset,
                            onSelected: (_) => onThemePresetChanged(preset),
                          ))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: WzAccentPreset.values
                      .map((preset) => ChoiceChip(
                            avatar: CircleAvatar(backgroundColor: WzThemeConfig(accentPreset: preset).accent, radius: 7),
                            label: Text(preset.label),
                            selected: themeConfig.accentPreset == preset,
                            onSelected: (_) => onAccentPresetChanged(preset),
                          ))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.md),
                Container(
                  padding: const EdgeInsets.all(WzSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(WzRadius.lg),
                    border: Border.all(color: themeConfig.accent.withOpacity(0.55)),
                    gradient: themeConfig.accentGradient,
                  ),
                  child: const Text('Preview: selected theme and accent are applied to app controls, navigation, and the shell.', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Playback', subtitle: 'User-friendly playback, quality, and effect preferences.', icon: Icons.graphic_eq),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Shuffle'),
                  subtitle: Text(shuffleEnabled ? 'Shuffle on' : 'Shuffle off'),
                  value: shuffleEnabled,
                  onChanged: controlsDisabled ? null : onShuffleChanged,
                ),
                const SizedBox(height: WzSpacing.xs),
                Text('Repeat mode', style: WzText.sectionTitle),
                const SizedBox(height: WzSpacing.xs),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: WzRepeatMode.values
                      .map((mode) => ChoiceChip(
                            avatar: Icon(mode.icon, size: 18),
                            label: Text(mode.label),
                            selected: repeatMode == mode,
                            onSelected: controlsDisabled ? null : (_) => onRepeatModeChanged(mode),
                          ))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    WzStatusPill(label: sleepTimerLabel, active: sleepTimerActive, icon: sleepTimerActive ? Icons.bedtime : Icons.timer_outlined),
                    OutlinedButton.icon(onPressed: controlsDisabled ? null : onOpenSleepTimer, icon: const Icon(Icons.timer_outlined), label: const Text('Sleep timer')),
                  ],
                ),
                const SizedBox(height: WzSpacing.md),
                Text('Preferred audio quality', style: WzText.sectionTitle),
                const SizedBox(height: WzSpacing.xs),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: [AudioQualityTier.standard, AudioQualityTier.high, AudioQualityTier.original]
                      .map((tier) => ChoiceChip(
                            label: Text(_productQualityLabel(tier.label)),
                            selected: preferredAudioQuality == tier,
                            onSelected: controlsDisabled ? null : (_) => onQualityChanged(tier),
                          ))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.xs),
                Text('Current selected quality: ${_productQualityLabel(preferredAudioQuality.label)}. If a track does not include that asset, WaveZero chooses the closest available quality.', style: WzText.caption),
                const SizedBox(height: WzSpacing.md),
                Text('Audio effects profile', style: WzText.sectionTitle),
                const SizedBox(height: WzSpacing.xs),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: AudioEffectProfile.values
                      .map((profile) => ChoiceChip(
                            label: Text(profile.shortLabel),
                            selected: selectedAudioEffectProfile == profile,
                            onSelected: controlsDisabled ? null : (_) => onAudioEffectChanged(profile),
                          ))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.xs),
                Text('Off / Original is the safest default. ${nativeAudioEffectStatus == NativeAudioEffectStatus.unsupported ? 'Effect profile saved. Native DSP support is still foundation-level.' : lastAudioEffectApplyResult}', maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.caption),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Downloads & Storage', subtitle: WaveZeroReleaseCopy.downloadsStayOnDevice, icon: Icons.offline_pin),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Smart Downloads'),
                  subtitle: const Text('WaveZero can cache the current and up-next tracks for faster offline-ready playback.'),
                  value: smartDownloadsEnabled,
                  onChanged: onSmartDownloadsChanged,
                ),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzMiniMetric(label: 'Cached for offline', value: '$cachedTrackCount', active: cachedTrackCount > 0, icon: Icons.library_music),
                    WzMiniMetric(label: 'Device storage', value: _formatCacheBytes(cacheBytes), active: cacheBytes > 0, icon: Icons.sd_storage),
                    WzMiniMetric(label: 'Manual', value: '$manualDownloadedCount', active: manualDownloadedCount > 0, icon: Icons.download_done),
                    WzMiniMetric(label: 'Smart', value: '$smartDownloadedCount', active: smartDownloadedCount > 0, icon: Icons.auto_awesome),
                  ],
                ),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzPrimaryAction(label: 'Manage storage', icon: Icons.storage, onPressed: onManageStorage),
                    OutlinedButton.icon(
                      onPressed: controlsDisabled || cachedTrackCount == 0 ? null : () => unawaited(onClearCache()),
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear all downloads'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Listening History', subtitle: WaveZeroReleaseCopy.historyLocal, icon: Icons.history),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzMiniMetric(label: 'Recently played', value: '$listeningHistoryCount', active: listeningHistoryCount > 0, icon: Icons.history),
                    WzMiniMetric(label: 'Most played', value: mostPlayedHistoryTitle ?? 'None yet', active: mostPlayedHistoryTitle != null, icon: Icons.repeat),
                    const WzMiniMetric(label: 'Privacy', value: 'Device only', active: true, icon: Icons.lock),
                  ],
                ),
                const SizedBox(height: WzSpacing.sm),
                const Text('Clear listening history does not delete downloads, playlists, collections, or device music.', style: WzText.caption),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzPrimaryAction(label: 'View History', icon: Icons.history, onPressed: onOpenHistory),
                    OutlinedButton.icon(
                      onPressed: onClearListeningHistory,
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Clear listening history'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Device music', subtitle: WaveZeroReleaseCopy.deviceMusicPermission, icon: Icons.perm_media),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzStatusPill(label: 'Permission: $devicePermissionStatus', active: devicePermissionStatus == 'granted', warning: devicePermissionStatus.contains('denied'), icon: Icons.privacy_tip),
                    WzStatusPill(label: devicePlatformSupported ? 'Platform supported' : 'Platform unavailable', active: devicePlatformSupported, warning: !devicePlatformSupported, icon: Icons.phone_android),
                    WzStatusPill(label: 'Scan: $deviceScanStatus', active: deviceScanStatus == 'success', warning: deviceScanStatus == 'error', icon: Icons.search),
                  ],
                ),
                const SizedBox(height: WzSpacing.sm),
                Text('Imported device tracks: $importedDeviceTrackCount', style: WzText.body),
                const Text(WaveZeroReleaseCopy.deviceMusicPrivacy, style: WzText.caption),
                if (deviceLastError != null) Text('Last message: $deviceLastError', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzPrimaryAction(label: 'Import Device music', icon: Icons.library_add, onPressed: controlsDisabled ? null : () => unawaited(onImportDeviceMusic())),
                    OutlinedButton.icon(onPressed: controlsDisabled ? null : () => unawaited(onImportDeviceMusic()), icon: const Icon(Icons.refresh), label: const Text('Rescan Device music')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Notifications & Lock Screen', subtitle: 'Playback session presentation.', icon: Icons.notifications_active),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
                  WzStatusPill(label: notificationActive ? 'Media notification active' : 'Media notification inactive', active: notificationActive, icon: Icons.notifications),
                  WzStatusPill(label: notificationActive ? 'Lock-screen controls ready' : 'Start playback to enable controls', active: notificationActive, icon: Icons.lock),
                ]),
                const SizedBox(height: WzSpacing.xs),
                const Text('Lock-screen controls use the current playback session and current track metadata when playback is active.', style: WzText.caption),
              ],
            ),
          ),
          const SizedBox(height: WzSpacing.md),
          if (showDeveloperEntry) ...[
            const WzSectionHeader(title: 'Developer', subtitle: 'Keep diagnostics separate from the consumer experience.', icon: Icons.developer_mode),
            WzPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Developer Mode'),
                    subtitle: Text(appMode == _AppMode.developer ? 'On — Engine diagnostics are available in the bottom navigation.' : 'Off — consumer navigation stays clean.'),
                    value: appMode == _AppMode.developer,
                    onChanged: onDeveloperModeChanged,
                  ),
                  if (appMode == _AppMode.developer) ...[
                    const SizedBox(height: WzSpacing.xs),
                    const Text('Engine diagnostics remain in the Engine tab and are not shown as raw metrics on consumer Settings.', style: WzText.caption),
                    const SizedBox(height: WzSpacing.sm),
                    WzPrimaryAction(label: 'Open Engine diagnostics', icon: Icons.engineering, onPressed: onOpenEngine),
                  ],
                ],
              ),
            ),
            const SizedBox(height: WzSpacing.md),
          ],
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'About', subtitle: 'WaveZero app information.', icon: Icons.info_outline),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WaveZero', style: WzText.title),
                const SizedBox(height: WzSpacing.xs),
                const Text('A smart music experience engine for native playback, offline listening, queue intelligence, and premium now-playing UX.', style: WzText.body),
                const SizedBox(height: WzSpacing.xs),
                Text('Version/build: ${appConfig.displayVersion} • ${appConfig.buildLabel}', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                Text('App environment: ${appConfig.appEnvLabel}', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                Text('Content mode: $contentModeLabel', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                Text('Catalog status: $catalogStatusLabel', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                const Text('Local privacy: Device Music, downloads, collections, search history, and listening history stay on this device unless you choose otherwise.', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                const Text('Device Music belongs to your device context. WaveZero does not upload your device music.', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                const Text('Catalog tracks require explicit rights metadata. Dev-only tracks are not production-safe, and beta builds do not claim commercial catalog rights.', style: WzText.caption),
                const SizedBox(height: WzSpacing.sm),
                WzPrimaryAction(
                  label: 'Open Legal / Licenses',
                  icon: Icons.policy,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => _LegalLicensesPage(tracks: legalTracks, appMode: appMode),
                  )),
                ),
              ],
            ),
          ),
        ],
      );
}

String _formatCacheBytes(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

Map<String, int> _cachedTrackSizeMap(List<CachedTrackMetadata> tracks) {
  final sizes = <String, int>{};
  for (final track in tracks) {
    final path = track.localFilePath;
    if (path.isEmpty) continue;
    try {
      final file = File(path);
      if (file.existsSync()) sizes[track.trackId] = file.lengthSync();
    } catch (_) {}
  }
  return sizes;
}


class _WzTokens {
  const _WzTokens._();

  static const Color canvas = WzColors.canvas;
  static const Color surface = WzColors.surface;
  static const Color surfaceElevated = WzColors.surfaceElevated;
  static const Color surfaceMuted = WzColors.surfaceMuted;
  static const Color border = WzColors.border;
  static const Color borderSoft = WzColors.borderSoft;
  static const Color accent = WzColors.accent;
  static const Color accentSoft = WzColors.accentSoft;
  static const Color success = WzColors.success;
  static const Color successSoft = WzColors.successSoft;
  static const Color warning = WzColors.warning;
  static const Color warningSoft = WzColors.warningSoft;
  static const Color textPrimary = WzColors.textPrimary;
  static const Color textMuted = WzColors.textMuted;
  static const Color textSubtle = WzColors.textSubtle;

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double radiusMd = 18;
  static const double radiusLg = 26;
  static const double radiusXl = 32;

  static const TextStyle eyebrow = TextStyle(
    color: accent,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
  );
  static const TextStyle title = TextStyle(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
  );
  static const TextStyle body = TextStyle(color: textMuted, fontSize: 13, height: 1.35);
  static const TextStyle caption = TextStyle(color: textSubtle, fontSize: 12, height: 1.3);
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WaveZero',
                  style: TextStyle(
                    color: _WzTokens.textPrimary,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                SizedBox(height: _WzTokens.space1),
                Text(
                  'Premium music engine shell for predictive native playback.',
                  style: _WzTokens.body,
                ),
              ],
            ),
          ),
          Icon(Icons.graphic_eq, color: _WzTokens.accent),
        ],
      );
}


class _ProductShellHeader extends StatelessWidget {
  const _ProductShellHeader({
    required this.selectedTabLabel,
    required this.status,
    required this.engineSummary,
    required this.offlineReady,
    required this.appMode,
    required this.themeConfig,
    required this.onLogoLongPress,
    required this.onOpenSettings,
  });

  final String selectedTabLabel;
  final String status;
  final String engineSummary;
  final bool offlineReady;
  final _AppMode appMode;
  final WzThemeConfig themeConfig;
  final VoidCallback onLogoLongPress;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: WzPanel(
          padding: const EdgeInsets.symmetric(horizontal: WzSpacing.sm, vertical: WzSpacing.xs),
          gradient: themeConfig.shellGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onLongPress: onLogoLongPress,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: themeConfig.accentGradient,
                        borderRadius: BorderRadius.circular(WzRadius.md),
                      ),
                      child: const Icon(Icons.graphic_eq, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: WzSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WaveZero',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                        ),
                        const SizedBox(height: WzSpacing.xxs),
                        Text(
                          appMode == _AppMode.developer
                              ? '$selectedTabLabel • Developer mode • $engineSummary'
                              : '$selectedTabLabel • $engineSummary',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WzText.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: onOpenSettings,
                    icon: Icon(Icons.settings, color: themeConfig.accent),
                  ),
                ],
              ),
              const SizedBox(height: WzSpacing.xs),
              Wrap(
                spacing: WzSpacing.xs,
                runSpacing: WzSpacing.xs,
                children: [
                  WzStatusPill(label: status, active: status == 'Playing', warning: status == 'Error', icon: Icons.radio_button_checked),
                  WzStatusPill(label: offlineReady ? 'Offline Ready' : 'Online catalog', active: offlineReady, icon: Icons.offline_pin),
                ],
              ),
            ],
          ),
        ),
      );
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.engineSummary, required this.themeConfig});

  final String engineSummary;
  final WzThemeConfig themeConfig;

  @override
  Widget build(BuildContext context) => WzPanel(
        padding: const EdgeInsets.all(WzSpacing.md),
        gradient: themeConfig.shellGradient,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WaveZero', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: WzText.title),
            const SizedBox(height: WzSpacing.xs),
            const Text('A smart music experience engine.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: WzColors.textMuted, height: 1.35)),
            const SizedBox(height: WzSpacing.md),
            Wrap(
              spacing: WzSpacing.xs,
              runSpacing: WzSpacing.xs,
              children: [
                const WzStatusPill(label: 'Native playback', active: true, icon: Icons.phone_android),
                WzStatusPill(label: engineSummary, active: true, icon: Icons.auto_awesome),
              ],
            ),
          ],
        ),
      );
}

class _HomeContinueListeningSummary extends StatelessWidget {
  const _HomeContinueListeningSummary({
    required this.title,
    required this.subtitle,
    required this.sourceLabel,
    required this.isPlaying,
    required this.onOpenNow,
  });

  final String title;
  final String subtitle;
  final String sourceLabel;
  final bool isPlaying;
  final VoidCallback onOpenNow;

  @override
  Widget build(BuildContext context) => WzPanel(
        padding: const EdgeInsets.all(WzSpacing.md),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: WzColors.accentGradient,
                borderRadius: BorderRadius.circular(WzRadius.lg),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 10))],
              ),
              child: Icon(isPlaying ? Icons.equalizer : Icons.album_rounded, color: Colors.white),
            ),
            const SizedBox(width: WzSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isPlaying ? 'Continue listening' : 'Ready when you are', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.eyebrow),
                  const SizedBox(height: WzSpacing.xxs),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                  Text('$subtitle • $sourceLabel', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                ],
              ),
            ),
            const SizedBox(width: WzSpacing.sm),
            IconButton.filledTonal(tooltip: 'Open Now', onPressed: onOpenNow, icon: const Icon(Icons.open_in_full)),
          ],
        ),
      );
}

class _CurrentListeningCard extends StatelessWidget {
  const _CurrentListeningCard({
    required this.metrics,
    required this.manifest,
    required this.qualityLabel,
    required this.playingFromCache,
    required this.devicePlayback,
    required this.offlineReady,
    required this.deviceTrackCount,
    required this.devicePermissionStatus,
    required this.status,
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final String qualityLabel;
  final bool playingFromCache;
  final bool devicePlayback;
  final bool offlineReady;
  final int deviceTrackCount;
  final String devicePermissionStatus;
  final String status;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? 'No track loaded';
    return WzPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WzSectionHeader(title: 'Current listening', subtitle: 'Real playback state from the engine.', icon: Icons.album),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;
              final art = _Artwork(artworkUrl: manifest?.artworkUrl, size: compact ? 84 : 108);
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.title),
                  const SizedBox(height: WzSpacing.xs),
                  Text(manifest?.subtitle ?? 'Choose a track from Library to start listening.', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.body),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    art,
                    const SizedBox(height: WzSpacing.sm),
                    identity,
                  ],
                );
              }
              return Row(
                children: [
                  art,
                  const SizedBox(width: WzSpacing.md),
                  Expanded(child: identity),
                ],
              );
            },
          ),
          const SizedBox(height: WzSpacing.md),
          Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              WzStatusPill(label: status, active: metrics.isPlaying, warning: status == 'Error', icon: metrics.isPlaying ? Icons.play_arrow : Icons.pause),
              WzStatusPill(label: 'Quality: ${_productQualityLabel(qualityLabel)}', active: qualityLabel != 'unknown', icon: Icons.high_quality),
              if (devicePlayback) const WzStatusPill(label: 'Device music', active: true, icon: Icons.phone_android),
              if (playingFromCache) const WzStatusPill(label: 'Downloaded', active: true, icon: Icons.offline_pin),
              if (offlineReady) const WzStatusPill(label: 'Offline Ready', active: true, icon: Icons.download_done),
              WzStatusPill(label: 'Device music: $deviceTrackCount', active: deviceTrackCount > 0, icon: Icons.perm_media),
              WzStatusPill(label: 'Permission: $devicePermissionStatus', active: devicePermissionStatus == 'granted', warning: devicePermissionStatus.contains('denied'), icon: Icons.privacy_tip),
            ],
          ),
        ],
      ),
    );
  }
}


class _HomeCollectionsOfflineSection extends StatelessWidget {
  const _HomeCollectionsOfflineSection({
    required this.collections,
    required this.offlineTrackCount,
    required this.cacheBytes,
    required this.onOpenCollections,
    required this.onOpenDownloads,
  });

  final List<WzCollection> collections;
  final int offlineTrackCount;
  final int cacheBytes;
  final VoidCallback onOpenCollections;
  final VoidCallback onOpenDownloads;

  @override
  Widget build(BuildContext context) {
    final userCollectionCount = collections.where((collection) => collection.type == WzCollectionType.user).length;
    final liked = collections.firstWhere((collection) => collection.type == WzCollectionType.liked, orElse: () => WzCollection.liked());
    return WzPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WzSectionHeader(title: 'Collections & Offline Ready', subtitle: 'Saved music and downloads without duplicating the player.', icon: Icons.collections_bookmark),
          Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            children: [
              WzMiniMetric(label: 'Liked Tracks', value: '${liked.trackCount}', active: liked.trackCount > 0, icon: Icons.favorite),
              WzMiniMetric(label: 'Collections', value: '$userCollectionCount', active: userCollectionCount > 0, icon: Icons.playlist_play),
              WzMiniMetric(label: 'Offline Ready', value: offlineTrackCount > 0 ? '$offlineTrackCount tracks' : 'No downloads yet', active: offlineTrackCount > 0, icon: Icons.download_done),
              WzMiniMetric(label: 'Storage', value: _formatCacheBytes(cacheBytes), active: cacheBytes > 0, icon: Icons.sd_storage),
            ],
          ),
          const SizedBox(height: WzSpacing.md),
          Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            children: [
              WzPrimaryAction(label: 'Open Collections', icon: Icons.playlist_play, onPressed: onOpenCollections),
              OutlinedButton.icon(onPressed: onOpenDownloads, icon: const Icon(Icons.download_done), label: const Text('Open Downloads')),
            ],
          ),
          if (userCollectionCount == 0 && liked.trackCount == 0) ...[
            const SizedBox(height: WzSpacing.sm),
            const Text('No collections yet. Save tracks from Library, Search, or Now Playing.', style: WzText.caption),
          ],
          if (offlineTrackCount == 0) ...[
            const SizedBox(height: WzSpacing.xs),
            const Text('No downloads yet. Download tracks from Library to listen offline.', style: WzText.caption),
          ],
        ],
      ),
    );
  }
}

class _SmartEngineCards extends StatelessWidget {
  const _SmartEngineCards({
    required this.smartDownloadsEnabled,
    required this.smartDownloadsCompleted,
    required this.prefetchEnabled,
    required this.prefetchedTrackTitle,
    required this.offlineReady,
    required this.offlineTrackCount,
    required this.qualityLabel,
  });

  final bool smartDownloadsEnabled;
  final int smartDownloadsCompleted;
  final bool prefetchEnabled;
  final String? prefetchedTrackTitle;
  final bool offlineReady;
  final int offlineTrackCount;
  final String qualityLabel;

  @override
  Widget build(BuildContext context) => WzPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WzSectionHeader(title: 'Smart listening', subtitle: 'Downloads, instant next, and quality at a glance.', icon: Icons.auto_awesome),
            Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzMiniMetric(label: 'Smart Downloads', value: smartDownloadsEnabled ? '$smartDownloadsCompleted cached' : 'Off', active: smartDownloadsEnabled, icon: Icons.download_for_offline),
                WzMiniMetric(label: 'Instant Next / Preload', value: prefetchEnabled ? (prefetchedTrackTitle ?? 'Ready') : 'Off', active: prefetchEnabled, icon: Icons.offline_bolt),
                WzMiniMetric(label: 'Offline Ready', value: offlineReady ? '$offlineTrackCount tracks' : 'No cached tracks', active: offlineReady, icon: Icons.offline_pin),
                WzMiniMetric(label: 'Audio Quality', value: _productQualityLabel(qualityLabel), active: qualityLabel != 'unknown', icon: Icons.high_quality),
              ],
            ),
          ],
        ),
      );
}

class _HomeQuickActions extends StatelessWidget {
  const _HomeQuickActions({required this.onNavigate, required this.showDeveloperTools});

  final ValueChanged<_AppTab> onNavigate;
  final bool showDeveloperTools;

  @override
  Widget build(BuildContext context) => WzPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WzSectionHeader(title: 'Start here', subtitle: 'Find music, organize collections, or manage offline listening.', icon: Icons.bolt),
            Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzPrimaryAction(label: 'Search music', icon: Icons.search, onPressed: () => onNavigate(_AppTab.search)),
                WzPrimaryAction(label: 'Library', icon: Icons.library_music, onPressed: () => onNavigate(_AppTab.library)),
                WzPrimaryAction(label: 'Collections', icon: Icons.playlist_play, onPressed: () => onNavigate(_AppTab.collections)),
                WzPrimaryAction(label: 'Now Playing', icon: Icons.play_circle_fill, onPressed: () => onNavigate(_AppTab.now)),
                WzPrimaryAction(label: 'Queue', icon: Icons.queue_music, onPressed: () => onNavigate(_AppTab.queue)),
                WzPrimaryAction(label: 'Downloads', icon: Icons.download_done, onPressed: () => onNavigate(_AppTab.downloads)),
                WzPrimaryAction(label: 'Settings', icon: Icons.settings, onPressed: () => onNavigate(_AppTab.settings)),
                if (showDeveloperTools) WzPrimaryAction(label: 'Engine', icon: Icons.engineering, onPressed: () => onNavigate(_AppTab.engine)),
              ],
            ),
          ],
        ),
      );
}

class _NowContextPanel extends StatelessWidget {
  const _NowContextPanel({
    required this.qualityLabel,
    required this.effectsSummary,
    required this.playingFromCache,
    required this.devicePlayback,
    required this.offlineReady,
    required this.nextTrack,
    required this.manifest,
    required this.selectedEffectProfile,
    required this.nativeAudioEffectStatus,
    required this.queueIndex,
    required this.queueLength,
  });

  final String qualityLabel;
  final String effectsSummary;
  final bool playingFromCache;
  final bool devicePlayback;
  final bool offlineReady;
  final CatalogTrackSummary? nextTrack;
  final CatalogTrackManifest? manifest;
  final AudioEffectProfile selectedEffectProfile;
  final NativeAudioEffectStatus nativeAudioEffectStatus;
  final int queueIndex;
  final int queueLength;

  @override
  Widget build(BuildContext context) {
    final currentPosition = queueIndex >= 0 && queueLength > 0 ? '${queueIndex + 1} of $queueLength' : 'No active queue item';
    final bitrate = manifest?.bitrateKbps == null ? 'Unknown bitrate' : '${manifest!.bitrateKbps} kbps';
    final codec = manifest?.codec ?? 'Unknown codec';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WzSectionHeader(title: 'Player context', subtitle: 'Live quality, effects, cache, and queue state.', icon: Icons.dashboard_customize),
        _PlayerSourceCard(icon: Icons.high_quality, title: 'Audio Quality', primary: _productQualityLabel(qualityLabel), detail: '$codec • $bitrate', active: qualityLabel != 'unknown'),
        const SizedBox(height: WzSpacing.sm),
        _PlayerSourceCard(icon: Icons.tune, title: 'Audio Effects', primary: selectedEffectProfile.label, detail: 'Native status: ${_effectStatusLabel(nativeAudioEffectStatus)} • Badge: $effectsSummary', active: nativeAudioEffectStatus == NativeAudioEffectStatus.applied),
        const SizedBox(height: WzSpacing.sm),
        _PlayerSourceCard(
          icon: Icons.offline_pin,
          title: 'Cache / Offline',
          primary: devicePlayback ? 'Already local' : playingFromCache ? 'Playing from cache' : offlineReady ? 'Offline Ready' : 'Not cached',
          detail: devicePlayback ? 'Playing from Device music.' : playingFromCache ? 'Playing from Downloaded music.' : offlineReady ? 'Offline Ready music is available.' : 'No downloaded track is active right now.',
          active: devicePlayback || playingFromCache || offlineReady,
        ),
        const SizedBox(height: WzSpacing.sm),
        _PlayerSourceCard(icon: Icons.queue_music, title: 'Queue', primary: currentPosition, detail: nextTrack == null ? 'No up-next track from Queue Engine v2.' : 'Up next: ${nextTrack!.title}', active: nextTrack != null),
      ],
    );
  }
}

class _AudioQualityPanel extends StatelessWidget {
  const _AudioQualityPanel({
    required this.preferredAudioQuality,
    required this.manifest,
    required this.currentAssetUrl,
    required this.currentCachedQuality,
    required this.lastQualityFallbackReason,
    required this.controlsDisabled,
    required this.onSelected,
  });

  final AudioQualityTier preferredAudioQuality;
  final CatalogTrackManifest? manifest;
  final String? currentAssetUrl;
  final String? currentCachedQuality;
  final String lastQualityFallbackReason;
  final bool controlsDisabled;
  final ValueChanged<Set<AudioQualityTier>> onSelected;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _PanelHeader(icon: Icons.high_quality, title: 'Audio Quality', subtitle: 'Selection foundation without changing quality logic.'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AudioQualityTier.values
                .map((tier) => ChoiceChip(
                      label: Text(tier.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      selected: tier == preferredAudioQuality,
                      onSelected: controlsDisabled ? null : (_) => onSelected({tier}),
                    ))
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          Text('Preferred quality: ${_productQualityLabel(preferredAudioQuality.label)}', style: _WzTokens.caption),
          Text('Current track quality: ${_productQualityLabel(manifest?.qualityLabel ?? 'unknown')}', style: _WzTokens.caption),
          Text('Current codec: ${manifest?.codec ?? 'unknown'}', style: _WzTokens.caption),
          Text('Current bitrate: ${manifest?.bitrateKbps == null ? 'unknown' : '${manifest!.bitrateKbps} kbps'}', style: _WzTokens.caption),
          Text('Current asset URL: ${currentAssetUrl ?? manifest?.streamUrl ?? 'none'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
          Text('Quality fallback reason: $lastQualityFallbackReason', style: _WzTokens.caption),
          Text('Cached quality: ${currentCachedQuality ?? 'not playing from cache'}', style: _WzTokens.caption),
        ]),
      );
}


class _ContentServerDiagnosticsPanel extends StatelessWidget {
  const _ContentServerDiagnosticsPanel({
    required this.contentStatus,
    required this.catalogStatus,
    required this.apiBaseUrl,
    required this.configuredContentModeLabel,
    required this.catalogTrackCount,
    required this.cachedTrackCount,
  });

  final ContentStatus? contentStatus;
  final String catalogStatus;
  final String apiBaseUrl;
  final String configuredContentModeLabel;
  final int catalogTrackCount;
  final int cachedTrackCount;

  @override
  Widget build(BuildContext context) {
    final status = contentStatus;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(label: 'Content', value: status?.friendlyLabel ?? 'Catalog unavailable', active: status?.ok ?? catalogTrackCount > 0),
              _MetricCard(label: 'Mode', value: status?.contentMode ?? configuredContentModeLabel, active: status?.contentMode == 'production' || status?.contentMode == 'demo'),
              _MetricCard(label: 'Tracks', value: '${status?.trackCount ?? catalogTrackCount}', active: (status?.trackCount ?? catalogTrackCount) > 0),
              _MetricCard(label: 'Assets', value: '${status?.assetCount ?? 0}', active: (status?.assetCount ?? 0) > 0),
              _MetricCard(label: 'Production-safe', value: '${status?.productionSafeTrackCount ?? 0}', active: (status?.productionSafeTrackCount ?? 0) > 0),
              _MetricCard(label: 'Local folder', value: status?.localFolderCatalogEnabled == true ? 'enabled' : 'disabled', active: status?.localFolderCatalogEnabled == true),
              _MetricCard(label: 'Cached', value: '$cachedTrackCount', active: cachedTrackCount > 0),
            ],
          ),
          const SizedBox(height: 10),
          Text('Catalog status: $catalogStatus', maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
          Text('API base URL: $apiBaseUrl', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
          Text(status?.developerSummary ?? catalogStatus, maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
          const Text('Content Server diagnostics are developer-only. Consumer surfaces use friendly catalog labels and hide raw URLs.', style: _WzTokens.caption),
        ],
      ),
    );
  }
}

class _DeviceMusicDiagnosticsPanel extends StatelessWidget {
  const _DeviceMusicDiagnosticsPanel({
    required this.permissionStatus,
    required this.platformSupported,
    required this.importedCount,
    required this.lastScanStatus,
    required this.lastError,
    required this.importedAtMs,
  });

  final String permissionStatus;
  final bool platformSupported;
  final int importedCount;
  final String lastScanStatus;
  final String? lastError;
  final int? importedAtMs;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _MetricCard(label: 'Permission', value: permissionStatus, active: permissionStatus == 'granted'),
            _MetricCard(label: 'Imported', value: '$importedCount tracks', active: importedCount > 0),
            _MetricCard(label: 'Scan', value: lastScanStatus, active: lastScanStatus == 'success'),
            _MetricCard(label: 'Platform', value: platformSupported ? 'Android bridge' : 'unsupported', active: platformSupported),
          ]),
          const SizedBox(height: 10),
          Text('Last import: ${importedAtMs == null ? 'never' : DateTime.fromMillisecondsSinceEpoch(importedAtMs!).toLocal()}', style: _WzTokens.caption),
          Text('Last error: ${lastError ?? 'none'}', style: _WzTokens.caption),
          const Text('MediaStore scan is audio-only, capped at 500 tracks, and ignores clips under 30 seconds.', style: _WzTokens.caption),
        ]),
      );
}

class _LibraryDiagnosticsPanel extends StatelessWidget {
  const _LibraryDiagnosticsPanel({
    required this.selectedSource,
    required this.filteredResultCount,
    required this.sortMode,
    required this.deviceImportCount,
    required this.cachedLibraryCount,
  });

  final String selectedSource;
  final int filteredResultCount;
  final String sortMode;
  final int deviceImportCount;
  final int cachedLibraryCount;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _MetricCard(label: 'Source', value: selectedSource, active: true),
            _MetricCard(label: 'Results', value: '$filteredResultCount', active: filteredResultCount > 0),
            _MetricCard(label: 'Sort', value: sortMode, active: true),
            _MetricCard(label: 'Device', value: '$deviceImportCount', active: deviceImportCount > 0),
            _MetricCard(label: 'Cached', value: '$cachedLibraryCount', active: cachedLibraryCount > 0),
          ]),
          const SizedBox(height: 10),
          const Text('Library v2 diagnostics are UI-only and do not alter playback, queue, cache, MediaStore scan, or quality selection semantics.', style: _WzTokens.caption),
        ]),
      );
}

class _CacheDiagnosticsPanel extends StatelessWidget {
  const _CacheDiagnosticsPanel({
    required this.cachedTrackCount,
    required this.cacheBytes,
    required this.offlineLibraryAvailable,
    required this.offlineCachedTrackCount,
    required this.manualDownloadedCount,
    required this.smartDownloadedCount,
    required this.lastOfflineLibraryStatus,
    required this.lastCacheResult,
    required this.lastCacheDeleteResult,
    required this.controlsDisabled,
    required this.onClearCache,
  });

  final int cachedTrackCount;
  final int cacheBytes;
  final bool offlineLibraryAvailable;
  final int offlineCachedTrackCount;
  final int manualDownloadedCount;
  final int smartDownloadedCount;
  final String lastOfflineLibraryStatus;
  final String? lastCacheResult;
  final String? lastCacheDeleteResult;
  final bool controlsDisabled;
  final Future<void> Function() onClearCache;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PanelHeader(icon: Icons.offline_pin, title: 'Cache / Offline', subtitle: 'Offline Ready plus raw cache counters.'),
            const SizedBox(height: 10),
            Text('Cached tracks: $cachedTrackCount • ${(cacheBytes / 1024).toStringAsFixed(1)} KB', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            Text('Offline cached library: ${offlineLibraryAvailable ? 'available' : 'unavailable'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            Text('Offline cache items: $offlineCachedTrackCount', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            Text('downloadedTrackCount: $cachedTrackCount', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            Text('totalCacheBytes: $cacheBytes', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            Text('manualDownloadedCount: $manualDownloadedCount', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            Text('smartDownloadedCount: $smartDownloadedCount', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            Text('Offline status: $lastOfflineLibraryStatus', maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            if (lastCacheResult != null) Text('Last: $lastCacheResult', maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            if (lastCacheDeleteResult != null) Text('lastCacheDeleteResult: $lastCacheDeleteResult', maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(onPressed: controlsDisabled ? null : () async { await onClearCache(); }, icon: const Icon(Icons.clear_all), label: const Text('Clear cache')),
            ),
          ],
        ),
      );
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.status,
    required this.detail,
    required this.operation,
    required this.refreshingMetrics,
  });

  final String status;
  final String detail;
  final String operation;
  final bool refreshingMetrics;

  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.symmetric(horizontal: _WzTokens.space4, vertical: 14),
        child: Row(
          children: [
            Icon(
              refreshingMetrics ? Icons.sync : Icons.radio_button_checked,
              color: _WzTokens.accent,
              size: 18,
            ),
            const SizedBox(width: _WzTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: _WzTokens.space1),
                  Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
                ],
              ),
            ),
            const SizedBox(width: _WzTokens.space2),
            Flexible(
              child: Text(
                operation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: _WzTokens.caption,
              ),
            ),
          ],
        ),
      );
}

class _SessionStrip extends StatelessWidget {
  const _SessionStrip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.symmetric(horizontal: _WzTokens.space4, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.restore, color: _WzTokens.accent, size: 17),
            const SizedBox(width: 10),
            Expanded(child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption)),
          ],
        ),
      );
}

class _PremiumPlayerSheet extends StatelessWidget {
  const _PremiumPlayerSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.28,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF181D33), Color(0xFF070A13)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: WzColors.borderSoft)),
            boxShadow: [BoxShadow(color: Color(0xAA000000), blurRadius: 32, offset: Offset(0, -18))],
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(WzSpacing.md, WzSpacing.sm, WzSpacing.md, WzSpacing.xl),
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: WzSpacing.sm),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.28), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                Row(
                  children: [
                    const Expanded(child: Text('Now playing', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.eyebrow)),
                    IconButton(tooltip: 'Close player', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.keyboard_arrow_down)),
                  ],
                ),
                const SizedBox(height: WzSpacing.xs),
                child,
              ],
            ),
          ),
        ),
      );
}

class _PremiumPlayerSurface extends StatelessWidget {
  const _PremiumPlayerSurface({
    required this.metrics,
    required this.manifest,
    required this.nextTrack,
    required this.qualityLabel,
    required this.effectsSummary,
    required this.sourceLabel,
    required this.progressValue,
    required this.displayedPositionMs,
    required this.durationMs,
    required this.controlsDisabled,
    required this.canPlayPrevious,
    required this.canPlayNext,
    required this.onPlayPause,
    required this.onStop,
    required this.onRetry,
    required this.onPrevious,
    required this.onNext,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.canSaveTrack,
    required this.liked,
    required this.onToggleLike,
    required this.onAddToCollection,
    required this.onAddToQueue,
    required this.onOpenQueue,
    required this.offlineReady,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerLabel,
    required this.sleepTimerActive,
    required this.onShuffleChanged,
    required this.onCycleRepeatMode,
    required this.onOpenSleepTimer,
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final CatalogTrackSummary? nextTrack;
  final String qualityLabel;
  final String effectsSummary;
  final String sourceLabel;
  final double progressValue;
  final int displayedPositionMs;
  final int? durationMs;
  final bool controlsDisabled;
  final bool canPlayPrevious;
  final bool canPlayNext;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onRetry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;
  final bool canSaveTrack;
  final bool liked;
  final VoidCallback? onToggleLike;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onAddToQueue;
  final VoidCallback onOpenQueue;
  final bool offlineReady;
  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final String sleepTimerLabel;
  final bool sleepTimerActive;
  final ValueChanged<bool> onShuffleChanged;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback onOpenSleepTimer;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? 'No track loaded';
    final subtitle = manifest?.subtitle ?? 'Choose a track from Library to begin playback.';
    final status = metrics.isPlaying ? 'Playing' : _statusFromEvent(metrics.lastEvent);
    return WzPanel(
      padding: const EdgeInsets.all(WzSpacing.md),
      gradient: WzColors.heroGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 620;
              final artSize = stacked ? math.min(220.0, constraints.maxWidth) : 280.0;
              final art = _PlayerArtworkHero(artworkUrl: manifest?.artworkUrl, size: artSize);
              final identity = _NowTrackIdentity(title: title, subtitle: subtitle, status: status);
              if (stacked) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Center(child: art), const SizedBox(height: WzSpacing.xl), identity]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [art, const SizedBox(width: WzSpacing.xxl), Expanded(child: identity)]);
            },
          ),
          const SizedBox(height: WzSpacing.lg),
          _PlayerContextBadges(qualityLabel: qualityLabel, effectsSummary: effectsSummary, sourceLabel: sourceLabel, upNextTitle: nextTrack?.title, offlineReady: offlineReady, status: status),
          const SizedBox(height: WzSpacing.xl),
          _PlayerProgressBlock(progressValue: progressValue, displayedPositionMs: displayedPositionMs, durationMs: durationMs, onSeekChanged: onSeekChanged, onSeekEnd: onSeekEnd),
          const SizedBox(height: WzSpacing.xl),
          _PlayerPrimaryControls(isPlaying: metrics.isPlaying, controlsDisabled: controlsDisabled, canPlayPrevious: canPlayPrevious, canPlayNext: canPlayNext, onPlayPause: onPlayPause, onStop: onStop, onRetry: onRetry, onPrevious: onPrevious, onNext: onNext),
          const SizedBox(height: WzSpacing.md),
          _PlaybackModesCard(
            shuffleEnabled: shuffleEnabled,
            repeatMode: repeatMode,
            sleepTimerLabel: sleepTimerLabel,
            sleepTimerActive: sleepTimerActive,
            controlsDisabled: controlsDisabled,
            onShuffleChanged: onShuffleChanged,
            onCycleRepeatMode: onCycleRepeatMode,
            onOpenSleepTimer: onOpenSleepTimer,
          ),
          const SizedBox(height: WzSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            children: [
              OutlinedButton.icon(onPressed: canSaveTrack ? onToggleLike : null, icon: Icon(liked ? Icons.favorite : Icons.favorite_border), label: Text(liked ? 'Liked' : 'Like')),
              OutlinedButton.icon(onPressed: canSaveTrack ? onAddToCollection : null, icon: const Icon(Icons.playlist_add), label: const Text('Add to collection')),
              OutlinedButton.icon(onPressed: canSaveTrack ? onAddToQueue : null, icon: const Icon(Icons.queue_music), label: const Text('Add up next')),
              OutlinedButton.icon(onPressed: onOpenQueue, icon: const Icon(Icons.open_in_new), label: const Text('Open queue')),
            ],
          ),
          const SizedBox(height: WzSpacing.lg),
          _PlayerUpNextPreview(nextTrack: nextTrack),
        ],
      ),
    );
  }
}


class _PlaybackModesCard extends StatelessWidget {
  const _PlaybackModesCard({
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerLabel,
    required this.sleepTimerActive,
    required this.controlsDisabled,
    required this.onShuffleChanged,
    required this.onCycleRepeatMode,
    required this.onOpenSleepTimer,
  });

  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final String sleepTimerLabel;
  final bool sleepTimerActive;
  final bool controlsDisabled;
  final ValueChanged<bool> onShuffleChanged;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback onOpenSleepTimer;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(WzSpacing.sm),
        decoration: BoxDecoration(
          color: WzColors.surfaceMuted.withOpacity(0.56),
          borderRadius: BorderRadius.circular(WzRadius.lg),
          border: Border.all(color: WzColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Playback modes', style: WzText.eyebrow),
            const SizedBox(height: WzSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                FilterChip(
                  avatar: const Icon(Icons.shuffle, size: 18),
                  label: Text(shuffleEnabled ? 'Shuffle on' : 'Shuffle off'),
                  selected: shuffleEnabled,
                  onSelected: controlsDisabled ? null : onShuffleChanged,
                ),
                OutlinedButton.icon(
                  onPressed: controlsDisabled ? null : onCycleRepeatMode,
                  icon: Icon(repeatMode.icon),
                  label: Text(repeatMode.label),
                ),
                OutlinedButton.icon(
                  onPressed: controlsDisabled ? null : onOpenSleepTimer,
                  icon: Icon(sleepTimerActive ? Icons.bedtime : Icons.timer_outlined),
                  label: Text(sleepTimerActive ? sleepTimerLabel : 'Sleep timer'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _PlayerArtworkHero extends StatelessWidget {
  const _PlayerArtworkHero({this.artworkUrl, required this.size});

  final String? artworkUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(WzRadius.xl), gradient: WzColors.accentGradient, border: Border.all(color: WzColors.border), boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 36, offset: Offset(0, 24))]),
      child: url == null || url.trim().isEmpty
          ? Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [WzColors.accent.withOpacity(0.9), WzColors.surfaceMuted, WzColors.accentAlt.withOpacity(0.55)]))),
                Positioned(top: -28, right: -20, child: Icon(Icons.graphic_eq, size: size * 0.42, color: Colors.white.withOpacity(0.08))),
                Center(child: Icon(Icons.album_rounded, size: size * 0.34, color: WzColors.textPrimary.withOpacity(0.9))),
              ],
            )
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.album_rounded, size: size * 0.34, color: WzColors.textPrimary))),
    );
  }
}

class _NowTrackIdentity extends StatelessWidget {
  const _NowTrackIdentity({required this.title, required this.subtitle, required this.status});

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WzStatusPill(label: status, active: status == 'Playing', icon: status == 'Playing' ? Icons.play_arrow : Icons.pause),
          const SizedBox(height: WzSpacing.md),
          Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.display.copyWith(fontSize: 34)),
          const SizedBox(height: WzSpacing.sm),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.body.copyWith(fontSize: 15)),
        ],
      );
}

class _PlayerContextBadges extends StatelessWidget {
  const _PlayerContextBadges({required this.qualityLabel, required this.effectsSummary, required this.sourceLabel, required this.upNextTitle, required this.offlineReady, required this.status});

  final String qualityLabel;
  final String effectsSummary;
  final String sourceLabel;
  final String? upNextTitle;
  final bool offlineReady;
  final String status;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: WzSpacing.sm,
        runSpacing: WzSpacing.sm,
        children: [
          WzStatusPill(label: status, active: status == 'Playing', icon: status == 'Playing' ? Icons.play_arrow : Icons.pause),
          WzStatusPill(label: 'Quality: ${_productQualityLabel(qualityLabel)}', active: qualityLabel != 'unknown', icon: Icons.high_quality),
          WzStatusPill(label: 'Effects: $effectsSummary', active: effectsSummary == 'Applied', warning: effectsSummary == 'Pending' || effectsSummary == 'Failed', icon: Icons.tune),
          WzStatusPill(label: 'Source: $sourceLabel', active: sourceLabel == 'Cache' || sourceLabel == 'Offline Ready' || sourceLabel == 'Device', icon: sourceLabel == 'Device' ? Icons.phone_android : Icons.offline_pin),
          if (offlineReady) const WzStatusPill(label: 'Offline Ready', active: true, icon: Icons.download_done),
          WzStatusPill(label: upNextTitle == null ? 'Up next: none' : 'Up next: $upNextTitle', active: upNextTitle != null, icon: Icons.skip_next),
        ],
      );
}

class _PlayerProgressBlock extends StatelessWidget {
  const _PlayerProgressBlock({required this.progressValue, required this.displayedPositionMs, required this.durationMs, required this.onSeekChanged, required this.onSeekEnd});

  final double progressValue;
  final int displayedPositionMs;
  final int? durationMs;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;

  @override
  Widget build(BuildContext context) {
    final remainingMs = durationMs == null ? null : (durationMs! - displayedPositionMs).clamp(0, durationMs!).toInt();
    final percent = (progressValue * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 7, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9)), child: Slider(value: progressValue, onChanged: onSeekChanged, onChangeEnd: onSeekEnd)),
        const SizedBox(height: WzSpacing.xs),
        Row(children: [Text(_formatTime(displayedPositionMs), style: WzText.caption.copyWith(color: WzColors.textPrimary)), Expanded(child: Text(durationMs == null ? 'Duration unknown' : '$percent% • -${_formatTime(remainingMs)}', textAlign: TextAlign.center, style: WzText.caption)), Text(_formatTime(durationMs), style: WzText.caption.copyWith(color: WzColors.textPrimary))]),
      ],
    );
  }
}

class _PlayerPrimaryControls extends StatelessWidget {
  const _PlayerPrimaryControls({required this.isPlaying, required this.controlsDisabled, required this.canPlayPrevious, required this.canPlayNext, required this.onPlayPause, required this.onStop, required this.onRetry, required this.onPrevious, required this.onNext});

  final bool isPlaying;
  final bool controlsDisabled;
  final bool canPlayPrevious;
  final bool canPlayNext;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onRetry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: WzSpacing.md,
        runSpacing: WzSpacing.sm,
        children: [
          IconButton.outlined(tooltip: 'Retry', onPressed: controlsDisabled ? null : onRetry, icon: const Icon(Icons.replay)),
          IconButton.filledTonal(tooltip: 'Previous', onPressed: controlsDisabled || !canPlayPrevious ? null : onPrevious, icon: const Icon(Icons.skip_previous), iconSize: 30),
          SizedBox(width: 84, height: 84, child: FilledButton(onPressed: controlsDisabled ? null : onPlayPause, style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: WzColors.accent), child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 44))),
          IconButton.filledTonal(tooltip: 'Next', onPressed: controlsDisabled || !canPlayNext ? null : onNext, icon: const Icon(Icons.skip_next), iconSize: 30),
          IconButton.outlined(tooltip: 'Stop', onPressed: controlsDisabled ? null : onStop, icon: const Icon(Icons.stop)),
        ],
      );
}

class _PlayerUpNextPreview extends StatelessWidget {
  const _PlayerUpNextPreview({required this.nextTrack});

  final CatalogTrackSummary? nextTrack;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(WzSpacing.md),
        decoration: BoxDecoration(color: WzColors.surfaceMuted.withOpacity(0.72), borderRadius: BorderRadius.circular(WzRadius.lg), border: Border.all(color: WzColors.borderSoft)),
        child: Row(
          children: [
            Icon(Icons.queue_music, color: nextTrack == null ? WzColors.textSubtle : WzColors.accentAlt),
            const SizedBox(width: WzSpacing.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Up next', style: WzText.eyebrow), const SizedBox(height: WzSpacing.xxs), Text(nextTrack?.title ?? 'Add more tracks to Queue', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle), if (nextTrack != null) Text(nextTrack!.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption)])),
          ],
        ),
      );
}

class _PlayerSourceCard extends StatelessWidget {
  const _PlayerSourceCard({required this.icon, required this.title, required this.primary, required this.detail, required this.active});

  final IconData icon;
  final String title;
  final String primary;
  final String detail;
  final bool active;

  @override
  Widget build(BuildContext context) => WzPanel(
        padding: const EdgeInsets.all(WzSpacing.md),
        child: Row(
          children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: active ? WzColors.successSoft : WzColors.accentSoft, borderRadius: BorderRadius.circular(WzRadius.md)), child: Icon(icon, color: active ? WzColors.success : WzColors.accent)),
            const SizedBox(width: WzSpacing.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: WzText.caption), const SizedBox(height: WzSpacing.xxs), Text(primary, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle), Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption)])),
          ],
        ),
      );
}

class _Artwork extends StatelessWidget {
  const _Artwork({this.artworkUrl, this.size = 118});

  final String? artworkUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size > 60 ? 28 : 14),
        color: _WzTokens.surfaceElevated,
        border: Border.all(color: _WzTokens.borderSoft),
      ),
      child: url == null || url.trim().isEmpty
          ? Icon(Icons.music_note_rounded, size: size * 0.4, color: _WzTokens.textPrimary)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.music_note_rounded, size: size * 0.4, color: _WzTokens.textPrimary),
            ),
    );
  }
}

class _PerformanceBaselinePanel extends StatelessWidget {
  const _PerformanceBaselinePanel({
    required this.metrics,
    required this.nextTapToAudioMs,
    required this.prefetchHitCount,
    required this.prefetchMissCount,
    required this.stopToPlayRecoveryMs,
    required this.sessionRecoveryMs,
    required this.audioPreparedBeforeNext,
    required this.nextPreparedBeforePlay,
  });

  final PlaybackMetrics metrics;
  final int? nextTapToAudioMs;
  final int prefetchHitCount;
  final int prefetchMissCount;
  final int? stopToPlayRecoveryMs;
  final int? sessionRecoveryMs;
  final bool audioPreparedBeforeNext;
  final bool nextPreparedBeforePlay;

  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.all(_WzTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PanelHeader(
              icon: Icons.speed,
              title: 'Performance Baseline',
              subtitle: 'Clean session signals for startup, Next handoff, recovery, and playback health.',
            ),
            const SizedBox(height: _WzTokens.space4),
            Wrap(
              spacing: _WzTokens.space3,
              runSpacing: _WzTokens.space3,
              children: [
                _MetricCard(label: 'Tap to audio', value: _formatMetric(metrics.tapToFirstAudioMs), active: metrics.tapToFirstAudioMs != null),
                _MetricCard(label: 'Next to audio', value: _formatMetric(nextTapToAudioMs), active: nextTapToAudioMs != null),
                _MetricCard(label: 'Stop recovery', value: _formatMetric(stopToPlayRecoveryMs), active: stopToPlayRecoveryMs != null),
                _MetricCard(label: 'Session recovery', value: _formatMetric(sessionRecoveryMs), active: sessionRecoveryMs != null),
                _MetricCard(label: 'Playback error', value: metrics.playbackError ?? 'none', active: metrics.playbackError == null),
              ],
            ),
            const SizedBox(height: _WzTokens.space3),
            Text(
              'Hit/miss and prepared handoff detail now lives in Smart Preload. Unavailable values simply mean that flow has not been observed this session.',
              style: _WzTokens.caption,
            ),
          ],
        ),
      );
}

class _AudioEffectsPanel extends StatelessWidget {
  const _AudioEffectsPanel({
    required this.selectedProfile,
    required this.nativeStatus,
    required this.lastApplyResult,
    required this.preferredAudioQuality,
    required this.controlsDisabled,
    required this.onSelected,
  });

  final AudioEffectProfile selectedProfile;
  final NativeAudioEffectStatus nativeStatus;
  final String lastApplyResult;
  final AudioQualityTier preferredAudioQuality;
  final bool controlsDisabled;
  final ValueChanged<AudioEffectProfile> onSelected;

  @override
  Widget build(BuildContext context) {
    final effectsMayAlterOriginalAudio = selectedProfile != AudioEffectProfile.off;
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Audio Effects', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Effects may alter original audio. Original/lossless playback stays unchanged unless you explicitly select a profile.',
          style: _WzTokens.caption,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AudioEffectProfile.values
              .map(
                (profile) => ChoiceChip(
                  label: Text(profile.shortLabel),
                  selected: profile == selectedProfile,
                  onSelected: controlsDisabled ? null : (_) => onSelected(profile),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        Text('Selected effect profile: ${selectedProfile.label}', style: _WzTokens.caption),
        Text('Description: ${selectedProfile.description}', style: _WzTokens.caption),
        Text('Profile intensity: ${selectedProfile.safetyLabel}', style: _WzTokens.caption),
        Text('Bass / Mid / Treble / Preamp: ${_formatDb(selectedProfile.bassGainDb)} / ${_formatDb(selectedProfile.midGainDb)} / ${_formatDb(selectedProfile.trebleGainDb)} / ${_formatDb(selectedProfile.preampGainDb)}', style: _WzTokens.caption),
        Text('Native effect status: ${nativeStatus.label}', style: _WzTokens.caption),
        Text('Last effect apply result: $lastApplyResult', style: _WzTokens.caption),
        if (preferredAudioQuality == AudioQualityTier.original && effectsMayAlterOriginalAudio) ...[
          const SizedBox(height: 8),
          Text(
            'Original quality is selected and ${selectedProfile.label} was explicitly enabled by the user; effects may alter original audio.',
            style: _WzTokens.caption.copyWith(color: _WzTokens.warning),
          ),
        ],
      ]),
    );
  }

  String _formatDb(double value) {
    if (value == 0) return '0.0 dB';
    return '${value > 0 ? '+' : ''}${value.toStringAsFixed(1)} dB';
  }
}

class _SmartPreloadCard extends StatelessWidget {
  const _SmartPreloadCard({
    required this.metrics,
    required this.enabled,
    required this.prefetchedTrackId,
    required this.prefetchedTrackTitle,
    required this.prefetchInFlight,
    required this.manifestPrefetched,
    required this.audioPreparedBeforeNext,
    required this.lastPrefetchHit,
    required this.prefetchHitCount,
    required this.prefetchMissCount,
    required this.nextTapToAudioMs,
    required this.nextPreparedBeforePlay,
    required this.smartQueueCandidateTrackId,
    required this.smartQueueReason,
    required this.controlsDisabled,
    required this.onToggle,
  });

  final PlaybackMetrics metrics;
  final bool enabled;
  final String? prefetchedTrackId;
  final String? prefetchedTrackTitle;
  final bool prefetchInFlight;
  final bool manifestPrefetched;
  final bool audioPreparedBeforeNext;
  final bool? lastPrefetchHit;
  final int prefetchHitCount;
  final int prefetchMissCount;
  final int? nextTapToAudioMs;
  final bool nextPreparedBeforePlay;
  final String? smartQueueCandidateTrackId;
  final String smartQueueReason;
  final bool controlsDisabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final prepareMs = metrics.nativePrebufferPrepareMs ?? metrics.lastNativePrebufferPrepareMs;
    return _Panel(
      padding: const EdgeInsets.all(_WzTokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: _PanelHeader(
                  icon: Icons.auto_awesome,
                  title: 'Smart Preload',
                  subtitle: 'Predictive manifest, native prebuffer, and prepared handoff signals.',
                ),
              ),
              Switch(value: enabled, onChanged: controlsDisabled ? null : onToggle),
            ],
          ),
          const SizedBox(height: _WzTokens.space4),
          _MetricSection(
            title: 'Smart Queue Policy',
            description: smartQueueCandidateTrackId == null ? 'No deterministic queue candidate selected' : 'Candidate: $smartQueueCandidateTrackId',
            metrics: [
              _MetricCard(label: 'smartQueueReason', value: smartQueueReason, active: smartQueueCandidateTrackId != null),
              _MetricCard(label: 'Candidate', value: smartQueueCandidateTrackId ?? 'none', active: smartQueueCandidateTrackId != null),
            ],
          ),
          const SizedBox(height: _WzTokens.space4),
          _MetricSection(
            title: 'Manifest Prefetch',
            description: prefetchedTrackTitle ?? 'No manifest candidate yet',
            metrics: [
              _MetricCard(label: 'Enabled', value: enabled ? 'on' : 'off', active: enabled),
              _MetricCard(label: 'Manifest ready', value: manifestPrefetched ? 'true' : 'false', active: manifestPrefetched),
              _MetricCard(label: 'Last result', value: _prefetchResultLabel(lastPrefetchHit), active: lastPrefetchHit == true),
            ],
          ),
          const SizedBox(height: _WzTokens.space4),
          _MetricSection(
            title: 'Native Prebuffer',
            description: metrics.nativePrebufferTrackTitle ?? prefetchedTrackId ?? 'Waiting for the up-next native candidate',
            metrics: [
              _MetricCard(label: 'nativePrebufferReady', value: metrics.nativePrebufferReady ? 'true' : 'false', active: metrics.nativePrebufferReady),
              _MetricCard(label: metrics.nativePrebufferPrepareMs == null ? 'lastNativePrebufferPrepareMs' : 'nativePrebufferPrepareMs', value: _formatMetric(prepareMs), active: prepareMs != null),
              _MetricCard(label: 'nativePrebufferHit / Miss', value: '${metrics.nativePrebufferHitCount} / ${metrics.nativePrebufferMissCount}', active: metrics.nativePrebufferHitCount > 0),
            ],
          ),
          const SizedBox(height: _WzTokens.space4),
          _MetricSection(
            title: 'Prepared Handoff',
            description: metrics.lastNativePrebufferTrackTitle ?? 'Explicit Next and auto-advance prepared handoff telemetry',
            metrics: [
              _MetricCard(label: 'nativeHandoffToPlayingMs', value: _formatMetric(metrics.nativeHandoffToPlayingMs), active: metrics.nativeHandoffToPlayingMs != null),
              _MetricCard(label: 'nextPreparedBeforePlay', value: nextPreparedBeforePlay ? 'true' : 'false', active: nextPreparedBeforePlay),
              _MetricCard(label: 'auto prepared', value: metrics.autoAdvancePreparedBeforePlay ? 'true' : 'false', active: metrics.autoAdvancePreparedBeforePlay),
            ],
          ),
          const SizedBox(height: _WzTokens.space3),
          Text(
            'Track IDs, in-flight flags, clear reasons, and full counters remain available in Show raw metrics.',
            style: _WzTokens.caption,
          ),
        ],
      ),
    );
  }
}

class _SmartDownloadsCard extends StatelessWidget {
  const _SmartDownloadsCard({
    required this.enabled,
    required this.lastTrackId,
    required this.lastTitle,
    required this.lastReason,
    required this.lastResult,
    required this.startedCount,
    required this.completedCount,
    required this.failedCount,
    required this.skippedCount,
    required this.inFlight,
    required this.onToggle,
  });

  final bool enabled;
  final String? lastTrackId;
  final String? lastTitle;
  final String? lastReason;
  final String? lastResult;
  final int startedCount;
  final int completedCount;
  final int failedCount;
  final int skippedCount;
  final int inFlight;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(_WzTokens.space5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(
            child: _PanelHeader(
              icon: Icons.download_for_offline,
              title: 'Smart Downloads',
              subtitle: 'Predictive background caching for current and up-next tracks.',
            ),
          ),
          Switch(value: enabled, onChanged: onToggle),
        ]),
        const SizedBox(height: _WzTokens.space4),
        _MetricSection(
          title: 'Last Smart Download',
          description: lastTitle ?? 'No smart downloads yet',
          metrics: [
            _MetricCard(label: 'Track', value: lastTrackId ?? 'none', active: lastTrackId != null),
            _MetricCard(label: 'Result', value: lastResult ?? 'none', active: lastResult == 'cached'),
            _MetricCard(label: 'Reason', value: lastReason ?? 'none', active: lastReason != null),
          ],
        ),
        const SizedBox(height: _WzTokens.space4),
        _MetricSection(
          title: 'Counters',
          description: 'Started / Completed / Failed / Skipped',
          metrics: [
            _MetricCard(label: 'Started', value: '$startedCount', active: startedCount > 0),
            _MetricCard(label: 'Completed', value: '$completedCount', active: completedCount > 0),
            _MetricCard(label: 'Failed', value: '$failedCount', active: failedCount > 0),
            _MetricCard(label: 'Skipped', value: '$skippedCount', active: skippedCount > 0),
            _MetricCard(label: 'InFlight', value: '$inFlight', active: inFlight > 0),
          ],
        ),
      ]),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: _WzTokens.accent),
          const SizedBox(width: _WzTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _WzTokens.title),
                const SizedBox(height: _WzTokens.space1),
                Text(subtitle, style: _WzTokens.caption),
              ],
            ),
          ),
        ],
      );
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({required this.title, required this.description, required this.metrics});

  final String title;
  final String description;
  final List<Widget> metrics;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(_WzTokens.space4),
        decoration: BoxDecoration(
          color: _WzTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(_WzTokens.radiusLg),
          border: Border.all(color: _WzTokens.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: _WzTokens.space1),
            Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            const SizedBox(height: _WzTokens.space3),
            Wrap(spacing: _WzTokens.space3, runSpacing: _WzTokens.space3, children: metrics),
          ],
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.active});

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 132, maxWidth: 218),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? _WzTokens.successSoft : _WzTokens.surfaceElevated,
          borderRadius: BorderRadius.circular(_WzTokens.radiusMd),
          border: Border.all(color: active ? const Color(0x5538D996) : _WzTokens.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
            const SizedBox(height: _WzTokens.space1),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

String _effectStatusLabel(NativeAudioEffectStatus status) {
  switch (status) {
    case NativeAudioEffectStatus.applied:
      return 'Applied';
    case NativeAudioEffectStatus.unsupported:
      return 'Unsupported';
    case NativeAudioEffectStatus.pending:
      return 'Pending';
    case NativeAudioEffectStatus.failed:
      return 'Failed';
    case NativeAudioEffectStatus.off:
      return 'Off';
  }
}

String _playerSourceLabel({required bool isPlayingFromCache, required bool offlineReady, required bool hasTrack}) {
  if (isPlayingFromCache) return 'Downloaded';
  if (hasTrack) return 'Catalog';
  if (offlineReady) return 'Offline Ready';
  return 'Not cached';
}

String _productQualityLabel(String? value) {
  final normalized = value?.trim().toLowerCase();
  switch (normalized) {
    case 'original':
    case 'lossless':
      return 'Original';
    case 'high':
      return 'High';
    case 'standard':
    case 'low':
      return 'Standard';
    case null:
    case '':
    case 'unknown':
      return 'Unknown';
    default:
      return value!;
  }
}

String _prefetchResultLabel(bool? value) {
  if (value == null) return 'none';
  return value ? 'hit' : 'miss';
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.queue,
    required this.currentTrackId,
    required this.currentIndex,
    required this.status,
    required this.controlsDisabled,
    required this.autoAdvanceEnabled,
    required this.autoAdvanceCount,
    required this.smartQueueCandidateTrackId,
    required this.smartQueueReason,
    required this.showDeveloperDetails,
    required this.onToggleAutoAdvance,
    required this.onPlayTrack,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onPlayNext,
    required this.onRemoveTrack,
    required this.onClearQueue,
  });

  final List<CatalogTrackSummary> queue;
  final String? currentTrackId;
  final int currentIndex;
  final String status;
  final bool controlsDisabled;
  final bool autoAdvanceEnabled;
  final int autoAdvanceCount;
  final String? smartQueueCandidateTrackId;
  final String smartQueueReason;
  final bool showDeveloperDetails;
  final ValueChanged<bool> onToggleAutoAdvance;
  final ValueChanged<CatalogTrackSummary> onPlayTrack;
  final ValueChanged<CatalogTrackSummary> onMoveUp;
  final ValueChanged<CatalogTrackSummary> onMoveDown;
  final ValueChanged<CatalogTrackSummary> onPlayNext;
  final ValueChanged<CatalogTrackSummary> onRemoveTrack;
  final VoidCallback onClearQueue;

  @override
  Widget build(BuildContext context) {
    final currentTrack = currentIndex >= 0 && currentIndex < queue.length ? queue[currentIndex] : null;
    final nextTrack = currentIndex >= 0 && currentIndex < queue.length - 1 ? queue[currentIndex + 1] : null;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Queue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Queue Engine v2: reorder, remove, Play Next, and persistence.', style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13)),
                  ],
                ),
              ),
              Text('${queue.length} tracks', style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Clear queue',
                onPressed: queue.isEmpty || controlsDisabled ? null : onClearQueue,
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _QueueStateChip(label: 'Current', value: currentTrack?.title ?? 'none', active: currentTrack != null),
              _QueueStateChip(label: 'Up next', value: nextTrack?.title ?? 'none', active: nextTrack != null),
              if (showDeveloperDetails) _QueueStateChip(label: 'Auto', value: '$autoAdvanceCount advances', active: autoAdvanceEnabled),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(status, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
              ),
              Switch(value: autoAdvanceEnabled, onChanged: controlsDisabled ? null : onToggleAutoAdvance),
            ],
          ),
          if (showDeveloperDetails)
            Text(
              'smartQueueReason: $smartQueueReason • candidate: ${smartQueueCandidateTrackId ?? 'none'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
            ),
          const SizedBox(height: 12),
          if (queue.isEmpty)
            const _EmptyCatalogMessage(message: 'Queue is empty. Add tracks from Library or Search to choose what plays next.')
          else
            ...queue.indexed.map((entry) => _QueueRow(
                  track: entry.$2,
                  index: entry.$1,
                  current: entry.$2.trackId == currentTrackId,
                  upNext: entry.$1 == currentIndex + 1,
                  disabled: controlsDisabled,
                  canMoveUp: entry.$1 > 0,
                  canMoveDown: entry.$1 < queue.length - 1,
                  onPlay: () => onPlayTrack(entry.$2),
                  onMoveUp: () => onMoveUp(entry.$2),
                  onMoveDown: () => onMoveDown(entry.$2),
                  onPlayNext: () => onPlayNext(entry.$2),
                  onRemove: () => onRemoveTrack(entry.$2),
                )),
        ],
      ),
    );
  }
}

class _QueueStateChip extends StatelessWidget {
  const _QueueStateChip({required this.label, required this.value, required this.active});

  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0x227C5CFF) : _WzTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? _WzTokens.accent : _WzTokens.border),
        ),
        child: Text('$label: $value', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
      );
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.track,
    required this.index,
    required this.current,
    required this.upNext,
    required this.disabled,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onPlay,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onPlayNext,
    required this.onRemove,
  });

  final CatalogTrackSummary track;
  final int index;
  final bool current;
  final bool upNext;
  final bool disabled;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onPlay;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onPlayNext;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = current ? 'Now playing' : upNext ? 'Up next' : '#${index + 1}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: current ? const Color(0x227C5CFF) : const Color(0xFF0B0E18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: current ? const Color(0xFF8D7CFF) : upNext ? const Color(0xFF38D996) : const Color(0xFF20273A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(current ? Icons.equalizer : upNext ? Icons.next_plan : Icons.queue_music, color: current || upNext ? const Color(0xFF8D7CFF) : const Color(0xFF98A1B8)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 2,
            runSpacing: 2,
            children: [
              IconButton(tooltip: 'Play/select', onPressed: disabled ? null : onPlay, icon: Icon(current ? Icons.check_circle : Icons.play_arrow, color: const Color(0xFF8D7CFF))),
              IconButton(tooltip: 'Move up', onPressed: disabled || !canMoveUp ? null : onMoveUp, icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF98A1B8))),
              IconButton(tooltip: 'Move down', onPressed: disabled || !canMoveDown ? null : onMoveDown, icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF98A1B8))),
              IconButton(tooltip: 'Play next', onPressed: disabled || current || upNext ? null : onPlayNext, icon: const Icon(Icons.low_priority, color: Color(0xFF38D996))),
              IconButton(tooltip: 'Remove', onPressed: disabled ? null : onRemove, icon: const Icon(Icons.close, color: Color(0xFF98A1B8))),
            ],
          ),
        ],
      ),
    );
  }
}


class _StorageManagerPage extends StatelessWidget {
  const _StorageManagerPage({
    required this.downloads,
    required this.onBack,
    required this.cacheBytes,
    required this.trackBytes,
    required this.manualDownloadedCount,
    required this.smartDownloadedCount,
    required this.offlineReadyCount,
    required this.smartDownloadsEnabled,
    required this.controlsDisabled,
    required this.onSmartDownloadsChanged,
    required this.onPlay,
    required this.onDelete,
    required this.onClearAll,
  });

  final List<CachedTrackMetadata> downloads;
  final VoidCallback onBack;
  final int cacheBytes;
  final Map<String, int> trackBytes;
  final int manualDownloadedCount;
  final int smartDownloadedCount;
  final int offlineReadyCount;
  final bool smartDownloadsEnabled;
  final bool controlsDisabled;
  final ValueChanged<bool> onSmartDownloadsChanged;
  final ValueChanged<CachedTrackMetadata> onPlay;
  final ValueChanged<CachedTrackMetadata> onDelete;
  final Future<void> Function() onClearAll;

  int get _currentOrRecentCount => downloads.where((track) => track.downloadSource == 'smart_current').length;
  int get _unknownCount => downloads.where((track) => track.downloadSource != 'manual' && !track.downloadSource.startsWith('smart_')).length;

  @override
  Widget build(BuildContext context) {
    final healthLabel = downloads.isEmpty ? 'No downloads yet' : 'Ready for offline playback';
    return WzPageScaffold(
      children: [
        WzPageHeader(
          icon: Icons.storage,
          title: 'Storage Manager',
          subtitle: 'Manage downloaded tracks for offline playback.',
          trailing: IconButton.outlined(tooltip: 'Back to Downloads', onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        ),
        const SizedBox(height: WzSpacing.md),
        WzPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: WzSpacing.xs,
                runSpacing: WzSpacing.xs,
                children: [
                  WzStatusPill(label: healthLabel, active: downloads.isNotEmpty, icon: downloads.isEmpty ? Icons.inbox_outlined : Icons.offline_pin),
                  WzStatusPill(label: smartDownloadsEnabled ? 'Smart Downloads on' : 'Smart Downloads off', active: smartDownloadsEnabled, icon: Icons.auto_awesome),
                ],
              ),
              const SizedBox(height: WzSpacing.md),
              Wrap(
                spacing: WzSpacing.sm,
                runSpacing: WzSpacing.sm,
                children: [
                  WzMiniMetric(label: 'Cached for offline', value: '${downloads.length}', active: downloads.isNotEmpty, icon: Icons.library_music),
                  WzMiniMetric(label: 'Device storage', value: _formatCacheBytes(cacheBytes), active: cacheBytes > 0, icon: Icons.sd_storage),
                  WzMiniMetric(label: 'Manual downloads', value: '$manualDownloadedCount', active: manualDownloadedCount > 0, icon: Icons.download_done),
                  WzMiniMetric(label: 'Smart downloads', value: '$smartDownloadedCount', active: smartDownloadedCount > 0, icon: Icons.auto_awesome),
                  WzMiniMetric(label: 'Offline-ready', value: '$offlineReadyCount', active: offlineReadyCount > 0, icon: Icons.offline_pin),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        const WzSectionHeader(title: 'Smart Downloads', subtitle: 'Keep likely next tracks ready without changing playback behavior.', icon: Icons.auto_awesome),
        WzPanel(
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Smart Downloads'),
            subtitle: const Text('WaveZero can cache the current and up-next tracks for faster offline-ready playback.'),
            value: smartDownloadsEnabled,
            onChanged: controlsDisabled ? null : onSmartDownloadsChanged,
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        const WzSectionHeader(title: 'Categories', subtitle: 'See what kind of downloads are using storage.', icon: Icons.category),
        WzPanel(
          child: Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            children: [
              _StorageCategoryCard(label: 'All cached', count: downloads.length, icon: Icons.all_inbox),
              _StorageCategoryCard(label: 'Manual downloads', count: manualDownloadedCount, icon: Icons.download_done),
              _StorageCategoryCard(label: 'Smart downloads', count: smartDownloadedCount, icon: Icons.auto_awesome),
              _StorageCategoryCard(label: 'Current / recently cached', count: _currentOrRecentCount, icon: Icons.flash_on),
              _StorageCategoryCard(label: 'Unknown source', count: _unknownCount, icon: Icons.help_outline),
            ],
          ),
        ),
        const SizedBox(height: WzSpacing.md),
        WzSectionHeader(
          title: 'Downloaded tracks',
          subtitle: downloads.isEmpty ? 'No downloads yet.' : 'Play or remove individual offline-ready tracks.',
          icon: Icons.playlist_play,
        ),
        WzPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: WzSpacing.sm,
                runSpacing: WzSpacing.sm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(downloads.isEmpty ? 'Downloads cleared' : '${downloads.length} downloaded • ${_formatCacheBytes(cacheBytes)}', style: WzText.body),
                  OutlinedButton.icon(
                    onPressed: controlsDisabled || downloads.isEmpty ? null : () => unawaited(onClearAll()),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear all downloads'),
                  ),
                ],
              ),
              const SizedBox(height: WzSpacing.md),
              if (downloads.isEmpty)
                const _EmptyCatalogMessage(message: 'No downloads yet. Download tracks from Library to listen offline.')
              else
                ...downloads.map((track) => _StorageTrackRow(
                      track: track,
                      sizeBytes: trackBytes[track.trackId],
                      disabled: controlsDisabled,
                      onPlay: () => onPlay(track),
                      onDelete: () => onDelete(track),
                    )),
            ],
          ),
        ),
      ],
    );
  }
}

class _StorageCategoryCard extends StatelessWidget {
  const _StorageCategoryCard({required this.label, required this.count, required this.icon});

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: WzMiniMetric(label: label, value: '$count', active: count > 0, icon: icon),
      );
}

class _StorageTrackRow extends StatelessWidget {
  const _StorageTrackRow({required this.track, required this.sizeBytes, required this.disabled, required this.onPlay, required this.onDelete});

  final CachedTrackMetadata track;
  final int? sizeBytes;
  final bool disabled;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final quality = _productQualityLabel(track.qualityLabel);
    final details = <String>[
      if (quality != 'Unknown') quality,
      if (track.codec != null && track.codec!.trim().isNotEmpty) track.codec!,
      if (track.bitrateKbps != null) '${track.bitrateKbps}kbps',
      if (sizeBytes != null) _formatCacheBytes(sizeBytes!),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: WzSpacing.sm),
      padding: const EdgeInsets.all(WzSpacing.sm),
      decoration: BoxDecoration(
        color: WzColors.surfaceElevated,
        borderRadius: BorderRadius.circular(WzRadius.lg),
        border: Border.all(color: WzColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Artwork(artworkUrl: track.artworkUrl, size: 48),
              const SizedBox(width: WzSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: WzSpacing.xxs),
                    Text(track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: WzSpacing.sm),
          Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              WzStatusPill(label: _downloadSourceLabel(track.downloadSource), active: track.downloadSource != 'unknown', icon: _downloadSourceIcon(track.downloadSource)),
              if (quality != 'Unknown') WzStatusPill(label: quality, active: true, icon: Icons.high_quality),
              if (track.codec != null && track.codec!.trim().isNotEmpty) WzStatusPill(label: track.codec!, active: true, icon: Icons.memory),
              if (track.bitrateKbps != null) WzStatusPill(label: '${track.bitrateKbps}kbps', active: true, icon: Icons.speed),
              if (sizeBytes != null) WzStatusPill(label: _formatCacheBytes(sizeBytes!), active: true, icon: Icons.sd_storage),
              if (details.isEmpty) const WzStatusPill(label: 'Offline-ready', active: true, icon: Icons.offline_pin),
            ],
          ),
          const SizedBox(height: WzSpacing.xs),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              OutlinedButton.icon(onPressed: disabled ? null : onPlay, icon: const Icon(Icons.play_arrow), label: const Text('Play')),
              OutlinedButton.icon(onPressed: disabled ? null : onDelete, icon: const Icon(Icons.delete_outline), label: const Text('Remove from device')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadsCard extends StatelessWidget {
  const _DownloadsCard({
    required this.downloads,
    required this.cacheBytes,
    required this.controlsDisabled,
    required this.onPlay,
    required this.onDelete,
    required this.onClearAll,
    required this.onManageStorage,
  });

  final List<CachedTrackMetadata> downloads;
  final int cacheBytes;
  final bool controlsDisabled;
  final ValueChanged<CachedTrackMetadata> onPlay;
  final ValueChanged<CachedTrackMetadata> onDelete;
  final VoidCallback onClearAll;
  final VoidCallback onManageStorage;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Downloads', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('Cached tracks available for offline playback.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13)),
                    ],
                  ),
                ),
                Text('${downloads.length} • ${_formatCacheBytes(cacheBytes)}', style: _WzTokens.caption),
                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: [
                    OutlinedButton.icon(onPressed: onManageStorage, icon: const Icon(Icons.storage), label: const Text('Manage Storage')),
                    IconButton.outlined(
                      tooltip: 'Clear all downloads',
                      onPressed: downloads.isEmpty || controlsDisabled ? null : onClearAll,
                      icon: const Icon(Icons.clear_all),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (downloads.isEmpty)
              const _EmptyCatalogMessage(message: 'No downloads yet. Download tracks from Library to listen offline.')
            else
              ...downloads.map((track) => _DownloadRow(
                    track: track,
                    disabled: controlsDisabled,
                    onPlay: () => onPlay(track),
                    onDelete: () => onDelete(track),
                  )),
          ],
        ),
      );
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.track, required this.disabled, required this.onPlay, required this.onDelete});

  final CachedTrackMetadata track;
  final bool disabled;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF20273A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Artwork(artworkUrl: track.artworkUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${track.subtitle} • ${_productQualityLabel(track.qualityLabel)}${track.codec == null ? '' : ' • ${track.codec}'}${track.bitrateKbps == null ? '' : ' • ${track.bitrateKbps}kbps'} • ${_downloadSourceLabel(track.downloadSource)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                IconButton(tooltip: 'Play downloaded track', onPressed: disabled ? null : onPlay, icon: const Icon(Icons.play_arrow, color: Color(0xFF8D7CFF))),
                IconButton(tooltip: 'Remove from device', onPressed: disabled ? null : onDelete, icon: const Icon(Icons.delete_outline, color: Color(0xFFFF8F8F))),
              ],
            ),
          ],
        ),
      );
}

String _cachedSourceBadgeLabel(String? displayName) {
  final source = displayName?.split(' ').first ?? 'unknown';
  return _downloadSourceLabel(source);
}

String _downloadSourceLabel(String source) {
  switch (source) {
    case 'manual':
      return 'Manual';
    case 'smart_current':
      return 'Smart Current';
    case 'smart_up_next':
      return 'Smart Up Next';
    default:
      return 'Unknown';
  }
}

IconData _downloadSourceIcon(String source) {
  switch (source) {
    case 'manual':
      return Icons.download_done;
    case 'smart_current':
      return Icons.flash_on;
    case 'smart_up_next':
      return Icons.auto_awesome;
    default:
      return Icons.help_outline;
  }
}

class _LibrarySourceSummaryCard extends StatelessWidget {
  const _LibrarySourceSummaryCard({
    required this.title,
    required this.detail,
    required this.status,
    required this.icon,
    required this.active,
  });

  final String title;
  final String detail;
  final String status;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 132, maxWidth: 220),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? const Color(0x227C5CFF) : const Color(0xFF0B0E18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? const Color(0xFF8D7CFF) : const Color(0xFF20273A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: active ? const Color(0xFF8D7CFF) : const Color(0xFF98A1B8)),
            const SizedBox(height: 8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(status, maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
          ],
        ),
      );
}

class _CollectionsPage extends StatelessWidget {
  const _CollectionsPage({
    required this.collections,
    required this.onBack,
    required this.onOpen,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  final List<WzCollection> collections;
  final VoidCallback onBack;
  final ValueChanged<WzCollection> onOpen;
  final VoidCallback onCreate;
  final ValueChanged<WzCollection> onRename;
  final ValueChanged<WzCollection> onDelete;

  @override
  Widget build(BuildContext context) {
    final liked = collections.firstWhere((collection) => collection.type == WzCollectionType.liked, orElse: () => WzCollection.liked());
    final userCollections = collections.where((collection) => collection.type == WzCollectionType.user).toList(growable: false);
    return WzPageScaffold(
      children: [
        WzPageHeader(
          icon: Icons.playlist_play,
          title: 'Collections',
          subtitle: 'Save tracks into playlists and liked music on this device.',
          trailing: Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [IconButton.outlined(tooltip: 'Back to Home', onPressed: onBack, icon: const Icon(Icons.arrow_back)), WzPrimaryAction(label: 'Create', icon: Icons.add, onPressed: onCreate)]),
        ),
        const SizedBox(height: WzSpacing.md),
        _CollectionCard(collection: liked, onOpen: () => onOpen(liked), onRename: null, onDelete: null),
        const SizedBox(height: WzSpacing.md),
        const WzSectionHeader(title: 'Your collections', subtitle: 'Local playlists stored on this device.', icon: Icons.queue_music),
        if (userCollections.isEmpty)
          const WzPanel(
            child: Text('No collections yet. Save tracks from Library, Search, or Now Playing.', style: WzText.body),
          )
        else
          ...userCollections.map((collection) => Padding(
                padding: const EdgeInsets.only(bottom: WzSpacing.sm),
                child: _CollectionCard(
                  collection: collection,
                  onOpen: () => onOpen(collection),
                  onRename: () => onRename(collection),
                  onDelete: () => onDelete(collection),
                ),
              )),
        const SizedBox(height: WzSpacing.md),
        const WzPanel(
          child: Text('Collections only store lightweight metadata. Removing tracks or deleting a collection does not delete downloads, cache files, or device music.', style: WzText.caption),
        ),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection, required this.onOpen, required this.onRename, required this.onDelete});

  final WzCollection collection;
  final VoidCallback onOpen;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final preview = collection.tracks.isEmpty ? 'No tracks yet' : collection.tracks.first.title;
    return WzPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Artwork(artworkUrl: collection.tracks.isEmpty ? null : collection.tracks.first.artworkUrl, size: 54),
              const SizedBox(width: WzSpacing.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(collection.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                  const SizedBox(height: WzSpacing.xxs),
                  Text('${collection.trackCount} ${collection.trackCount == 1 ? 'track' : 'tracks'} • Updated ${_friendlyUpdated(collection.updatedAtMs)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.body),
                ]),
              ),
            ],
          ),
          const SizedBox(height: WzSpacing.sm),
          Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.xs,
            children: [
              FilledButton.tonalIcon(onPressed: onOpen, icon: const Icon(Icons.open_in_new), label: const Text('Open')),
              if (onRename != null) OutlinedButton.icon(onPressed: onRename, icon: const Icon(Icons.edit), label: const Text('Rename')),
              if (onDelete != null) OutlinedButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline), label: const Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollectionDetailPage extends StatelessWidget {
  const _CollectionDetailPage({
    required this.collection,
    required this.onBack,
    required this.onPlayFirst,
    required this.onAddAllToQueue,
    required this.onRename,
    required this.onDelete,
    required this.onPlayTrack,
    required this.onAddTrackToQueue,
    required this.onRemoveTrack,
    required this.resolver,
  });

  final WzCollection collection;
  final VoidCallback onBack;
  final ValueChanged<WzCollection> onPlayFirst;
  final ValueChanged<WzCollection> onAddAllToQueue;
  final ValueChanged<WzCollection> onRename;
  final ValueChanged<WzCollection> onDelete;
  final ValueChanged<WzCollectionTrackSnapshot> onPlayTrack;
  final ValueChanged<WzCollectionTrackSnapshot> onAddTrackToQueue;
  final void Function(WzCollection collection, WzCollectionTrackSnapshot track) onRemoveTrack;
  final CatalogTrackSummary? Function(WzCollectionTrackSnapshot track) resolver;

  @override
  Widget build(BuildContext context) => WzPageScaffold(
        children: [
          WzPageHeader(
            icon: collection.type == WzCollectionType.liked ? Icons.favorite : Icons.playlist_play,
            title: collection.name,
            subtitle: '${collection.trackCount} ${collection.trackCount == 1 ? 'track' : 'tracks'} saved locally on this device.',
            trailing: IconButton.outlined(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          ),
          const SizedBox(height: WzSpacing.md),
          WzPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
                WzStatusPill(label: collection.type == WzCollectionType.liked ? 'Liked' : 'Collection', active: true, icon: collection.type == WzCollectionType.liked ? Icons.favorite : Icons.playlist_play),
                WzStatusPill(label: '${collection.trackCount} tracks', icon: Icons.music_note),
                WzStatusPill(label: 'Local only', icon: Icons.phone_android),
              ]),
              const SizedBox(height: WzSpacing.md),
              Wrap(spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
                FilledButton.tonalIcon(onPressed: collection.tracks.isEmpty ? null : () => onPlayFirst(collection), icon: const Icon(Icons.play_arrow), label: const Text('Play first')),
                OutlinedButton.icon(onPressed: collection.tracks.isEmpty ? null : () => onAddAllToQueue(collection), icon: const Icon(Icons.queue_music), label: const Text('Add all to Queue')),
                if (collection.type == WzCollectionType.user) OutlinedButton.icon(onPressed: () => onRename(collection), icon: const Icon(Icons.edit), label: const Text('Rename')),
                if (collection.type == WzCollectionType.user) OutlinedButton.icon(onPressed: () => onDelete(collection), icon: const Icon(Icons.delete_outline), label: const Text('Delete')),
              ]),
            ]),
          ),
          const SizedBox(height: WzSpacing.md),
          if (collection.tracks.isEmpty)
            const WzPanel(child: Text('This collection is empty. Save tracks from Library, Search, or Now Playing.', style: WzText.body))
          else
            ...collection.tracks.map((track) => Padding(
                  padding: const EdgeInsets.only(bottom: WzSpacing.sm),
                  child: _CollectionTrackRow(
                    track: track,
                    available: resolver(track) != null,
                    onPlay: () => onPlayTrack(track),
                    onAddToQueue: () => onAddTrackToQueue(track),
                    onRemove: () => onRemoveTrack(collection, track),
                  ),
                )),
        ],
      );
}

class _CollectionTrackRow extends StatelessWidget {
  const _CollectionTrackRow({required this.track, required this.available, required this.onPlay, required this.onAddToQueue, required this.onRemove});

  final WzCollectionTrackSnapshot track;
  final bool available;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => WzPanel(
        padding: const EdgeInsets.all(WzSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            _Artwork(artworkUrl: track.artworkUrl, size: 48),
            const SizedBox(width: WzSpacing.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
              Text(track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
            ])),
          ]),
          const SizedBox(height: WzSpacing.xs),
          Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
            WzStatusPill(label: _collectionSourceLabel(track.source), active: track.source == WzCollectionTrackSource.device || track.source == WzCollectionTrackSource.cached, icon: Icons.source),
            if (track.qualityLabel != null) WzStatusPill(label: _productQualityLabel(track.qualityLabel!), icon: Icons.high_quality),
            WzStatusPill(label: track.source == WzCollectionTrackSource.device ? 'Your device' : track.license.badgeLabel, active: track.source == WzCollectionTrackSource.device || !track.license.needsRightsWarning, warning: track.license.needsRightsWarning && track.source != WzCollectionTrackSource.device, icon: Icons.policy),
            if (!available) const WzStatusPill(label: 'Track is not available right now', warning: true, icon: Icons.cloud_off),
          ]),
          const SizedBox(height: WzSpacing.xs),
          Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
            OutlinedButton.icon(onPressed: available ? onPlay : null, icon: const Icon(Icons.play_arrow), label: const Text('Play')),
            OutlinedButton.icon(onPressed: available ? onAddToQueue : null, icon: const Icon(Icons.queue_music), label: const Text('Add to Queue')),
            OutlinedButton.icon(onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline), label: const Text('Remove')),
          ]),
        ]),
      );
}

String _collectionSourceLabel(WzCollectionTrackSource source) => switch (source) {
      WzCollectionTrackSource.api => 'Catalog',
      WzCollectionTrackSource.device => 'Device',
      WzCollectionTrackSource.cached => 'Downloaded',
      WzCollectionTrackSource.unknown => 'Unknown',
    };

String _friendlyUpdated(int updatedAtMs) {
  final age = DateTime.now().millisecondsSinceEpoch - updatedAtMs;
  if (age < 60000) return 'just now';
  final minutes = age ~/ 60000;
  if (minutes < 60) return '${minutes}m ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return '${hours}h ago';
  final days = hours ~/ 24;
  return '${days}d ago';
}

class _CatalogListCard extends StatelessWidget {
  const _CatalogListCard({
    required this.tracks,
    required this.totalTrackCount,
    required this.apiTrackCount,
    required this.deviceTrackCount,
    required this.cachedTrackCount,
    required this.combinedTrackCount,
    required this.cacheBytes,
    required this.selectedTrackId,
    required this.status,
    required this.loading,
    required this.refreshDisabled,
    required this.addToQueueDisabled,
    required this.searchController,
    required this.librarySourceFilter,
    required this.librarySortMode,
    required this.devicePermissionStatus,
    required this.deviceScanStatus,
    required this.deviceLastError,
    required this.onSourceFilterChanged,
    required this.onSortModeChanged,
    required this.onClearSearch,
    required this.onOpenFullSearch,
    required this.onRefresh,
    required this.onImportDeviceMusic,
    required this.onSelectTrack,
    required this.onAddToQueue,
    required this.onToggleLike,
    required this.onAddToCollection,
    required this.isLiked,
    required this.onOpenCollections,
    required this.onCache,
    required this.onDeleteCachedTrack,
    this.offlineMode = false,
  });

  final List<CatalogTrackSummary> tracks;
  final int totalTrackCount;
  final int apiTrackCount;
  final int deviceTrackCount;
  final int cachedTrackCount;
  final int combinedTrackCount;
  final int cacheBytes;
  final String? selectedTrackId;
  final String status;
  final bool loading;
  final bool refreshDisabled;
  final bool addToQueueDisabled;
  final TextEditingController searchController;
  final _LibrarySourceFilter librarySourceFilter;
  final _LibrarySortMode librarySortMode;
  final String devicePermissionStatus;
  final String deviceScanStatus;
  final String? deviceLastError;
  final ValueChanged<_LibrarySourceFilter> onSourceFilterChanged;
  final ValueChanged<_LibrarySortMode> onSortModeChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenFullSearch;
  final VoidCallback onRefresh;
  final VoidCallback onImportDeviceMusic;
  final ValueChanged<CatalogTrackSummary> onSelectTrack;
  final ValueChanged<CatalogTrackSummary> onAddToQueue;
  final ValueChanged<CatalogTrackSummary> onToggleLike;
  final ValueChanged<CatalogTrackSummary> onAddToCollection;
  final bool Function(CatalogTrackSummary track) isLiked;
  final VoidCallback onOpenCollections;
  final ValueChanged<CatalogTrackSummary> onCache;
  final ValueChanged<CatalogTrackSummary> onDeleteCachedTrack;
  final bool offlineMode;

  @override
  Widget build(BuildContext context) {
    final hasQuery = searchController.text.trim().isNotEmpty;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Browse Catalog, Device music, Downloaded, or everything together.', style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13)),
                  ],
                ),
              ),
              IconButton.outlined(
                onPressed: refreshDisabled ? null : onRefresh,
                icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 360
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'All', detail: '$combinedTrackCount tracks', status: 'Unified library', icon: Icons.library_music, active: librarySourceFilter == _LibrarySourceFilter.all)),
                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'Catalog', detail: '$apiTrackCount tracks', status: status, icon: Icons.cloud_queue, active: librarySourceFilter == _LibrarySourceFilter.api)),
                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'Device music', detail: '$deviceTrackCount imported', status: 'Permission $devicePermissionStatus • $deviceScanStatus', icon: Icons.phone_android, active: librarySourceFilter == _LibrarySourceFilter.device)),
                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'Downloads', detail: '$cachedTrackCount cached', status: '${(cacheBytes / 1024).toStringAsFixed(1)} KB stored', icon: Icons.download_done, active: librarySourceFilter == _LibrarySourceFilter.downloads)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _LibrarySourceFilter.values
                .map((filter) => ChoiceChip(
                      avatar: Icon(_librarySourceFilterIcon(filter), size: 16),
                      label: Text(_librarySourceFilterShortLabel(filter), maxLines: 1, overflow: TextOverflow.ellipsis),
                      selected: librarySourceFilter == filter,
                      onSelected: (_) => onSourceFilterChanged(filter),
                    ))
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: refreshDisabled ? null : onImportDeviceMusic,
                icon: const Icon(Icons.perm_media),
                label: Text(deviceTrackCount == 0 ? 'Import Device music' : 'Rescan Device music'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenCollections,
                icon: const Icon(Icons.playlist_play),
                label: const Text('Collections / Playlists'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenFullSearch,
                icon: const Icon(Icons.search),
                label: const Text('Open full search'),
              ),
              Text('Permission: $devicePermissionStatus', style: _WzTokens.caption),
              Text('Device scan: $deviceScanStatus • $deviceTrackCount tracks', style: _WzTokens.caption),
            ],
          ),
          if (deviceLastError != null) ...[
            const SizedBox(height: 6),
            Text(deviceLastError!, style: const TextStyle(color: Color(0xFFFFC46B), fontSize: 12)),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<_LibrarySortMode>(
            value: librarySortMode,
            decoration: const InputDecoration(labelText: 'Sort library'),
            items: _LibrarySortMode.values
                .map((mode) => DropdownMenuItem(value: mode, child: Text(mode.label)))
                .toList(growable: false),
            onChanged: (mode) {
              if (mode != null) onSortModeChanged(mode);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Search ${librarySourceFilter.label}',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasQuery ? IconButton(onPressed: onClearSearch, icon: const Icon(Icons.close)) : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery
                ? 'Search active: ${tracks.length} result${tracks.length == 1 ? '' : 's'} in ${librarySourceFilter.label} (from $totalTrackCount available).'
                : 'Showing $totalTrackCount tracks in ${librarySourceFilter.label}. Total available: $combinedTrackCount. $status',
            style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (totalTrackCount == 0)
            _EmptyCatalogMessage(
              message: offlineMode ? 'No cached tracks available offline.' : 'No catalog tracks loaded yet.',
            )
          else if (tracks.isEmpty)
            _EmptyCatalogMessage(message: hasQuery ? 'No tracks match this search. Clear search to show ${librarySourceFilter.label}.' : 'No tracks available for ${librarySourceFilter.label}.')
          else ...tracks.map((track) => _CatalogRow(
                track: track,
                selected: track.trackId == selectedTrackId,
                addDisabled: addToQueueDisabled,
                onTap: () => onSelectTrack(track),
                onAdd: () => onAddToQueue(track),
                onToggleLike: () => onToggleLike(track),
                onAddToCollection: () => onAddToCollection(track),
                liked: isLiked(track),
                onCache: _isDeviceCatalogTrack(track) || _isCachedCatalogTrack(track) ? null : () => onCache(track),
                onDeleteCached: _isCachedCatalogTrack(track) ? () => onDeleteCachedTrack(track) : null,
              )),
        ],
      ),
    );
  }
}

IconData _librarySourceFilterIcon(_LibrarySourceFilter filter) => switch (filter) {
      _LibrarySourceFilter.all => Icons.library_music,
      _LibrarySourceFilter.api => Icons.cloud_queue,
      _LibrarySourceFilter.device => Icons.phone_android,
      _LibrarySourceFilter.downloads => Icons.download_done,
    };

String _librarySourceFilterShortLabel(_LibrarySourceFilter filter) => switch (filter) {
      _LibrarySourceFilter.all => 'All',
      _LibrarySourceFilter.api => 'API',
      _LibrarySourceFilter.device => 'Device',
      _LibrarySourceFilter.downloads => 'Downloads',
    };

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF172A36) : const Color(0xFF171B28),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFF9EDBFF), fontSize: 10, fontWeight: FontWeight.w800)),
      );
}


class _LicenseBadge extends StatelessWidget {
  const _LicenseBadge({required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: warning ? const Color(0xFF332613) : const Color(0xFF15251E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: warning ? const Color(0xFFFFC46B) : const Color(0xFF38D996).withOpacity(0.4)),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: warning ? const Color(0xFFFFC46B) : const Color(0xFF8FF0C0), fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

class _LegalLicensesPage extends StatelessWidget {
  const _LegalLicensesPage({required this.tracks, required this.appMode});

  final List<CatalogTrackSummary> tracks;
  final _AppMode appMode;

  @override
  Widget build(BuildContext context) {
    final uniqueTracks = <String, CatalogTrackSummary>{};
    for (final track in tracks) {
      uniqueTracks.putIfAbsent(track.trackId, () => track);
    }

    return Scaffold(
      backgroundColor: _WzTokens.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: WzPageScaffold(
              children: [
                Row(
                  children: [
                    IconButton.outlined(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back)),
                    const SizedBox(width: WzSpacing.sm),
                    const Expanded(child: WzPageHeader(icon: Icons.policy, title: 'Legal / Licenses', subtitle: 'Credits, license status, and safe catalog source labels.')),
                  ],
                ),
                const SizedBox(height: WzSpacing.md),
                WzPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('WaveZero separates user device music, local dev audio, demo catalog tracks, and future licensed/artist uploads.', style: WzText.body),
                      SizedBox(height: WzSpacing.xs),
                      Text('Device Music belongs to the user/device context and is not uploaded by WaveZero.', style: WzText.caption),
                      SizedBox(height: WzSpacing.xs),
                      Text('Local/dev-only tracks are not production-safe until rights are verified. Beta builds do not claim commercial catalog rights.', style: WzText.caption),
                    ],
                  ),
                ),
                const SizedBox(height: WzSpacing.md),
                const WzSectionHeader(title: 'Status guide', subtitle: 'Badges are metadata labels, not automated legal verification.', icon: Icons.verified_user_outlined),
                WzPanel(
                  child: Wrap(
                    spacing: WzSpacing.xs,
                    runSpacing: WzSpacing.xs,
                    children: LicenseStatus.values.map((status) => WzStatusPill(label: status.label, active: status == LicenseStatus.verified || status == LicenseStatus.publicDomain || status == LicenseStatus.userDevice, warning: status == LicenseStatus.devOnly || status == LicenseStatus.licensePending || status == LicenseStatus.unknown, icon: Icons.label_outline)).toList(growable: false),
                  ),
                ),
                const SizedBox(height: WzSpacing.md),
                const WzSectionHeader(title: 'Catalog credits', subtitle: 'Current library entries and their available rights metadata.', icon: Icons.library_music),
                if (uniqueTracks.isEmpty)
                  const WzPanel(child: Text('No license entries yet. Load the Catalog or import Device music to review rights labels.', style: WzText.body))
                else
                  ...uniqueTracks.values.map((track) => _LegalTrackCard(track: track, developerMode: appMode == _AppMode.developer)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalTrackCard extends StatelessWidget {
  const _LegalTrackCard({required this.track, required this.developerMode});

  final CatalogTrackSummary track;
  final bool developerMode;

  @override
  Widget build(BuildContext context) {
    final license = track.license;
    final source = license.sourceName ?? (_isDeviceCatalogTrack(track) ? 'Device music' : _isCachedCatalogTrack(track) ? 'Downloaded' : 'Catalog');
    return Padding(
      padding: const EdgeInsets.only(bottom: WzSpacing.sm),
      child: WzPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
            const SizedBox(height: WzSpacing.xs),
            Text(track.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
            const SizedBox(height: WzSpacing.sm),
            Wrap(
              spacing: WzSpacing.xs,
              runSpacing: WzSpacing.xs,
              children: [
                WzStatusPill(label: license.badgeLabel, active: !license.needsRightsWarning, warning: license.needsRightsWarning, icon: Icons.policy),
                WzStatusPill(label: source, active: _isDeviceCatalogTrack(track), warning: license.status == LicenseStatus.devOnly, icon: Icons.source),
                if (license.attributionRequired) const WzStatusPill(label: 'Attribution required', active: true, icon: Icons.badge),
              ],
            ),
            if (license.attributionText != null && license.attributionText!.trim().isNotEmpty) ...[
              const SizedBox(height: WzSpacing.sm),
              Text(license.attributionText!, maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.body),
            ],
            if (license.licenseName != null || license.licenseUrl != null || license.sourceUrl != null) ...[
              const SizedBox(height: WzSpacing.xs),
              Text([license.licenseName, license.licenseUrl, license.sourceUrl].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
            ],
            if (license.needsRightsWarning) ...[
              const SizedBox(height: WzSpacing.xs),
              const Text('Not for production distribution until rights are verified.', style: WzText.caption),
            ],
            if (license.usageNotes != null && license.usageNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: WzSpacing.xs),
              Text(license.usageNotes!, maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.caption),
            ],
            if (developerMode) ...[
              const SizedBox(height: WzSpacing.xs),
              Text('Internal track id: ${track.trackId} • source: ${track.source}', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
            ],
          ],
        ),
      ),
    );
  }
}

String _licenseBadgeLabel(CatalogTrackSummary track) {
  if (_isDeviceCatalogTrack(track)) return 'Device music';
  if (track.license.status == LicenseStatus.unknown && track.trackId.startsWith('track-local-')) return 'Dev only';
  return track.license.badgeLabel;
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.track,
    required this.selected,
    required this.addDisabled,
    required this.onTap,
    required this.onAdd,
    required this.onToggleLike,
    required this.onAddToCollection,
    required this.liked,
    required this.onCache,
    required this.onDeleteCached,
  });

  final CatalogTrackSummary track;
  final bool selected;
  final bool addDisabled;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onToggleLike;
  final VoidCallback onAddToCollection;
  final bool liked;
  final VoidCallback? onCache;
  final VoidCallback? onDeleteCached;

  @override
  Widget build(BuildContext context) {
    final status = CacheService().statusForTrack(track.trackId);
    final isDevice = _isDeviceCatalogTrack(track);
    final isCached = _isCachedCatalogTrack(track);
    final sourceLabel = isDevice ? 'Device' : isCached ? _cachedSourceBadgeLabel(track.displayName) : (track.license.sourceName ?? 'API');
    final licenseLabel = _licenseBadgeLabel(track);
    final asset = track.primaryAsset;
    Icon cacheIcon;
    switch (status) {
      case TrackCacheStatus.caching:
        cacheIcon = const Icon(Icons.downloading, color: Color(0xFF98A1B8));
        break;
      case TrackCacheStatus.cached:
        cacheIcon = const Icon(Icons.check_circle, color: Color(0xFF38D996));
        break;
      case TrackCacheStatus.failed:
        cacheIcon = const Icon(Icons.error, color: Color(0xFFFFC46B));
        break;
      case TrackCacheStatus.notCached:
      default:
        cacheIcon = const Icon(Icons.download, color: Color(0xFF8D7CFF));
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: selected ? const Color(0x227C5CFF) : const Color(0xFF0B0E18), borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? const Color(0xFF8D7CFF) : const Color(0xFF20273A))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Artwork(artworkUrl: track.artworkUrl, size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                    ]),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _SourceBadge(label: sourceLabel, active: selected || isDevice || isCached),
                        _LicenseBadge(label: licenseLabel, warning: track.license.needsRightsWarning),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_trackSubtitle(track), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
                    const SizedBox(height: 3),
                    Text('${asset?.qualityLabel ?? 'quality unknown'}${asset?.codec == null ? '' : ' • ${asset!.codec}'}${isDevice ? ' • Already local' : isCached ? ' • Cached locally' : ' • ${status.name}'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                Text(_formatTime(track.durationMs), style: _timeStyle),
                if (status == TrackCacheStatus.cached && !isCached)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF173626), borderRadius: BorderRadius.circular(10)),
                    child: const Text('Cached', style: TextStyle(color: Color(0xFF38D996), fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                IconButton(tooltip: liked ? 'Unlike' : 'Like', onPressed: onToggleLike, icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Color(0xFFFF6B8A) : Color(0xFF8D7CFF))),
                IconButton(tooltip: 'Add to queue', onPressed: addDisabled ? null : onAdd, icon: const Icon(Icons.playlist_add, color: Color(0xFF8D7CFF))),
                IconButton(tooltip: 'Add to collection', onPressed: onAddToCollection, icon: const Icon(Icons.library_add, color: Color(0xFF8D7CFF))),
                if (onCache != null) IconButton(tooltip: 'Cache/download', onPressed: onCache, icon: cacheIcon),
                if (onDeleteCached != null) IconButton(tooltip: 'Delete cached file', onPressed: onDeleteCached, icon: const Icon(Icons.delete_outline, color: Color(0xFFFF8F8F))),
                if (onCache == null && onDeleteCached == null) const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.phone_android, color: Color(0xFF38D996))),
                Icon(selected ? Icons.check_circle : Icons.play_circle_outline, color: const Color(0xFF8D7CFF)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _ContentServerDiagnosticsPanel extends StatelessWidget {
  const _ContentServerDiagnosticsPanel({required this.apiBaseUrl, required this.status, required this.catalogStatus, required this.catalogTrackCount});

  final String apiBaseUrl;
  final ContentStatus? status;
  final String catalogStatus;
  final int catalogTrackCount;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(label: 'Catalog', value: status?.friendlyLabel ?? catalogStatus, active: status?.ok ?? catalogTrackCount > 0),
              _MetricCard(label: 'Mode', value: status?.contentMode ?? 'unknown', active: status?.contentMode == 'production' || status?.contentMode == 'demo'),
              _MetricCard(label: 'Tracks', value: '${status?.trackCount ?? catalogTrackCount}', active: (status?.trackCount ?? catalogTrackCount) > 0),
              _MetricCard(label: 'Assets', value: '${status?.assetCount ?? 0}', active: (status?.assetCount ?? 0) > 0),
              _MetricCard(label: 'Production-safe', value: '${status?.productionSafeTrackCount ?? 0}', active: (status?.productionSafeTrackCount ?? 0) > 0),
              _MetricCard(label: 'Local folder', value: status?.localFolderCatalogEnabled == true ? 'enabled' : 'disabled', active: status?.localFolderCatalogEnabled == true),
            ],
          ),
          const SizedBox(height: 10),
          Text('API base URL: $apiBaseUrl', style: _WzTokens.caption),
          Text(status?.developerSummary ?? catalogStatus, style: _WzTokens.caption),
        ],
      ),
    );
  }
}

class _TrackSetupCard extends StatelessWidget { const _TrackSetupCard({required this.titleController, required this.urlController, required this.apiBaseUrlController, required this.catalogStatus, required this.loading, required this.onLoadCatalog, required this.onLoadTrack}); final TextEditingController titleController; final TextEditingController urlController; final TextEditingController apiBaseUrlController; final String catalogStatus; final bool loading; final VoidCallback onLoadCatalog; final VoidCallback onLoadTrack; @override Widget build(BuildContext context) => _Panel(child: ExpansionTile(tilePadding: EdgeInsets.zero, title: const Text('Manual / API setup'), subtitle: Text(catalogStatus, maxLines: 2, overflow: TextOverflow.ellipsis), children: [TextField(controller: apiBaseUrlController, decoration: const InputDecoration(labelText: 'API base URL')), const SizedBox(height: 12), TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Manual title')), const SizedBox(height: 12), TextField(controller: urlController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Manual audio URL')), const SizedBox(height: 16), Wrap(spacing: 10, runSpacing: 10, children: [FilledButton.tonalIcon(onPressed: loading ? null : onLoadCatalog, icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_download), label: const Text('Reload selected/API')), OutlinedButton.icon(onPressed: loading ? null : onLoadTrack, icon: const Icon(Icons.bolt), label: const Text('Load manual track'))]) ])); }

class _HealthStrip extends StatelessWidget {
  const _HealthStrip({required this.metrics});

  final PlaybackMetrics metrics;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: _WzTokens.space3,
        runSpacing: _WzTokens.space3,
        children: [
          _MetricCard(
            label: 'Tap to audio',
            value: _formatMetric(metrics.tapToFirstAudioMs),
            active: metrics.tapToFirstAudioMs != null && metrics.tapToFirstAudioMs! < 800,
          ),
          _MetricCard(
            label: 'Ready',
            value: _formatMetric(metrics.loadToReadyMs),
            active: metrics.preparedBeforePlay,
          ),
          _MetricCard(label: 'Rebuffers', value: metrics.rebufferCount.toString(), active: metrics.rebufferCount == 0),
          _MetricCard(label: 'Error', value: metrics.playbackError == null ? 'none' : 'check', active: metrics.playbackError == null),
        ],
      );
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.label, required this.value, required this.good});

  final String label;
  final String value;
  final bool good;

  @override
  Widget build(BuildContext context) => _MetricCard(label: label, value: value, active: good);
}

class _DeveloperModePanel extends StatelessWidget {
  const _DeveloperModePanel({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _Panel(
        child: SwitchListTile(
          value: enabled,
          onChanged: onChanged,
          secondary: const Icon(Icons.admin_panel_settings),
          title: const Text('Internal developer mode'),
          subtitle: const Text('Turn off to return to the consumer music shell.'),
        ),
      );
}

class _MetricsToggle extends StatelessWidget {
  const _MetricsToggle({
    required this.showMetrics,
    required this.operationBusy,
    required this.onToggle,
    required this.onCopyMetrics,
    required this.onResetMetrics,
  });

  final bool showMetrics;
  final bool operationBusy;
  final VoidCallback onToggle;
  final VoidCallback onCopyMetrics;
  final VoidCallback onResetMetrics;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onToggle,
              icon: Icon(showMetrics ? Icons.expand_less : Icons.analytics_outlined),
              label: Text(showMetrics ? 'Hide raw metrics' : 'Show raw metrics'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.outlined(onPressed: operationBusy ? null : onCopyMetrics, icon: const Icon(Icons.copy), tooltip: 'Copy metrics'),
          const SizedBox(width: 10),
          IconButton.outlined(onPressed: operationBusy ? null : onResetMetrics, icon: const Icon(Icons.restart_alt), tooltip: 'Reset metrics'),
        ],
      );
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.metrics});

  final PlaybackMetrics metrics;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _PanelHeader(
              icon: Icons.data_object,
              title: 'Raw metrics',
              subtitle: 'Complete developer telemetry without changing metric names or meaning.',
            ),
            const SizedBox(height: _WzTokens.space4),
            SelectableText(
              metrics.toDisplayText(),
              style: const TextStyle(color: Color(0xFFD7DDF0), fontFamily: 'monospace', height: 1.45),
            ),
          ],
        ),
      );
}

class _PremiumMiniPlayer extends StatelessWidget {
  const _PremiumMiniPlayer({
    required this.metrics,
    required this.manifest,
    required this.progressValue,
    required this.sourceLabel,
    required this.offlineReady,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerBadge,
    required this.controlsDisabled,
    required this.onTap,
    required this.onPlayPause,
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final double progressValue;
  final String sourceLabel;
  final bool offlineReady;
  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final String? sleepTimerBadge;
  final bool controlsDisabled;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? 'Current track';
    final subtitle = manifest?.subtitle ?? (metrics.isPlaying ? 'Playing from WaveZero' : 'Paused in WaveZero');
    return SafeArea(
      top: false,
      bottom: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(WzRadius.xl),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xEE20263F), Color(0xEE0A0D18)]),
              borderRadius: BorderRadius.circular(WzRadius.xl),
              border: Border.all(color: WzColors.borderSoft),
              boxShadow: const [BoxShadow(color: Color(0x77000000), blurRadius: 24, offset: Offset(0, 12))],
            ),
            child: Row(
              children: [
                _MiniArtwork(artworkUrl: manifest?.artworkUrl),
                const SizedBox(width: WzSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: WzSpacing.xs,
                        runSpacing: WzSpacing.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14)),
                          ),
                          _MiniBadge(label: sourceLabel),
                          if (offlineReady) const _MiniBadge(label: 'Offline Ready'),
                          if (shuffleEnabled) const _MiniBadge(label: 'Shuffle'),
                          if (repeatMode != WzRepeatMode.off) _MiniBadge(label: repeatMode == WzRepeatMode.one ? 'Repeat 1' : 'Repeat all'),
                          if (sleepTimerBadge != null) _MiniBadge(label: sleepTimerBadge!),
                        ],
                      ),
                      const SizedBox(height: WzSpacing.xxs),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                      const SizedBox(height: WzSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(value: progressValue.clamp(0.0, 1.0), minHeight: 3, backgroundColor: Colors.white.withOpacity(0.10), valueColor: const AlwaysStoppedAnimation<Color>(WzColors.accentAlt)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: WzSpacing.xs),
                IconButton.filled(
                  tooltip: metrics.isPlaying ? 'Pause' : 'Play',
                  onPressed: controlsDisabled ? null : onPlayPause,
                  icon: Icon(metrics.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({this.artworkUrl});

  final String? artworkUrl;

  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: WzColors.accentGradient, borderRadius: BorderRadius.circular(WzRadius.md), border: Border.all(color: Colors.white.withOpacity(0.16))),
      child: url == null || url.trim().isEmpty
          ? Stack(
              fit: StackFit.expand,
              children: [
                Icon(Icons.album_rounded, color: Colors.white.withOpacity(0.88), size: 28),
                Positioned(right: -7, bottom: -7, child: Icon(Icons.graphic_eq, color: Colors.white.withOpacity(0.14), size: 30)),
              ],
            )
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.album_rounded, color: Colors.white)),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.10))),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(fontSize: 10, color: WzColors.textPrimary)),
      );
}


class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: _WzTokens.surface,
          borderRadius: BorderRadius.circular(_WzTokens.radiusXl),
          border: Border.all(color: _WzTokens.border),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 18)),
          ],
        ),
        child: Padding(padding: padding, child: child),
      );
}

class _EmptyCatalogMessage extends StatelessWidget {
  const _EmptyCatalogMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _WzTokens.surfaceMuted, borderRadius: BorderRadius.circular(_WzTokens.radiusMd)),
        child: Text(message, style: _WzTokens.body),
      );
}

CatalogTrackSummary? _findTrack(List<CatalogTrackSummary> tracks, String? trackId) { if (trackId == null) return null; for (final track in tracks) { if (track.trackId == trackId) return track; } return null; }
String _trackSubtitle(CatalogTrackSummary track) { final asset = track.primaryAsset; final parts = <String>[track.subtitle]; if (asset?.qualityLabel != null) parts.add(asset!.qualityLabel!); if (asset?.codec != null) parts.add(asset!.codec!); if (asset?.bitrateKbps != null) parts.add('${asset!.bitrateKbps}kbps'); parts.add(_isDeviceCatalogTrack(track) ? 'source: Device' : 'source: ${track.license.sourceName ?? 'API'}'); parts.add(track.license.badgeLabel); return parts.join(' • '); }
String _statusFromEvent(String? event) { switch (event) { case 'track_loaded': case 'buffering_started': return 'Preparing'; case 'ready': case 'buffering_ended': case 'manifest_loaded': return 'Ready'; case 'not_playing': return 'Paused'; case 'stopped': return 'Paused'; case 'ended': case 'playback_ended': return 'Ended'; default: return 'Ready'; } }
String _formatMetric(int? valueMs) => valueMs == null ? '—' : '${valueMs}ms';
String _formatTime(int? valueMs) { if (valueMs == null || valueMs < 0) return '—:—'; final totalSeconds = (valueMs / 1000).floor(); final minutes = totalSeconds ~/ 60; final seconds = totalSeconds % 60; return '$minutes:${seconds.toString().padLeft(2, '0')}'; }
const _timeStyle = TextStyle(color: Color(0xFF9BA3B4), fontSize: 12);

