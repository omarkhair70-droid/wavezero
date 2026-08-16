import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/audio_effects.dart';
import 'app_config.dart';
import 'app_shell/wavezero_product_header.dart';
import 'curated_demo_picks.dart';
import '../catalog/audio_quality.dart';
import '../catalog/catalog_client.dart';
import '../catalog/catalog_track_manifest.dart';
import '../playback/playback_bridge.dart';
import '../playback/playback_metrics.dart';
import '../playback/test_track.dart';
import '../features/playback/auto_advance_trigger.dart';
import '../features/playback/playback_modes.dart';
import '../features/library/library_controls.dart';
import '../features/library/library_catalog_panel.dart';
import '../features/library/library_sort.dart';
import '../features/library/library_sources.dart';
import '../features/library/library_status_presentation.dart';
import '../features/search/search_controls.dart';
import '../features/search/recent_searches_store.dart';
import '../features/search/search_text.dart';
import '../features/search/search_results.dart';
import '../features/search/search_index.dart';
import '../features/search/search_page.dart';
import '../features/playback/playback_preferences.dart';
import '../features/playback/audio_effect_preferences.dart';
import '../features/downloads/cache_service.dart';
import '../features/downloads/downloads_presentation.dart';
import '../features/downloads/downloads_panel.dart';
import '../features/downloads/smart_download_policy.dart';
import '../features/downloads/storage_manager_page.dart';
import '../features/cloud_vault/cloud_vault_models.dart';
import '../features/cloud_vault/cloud_vault_service.dart';
import '../features/cloud_vault/cloud_vault_page.dart';
import '../design/wavezero_design_system.dart';
import '../features/device_music/device_music_service.dart';
import '../features/device_music/device_music_track.dart';
import '../features/device_music/device_music_projection.dart';
import '../features/collections/collections_service.dart';
import '../features/collections/collection_resolution.dart';
import '../features/collections/collection_mutations.dart';
import '../features/collections/collections_pages.dart';
import '../features/home/home_sections.dart';
import '../features/history/listening_history_service.dart';
import '../features/history/history_selection.dart';
import '../features/history/history_resolution.dart';
import '../features/history/history_presentation.dart';
import '../features/history/listening_history_page.dart';
import '../features/settings/app_mode_preferences.dart';
import '../features/settings/legal_licenses_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/media/media_presentation.dart';
import '../shared/media/track_source.dart';
import '../shared/widgets/wavezero_artwork.dart';
import '../shared/widgets/wavezero_empty_message.dart';
import '../features/playback/playback_operation_controller.dart';
import '../features/playback/player_operation_state.dart';
import '../features/playback/playback_status.dart';
import '../features/playback/sleep_timer_presentation.dart';
import '../features/queue/queue_session_store.dart';
import '../features/queue/queue_session_restore.dart';
import '../features/queue/queue_mutations.dart';
import '../features/queue/queue_position.dart';
import '../features/queue/queue_panel.dart';
import '../features/queue/smart_queue_policy.dart';
import 'navigation/wavezero_navigation.dart';
import 'theme/wavezero_theme.dart';
import 'theme/wavezero_theme_preferences.dart';

class WaveZeroApp extends StatefulWidget {
  const WaveZeroApp({super.key, PlaybackBridge? playbackBridge, QueueSessionStore? sessionStore})
      : _playbackBridge = playbackBridge,
        _sessionStore = sessionStore;

  final PlaybackBridge? _playbackBridge;
  final QueueSessionStore? _sessionStore;

  @override
  State<WaveZeroApp> createState() => _WaveZeroAppState();
}

class _WaveZeroAppState extends State<WaveZeroApp> {
  final WzThemePreferences _themePreferences = const WzThemePreferences();
  WzThemeConfig _themeConfig = const WzThemeConfig();

  @override
  void initState() {
    super.initState();
    unawaited(_loadThemeConfig());
  }

  Future<void> _loadThemeConfig() async {
    final config = await _themePreferences.load();
    if (!mounted) return;
    setState(() => _themeConfig = config);
  }

  Future<void> _setThemeConfig(WzThemeConfig config) async {
    setState(() => _themeConfig = config);
    await _themePreferences.save(config);
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
  static const int _defaultCatalogLimit = 300;
  static const int _initialVisibleTrackCount = 200;
  static const int _libraryPageSize = 100;
  static const int _searchResultLimit = 100;
  static const Duration _searchDebounce = Duration(milliseconds: 250);

  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _searchController;
  late final TextEditingController _fullSearchController;
  late final TextEditingController _cloudSeedTitleController;
  late final TextEditingController _cloudSeedArtistController;
  late final TextEditingController _cloudSeedUrlController;
  late final TextEditingController _cloudSeedProviderController;

  Timer? _poller;
  Timer? _sleepTimer;
  Timer? _librarySearchDebounce;
  Timer? _fullSearchDebounce;
  PlaybackMetrics _metrics = const PlaybackMetrics();
  CatalogTrackManifest? _manifest;
  List<CatalogTrackSummary> _catalog = const [];
  List<CatalogTrackSummary> _queue = const [];
  Set<String> _catalogTrackIds = const <String>{};
  int _visibleTrackCount = _initialVisibleTrackCount;
  int _filteredTrackCount = 0;
  String _debouncedFullSearchQuery = '';
  List<CatalogTrackSummary>? _filteredCatalogMemo;
  int _filteredCatalogMemoKey = 0;
  List<WzSearchResult>? _searchIndexMemo;
  int _searchIndexMemoKey = 0;
  List<WzSearchResult>? _filteredSearchMemo;
  int _filteredSearchMemoKey = 0;
  final DeviceMusicService _deviceMusicService = DeviceMusicService();
  DeviceMusicPermissionStatus _deviceMusicPermissionStatus = const DeviceMusicPermissionStatus(status: 'unknown');
  String _deviceMusicScanStatus = 'not_scanned';
  List<DeviceMusicTrack> _deviceMusicTracks = const [];
  final CloudVaultService _cloudVaultService = const CloudVaultService();
  List<CloudVaultTrack> _cloudVaultTracks = const [];
  int _deviceMusicLastScanCount = 0;
  String? _deviceMusicLastError;
  int? _deviceMusicImportedAtMs;
  WzLibrarySourceFilter _librarySourceFilter = WzLibrarySourceFilter.all;
  WzLibrarySortMode _librarySortMode = WzLibrarySortMode.recentlyAdded;

  final WzPlaybackPreferences _playbackPreferences = const WzPlaybackPreferences();
  final WzAudioEffectPreferences _audioEffectPreferences = const WzAudioEffectPreferences();
  final WzAppModePreferences _appModePreferences = const WzAppModePreferences();

  final WzPlaybackOperationController _operationController = WzPlaybackOperationController();
  PlayerOperation get _operation => _operationController.current;
  bool _refreshingMetrics = false;
  bool _showMetrics = false;
  WzAppMode _appMode = WzAppMode.consumer;
  WzAppTab _selectedTab = WzAppTab.home;
  bool _autoAdvanceEnabled = true;
  bool _shuffleEnabled = false;
  WzRepeatMode _repeatMode = WzRepeatMode.off;
  WzSleepTimerPreset _sleepTimerPreset = WzSleepTimerPreset.off;
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
  WzSearchFilter _searchFilter = WzSearchFilter.all;
  final WzRecentSearchesStore _recentSearchesStore = const WzRecentSearchesStore();
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

  WzListeningHistoryEntry? get _continueListeningEntry => wzContinueListeningEntry(_listeningHistory);

  WzListeningHistoryEntry? get _mostPlayedHistoryEntry => wzMostPlayedHistoryEntry(_listeningHistory);

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
      _deviceMusicTracks.map(wzCatalogSummaryFromDeviceTrack).toList(growable: false);

  List<CatalogTrackSummary> get _cachedCatalogTracks =>
      _cachedLibrary.map(wzCatalogSummaryFromCachedTrack).toList(growable: false);

  List<CatalogTrackSummary> get _cloudCatalogTracks =>
      _cloudVaultTracks.map((track) => track.toCatalogSummary()).toList(growable: false);

  List<CatalogTrackSummary> get _libraryTracks => composeWzLibraryTracks(
        filter: _librarySourceFilter,
        catalogTracks: _catalog,
        deviceTracks: _deviceCatalogTracks,
        downloadedTracks: _cachedCatalogTracks,
        cloudTracks: _cloudCatalogTracks,
      );

  int get _libraryTotalTrackCount => _libraryTracks.length;
  int get _libraryCombinedTrackCount => _catalog.length + _deviceMusicTracks.length + _cachedLibrary.length + _cloudVaultTracks.length;
  bool get _largeCatalogMode => _libraryCombinedTrackCount > _catalogLimit;
  int get _catalogLimit => _PlayerScreenState._defaultCatalogLimit;
  int get _effectiveVisibleTrackCount => math.min(_visibleTrackCount, _filteredTrackCount);

  void _invalidateCatalogMemos() {
    _filteredCatalogMemo = null;
    _searchIndexMemo = null;
    _filteredSearchMemo = null;
  }

  int _libraryMemoKey() => Object.hash(
        _catalog.length,
        _deviceMusicTracks.length,
        _cachedLibrary.length,
        _cloudVaultTracks.length,
        _librarySourceFilter,
        _librarySortMode,
        _catalogQuery,
        _visibleTrackCount,
        _deviceMusicImportedAtMs,
      );

  List<CatalogTrackSummary> get _filteredCatalog {
    final key = _libraryMemoKey();
    final memo = _filteredCatalogMemo;
    if (memo != null && _filteredCatalogMemoKey == key) return memo;
    final query = _catalogQuery.trim();
    final List<CatalogTrackSummary> matching = query.isEmpty
        ? _libraryTracks
        : _libraryTracks.where((track) => track.matchesQuery(query)).toList(growable: false);
    _filteredTrackCount = matching.length;
    final sorted = sortWzLibraryTracks(matching, mode: _librarySortMode, addedRank: _libraryAddedRank);
    final visible = sorted.take(_visibleTrackCount).toList(growable: false);
    _filteredCatalogMemoKey = key;
    _filteredCatalogMemo = visible;
    return visible;
  }

  List<CatalogTrackSummary> get _searchableCatalogTracks => _catalog.take(_defaultCatalogLimit).toList(growable: false);
  List<ResolvedCuratedDemoShelf> get _resolvedCuratedShelves => CuratedDemoPicks.resolveShelves(_catalog);
  List<ResolvedCuratedDemoPick> get _featuredCuratedPicks => CuratedDemoPicks.resolveFeatured(_catalog, limit: 12);

  int _searchIndexKey() => Object.hash(
        _catalog.length,
        _deviceMusicTracks.length,
        _cachedLibrary.length,
        _cloudVaultTracks.length,
        _collections.length,
        _listeningHistory.length,
      );

  List<WzSearchResult> get _allSearchResults {
    final key = _searchIndexKey();
    final memo = _searchIndexMemo;
    if (memo != null && _searchIndexMemoKey == key) return memo;
    final results = buildWzSearchIndex(
      catalogTracks: _searchableCatalogTracks,
      deviceTracks: _deviceCatalogTracks,
      downloadedTracks: _cachedCatalogTracks,
      cloudTracks: _cloudCatalogTracks,
      collections: _collections,
      historyEntries: _listeningHistory,
      resolveHistoryEntry: _resolveHistoryEntry,
      isDeviceTrack: isWzDeviceCatalogTrack,
      historySourceLabel: wzHistorySourceLabel,
    );
    _searchIndexMemoKey = key;
    _searchIndexMemo = results;
    return results;
  }

  int _filteredSearchKey() => Object.hash(_searchIndexKey(), _searchFilter, _debouncedFullSearchQuery);

  List<WzSearchResult> get _filteredSearchResults {
    final query = _debouncedFullSearchQuery;
    final normalized = normalizeWzSearch(query);
    if (normalized.isEmpty) return const <WzSearchResult>[];
    final key = _filteredSearchKey();
    final memo = _filteredSearchMemo;
    if (memo != null && _filteredSearchMemoKey == key) return memo;
    final matches = _allSearchResults
        .where((result) => wzSearchFilterAllows(_searchFilter, result) && result.searchText.contains(normalized))
        .toList(growable: false);
    final indexed = matches.indexed.toList(growable: false);
    indexed.sort((a, b) {
      final rank = wzSearchRank(a.$2, query).compareTo(wzSearchRank(b.$2, query));
      if (rank != 0) return rank;
      final title = a.$2.searchText.compareTo(b.$2.searchText);
      if (title != 0) return title;
      return a.$1.compareTo(b.$1);
    });
    final limited = indexed.map((item) => item.$2).take(_searchResultLimit).toList(growable: false);
    _filteredSearchMemoKey = key;
    _filteredSearchMemo = limited;
    return limited;
  }

  WzQueuePosition get _queuePosition => resolveWzQueuePosition(
        queue: _queue,
        currentTrackId: _queueCurrentTrackId,
        selectedTrackId: _selectedTrackId,
        shuffleEnabled: _shuffleEnabled,
      );

  int get _queueIndex => _queuePosition.index;
  CatalogTrackSummary? get _currentQueueTrack => _queuePosition.currentTrack;
  CatalogTrackSummary? get _upNextQueueTrack => _queuePosition.upNextTrack;

  SmartQueueDecision _smartQueueDecision() => decideSmartQueueCandidate(
        smartPreloadEnabled: _prefetchEnabled,
        queue: _queue,
        catalogTrackIds: _catalogTrackIds,
        currentTrackId: _queueCurrentTrackId,
        selectedTrackId: _selectedTrackId,
        previousCandidateTrackId: _smartQueueCandidateTrackId ?? _prefetchedTrackId,
        manifestPrefetched: _manifestPrefetched,
        metrics: _metrics,
      );

  bool get _canPrevious => _queuePosition.canPrevious;
  bool get _canNext => _queuePosition.canNext;
  bool get _canShuffleNext => _queuePosition.canShuffleNext;
  bool get _canPlayNextControl => _queuePosition.canPlayNext;

  String get _sleepTimerStatusLabel => WzSleepTimerPresentation.statusLabel(
        deadline: _sleepTimerDeadline,
        now: DateTime.now(),
      );

  String get _sleepTimerSettingsLabel => WzSleepTimerPresentation.settingsLabel(
        deadline: _sleepTimerDeadline,
        now: DateTime.now(),
      );
  bool get _playerDisabled => _operation.disablesPlayerControls;
  bool get _catalogRefreshDisabled => _operation.disablesCatalogRefresh;
  bool get _queueDisabled => _operation.disablesQueueControls;
  bool get _manualDisabled => _operation.disablesManualTrackControls;
  bool get _developerMode => _appMode == WzAppMode.developer;
  bool get _showDeveloperControls => widget.appConfig.showDeveloperEntry || _developerMode;
  bool get _allowManualApiSetup => widget.appConfig.allowManualApiSetup && _developerMode;

  String get _consumerLibraryHeaderStatus {
    if (_offlineLibraryAvailable) return 'Offline Ready';
    if (_deviceMusicTracks.isNotEmpty) return 'Device music ready';
    if (_catalog.isNotEmpty) return _contentStatus?.friendlyLabel ?? 'Catalog ready';

    final normalized = _catalogStatus.toLowerCase();
    if (normalized.contains('loading')) return 'Loading library';
    if (normalized.contains('unavailable') ||
        normalized.contains('error') ||
        normalized.contains('exception') ||
        normalized.contains('failed')) {
      return 'Catalog unavailable';
    }
    return 'Library ready';
  }

  bool get _consumerLibraryHeaderWarning => _consumerLibraryHeaderStatus == 'Catalog unavailable';
  bool get _consumerLibraryHeaderActive => !_consumerLibraryHeaderWarning && _consumerLibraryHeaderStatus != 'Loading library';

  String get _statusText => WzPlaybackStatusPresentation.headline(
        lastError: _lastError,
        playbackError: _metrics.playbackError,
        operation: _operation,
        isPlaying: _metrics.isPlaying,
        hasLoadedTrack: _manifest != null || _metrics.trackTitle != null,
      );

  String get _statusDetail => WzPlaybackStatusPresentation.detail(
        lastError: _lastError,
        playbackError: _metrics.playbackError,
        developerMode: _developerMode,
        refreshingMetrics: _refreshingMetrics,
        upNextTitle: _upNextQueueTrack?.title,
        queueStatus: _queueStatus,
        consumerError: friendlyWzLoadError,
      );

  @override
  void initState() {
    super.initState();
    _sessionRecoveryStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    _titleController = TextEditingController(text: waveZeroTestTrack.title);
    _urlController = TextEditingController(text: waveZeroTestTrack.url);
    _apiBaseUrlController = TextEditingController(text: widget.appConfig.apiBaseUrl);
    _searchController = TextEditingController();
    _fullSearchController = TextEditingController();
    _cloudSeedTitleController = TextEditingController();
    _cloudSeedArtistController = TextEditingController();
    _cloudSeedUrlController = TextEditingController();
    _cloudSeedProviderController = TextEditingController(text: CloudVaultProvider.manualUrl.label);
    _searchController.addListener(() {
      _librarySearchDebounce?.cancel();
      _librarySearchDebounce = Timer(_searchDebounce, () {
        if (mounted) {
          setState(() {
            _catalogQuery = _searchController.text;
            _visibleTrackCount = _initialVisibleTrackCount;
            _invalidateCatalogMemos();
          });
        }
      });
    });
    _fullSearchController.addListener(() {
      _fullSearchDebounce?.cancel();
      _fullSearchDebounce = Timer(_searchDebounce, () {
        if (mounted) {
          setState(() {
            _debouncedFullSearchQuery = _fullSearchController.text;
            _filteredSearchMemo = null;
          });
        }
      });
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
    unawaited(_loadCloudVault());
    unawaited(_loadPlaybackModePrefs());
  }

  Future<void> _loadCloudVault() async {
    final tracks = await _cloudVaultService.listTracks();
    if (!mounted) return;
    setState(() {
      _cloudVaultTracks = tracks;
      _invalidateCatalogMemos();
    });
  }

  Future<void> _addDeveloperCloudSeed() async {
    final title = _cloudSeedTitleController.text.trim();
    final playableUrl = _cloudSeedUrlController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a title for the developer preview track.')));
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final track = CloudVaultTrack(
      cloudTrackId: 'cloud-manual-$now',
      title: title,
      artistName: _cloudSeedArtistController.text.trim().isEmpty ? null : _cloudSeedArtistController.text.trim(),
      provider: CloudVaultProvider.manualUrl,
      providerFileId: _cloudSeedProviderController.text.trim().isEmpty ? null : _cloudSeedProviderController.text.trim(),
      sourceUri: playableUrl.isEmpty ? null : playableUrl,
      playableUri: playableUrl.isEmpty ? null : playableUrl,
      importedAtMs: now,
      isAvailable: playableUrl.isNotEmpty,
      isLocalOnly: true,
      isPrivate: true,
      userOwned: true,
    );
    final next = await _cloudVaultService.addTrack(track);
    if (!mounted) return;
    setState(() => _cloudVaultTracks = next);
    _cloudSeedTitleController.clear();
    _cloudSeedArtistController.clear();
    _cloudSeedUrlController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Developer preview cloud track added locally.')));
  }

  Future<void> _removeCloudVaultTrack(CloudVaultTrack track) async {
    final next = await _cloudVaultService.removeTrack(track.cloudTrackId);
    if (!mounted) return;
    setState(() => _cloudVaultTracks = next);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Cloud Vault.')));
  }

  Future<void> _clearCloudVaultTracks() async {
    await _cloudVaultService.clearTracks();
    if (!mounted) return;
    setState(() => _cloudVaultTracks = const <CloudVaultTrack>[]);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud Vault entries cleared from this device.')));
  }

  Future<void> _playCloudVaultTrack(CloudVaultTrack track, {bool autoPlay = true}) async {
    if (!track.isResolvable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud playback is not connected yet.')));
      return;
    }
    final manifest = CatalogTrackManifest(
      trackId: track.cloudTrackId,
      title: track.title,
      streamUrl: track.playableUri!,
      artistName: track.artistName,
      durationMs: track.durationMs,
      artworkUrl: track.artworkUrl,
      assetId: 'cloud-vault-${track.cloudTrackId}',
      qualityLabel: 'Cloud',
      codec: track.mimeType,
      fileSizeBytes: track.fileSizeBytes,
      license: const LicenseMetadata(
        status: LicenseStatus.userDevice,
        sourceName: 'Cloud Vault',
        usageNotes: 'Private user-owned cloud source. Public redistribution is not supported.',
      ),
    );
    return _runOperation(PlayerOperation.loadingManualTrack, () async {
      await _clearNativeNextPrebuffer();
      await widget.playbackBridge.loadTrack(title: manifest.title, url: manifest.streamUrl);
      await _pushNotificationMetadata(manifest, url: manifest.streamUrl, source: 'cloud_vault');
      final next = await _cloudVaultService.markPlayed(track.cloudTrackId, DateTime.now().millisecondsSinceEpoch);
      if (!mounted) return;
      setState(() {
        _cloudVaultTracks = next;
        _manifest = manifest;
        _selectedTrackId = manifest.trackId;
        _queueCurrentTrackId = manifest.trackId;
        _currentAssetUrl = manifest.streamUrl;
        _currentCachedQuality = null;
        _catalogStatus = 'Loaded Cloud Vault track: ${manifest.title}';
      });
      if (autoPlay) await widget.playbackBridge.play();
      unawaited(_saveSession());
    });
  }

  void _addCloudVaultTrackToQueue(CloudVaultTrack track) {
    if (!track.isResolvable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cloud playback is not connected yet.')));
      return;
    }
    _addToQueue(track.toCatalogSummary());
  }

  Future<void> _openCloudVaultPage() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WzCloudVaultPage(
        tracks: _cloudVaultTracks,
        developerMode: _developerMode,
        titleController: _cloudSeedTitleController,
        artistController: _cloudSeedArtistController,
        playableUrlController: _cloudSeedUrlController,
        providerLabelController: _cloudSeedProviderController,
        onAddDeveloperTrack: _addDeveloperCloudSeed,
        onPlay: _playCloudVaultTrack,
        onAddToQueue: _addCloudVaultTrackToQueue,
        onRemove: (track) => unawaited(_removeCloudVaultTrack(track)),
        onClearAll: _cloudVaultTracks.isEmpty ? null : () => unawaited(_clearCloudVaultTracks()),
      ),
    ));
  }

  Future<void> _loadListeningHistory() async {
    final entries = await _listeningHistoryService.load();
    if (!mounted) return;
    setState(() => _listeningHistory = entries);
  }

  Future<void> _loadPlaybackModePrefs() async {
    final snapshot = await _playbackPreferences.load();
    if (!mounted) return;
    setState(() {
      _shuffleEnabled = snapshot.shuffleEnabled;
      _repeatMode = snapshot.repeatMode;
      _sleepTimerPreset = snapshot.sleepTimerPreset;
      _sleepTimerDeadline = null;
    });
  }

  Future<void> _loadRecentSearches() async {
    final searches = await _recentSearchesStore.load();
    if (!mounted) return;
    setState(() => _recentSearches = searches);
  }

  Future<void> _rememberSearchQuery(String query) async {
    final canonical = canonicalizeWzRecentSearch(query);
    if (canonical.isEmpty) return;
    final next = buildWzRecentSearches(current: _recentSearches, query: canonical);
    setState(() => _recentSearches = next);
    await _recentSearchesStore.save(next);
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches = const <String>[]);
    await _recentSearchesStore.clear();
  }

  void _openSearch({String? query}) {
    if (query != null) _fullSearchController.text = query;
    setState(() => _selectedTab = WzAppTab.search);
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

  bool _isLiked(String trackId) => wzCollectionContainsTrack(_likedCollection, trackId);

  WzCollectionTrackSnapshot _snapshotForTrack(CatalogTrackSummary track) {
    final source = isWzDeviceCatalogTrack(track)
        ? WzCollectionTrackSource.device
        : isWzCachedCatalogTrack(track)
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
      license: isWzDeviceCatalogTrack(track) ? LicenseMetadata.userDevice : track.license,
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

  CatalogTrackSummary? _resolveCollectionTrack(WzCollectionTrackSnapshot snapshot) =>
      wzResolveCollectionTrack(libraryTracks: _libraryTracks, snapshot: snapshot);

  CatalogTrackSummary? _resolveHistoryEntry(WzListeningHistoryEntry entry) {
    final restoredDeviceTrack = _findDeviceTrack(entry.trackId);
    return wzResolveHistoryEntry(
      libraryTracks: _libraryTracks,
      entry: entry,
      fallbackTrack: restoredDeviceTrack == null ? null : wzCatalogSummaryFromDeviceTrack(restoredDeviceTrack),
    );
  }

  WzListeningHistoryEntry _historySnapshotForManifest(
    CatalogTrackManifest manifest, {
    required WzListeningHistorySource source,
    required String? playableUrl,
  }) =>
      wzHistorySnapshotForManifest(
        manifest,
        source: source,
        playableUrl: playableUrl,
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );

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
    if (entry.lastPositionMs > 0) await _seekTo(entry.lastPositionMs.toDouble());
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
    final exists = wzCollectionContainsTrack(liked, track.trackId);
    final nextCollections = wzToggleCollectionTrack(
      collections: _collections,
      collectionId: liked.id,
      snapshot: _snapshotForTrack(track),
      removeExisting: exists,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
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
    final nextCollections = wzUpsertCollectionTrack(
      collections: _collections,
      collectionId: collection.id,
      snapshot: _snapshotForTrack(track),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistCollections(nextCollections);
  }

  Future<void> _removeTrackFromCollection(WzCollection collection, WzCollectionTrackSnapshot track) async {
    final nextCollections = wzRemoveCollectionTrack(
      collections: _collections,
      collectionId: collection.id,
      trackId: track.trackId,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistCollections(nextCollections);
  }

  Future<void> _renameCollection(WzCollection collection, String name) async {
    if (collection.type == WzCollectionType.liked) return;
    final trimmed = name.trim().isEmpty ? 'My Collection' : name.trim();
    await _persistCollections(wzRenameCollection(
      collections: _collections,
      collectionId: collection.id,
      name: trimmed,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> _deleteCollection(WzCollection collection) async {
    if (collection.type == WzCollectionType.liked) return;
    await _persistCollections(wzDeleteCollection(collections: _collections, collectionId: collection.id));
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
      _selectedTab = WzAppTab.collectionDetail;
    });
  }

  void _openCollection(WzCollection collection) {
    setState(() {
      _selectedCollectionId = collection.id;
      _selectedTab = WzAppTab.collectionDetail;
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
    final mode = await _appModePreferences.load(allowDeveloper: widget.appConfig.showDeveloperEntry);
    if (!mounted) return;
    setState(() {
      _appMode = mode;
      if (_appMode == WzAppMode.consumer && _selectedTab == WzAppTab.engine) _selectedTab = WzAppTab.home;
    });
  }

  Future<void> _setAppMode(WzAppMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    await _appModePreferences.save(mode);
    if (!mounted) return;
    setState(() {
      _appMode = mode;
      if (mode == WzAppMode.consumer && _selectedTab == WzAppTab.engine) _selectedTab = WzAppTab.home;
    });
    messenger.showSnackBar(SnackBar(content: Text(mode == WzAppMode.developer ? 'Developer mode enabled' : 'Consumer mode enabled')));
  }

  Future<void> _toggleAppMode() => _setAppMode(_developerMode ? WzAppMode.consumer : WzAppMode.developer);

  Future<void> _setShuffleEnabled(bool enabled) async {
    await _playbackPreferences.setShuffleEnabled(enabled);
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
    await _playbackPreferences.setRepeatMode(mode);
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
              ...WzSleepTimerPreset.values.map((preset) => ListTile(
                    leading: Icon(preset == WzSleepTimerPreset.off ? Icons.timer_off : Icons.bedtime),
                    title: Text(preset == WzSleepTimerPreset.off ? 'Sleep timer off' : preset.label),
                    trailing: _sleepTimerPreset == preset && (preset == WzSleepTimerPreset.off || _sleepTimerDeadline != null) ? const Icon(Icons.check) : null,
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

  Future<void> _setSleepTimerPreset(WzSleepTimerPreset preset) async {
    await _playbackPreferences.setSleepTimerPreset(preset);
    _sleepTimer?.cancel();
    final duration = preset.duration;
    if (!mounted) return;
    if (duration == null) {
      setState(() {
        _sleepTimerPreset = WzSleepTimerPreset.off;
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
      _sleepTimerPreset = WzSleepTimerPreset.off;
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

  void _navigateTo(WzAppTab tab) {
    if (tab == WzAppTab.engine && !_developerMode) return;
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
    if (!_operationController.tryBegin(PlayerOperation.loadingCatalog)) return;
    setState(() {
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
        _visibleTrackCount = _initialVisibleTrackCount;
        _invalidateCatalogMemos();
        if (scan.tracks.isNotEmpty) _librarySourceFilter = WzLibrarySourceFilter.device;
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
      if (mounted) setState(_operationController.end);
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
      final storedProfile = await _audioEffectPreferences.load();
      if (!mounted) return;
      setState(() {
        _selectedAudioEffectProfile = storedProfile;
        _nativeAudioEffectStatus = storedProfile == AudioEffectProfile.off ? NativeAudioEffectStatus.off : NativeAudioEffectStatus.pending;
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
      _nativeAudioEffectStatus = profile == AudioEffectProfile.off ? NativeAudioEffectStatus.off : NativeAudioEffectStatus.pending;
      _lastAudioEffectApplyResult = profile == AudioEffectProfile.off
          ? 'Turning audio effects off to preserve original playback.'
          : 'Applying ${profile.label} to native playback bridge...';
    });

    if (persist) {
      try {
        await _audioEffectPreferences.save(profile);
      } catch (error) {
        if (mounted) setState(() => _lastAudioEffectApplyResult = 'Effect selected but preference was not persisted: $error');
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
    _librarySearchDebounce?.cancel();
    _fullSearchDebounce?.cancel();
    _poller?.cancel();
    _sleepTimer?.cancel();
    _titleController.dispose();
    _urlController.dispose();
    _apiBaseUrlController.dispose();
    _searchController.dispose();
    _fullSearchController.dispose();
    _cloudSeedTitleController.dispose();
    _cloudSeedArtistController.dispose();
    _cloudSeedUrlController.dispose();
    _cloudSeedProviderController.dispose();
    super.dispose();
  }

  Future<void> _runOperation(PlayerOperation operation, Future<void> Function() body, {bool refreshAfter = true}) async {
    if (!_operationController.tryBegin(operation)) return;
    setState(() => _lastError = null);
    try {
      await body();
      if (refreshAfter) await _refreshMetrics(allowAutoAdvance: false);
    } catch (error) {
      if (mounted) setState(() => _lastError = error.toString());
    } finally {
      if (mounted) setState(_operationController.end);
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
    final existsInLibrary = _catalog.any((track) => track.trackId == trackId) ||
        _cachedLibrary.any((track) => track.trackId == trackId) ||
        _deviceMusicTracks.any((track) => track.trackId == trackId);
    if (!existsInQueue && !existsInLibrary) return;
    _selectedTrackId = trackId;
    if (existsInQueue) _queueCurrentTrackId = trackId;
    if (metrics.lastNotificationAction == 'next' || metrics.lastNotificationAction == 'previous') {
      _queueStatus = 'Notification ${metrics.lastNotificationAction} selected native track $trackId.';
    }
  }

  Future<void> _pushNotificationMetadata(CatalogTrackManifest manifest, {required String url, required String source}) async {
    await widget.playbackBridge.updateMediaNotificationMetadata(NotificationTrackSnapshot.fromManifest(manifest, url: url, source: source));
    await _pushNotificationQueueSnapshot();
  }

  Future<void> _pushNotificationQueueSnapshot() {
    return widget.playbackBridge.updateNotificationQueueSnapshot(
      _queue.take(_initialVisibleTrackCount).map(_notificationSnapshotForQueueTrack).where((track) => track.url.isNotEmpty).toList(growable: false),
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
        _invalidateCatalogMemos();
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
        (metrics.tapToFirstAudioMs != null || metrics.tapToPositionAdvanceMs != null || metrics.currentPositionMs > 0);
    if (_nextTapStartedAtMs != null && _nextTapToAudioMs == null && hasAudioSignal) _nextTapToAudioMs = now - _nextTapStartedAtMs!;
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
    final trigger = evaluateWzAutoAdvanceTrigger(
      enabled: _autoAdvanceEnabled,
      operation: _operation,
      currentPositionMs: metrics.currentPositionMs,
      metricsDurationMs: metrics.durationMs,
      manifestDurationMs: _manifest?.durationMs,
      lastEvent: metrics.lastEvent,
      currentTrackId: _currentQueueTrack?.trackId ?? _queueCurrentTrackId ?? _selectedTrackId,
      lastAutoAdvanceTrackId: _lastAutoAdvanceTrackId,
      thresholdMs: _autoAdvanceThresholdMs,
    );
    if (trigger.clearLastTrackGuard) _lastAutoAdvanceTrackId = null;
    if (!trigger.shouldAdvance) return;
    _lastAutoAdvanceTrackId = trigger.trackId;

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
    if (_repeatMode == WzRepeatMode.all && _queue.isNotEmpty) await _playQueueTrack(_queue.first, autoStart: true, source: QueueAdvanceSource.auto);
  }

  void _recordSmartDownloadSkip(String reason) {
    _lastSmartDownloadReason = reason;
    if (mounted) setState(() => _smartDownloadSkippedCount += 1);
  }

  Future<void> _autoCacheTrack({
    required String trackId,
    required String url,
    required String title,
    String? artistName,
    int? durationMs,
    String? artworkUrl,
    String reason = 'auto',
    String downloadSource = 'unknown',
    String qualityLabel = 'unknown',
    String? codec,
    int? bitrateKbps,
  }) async {
    final preflight = evaluateWzSmartDownloadPreflight(
      enabled: _smartDownloadsEnabled,
      trackId: trackId,
      url: url,
      isDeviceTrack: isWzDeviceTrackId(trackId),
      isDeviceUrl: isWzDeviceUrl(url),
    );
    if (!preflight.allowed) {
      _recordSmartDownloadSkip(preflight.reason!);
      return;
    }

    await _cacheService.ensureInitialized();
    final cacheState = evaluateWzSmartDownloadCacheState(
      status: _cacheService.statusForTrack(trackId),
      alreadyInFlight: _autoCacheInFlight.contains(trackId),
    );
    if (!cacheState.allowed) {
      _recordSmartDownloadSkip(cacheState.reason!);
      return;
    }

    final cachedLibrary = await _cacheService.cachedLibrary();
    final capacity = evaluateWzSmartDownloadCapacity(cachedTrackCount: cachedLibrary.length, maxCachedTracks: _maxSmartDownloadCachedTracks);
    if (!capacity.allowed) {
      _recordSmartDownloadSkip(capacity.reason!);
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
    if (isWzDeviceTrackId(manifest.trackId) || isWzDeviceUrl(manifest.streamUrl)) {
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
    if (isWzDeviceCatalogTrack(next)) {
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
    final client = CatalogClient(baseUrl: _apiBaseUrlController.text);
    try {
      final manifest = await client.fetchTrackManifest(trackId: next.trackId);
      final url2 = manifest.streamUrl;
      if (url2 != null && url2.isNotEmpty) {
        unawaited(_autoCacheTrack(
          trackId: manifest.trackId,
          url: url2,
          title: manifest.title,
          artistName: manifest.artistName,
          durationMs: manifest.durationMs,
          artworkUrl: manifest.artworkUrl,
          reason: 'up_next_fetched',
          downloadSource: 'smart_up_next',
          qualityLabel: manifest.qualityLabel ?? 'unknown',
          codec: manifest.codec,
          bitrateKbps: manifest.bitrateKbps,
        ));
      }
    } catch (_) {
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
        final restored = await _restoreSession(catalog.tracks);
        final preferred = _findTrack(catalog.tracks, restored?.currentTrackId) ??
            _findTrack(catalog.tracks, restored?.selectedTrackId) ??
            _findTrack(catalog.tracks, _selectedTrackId) ??
            (catalog.tracks.isEmpty ? null : catalog.tracks.first);
        final restoredQueue = restored == null ? const <CatalogTrackSummary>[] : resolveWzQueueFromSnapshot(catalogTracks: catalog.tracks, snapshot: restored);
        final startupQueue = restoredQueue.isNotEmpty
            ? restoredQueue.take(_initialVisibleTrackCount).toList(growable: false)
            : (preferred == null ? const <CatalogTrackSummary>[] : <CatalogTrackSummary>[preferred]);
        if (!mounted) return;
        setState(() {
          _catalog = catalog.tracks;
          _catalogTrackIds = catalog.tracks.map((track) => track.trackId).toSet();
          _visibleTrackCount = _initialVisibleTrackCount;
          _filteredTrackCount = catalog.tracks.length;
          _invalidateCatalogMemos();
          _queue = _queue.isEmpty ? startupQueue : _queue;
          if (_queue.isEmpty && preferred != null) _queue = <CatalogTrackSummary>[preferred];
          _selectedTrackId = preferred?.trackId;
          _queueCurrentTrackId = restored?.currentTrackId ?? preferred?.trackId;
          _autoAdvanceEnabled = restored?.autoAdvanceEnabled ?? _autoAdvanceEnabled;
          _contentStatus = contentStatus;
          _catalogStatus = catalog.tracks.isEmpty
              ? 'Catalog is empty.'
              : (catalog.tracks.length > _defaultCatalogLimit
                  ? 'Large demo library loaded. Showing first $_initialVisibleTrackCount tracks.'
                  : contentStatus?.friendlyLabel ?? wzCatalogModeLabel(catalog.contentMode, catalog.tracks.length));
          _queueStatus = restored == null ? 'Queue ready for selected track.' : 'Queue restored from previous session.';
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
            _lastError = null;
            _contentStatus = null;
            _catalog = offlineTracks;
            _catalogTrackIds = offlineTracks.map((track) => track.trackId).toSet();
            _visibleTrackCount = _initialVisibleTrackCount;
            _filteredTrackCount = offlineTracks.length;
            _invalidateCatalogMemos();
            _queue = offlineTracks.take(_initialVisibleTrackCount).toList(growable: false);
            _selectedTrackId = offlineTracks.first.trackId;
            _queueCurrentTrackId = offlineTracks.first.trackId;
            _catalogStatus = 'Catalog unavailable. Showing offline cached library.';
            _queueStatus = 'Offline cache available. Choose a cached track to play.';
            _sessionStatus = '${offlineTracks.length} cached tracks available offline.';
            _offlineCachedTrackCount = offlineLibrary.length;
            _offlineLibraryAvailable = true;
            _offlineLibraryMode = true;
            _lastOfflineLibraryStatus = 'Offline cached library loaded.';
          });
        } else {
          setState(() {
            _lastError = null;
            _catalogStatus = fallbackToDemo ? 'Catalog unavailable. Using local demo track.' : WaveZeroReleaseCopy.catalogUnavailable;
            _contentStatus = null;
            _offlineCachedTrackCount = 0;
            _offlineLibraryAvailable = false;
            _offlineLibraryMode = false;
            _lastOfflineLibraryStatus = 'Offline library empty.';
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
    return sanitizeWzQueueSessionSnapshot(catalogTracks: catalogTracks, snapshot: snapshot);
  }

  int? _elapsedSince(int? startedAtMs) {
    if (startedAtMs == null) return null;
    return DateTime.now().millisecondsSinceEpoch - startedAtMs;
  }

  int _libraryAddedRank(CatalogTrackSummary track) {
    final cached = _cachedMetadataForTrack(track);
    if (cached != null) return cached.cachedAt;
    if (isWzDeviceCatalogTrack(track)) return _deviceMusicImportedAtMs ?? 0;
    return 0;
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

    for (final entry in _listeningHistory) {
      if (entry.trackId != trackId) continue;
      final restored = wzDeviceTrackFromHistory(entry);
      if (restored != null) return restored;
    }
    return null;
  }

  Future<void> _loadDeviceMusicTrack(DeviceMusicTrack track, {bool autoPlay = false, PlayerOperation operation = PlayerOperation.loadingTrack, String? status}) {
    return _runOperation(operation, () async {
      await _clearNativeNextPrebuffer();
      if (!mounted) return;
      final manifest = wzDeviceManifest(track);
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
      if (autoPlay) {
        await widget.playbackBridge.play();
        unawaited(_maybeAutoCacheNextQueuedTrack());
      }
      unawaited(_saveSession());
      unawaited(_updatePredictivePreloadCandidate());
    });
  }

  Future<void> _loadCatalogTrack({String? trackId, bool autoPlay = false, PlayerOperation operation = PlayerOperation.loadingTrack, String? status, CatalogTrackManifest? prefetchedManifest}) {
    unawaited(_saveCurrentHistoryPosition());
    final id = trackId ?? _selectedTrackId ?? (_catalog.isNotEmpty ? _catalog.first.trackId : null);
    if (id == null) return Future<void>.value();
    final deviceTrack = _findDeviceTrack(id);
    if (deviceTrack != null) return _loadDeviceMusicTrack(deviceTrack, autoPlay: autoPlay, operation: operation, status: status);
    CloudVaultTrack? cloudTrack;
    for (final candidate in _cloudVaultTracks) {
      if (candidate.cloudTrackId == id) {
        cloudTrack = candidate;
        break;
      }
    }
    if (cloudTrack != null) return _playCloudVaultTrack(cloudTrack, autoPlay: autoPlay);
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
        if (mounted) setState(() => _catalogStatus = 'Loaded offline cached track: ${manifest.title}');
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
            if (mounted) setState(() => _catalogStatus = 'Loaded offline cached track: ${manifest.title}');
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
    if (mounted && resolvedUrl.startsWith('file://')) setState(() => _currentCachedQuality = cachedMetadata?.qualityLabel ?? 'unknown');
    await widget.playbackBridge.loadTrack(title: manifest.title, url: resolvedUrl);
    final historySource = resolvedUrl.startsWith('file://') ? WzListeningHistorySource.cached : WzListeningHistorySource.api;
    await _pushNotificationMetadata(manifest, url: resolvedUrl, source: historySource.name);
    unawaited(_recordListeningHistory(_historySnapshotForManifest(manifest, source: historySource, playableUrl: resolvedUrl)));
    unawaited(_refreshCacheStats());
    if (autoPlay) await widget.playbackBridge.play();
    if (_nextTapStartedAtMs != null && _queueCurrentTrackId == manifest.trackId) {
      setState(() {
        _nextTapToAudioMs = null;
        _nextPreparedBeforePlay = false;
      });
    }
    unawaited(_updatePredictivePreloadCandidate());
    if (autoPlay || _metrics.isPlaying) {
      unawaited(_maybeAutoCacheCurrentTrack(manifest));
      unawaited(_maybeAutoCacheNextQueuedTrack());
    }
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
        (sameFlutterCandidate && (_prefetchInFlight || (_prefetchedManifest != null && sameNativeCandidate)))) return;

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
        await widget.playbackBridge.prepareNextTrack(trackId: manifest.trackId, title: manifest.title, url: manifest.streamUrl);
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
      await widget.playbackBridge.updateMediaNotificationMetadata(NotificationTrackSnapshot(title: title, artistName: 'WaveZero', url: url, source: 'manual'));
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
    if (!_operationController.tryBegin(PlayerOperation.loadingTrack)) return;
    setState(() {});
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Downloaded ${track.title} (${wzProductQualityLabel(selectedAsset?.qualityLabel ?? 'unknown')})' : 'Download failed for ${track.title}')));
    } finally {
      if (mounted) setState(_operationController.end);
    }
  }

  Future<void> _deleteCachedTrack(CachedTrackMetadata track) async {
    if (_operation != PlayerOperation.idle) return;
    final messenger = ScaffoldMessenger.of(context);
    if (!_operationController.tryBegin(PlayerOperation.loadingCatalog)) return;
    setState(() {});
    try {
      final ok = await _cacheService.deleteCachedTrack(track.trackId);
      _lastCacheDeleteResult = ok ? 'removed:${track.trackId}' : 'remove failed:${track.trackId}';
      await _refreshCacheStats();
      _refreshOfflineLibraryIfNeeded();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(ok ? 'Removed from downloads' : 'Could not remove ${track.title}')));
    } finally {
      if (mounted) setState(_operationController.end);
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
      _catalogTrackIds = offlineTracks.map((track) => track.trackId).toSet();
      _visibleTrackCount = _initialVisibleTrackCount;
      _filteredTrackCount = offlineTracks.length;
      _invalidateCatalogMemos();
      _queue = offlineTracks.take(_initialVisibleTrackCount).toList(growable: false);
      if (!offlineTracks.any((track) => track.trackId == _selectedTrackId)) _selectedTrackId = offlineTracks.isEmpty ? null : offlineTracks.first.trackId;
      if (!offlineTracks.any((track) => track.trackId == _queueCurrentTrackId)) _queueCurrentTrackId = _selectedTrackId;
      _catalogStatus = offlineTracks.isEmpty ? 'Offline library is empty.' : 'Offline cached library refreshed.';
      _queueStatus = offlineTracks.isEmpty ? 'Queue cleared.' : 'Offline cache available. Choose a cached track to play.';
    });
  }

  Future<void> _clearCache() async {
    if (_operation != PlayerOperation.idle) return;
    if (!_operationController.tryBegin(PlayerOperation.loadingCatalog)) return;
    setState(() {});
    try {
      await _cacheService.clearCache();
      _lastCacheDeleteResult = 'storage is clear';
      await _refreshCacheStats();
      _refreshOfflineLibraryIfNeeded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloads cleared')));
    } finally {
      if (mounted) setState(_operationController.end);
    }
  }

  Future<void> _resetMetrics() => _runOperation(PlayerOperation.resettingMetrics, widget.playbackBridge.resetMetrics);

  void _addToQueue(CatalogTrackSummary track) {
    final mutation = addWzQueueTrack(queue: _queue, track: track, currentTrackId: _queueCurrentTrackId);
    setState(() {
      _queue = mutation.queue;
      _queueCurrentTrackId = mutation.currentTrackId;
      _queueStatus = mutation.alreadyPresent ? '${track.title} is already in queue.' : '${track.title} added to queue.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mutation.alreadyPresent ? 'Already in Queue' : 'Added to Queue')));
  }

  void _moveQueueTrack(CatalogTrackSummary track, int delta) {
    if (_queueDisabled) return;
    final mutation = moveWzQueueTrack(queue: _queue, trackId: track.trackId, delta: delta);
    if (!mutation.changed) return;
    setState(() {
      _queue = mutation.queue;
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
    final mutation = moveWzQueueTrackNext(queue: _queue, trackId: track.trackId, resolvedCurrentIndex: _queueIndex, currentTrackId: _queueCurrentTrackId);
    if (!mutation.changed) return;
    setState(() {
      _queue = mutation.queue;
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
    final mutation = removeWzQueueTrack(queue: _queue, trackId: track.trackId, currentTrackId: _queueCurrentTrackId);
    setState(() {
      _queue = mutation.queue;
      _queueCurrentTrackId = mutation.currentTrackId;
      if (_queue.isEmpty) {
        _queueStatus = 'Queue cleared.';
      } else if (mutation.wasCurrent) {
        _queueStatus = 'Removed current track. Queue moved to ${mutation.currentTrack!.title}.';
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
            ? await widget.playbackBridge.playPreparedAutoAdvanceTrackIfReady(trackId: preparedManifest.trackId, title: preparedManifest.title, url: preparedManifest.streamUrl)
            : await widget.playbackBridge.playPreparedNextTrackIfReady(trackId: preparedManifest.trackId, title: preparedManifest.title, url: preparedManifest.streamUrl);
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
        await widget.playbackBridge.recordNextTrackPrebufferOutcome(trackId: track.trackId, usedPreparedPath: false);
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
    unawaited(_recordListeningHistory(_historySnapshotForManifest(manifest, source: historySource, playableUrl: manifest.streamUrl)));
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
    final isDevicePlayback = isWzDeviceTrackId(_manifest?.trackId) || isWzDeviceUrl(_currentAssetUrl);
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
            _navigateTo(WzAppTab.queue);
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
    final isDevicePlayback = isWzDeviceTrackId(_manifest?.trackId) || isWzDeviceUrl(_currentAssetUrl);
    final isPlayingFromCache = !isDevicePlayback && (_currentCachedQuality != null || (_currentAssetUrl?.startsWith('file://') ?? false));
    final effectsSummary = _selectedAudioEffectProfile == AudioEffectProfile.off ? 'Off' : _effectStatusLabel(_nativeAudioEffectStatus);
    final engineSummary = '${_smartDownloadsEnabled ? 'Smart Downloads on' : 'Smart Downloads off'} • '
        '${_prefetchEnabled ? 'Instant Next on' : 'Instant Next off'} • '
        '${_offlineLibraryAvailable ? 'Offline Ready' : 'Offline empty'} • '
        'Library $_libraryCombinedTrackCount • Device ${_deviceMusicTracks.length} • Cached ${_cachedLibrary.length}';

    final pages = <Widget>[
      WzPageScaffold(
        children: [
          WzHomeHero(themeConfig: widget.themeConfig),
          const SizedBox(height: WzSpacing.md),
          if (hasPlayerTrack)
            WzHomeContinueListeningSummary(
              title: _metrics.trackTitle ?? _manifest?.title ?? 'Current track',
              subtitle: _manifest?.subtitle ?? 'Playback continues in the mini player.',
              sourceLabel: isDevicePlayback
                  ? 'Device music'
                  : _playerSourceLabel(isPlayingFromCache: isPlayingFromCache, offlineReady: _offlineLibraryAvailable, hasTrack: hasPlayerTrack),
              isPlaying: _metrics.isPlaying,
              onOpenNow: () => _navigateTo(WzAppTab.now),
            )
          else
            WzHomeCurrentListeningCard(
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
          WzHomeCuratedDemoSection(
            shelves: _resolvedCuratedShelves,
            onPlayPick: (pick) => _loadCatalogTrack(trackId: pick.track.trackId, autoPlay: true, status: 'Loaded WaveZero Pick: ${pick.track.title}'),
            onAddToQueue: (pick) => _addToQueue(pick.track),
            onOpenLibrary: () => _navigateTo(WzAppTab.library),
          ),
          const SizedBox(height: WzSpacing.md),
          WzHomeHistorySection(
            entries: _listeningHistory,
            continueEntry: _continueListeningEntry,
            mostPlayedEntry: _mostPlayedHistoryEntry,
            resolver: _resolveHistoryEntry,
            onPlay: (entry) => unawaited(_playHistoryEntry(entry)),
            onAddToQueue: (entry) => unawaited(_addHistoryEntryToQueue(entry)),
            onAddToCollection: (entry) => unawaited(_addHistoryEntryToCollection(entry)),
            onRemove: (entry) => unawaited(_removeHistoryEntry(entry)),
            onViewAll: () => _navigateTo(WzAppTab.history),
          ),
          const SizedBox(height: WzSpacing.md),
          WzHomeCollectionsOfflineSection(
            collections: _collections,
            offlineTrackCount: _offlineCachedTrackCount,
            cacheBytes: _cacheBytes,
            onOpenCollections: () => _navigateTo(WzAppTab.collections),
            onOpenDownloads: () => _navigateTo(WzAppTab.downloads),
          ),
          const SizedBox(height: WzSpacing.md),
          WzHomeSmartListeningCards(
            smartDownloadsEnabled: _smartDownloadsEnabled,
            smartDownloadsCompleted: _smartDownloadCompletedCount,
            prefetchEnabled: _prefetchEnabled,
            prefetchedTrackTitle: _prefetchedTrackTitle,
            offlineReady: _offlineLibraryAvailable,
            offlineTrackCount: _offlineCachedTrackCount,
            qualityLabel: qualityLabel,
          ),
          const SizedBox(height: WzSpacing.md),
          WzHomeQuickActions(onNavigate: _navigateTo, showDeveloperTools: _developerMode),
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
          const WzPageHeader(icon: Icons.play_circle_fill, title: 'Now Playing', subtitle: 'Your focused player for the current track and queue.'),
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
            onOpenQueue: () => _navigateTo(WzAppTab.queue),
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
          const WzPageHeader(icon: Icons.queue_music, title: 'Queue', subtitle: 'Queue Engine v2 stays intact with cleaner product hierarchy.'),
          const SizedBox(height: WzSpacing.md),
          WzQueuePanel(
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
              onToggle: (v) => setState(() => _smartDownloadsEnabled = v),
            ),
          ],
        ],
      ),
      WzPageScaffold(
        children: [
          const WzPageHeader(icon: Icons.library_music, title: 'Library', subtitle: 'Browse Catalog, Device music, and Downloaded tracks.'),
          const SizedBox(height: WzSpacing.md),
          WzLibraryCatalogPanel(
            tracks: _filteredCatalog,
            totalTrackCount: _libraryTotalTrackCount,
            apiTrackCount: _catalog.length,
            deviceTrackCount: _deviceMusicTracks.length,
            cachedTrackCount: _cachedLibrary.length,
            cloudTrackCount: _cloudVaultTracks.length,
            combinedTrackCount: _libraryCombinedTrackCount,
            visibleTrackCount: _effectiveVisibleTrackCount,
            filteredTrackCount: _filteredTrackCount,
            catalogLimit: _defaultCatalogLimit,
            largeCatalogMode: _largeCatalogMode,
            onLoadMore: _effectiveVisibleTrackCount < _filteredTrackCount
                ? () => setState(() {
                      _visibleTrackCount = math.min(_visibleTrackCount + _libraryPageSize, _filteredTrackCount);
                      _filteredCatalogMemo = null;
                    })
                : null,
            cacheBytes: _cacheBytes,
            curatedPicks: _featuredCuratedPicks,
            selectedTrackId: _selectedTrackId,
            status: _developerMode ? _catalogStatus : wzConsumerCatalogStatus(_catalogStatus),
            loading: _operation == PlayerOperation.loadingCatalog,
            refreshDisabled: _catalogRefreshDisabled,
            addToQueueDisabled: _operation.isTrackLoading || _operation.isQueueAdvancing,
            searchController: _searchController,
            librarySourceFilter: _librarySourceFilter,
            librarySortMode: _librarySortMode,
            devicePermissionStatus: _deviceMusicPermissionStatus.status,
            deviceScanStatus: _deviceMusicScanStatus,
            deviceLastError: _developerMode ? _deviceMusicLastError : wzConsumerDeviceError(_deviceMusicLastError),
            onSourceFilterChanged: (filter) => setState(() {
              _librarySourceFilter = filter;
              _visibleTrackCount = _initialVisibleTrackCount;
              _invalidateCatalogMemos();
            }),
            onSortModeChanged: (mode) => setState(() {
              _librarySortMode = mode;
              _visibleTrackCount = _initialVisibleTrackCount;
              _invalidateCatalogMemos();
            }),
            onClearSearch: () => _searchController.clear(),
            onOpenFullSearch: () => _openSearch(query: _searchController.text),
            onOpenCloudVault: _openCloudVaultPage,
            onRefresh: () => _loadCatalog(),
            onImportDeviceMusic: _importDeviceMusic,
            onSelectTrack: (track) => _loadCatalogTrack(trackId: track.trackId),
            onPlayCuratedPick: (pick) => _loadCatalogTrack(trackId: pick.track.trackId, autoPlay: true, status: 'Loaded featured demo pick: ${pick.track.title}'),
            onAddToQueue: _addToQueue,
            onToggleLike: _toggleLikedTrack,
            onAddToCollection: _showAddToCollectionSheet,
            isLiked: (track) => _isLiked(track.trackId),
            onOpenCollections: () => _navigateTo(WzAppTab.collections),
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
      WzCollectionsPage(
        collections: _collections,
        onBack: () => _navigateTo(WzAppTab.home),
        onOpen: _openCollection,
        onCreate: _createCollectionFromPage,
        onRename: _showRenameCollectionDialog,
        onDelete: _showDeleteCollectionDialog,
      ),
      WzCollectionDetailPage(
        collection: _selectedCollection ?? _likedCollection,
        onBack: () => _navigateTo(WzAppTab.collections),
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
          const WzPageHeader(icon: Icons.download_done, title: 'Downloads', subtitle: 'Offline Ready library with manual and smart cached tracks.'),
          const SizedBox(height: WzSpacing.md),
          WzDownloadsPanel(
            downloads: _cachedLibrary,
            cacheBytes: _cacheBytes,
            controlsDisabled: _queueDisabled,
            onPlay: (track) => _loadCatalogTrack(trackId: track.trackId, autoPlay: true),
            onDelete: _deleteCachedTrack,
            onClearAll: _clearCache,
            onManageStorage: () => _navigateTo(WzAppTab.storage),
          ),
        ],
      ),
      WzStorageManagerPage(
        downloads: _cachedLibrary,
        onBack: () => _navigateTo(WzAppTab.downloads),
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
      WzSearchPage(
        controller: _fullSearchController,
        onBack: () => _navigateTo(WzAppTab.home),
        filter: _searchFilter,
        results: _filteredSearchResults,
        allResultCount: _allSearchResults.length,
        recentSearches: _recentSearches,
        history: _listeningHistory,
        cachedTracks: _cachedCatalogTracks,
        collections: _collections,
        catalogTracks: _searchableCatalogTracks,
        curatedPicks: _featuredCuratedPicks.take(8).toList(growable: false),
        onFilterChanged: (filter) => setState(() {
          _searchFilter = filter;
          _filteredSearchMemo = null;
        }),
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
        onPlayCuratedPick: (pick) => unawaited(_loadCatalogTrack(trackId: pick.track.trackId, autoPlay: true, status: 'Loaded search pick: ${pick.track.title}')),
      ),
      WzListeningHistoryPage(
        entries: _listeningHistory,
        onBack: () => _navigateTo(WzAppTab.home),
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
          const WzPageHeader(icon: Icons.engineering, title: 'Engine diagnostics', subtitle: 'Advanced playback, preload, cache, quality, and effects diagnostics remain available.'),
          const SizedBox(height: WzSpacing.md),
          _DeveloperModePanel(enabled: _developerMode, onChanged: (enabled) => _setAppMode(enabled ? WzAppMode.developer : WzAppMode.consumer)),
          const SizedBox(height: WzSpacing.md),
          const WzSectionHeader(title: 'Content Server', subtitle: 'Developer-only catalog and content status.', icon: Icons.cloud_queue),
          _ContentServerDiagnosticsPanel(
            apiBaseUrl: _apiBaseUrlController.text,
            status: _contentStatus,
            catalogStatus: _catalogStatus,
            catalogTrackCount: _catalog.length,
            visibleTrackCount: _effectiveVisibleTrackCount,
            filteredTrackCount: _filteredTrackCount,
            catalogLimit: _defaultCatalogLimit,
            largeCatalogMode: _largeCatalogMode,
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
            onToggle: (v) => setState(() => _smartDownloadsEnabled = v),
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

    final settingsPage = WzSettingsPage(
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
      deviceLastError: wzConsumerDeviceError(_deviceMusicLastError),
      onImportDeviceMusic: _importDeviceMusic,
      notificationActive: _metrics.isPlaying || (_metrics.trackTitle?.isNotEmpty ?? false),
      appConfig: widget.appConfig,
      contentModeLabel: _contentStatus?.friendlyLabel ?? widget.appConfig.contentModeLabel,
      catalogStatusLabel: _developerMode ? _catalogStatus : wzConsumerCatalogStatus(_catalogStatus),
      showDeveloperEntry: _showDeveloperControls,
      appMode: _appMode,
      onDeveloperModeChanged: (enabled) => _setAppMode(enabled ? WzAppMode.developer : WzAppMode.consumer),
      onOpenEngine: _developerMode ? () => _navigateTo(WzAppTab.engine) : null,
      onManageStorage: () => _navigateTo(WzAppTab.storage),
      cloudVaultCount: _cloudVaultTracks.length,
      onOpenCloudVault: _openCloudVaultPage,
      onClearCloudVault: _cloudVaultTracks.isEmpty ? null : () => unawaited(_clearCloudVaultTracks()),
      listeningHistoryCount: _listeningHistory.length,
      mostPlayedHistoryTitle: _mostPlayedHistoryEntry?.title,
      onOpenHistory: () => _navigateTo(WzAppTab.history),
      onOpenSearch: () => _openSearch(),
      onClearRecentSearches: _recentSearches.isEmpty ? null : () => unawaited(_clearRecentSearches()),
      onClearListeningHistory: _listeningHistory.isEmpty ? null : () => unawaited(_clearListeningHistory()),
      legalTracks: _libraryTracks,
    );

    final destinations = _developerMode ? wzDeveloperShellDestinations : wzConsumerShellDestinations;
    final currentTab = _selectedTab == WzAppTab.engine && !_developerMode ? WzAppTab.home : _selectedTab;
    final currentIndex = destinations.indexWhere((destination) => destination.tab == currentTab);
    final selectedDestination = destinations[currentIndex < 0 ? 0 : currentIndex];
    final selectedTabLabel = switch (_selectedTab) {
      WzAppTab.settings => 'Settings',
      WzAppTab.storage => 'Storage Manager',
      WzAppTab.history => 'Listening History',
      WzAppTab.search => 'Search',
      WzAppTab.collections => 'Collections',
      WzAppTab.collectionDetail => _selectedCollection?.name ?? 'Collection',
      _ => selectedDestination.label,
    };
    final currentPage = switch (currentTab) {
      WzAppTab.home => pages[0],
      WzAppTab.now => pages[1],
      WzAppTab.queue => pages[2],
      WzAppTab.library => pages[3],
      WzAppTab.collections => pages[4],
      WzAppTab.collectionDetail => pages[5],
      WzAppTab.search => pages[8],
      WzAppTab.downloads => pages[6],
      WzAppTab.storage => pages[7],
      WzAppTab.history => pages[9],
      WzAppTab.settings => settingsPage,
      WzAppTab.engine => pages[10],
    };

    return Scaffold(
      backgroundColor: widget.themeConfig.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                WaveZeroProductHeader(
                  selectedTabLabel: selectedTabLabel,
                  status: _statusText,
                  engineSummary: engineSummary,
                  libraryStatus: _consumerLibraryHeaderStatus,
                  libraryStatusActive: _consumerLibraryHeaderActive,
                  libraryStatusWarning: _consumerLibraryHeaderWarning,
                  appMode: _appMode,
                  themeConfig: widget.themeConfig,
                  onLogoLongPress: _toggleAppMode,
                  onOpenSettings: () => _navigateTo(WzAppTab.settings),
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
              items: destinations.map((destination) => BottomNavigationBarItem(icon: Icon(destination.icon), label: destination.label)).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

enum QueueAdvanceSource { manual, next, previous, auto, shuffle }

IconData _searchResultIcon(WzSearchResult result) => switch (result.type) {
      WzSearchResultType.deviceTrack => Icons.phone_android,
      WzSearchResultType.downloadedTrack => Icons.download_done,
      WzSearchResultType.cloudTrack => Icons.cloud_done_outlined,
      WzSearchResultType.collection => Icons.playlist_play,
      WzSearchResultType.historyEntry => Icons.history,
      WzSearchResultType.artistLike => Icons.person,
      WzSearchResultType.track || WzSearchResultType.unknown => Icons.music_note,
    };

String _formatDuration(int ms) {
  final totalSeconds = (ms / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
  static const Color surfacePremium = WzColors.surfacePremium;
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

  static const Duration motionFast = WzMotion.fast;
  static const Duration motionNormal = WzMotion.normal;
  static const Duration motionSlow = WzMotion.slow;
  static const Curve motionCurve = WzMotion.curve;

  static const TextStyle eyebrow = TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6);
  static const TextStyle title = TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3);
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
                Text('WaveZero', style: TextStyle(color: _WzTokens.textPrimary, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
                SizedBox(height: _WzTokens.space1),
                Text('Premium music engine shell for predictive native playback.', style: _WzTokens.body),
              ],
            ),
          ),
          Icon(Icons.graphic_eq, color: _WzTokens.accent),
        ],
      );
}

class _NowContextPanel extends StatelessWidget {
  const _NowContextPanel({required this.qualityLabel, required this.effectsSummary, required this.playingFromCache, required this.devicePlayback, required this.offlineReady, required this.nextTrack, required this.manifest, required this.selectedEffectProfile, required this.nativeAudioEffectStatus, required this.queueIndex, required this.queueLength});
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const WzSectionHeader(title: 'Player context', subtitle: 'Live quality, effects, cache, and queue state.', icon: Icons.dashboard_customize),
      _PlayerSourceCard(icon: Icons.high_quality, title: 'Audio Quality', primary: wzProductQualityLabel(qualityLabel), detail: '$codec • $bitrate', active: qualityLabel != 'unknown'),
      const SizedBox(height: WzSpacing.sm),
      _PlayerSourceCard(icon: Icons.tune, title: 'Audio Effects', primary: selectedEffectProfile.label, detail: 'Native status: ${_effectStatusLabel(nativeAudioEffectStatus)} • Badge: $effectsSummary', active: nativeAudioEffectStatus == NativeAudioEffectStatus.applied),
      const SizedBox(height: WzSpacing.sm),
      _PlayerSourceCard(icon: Icons.offline_pin, title: 'Cache / Offline', primary: devicePlayback ? 'Already local' : playingFromCache ? 'Playing from cache' : offlineReady ? 'Offline Ready' : 'Not cached', detail: devicePlayback ? 'Playing from Device music.' : playingFromCache ? 'Playing from Downloaded music.' : offlineReady ? 'Offline Ready music is available.' : 'No downloaded track is active right now.', active: devicePlayback || playingFromCache || offlineReady),
      const SizedBox(height: WzSpacing.sm),
      _PlayerSourceCard(icon: Icons.queue_music, title: 'Queue', primary: currentPosition, detail: nextTrack == null ? 'No up-next track from Queue Engine v2.' : 'Up next: ${nextTrack!.title}', active: nextTrack != null),
    ]);
  }
}

class _AudioQualityPanel extends StatelessWidget {
  const _AudioQualityPanel({required this.preferredAudioQuality, required this.manifest, required this.currentAssetUrl, required this.currentCachedQuality, required this.lastQualityFallbackReason, required this.controlsDisabled, required this.onSelected});
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
          Wrap(spacing: 8, runSpacing: 8, children: AudioQualityTier.values.map((tier) => ChoiceChip(label: Text(tier.label, maxLines: 1, overflow: TextOverflow.ellipsis), selected: tier == preferredAudioQuality, onSelected: controlsDisabled ? null : (_) => onSelected({tier}))).toList(growable: false)),
          const SizedBox(height: 10),
          Text('Preferred quality: ${wzProductQualityLabel(preferredAudioQuality.label)}', style: _WzTokens.caption),
          Text('Current track quality: ${wzProductQualityLabel(manifest?.qualityLabel ?? 'unknown')}', style: _WzTokens.caption),
          Text('Current codec: ${manifest?.codec ?? 'unknown'}', style: _WzTokens.caption),
          Text('Current bitrate: ${manifest?.bitrateKbps == null ? 'unknown' : '${manifest!.bitrateKbps} kbps'}', style: _WzTokens.caption),
          Text('Current asset URL: ${currentAssetUrl ?? manifest?.streamUrl ?? 'none'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
          Text('Quality fallback reason: $lastQualityFallbackReason', style: _WzTokens.caption),
          Text('Cached quality: ${currentCachedQuality ?? 'not playing from cache'}', style: _WzTokens.caption),
        ]),
      );
}

class _DeviceMusicDiagnosticsPanel extends StatelessWidget {
  const _DeviceMusicDiagnosticsPanel({required this.permissionStatus, required this.platformSupported, required this.importedCount, required this.lastScanStatus, required this.lastError, required this.importedAtMs});
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
  const _LibraryDiagnosticsPanel({required this.selectedSource, required this.filteredResultCount, required this.sortMode, required this.deviceImportCount, required this.cachedLibraryCount});
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
  const _CacheDiagnosticsPanel({required this.cachedTrackCount, required this.cacheBytes, required this.offlineLibraryAvailable, required this.offlineCachedTrackCount, required this.manualDownloadedCount, required this.smartDownloadedCount, required this.lastOfflineLibraryStatus, required this.lastCacheResult, required this.lastCacheDeleteResult, required this.controlsDisabled, required this.onClearCache});
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
          Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: controlsDisabled ? null : () async { await onClearCache(); }, icon: const Icon(Icons.clear_all), label: const Text('Clear cache'))),
        ]),
      );
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.status, required this.detail, required this.operation, required this.refreshingMetrics});
  final String status;
  final String detail;
  final String operation;
  final bool refreshingMetrics;
  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.symmetric(horizontal: _WzTokens.space4, vertical: 14),
        child: Row(children: [
          Icon(refreshingMetrics ? Icons.sync : Icons.radio_button_checked, color: _WzTokens.accent, size: 18),
          const SizedBox(width: _WzTokens.space3),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(status, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: _WzTokens.space1),
            Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
          ])),
          const SizedBox(width: _WzTokens.space2),
          Flexible(child: Text(operation, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: _WzTokens.caption)),
        ]),
      );
}

class _SessionStrip extends StatelessWidget {
  const _SessionStrip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.symmetric(horizontal: _WzTokens.space4, vertical: 10),
        child: Row(children: [
          const Icon(Icons.restore, color: _WzTokens.accent, size: 17),
          const SizedBox(width: 10),
          Expanded(child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption)),
        ]),
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
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF181D33), Color(0xFF070A13)]),
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
                Center(child: Container(width: 46, height: 5, margin: const EdgeInsets.only(bottom: WzSpacing.sm), decoration: BoxDecoration(color: Colors.white.withOpacity(0.28), borderRadius: BorderRadius.circular(999)))),
                Row(children: [
                  const Expanded(child: Text('Now playing', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.eyebrow)),
                  IconButton(tooltip: 'Close player', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.keyboard_arrow_down)),
                ]),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 620;
          final artSize = stacked ? math.min(220.0, constraints.maxWidth) : 280.0;
          final art = _PlayerArtworkHero(artworkUrl: manifest?.artworkUrl, size: artSize, trackId: manifest?.trackId, title: manifest?.title, artist: manifest?.artistName);
          final identity = _NowTrackIdentity(title: title, subtitle: subtitle, status: status);
          if (stacked) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Center(child: art), const SizedBox(height: WzSpacing.xl), identity]);
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [art, const SizedBox(width: WzSpacing.xxl), Expanded(child: identity)]);
        }),
        const SizedBox(height: WzSpacing.lg),
        _PlayerContextBadges(qualityLabel: qualityLabel, effectsSummary: effectsSummary, sourceLabel: sourceLabel, upNextTitle: nextTrack?.title, offlineReady: offlineReady, status: status),
        const SizedBox(height: WzSpacing.xl),
        _PlayerProgressBlock(progressValue: progressValue, displayedPositionMs: displayedPositionMs, durationMs: durationMs, onSeekChanged: onSeekChanged, onSeekEnd: onSeekEnd),
        const SizedBox(height: WzSpacing.xl),
        _PlayerPrimaryControls(isPlaying: metrics.isPlaying, controlsDisabled: controlsDisabled, canPlayPrevious: canPlayPrevious, canPlayNext: canPlayNext, onPlayPause: onPlayPause, onStop: onStop, onRetry: onRetry, onPrevious: onPrevious, onNext: onNext),
        const SizedBox(height: WzSpacing.md),
        _PlaybackModesCard(shuffleEnabled: shuffleEnabled, repeatMode: repeatMode, sleepTimerLabel: sleepTimerLabel, sleepTimerActive: sleepTimerActive, controlsDisabled: controlsDisabled, onShuffleChanged: onShuffleChanged, onCycleRepeatMode: onCycleRepeatMode, onOpenSleepTimer: onOpenSleepTimer),
        const SizedBox(height: WzSpacing.sm),
        Wrap(alignment: WrapAlignment.center, spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
          OutlinedButton.icon(onPressed: canSaveTrack ? onToggleLike : null, icon: Icon(liked ? Icons.favorite : Icons.favorite_border), label: Text(liked ? 'Liked' : 'Like')),
          OutlinedButton.icon(onPressed: canSaveTrack ? onAddToCollection : null, icon: const Icon(Icons.playlist_add), label: const Text('Add to collection')),
          OutlinedButton.icon(onPressed: canSaveTrack ? onAddToQueue : null, icon: const Icon(Icons.queue_music), label: const Text('Add up next')),
          OutlinedButton.icon(onPressed: onOpenQueue, icon: const Icon(Icons.open_in_new), label: const Text('Open queue')),
        ]),
        const SizedBox(height: WzSpacing.lg),
        _PlayerUpNextPreview(nextTrack: nextTrack),
      ]),
    );
  }
}

class _PlaybackModesCard extends StatelessWidget {
  const _PlaybackModesCard({required this.shuffleEnabled, required this.repeatMode, required this.sleepTimerLabel, required this.sleepTimerActive, required this.controlsDisabled, required this.onShuffleChanged, required this.onCycleRepeatMode, required this.onOpenSleepTimer});
  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final String sleepTimerLabel;
  final bool sleepTimerActive;
  final bool controlsDisabled;
  final ValueChanged<bool> onShuffleChanged;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback onOpenSleepTimer;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: _WzTokens.motionNormal,
        curve: _WzTokens.motionCurve,
        padding: const EdgeInsets.all(WzSpacing.sm),
        decoration: BoxDecoration(color: WzColors.surfaceMuted.withOpacity(0.56), borderRadius: BorderRadius.circular(WzRadius.lg), border: Border.all(color: WzColors.borderSoft)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Playback modes', style: WzText.eyebrow),
          const SizedBox(height: WzSpacing.sm),
          Wrap(alignment: WrapAlignment.center, spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
            FilterChip(avatar: const Icon(Icons.shuffle, size: 18), label: Text(shuffleEnabled ? 'Shuffle on' : 'Shuffle'), selected: shuffleEnabled, onSelected: controlsDisabled ? null : onShuffleChanged),
            OutlinedButton.icon(onPressed: controlsDisabled ? null : onCycleRepeatMode, icon: Icon(repeatMode.icon), label: Text(repeatMode.label)),
            OutlinedButton.icon(onPressed: controlsDisabled ? null : onOpenSleepTimer, icon: Icon(sleepTimerActive ? Icons.bedtime : Icons.timer_outlined), label: Text(sleepTimerActive ? sleepTimerLabel : 'Sleep timer')),
          ]),
        ]),
      );
}

class _PlayerArtworkHero extends StatelessWidget {
  const _PlayerArtworkHero({this.artworkUrl, required this.size, this.trackId, this.title, this.artist, this.mood});
  final String? artworkUrl;
  final double size;
  final String? trackId;
  final String? title;
  final String? artist;
  final String? mood;
  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return AnimatedContainer(
      duration: _WzTokens.motionSlow,
      curve: _WzTokens.motionCurve,
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(WzRadius.xl), gradient: WzColors.accentGradient, border: Border.all(color: WzColors.border), boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 36, offset: Offset(0, 24))]),
      child: url == null || url.trim().isEmpty
          ? WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, mood: mood, size: size)
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, mood: mood, size: size)),
    );
  }
}

class _NowTrackIdentity extends StatelessWidget {
  const _NowTrackIdentity({required this.title, required this.subtitle, required this.status});
  final String title;
  final String subtitle;
  final String status;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WzStatusPill(label: status, active: status == 'Playing', icon: status == 'Playing' ? Icons.play_arrow : Icons.pause),
        const SizedBox(height: WzSpacing.md),
        Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.display.copyWith(fontSize: 34)),
        const SizedBox(height: WzSpacing.sm),
        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.body.copyWith(fontSize: 15)),
      ]);
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
  Widget build(BuildContext context) => Wrap(spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
        WzStatusPill(label: status, active: status == 'Playing', icon: status == 'Playing' ? Icons.play_arrow : Icons.pause),
        WzStatusPill(label: 'Quality: ${wzProductQualityLabel(qualityLabel)}', active: qualityLabel != 'unknown', icon: Icons.high_quality),
        WzStatusPill(label: 'Effects: $effectsSummary', active: effectsSummary == 'Applied', warning: effectsSummary == 'Pending' || effectsSummary == 'Failed', icon: Icons.tune),
        WzStatusPill(label: 'Source: $sourceLabel', active: sourceLabel == 'Cache' || sourceLabel == 'Offline Ready' || sourceLabel == 'Device', icon: sourceLabel == 'Device' ? Icons.phone_android : Icons.offline_pin),
        if (offlineReady) const WzStatusPill(label: 'Offline Ready', active: true, icon: Icons.download_done),
        WzStatusPill(label: upNextTitle == null ? 'Up next: none' : 'Up next: $upNextTitle', active: upNextTitle != null, icon: Icons.skip_next),
      ]);
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: WzSpacing.xs, vertical: WzSpacing.xs), decoration: BoxDecoration(color: WzColors.surfaceMuted.withOpacity(0.46), borderRadius: BorderRadius.circular(WzRadius.lg), border: Border.all(color: WzColors.borderSoft)), child: SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 7, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9)), child: Slider(value: progressValue, onChanged: onSeekChanged, onChangeEnd: onSeekEnd))),
      const SizedBox(height: WzSpacing.xs),
      Row(children: [Text(_formatTime(displayedPositionMs), style: WzText.caption.copyWith(color: WzColors.textPrimary)), Expanded(child: Text(durationMs == null ? 'Duration unknown' : '$percent% • -${_formatTime(remainingMs)}', textAlign: TextAlign.center, style: WzText.caption)), Text(_formatTime(durationMs), style: WzText.caption.copyWith(color: WzColors.textPrimary))]),
    ]);
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
  Widget build(BuildContext context) => Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: WzSpacing.md, runSpacing: WzSpacing.sm, children: [
        IconButton.outlined(tooltip: 'Retry', onPressed: controlsDisabled ? null : onRetry, icon: const Icon(Icons.replay)),
        IconButton.filledTonal(tooltip: 'Previous', onPressed: controlsDisabled || !canPlayPrevious ? null : onPrevious, icon: const Icon(Icons.skip_previous), iconSize: 30),
        SizedBox(width: 84, height: 84, child: FilledButton(onPressed: controlsDisabled ? null : onPlayPause, style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: WzColors.accent), child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 44))),
        IconButton.filledTonal(tooltip: 'Next', onPressed: controlsDisabled || !canPlayNext ? null : onNext, icon: const Icon(Icons.skip_next), iconSize: 30),
        IconButton.outlined(tooltip: 'Stop', onPressed: controlsDisabled ? null : onStop, icon: const Icon(Icons.stop)),
        IconButton.outlined(tooltip: 'Retry', onPressed: controlsDisabled ? null : onRetry, icon: const Icon(Icons.replay)),
      ]);
}

class _PlayerUpNextPreview extends StatelessWidget {
  const _PlayerUpNextPreview({required this.nextTrack});
  final CatalogTrackSummary? nextTrack;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(WzSpacing.md),
        decoration: BoxDecoration(color: WzColors.surfaceMuted.withOpacity(0.72), borderRadius: BorderRadius.circular(WzRadius.lg), border: Border.all(color: WzColors.borderSoft)),
        child: Row(children: [
          Icon(Icons.queue_music, color: nextTrack == null ? WzColors.textSubtle : WzColors.accentAlt),
          const SizedBox(width: WzSpacing.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Up next', style: WzText.eyebrow),
            const SizedBox(height: WzSpacing.xxs),
            Text(nextTrack?.title ?? 'Add more tracks to Queue', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
            if (nextTrack != null) Text(nextTrack!.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
          ])),
        ]),
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
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: active ? WzColors.successSoft : WzColors.accentSoft, borderRadius: BorderRadius.circular(WzRadius.md)), child: Icon(icon, color: active ? WzColors.success : WzColors.accent)),
          const SizedBox(width: WzSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: WzText.caption),
            const SizedBox(height: WzSpacing.xxs),
            Text(primary, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
            Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          ])),
        ]),
      );
}

class _PerformanceBaselinePanel extends StatelessWidget {
  const _PerformanceBaselinePanel({required this.metrics, required this.nextTapToAudioMs, required this.prefetchHitCount, required this.prefetchMissCount, required this.stopToPlayRecoveryMs, required this.sessionRecoveryMs, required this.audioPreparedBeforeNext, required this.nextPreparedBeforePlay});
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _PanelHeader(icon: Icons.speed, title: 'Performance Baseline', subtitle: 'Clean session signals for startup, Next handoff, recovery, and playback health.'),
          const SizedBox(height: _WzTokens.space4),
          Wrap(spacing: _WzTokens.space3, runSpacing: _WzTokens.space3, children: [
            _MetricCard(label: 'Tap to audio', value: _formatMetric(metrics.tapToFirstAudioMs), active: metrics.tapToFirstAudioMs != null),
            _MetricCard(label: 'Next to audio', value: _formatMetric(nextTapToAudioMs), active: nextTapToAudioMs != null),
            _MetricCard(label: 'Stop recovery', value: _formatMetric(stopToPlayRecoveryMs), active: stopToPlayRecoveryMs != null),
            _MetricCard(label: 'Session recovery', value: _formatMetric(sessionRecoveryMs), active: sessionRecoveryMs != null),
            _MetricCard(label: 'Playback error', value: metrics.playbackError ?? 'none', active: metrics.playbackError == null),
          ]),
          const SizedBox(height: _WzTokens.space3),
          Text('Hit/miss and prepared handoff detail now lives in Smart Preload. Unavailable values simply mean that flow has not been observed this session.', style: _WzTokens.caption),
        ]),
      );
}

class _AudioEffectsPanel extends StatelessWidget {
  const _AudioEffectsPanel({required this.selectedProfile, required this.nativeStatus, required this.lastApplyResult, required this.preferredAudioQuality, required this.controlsDisabled, required this.onSelected});
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
        Text('Effects may alter original audio. Original/lossless playback stays unchanged unless you explicitly select a profile.', style: _WzTokens.caption),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: AudioEffectProfile.values.map((profile) => ChoiceChip(label: Text(profile.shortLabel), selected: profile == selectedProfile, onSelected: controlsDisabled ? null : (_) => onSelected(profile))).toList(growable: false)),
        const SizedBox(height: 12),
        Text('Selected effect profile: ${selectedProfile.label}', style: _WzTokens.caption),
        Text('Description: ${selectedProfile.description}', style: _WzTokens.caption),
        Text('Profile intensity: ${selectedProfile.safetyLabel}', style: _WzTokens.caption),
        Text('Bass / Mid / Treble / Preamp: ${_formatDb(selectedProfile.bassGainDb)} / ${_formatDb(selectedProfile.midGainDb)} / ${_formatDb(selectedProfile.trebleGainDb)} / ${_formatDb(selectedProfile.preampGainDb)}', style: _WzTokens.caption),
        Text('Native effect status: ${nativeStatus.label}', style: _WzTokens.caption),
        Text('Last effect apply result: $lastApplyResult', style: _WzTokens.caption),
        if (preferredAudioQuality == AudioQualityTier.original && effectsMayAlterOriginalAudio) ...[
          const SizedBox(height: 8),
          Text('Original quality is selected and ${selectedProfile.label} was explicitly enabled by the user; effects may alter original audio.', style: _WzTokens.caption.copyWith(color: _WzTokens.warning)),
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
  const _SmartPreloadCard({required this.metrics, required this.enabled, required this.prefetchedTrackId, required this.prefetchedTrackTitle, required this.prefetchInFlight, required this.manifestPrefetched, required this.audioPreparedBeforeNext, required this.lastPrefetchHit, required this.prefetchHitCount, required this.prefetchMissCount, required this.nextTapToAudioMs, required this.nextPreparedBeforePlay, required this.smartQueueCandidateTrackId, required this.smartQueueReason, required this.controlsDisabled, required this.onToggle});
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: _PanelHeader(icon: Icons.auto_awesome, title: 'Smart Preload', subtitle: 'Predictive manifest, native prebuffer, and prepared handoff signals.')),
          Switch(value: enabled, onChanged: controlsDisabled ? null : onToggle),
        ]),
        const SizedBox(height: _WzTokens.space4),
        _MetricSection(title: 'Smart Queue Policy', description: smartQueueCandidateTrackId == null ? 'No deterministic queue candidate selected' : 'Candidate: $smartQueueCandidateTrackId', metrics: [
          _MetricCard(label: 'smartQueueReason', value: smartQueueReason, active: smartQueueCandidateTrackId != null),
          _MetricCard(label: 'Candidate', value: smartQueueCandidateTrackId ?? 'none', active: smartQueueCandidateTrackId != null),
        ]),
        const SizedBox(height: _WzTokens.space4),
        _MetricSection(title: 'Manifest Prefetch', description: prefetchedTrackTitle ?? 'No manifest candidate yet', metrics: [
          _MetricCard(label: 'Enabled', value: enabled ? 'on' : 'off', active: enabled),
          _MetricCard(label: 'Manifest ready', value: manifestPrefetched ? 'true' : 'false', active: manifestPrefetched),
          _MetricCard(label: 'Last result', value: _prefetchResultLabel(lastPrefetchHit), active: lastPrefetchHit == true),
        ]),
        const SizedBox(height: _WzTokens.space4),
        _MetricSection(title: 'Native Prebuffer', description: metrics.nativePrebufferTrackTitle ?? prefetchedTrackId ?? 'Waiting for the up-next native candidate', metrics: [
          _MetricCard(label: 'nativePrebufferReady', value: metrics.nativePrebufferReady ? 'true' : 'false', active: metrics.nativePrebufferReady),
          _MetricCard(label: metrics.nativePrebufferPrepareMs == null ? 'lastNativePrebufferPrepareMs' : 'nativePrebufferPrepareMs', value: _formatMetric(prepareMs), active: prepareMs != null),
          _MetricCard(label: 'nativePrebufferHit / Miss', value: '${metrics.nativePrebufferHitCount} / ${metrics.nativePrebufferMissCount}', active: metrics.nativePrebufferHitCount > 0),
        ]),
        const SizedBox(height: _WzTokens.space4),
        _MetricSection(title: 'Prepared Handoff', description: metrics.lastNativePrebufferTrackTitle ?? 'Explicit Next and auto-advance prepared handoff telemetry', metrics: [
          _MetricCard(label: 'nativeHandoffToPlayingMs', value: _formatMetric(metrics.nativeHandoffToPlayingMs), active: metrics.nativeHandoffToPlayingMs != null),
          _MetricCard(label: 'nextPreparedBeforePlay', value: nextPreparedBeforePlay ? 'true' : 'false', active: nextPreparedBeforePlay),
          _MetricCard(label: 'auto prepared', value: metrics.autoAdvancePreparedBeforePlay ? 'true' : 'false', active: metrics.autoAdvancePreparedBeforePlay),
        ]),
        const SizedBox(height: _WzTokens.space3),
        Text('Track IDs, in-flight flags, clear reasons, and full counters remain available in Show raw metrics.', style: _WzTokens.caption),
      ]),
    );
  }
}

class _SmartDownloadsCard extends StatelessWidget {
  const _SmartDownloadsCard({required this.enabled, required this.lastTrackId, required this.lastTitle, required this.lastReason, required this.lastResult, required this.startedCount, required this.completedCount, required this.failedCount, required this.skippedCount, required this.inFlight, required this.onToggle});
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
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.all(_WzTokens.space5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(child: _PanelHeader(icon: Icons.download_for_offline, title: 'Smart Downloads', subtitle: 'Predictive background caching for current and up-next tracks.')),
            Switch(value: enabled, onChanged: onToggle),
          ]),
          const SizedBox(height: _WzTokens.space4),
          _MetricSection(title: 'Last Smart Download', description: lastTitle ?? 'No smart downloads yet', metrics: [
            _MetricCard(label: 'Track', value: lastTrackId ?? 'none', active: lastTrackId != null),
            _MetricCard(label: 'Result', value: lastResult ?? 'none', active: lastResult == 'cached'),
            _MetricCard(label: 'Reason', value: lastReason ?? 'none', active: lastReason != null),
          ]),
          const SizedBox(height: _WzTokens.space4),
          _MetricSection(title: 'Counters', description: 'Started / Completed / Failed / Skipped', metrics: [
            _MetricCard(label: 'Started', value: '$startedCount', active: startedCount > 0),
            _MetricCard(label: 'Completed', value: '$completedCount', active: completedCount > 0),
            _MetricCard(label: 'Failed', value: '$failedCount', active: failedCount > 0),
            _MetricCard(label: 'Skipped', value: '$skippedCount', active: skippedCount > 0),
            _MetricCard(label: 'InFlight', value: '$inFlight', active: inFlight > 0),
          ]),
        ]),
      );
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: _WzTokens.accent),
        const SizedBox(width: _WzTokens.space3),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _WzTokens.title),
          const SizedBox(height: _WzTokens.space1),
          Text(subtitle, style: _WzTokens.caption),
        ])),
      ]);
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({required this.title, required this.description, required this.metrics});
  final String title;
  final String description;
  final List<Widget> metrics;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(_WzTokens.space4),
        decoration: BoxDecoration(color: _WzTokens.surfaceMuted, borderRadius: BorderRadius.circular(_WzTokens.radiusLg), border: Border.all(color: _WzTokens.borderSoft)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: _WzTokens.space1),
          Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
          const SizedBox(height: _WzTokens.space3),
          Wrap(spacing: _WzTokens.space3, runSpacing: _WzTokens.space3, children: metrics),
        ]),
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
        decoration: BoxDecoration(color: active ? _WzTokens.successSoft : _WzTokens.surfaceElevated, borderRadius: BorderRadius.circular(_WzTokens.radiusMd), border: Border.all(color: active ? const Color(0x5538D996) : _WzTokens.borderSoft)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
          const SizedBox(height: _WzTokens.space1),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      );
}

String _effectStatusLabel(NativeAudioEffectStatus status) {
  switch (status) {
    case NativeAudioEffectStatus.applied: return 'Applied';
    case NativeAudioEffectStatus.unsupported: return 'Unsupported';
    case NativeAudioEffectStatus.pending: return 'Pending';
    case NativeAudioEffectStatus.failed: return 'Failed';
    case NativeAudioEffectStatus.off: return 'Off';
  }
}

String _playerSourceLabel({required bool isPlayingFromCache, required bool offlineReady, required bool hasTrack}) {
  if (isPlayingFromCache) return 'Downloaded';
  if (hasTrack) return 'Catalog';
  if (offlineReady) return 'Offline Ready';
  return 'Not cached';
}

String _prefetchResultLabel(bool? value) {
  if (value == null) return 'none';
  return value ? 'hit' : 'miss';
}


class _ContentServerDiagnosticsPanel extends StatelessWidget {
  const _ContentServerDiagnosticsPanel({required this.apiBaseUrl, required this.status, required this.catalogStatus, required this.catalogTrackCount, required this.visibleTrackCount, required this.filteredTrackCount, required this.catalogLimit, required this.largeCatalogMode});
  final String apiBaseUrl;
  final ContentStatus? status;
  final String catalogStatus;
  final int catalogTrackCount;
  final int visibleTrackCount;
  final int filteredTrackCount;
  final int catalogLimit;
  final bool largeCatalogMode;
  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          _MetricCard(label: 'Catalog', value: status?.friendlyLabel ?? catalogStatus, active: status?.ok ?? catalogTrackCount > 0),
          _MetricCard(label: 'Mode', value: status?.contentMode ?? 'unknown', active: status?.contentMode == 'production' || status?.contentMode == 'demo'),
          _MetricCard(label: 'Tracks', value: '${status?.trackCount ?? catalogTrackCount}', active: (status?.trackCount ?? catalogTrackCount) > 0),
          _MetricCard(label: 'Visible', value: '$visibleTrackCount', active: visibleTrackCount > 0),
          _MetricCard(label: 'Filtered', value: '$filteredTrackCount', active: filteredTrackCount > 0),
          _MetricCard(label: 'Catalog limit', value: '$catalogLimit', active: largeCatalogMode),
          _MetricCard(label: 'Large catalog mode', value: largeCatalogMode ? 'enabled' : 'disabled', active: largeCatalogMode),
          _MetricCard(label: 'Assets', value: '${status?.assetCount ?? 0}', active: (status?.assetCount ?? 0) > 0),
          _MetricCard(label: 'Production-safe', value: '${status?.productionSafeTrackCount ?? 0}', active: (status?.productionSafeTrackCount ?? 0) > 0),
          _MetricCard(label: 'Local folder', value: status?.localFolderCatalogEnabled == true ? 'enabled' : 'disabled', active: status?.localFolderCatalogEnabled == true),
        ]),
        const SizedBox(height: 10),
        Text('API base URL: $apiBaseUrl', style: _WzTokens.caption),
        Text('catalogTrackCount=$catalogTrackCount • visibleTrackCount=$visibleTrackCount • filteredTrackCount=$filteredTrackCount • catalogLimit=$catalogLimit • largeCatalogMode=${largeCatalogMode ? 'enabled' : 'disabled'}', style: _WzTokens.caption),
        Text(status?.developerSummary ?? catalogStatus, style: _WzTokens.caption),
      ]),
    );
  }
}

class _TrackSetupCard extends StatelessWidget {
  const _TrackSetupCard({required this.titleController, required this.urlController, required this.apiBaseUrlController, required this.catalogStatus, required this.loading, required this.onLoadCatalog, required this.onLoadTrack});
  final TextEditingController titleController;
  final TextEditingController urlController;
  final TextEditingController apiBaseUrlController;
  final String catalogStatus;
  final bool loading;
  final VoidCallback onLoadCatalog;
  final VoidCallback onLoadTrack;
  @override
  Widget build(BuildContext context) => _Panel(child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Manual / API setup'),
        subtitle: Text(catalogStatus, maxLines: 2, overflow: TextOverflow.ellipsis),
        children: [
          TextField(controller: apiBaseUrlController, decoration: const InputDecoration(labelText: 'API base URL')),
          const SizedBox(height: 12),
          TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Manual title')),
          const SizedBox(height: 12),
          TextField(controller: urlController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Manual audio URL')),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.tonalIcon(onPressed: loading ? null : onLoadCatalog, icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_download), label: const Text('Reload selected/API')),
            OutlinedButton.icon(onPressed: loading ? null : onLoadTrack, icon: const Icon(Icons.bolt), label: const Text('Load manual track')),
          ]),
        ],
      ));
}

class _HealthStrip extends StatelessWidget {
  const _HealthStrip({required this.metrics});
  final PlaybackMetrics metrics;
  @override
  Widget build(BuildContext context) => Wrap(spacing: _WzTokens.space3, runSpacing: _WzTokens.space3, children: [
        _MetricCard(label: 'Tap to audio', value: _formatMetric(metrics.tapToFirstAudioMs), active: metrics.tapToFirstAudioMs != null && metrics.tapToFirstAudioMs! < 800),
        _MetricCard(label: 'Ready', value: _formatMetric(metrics.loadToReadyMs), active: metrics.preparedBeforePlay),
        _MetricCard(label: 'Rebuffers', value: metrics.rebufferCount.toString(), active: metrics.rebufferCount == 0),
        _MetricCard(label: 'Error', value: metrics.playbackError == null ? 'none' : 'check', active: metrics.playbackError == null),
      ]);
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
  Widget build(BuildContext context) => _Panel(child: SwitchListTile(value: enabled, onChanged: onChanged, secondary: const Icon(Icons.admin_panel_settings), title: const Text('Internal developer mode'), subtitle: const Text('Turn off to return to the consumer music shell.')));
}

class _MetricsToggle extends StatelessWidget {
  const _MetricsToggle({required this.showMetrics, required this.operationBusy, required this.onToggle, required this.onCopyMetrics, required this.onResetMetrics});
  final bool showMetrics;
  final bool operationBusy;
  final VoidCallback onToggle;
  final VoidCallback onCopyMetrics;
  final VoidCallback onResetMetrics;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: onToggle, icon: Icon(showMetrics ? Icons.expand_less : Icons.analytics_outlined), label: Text(showMetrics ? 'Hide raw metrics' : 'Show raw metrics'))),
        const SizedBox(width: 10),
        IconButton.outlined(onPressed: operationBusy ? null : onCopyMetrics, icon: const Icon(Icons.copy), tooltip: 'Copy metrics'),
        const SizedBox(width: 10),
        IconButton.outlined(onPressed: operationBusy ? null : onResetMetrics, icon: const Icon(Icons.restart_alt), tooltip: 'Reset metrics'),
      ]);
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.metrics});
  final PlaybackMetrics metrics;
  @override
  Widget build(BuildContext context) => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _PanelHeader(icon: Icons.data_object, title: 'Raw metrics', subtitle: 'Complete developer telemetry without changing metric names or meaning.'),
        const SizedBox(height: _WzTokens.space4),
        SelectableText(metrics.toDisplayText(), style: const TextStyle(color: Color(0xFFD7DDF0), fontFamily: 'monospace', height: 1.45)),
      ]));
}

class _PremiumMiniPlayer extends StatelessWidget {
  const _PremiumMiniPlayer({required this.metrics, required this.manifest, required this.progressValue, required this.sourceLabel, required this.offlineReady, required this.shuffleEnabled, required this.repeatMode, required this.sleepTimerBadge, required this.controlsDisabled, required this.onTap, required this.onPlayPause});
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
          child: AnimatedContainer(
            duration: _WzTokens.motionSlow,
            curve: _WzTokens.motionCurve,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xEE20263F), Color(0xEE0A0D18)]), borderRadius: BorderRadius.circular(WzRadius.xl), border: Border.all(color: WzColors.borderSoft), boxShadow: const [BoxShadow(color: Color(0x77000000), blurRadius: 24, offset: Offset(0, 12))]),
            child: Row(children: [
              _MiniArtwork(artworkUrl: manifest?.artworkUrl, trackId: manifest?.trackId, title: manifest?.title, artist: manifest?.artistName),
              const SizedBox(width: WzSpacing.sm),
              Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xxs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14))),
                  _MiniBadge(label: sourceLabel),
                  if (offlineReady) const _MiniBadge(label: 'Offline Ready'),
                  if (shuffleEnabled) const _MiniBadge(label: 'Shuffle'),
                  if (repeatMode != WzRepeatMode.off) _MiniBadge(label: repeatMode == WzRepeatMode.one ? 'Repeat 1' : 'Repeat all'),
                  if (sleepTimerBadge != null) _MiniBadge(label: sleepTimerBadge!),
                ]),
                const SizedBox(height: WzSpacing.xxs),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: progressValue.clamp(0.0, 1.0), minHeight: 3, backgroundColor: Colors.white.withOpacity(0.10), valueColor: const AlwaysStoppedAnimation<Color>(WzColors.accentAlt))),
              ])),
              const SizedBox(width: WzSpacing.xs),
              IconButton.filled(tooltip: metrics.isPlaying ? 'Pause' : 'Play', onPressed: controlsDisabled ? null : onPlayPause, icon: Icon(metrics.isPlaying ? Icons.pause : Icons.play_arrow)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({this.artworkUrl, this.trackId, this.title, this.artist, this.mood});
  final String? artworkUrl;
  final String? trackId;
  final String? title;
  final String? artist;
  final String? mood;
  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: WzColors.accentGradient, borderRadius: BorderRadius.circular(WzRadius.md), border: Border.all(color: Colors.white.withOpacity(0.16))),
      child: url == null || url.trim().isEmpty
          ? WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, mood: mood, size: 48, compact: true)
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, mood: mood, size: 48, compact: true)),
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
        decoration: BoxDecoration(color: _WzTokens.surface, borderRadius: BorderRadius.circular(_WzTokens.radiusXl), border: Border.all(color: _WzTokens.border), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 18))]),
        child: Padding(padding: padding, child: child),
      );
}

CatalogTrackSummary? _findTrack(List<CatalogTrackSummary> tracks, String? trackId) { if (trackId == null) return null; for (final track in tracks) { if (track.trackId == trackId) return track; } return null; }
String _statusFromEvent(String? event) { switch (event) { case 'track_loaded': case 'buffering_started': return 'Preparing'; case 'ready': case 'buffering_ended': case 'manifest_loaded': return 'Ready'; case 'not_playing': return 'Paused'; case 'stopped': return 'Paused'; case 'ended': case 'playback_ended': return 'Ended'; default: return 'Ready'; } }
String _formatMetric(int? valueMs) => valueMs == null ? '—' : '${valueMs}ms';
String _formatTime(int? valueMs) { if (valueMs == null || valueMs < 0) return '—:—'; final totalSeconds = (valueMs / 1000).floor(); final minutes = totalSeconds ~/ 60; final seconds = totalSeconds % 60; return '$minutes:${seconds.toString().padLeft(2, '0')}'; }
const _timeStyle = TextStyle(color: Color(0xFF9BA3B4), fontSize: 12);
