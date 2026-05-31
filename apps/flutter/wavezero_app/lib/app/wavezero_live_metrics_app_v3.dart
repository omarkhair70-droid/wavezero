import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_effects.dart';
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
import 'player_operation_state.dart';
import 'queue_session_store.dart';
import 'smart_queue_policy.dart';

enum _AppMode { consumer, developer }

enum _AppTab { home, library, now, queue, collections, collectionDetail, downloads, storage, settings, engine }

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

String _friendlyLoadError(String error) {
  final normalized = error.toLowerCase();
  if (normalized.contains('permission')) return 'Device music permission is needed to import local songs.';
  if (normalized.contains('socketexception') || normalized.contains('connection') || normalized.contains('http')) {
    return 'Couldn’t load music right now. Check your connection and try again.';
  }
  return 'Couldn’t load music right now.';
}

String _consumerCatalogStatus(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('error') || normalized.contains('exception') || normalized.contains('failed')) {
    return 'Couldn’t load music right now. Check your connection and try again.';
  }
  if (normalized.contains('permission')) return 'Device music permission is needed to import local songs.';
  if (normalized.contains('loaded') || normalized.contains('imported')) return status;
  if (normalized.contains('offline')) return status;
  return 'Choose music from your library.';
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
    required this.themeConfig,
    required this.onThemeConfigChanged,
  });

  final PlaybackBridge playbackBridge;
  final QueueSessionStore sessionStore;
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

  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _searchController;

  Timer? _poller;
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
  String _catalogQuery = '';
  String _catalogStatus = 'Catalog not loaded yet.';
  String _queueStatus = 'Queue is ready.';
  String _sessionStatus = 'Session recovery pending.';

  final CollectionsService _collectionsService = CollectionsService();
  List<WzCollection> _collections = <WzCollection>[WzCollection.liked()];
  String? _selectedCollectionId = likedTracksCollectionId;

  WzCollection get _likedCollection => _collections.firstWhere(
        (collection) => collection.type == WzCollectionType.liked,
        orElse: () => WzCollection.liked(),
      );

  List<WzCollection> get _userCollections => _collections.where((collection) => collection.type == WzCollectionType.user).toList(growable: false);

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
  bool get _playerDisabled => _operation.disablesPlayerControls;
  bool get _catalogRefreshDisabled => _operation.disablesCatalogRefresh;
  bool get _queueDisabled => _operation.disablesQueueControls;
  bool get _manualDisabled => _operation.disablesManualTrackControls;
  bool get _developerMode => _appMode == _AppMode.developer;

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
    _apiBaseUrlController = TextEditingController(text: CatalogClient.defaultBaseUrl);
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (mounted) setState(() => _catalogQuery = _searchController.text);
    });
    _poller = Timer.periodic(_refreshInterval, (_) => _refreshMetrics());
    _loadCatalog(fallbackToDemo: true);
    unawaited(_initCache());
    unawaited(_initAudioEffects());
    unawaited(_refreshDeviceMusicPermissionStatus());
    unawaited(_loadAppMode());
    unawaited(_loadCollections());
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exists ? 'Removed from Liked Tracks' : 'Added to Liked Tracks')));
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to New Collection')));
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
      _appMode = savedMode == _AppMode.developer.name ? _AppMode.developer : _AppMode.consumer;
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
    _titleController.dispose();
    _urlController.dispose();
    _apiBaseUrlController.dispose();
    _searchController.dispose();
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
    if (!_autoAdvanceEnabled || _operation != PlayerOperation.idle || !_canNext) return;
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
    await _playNext(autoStart: true, source: QueueAdvanceSource.auto);
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
        final catalog = await client.fetchCatalog();
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
          _catalogStatus = catalog.tracks.isEmpty ? 'Catalog API returned no tracks.' : 'Loaded ${catalog.tracks.length} catalog tracks.';
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
            _catalog = offlineTracks;
            _queue = offlineTracks;
            _selectedTrackId = offlineTracks.first.trackId;
            _queueCurrentTrackId = offlineTracks.first.trackId;
            _catalogStatus = 'Catalog unavailable. Showing offline cached library. $error';
            _queueStatus = 'Offline cache available. Choose a cached track to play.';
            _sessionStatus = '${offlineTracks.length} cached tracks available offline.';
            _offlineCachedTrackCount = offlineLibrary.length;
            _offlineLibraryAvailable = true;
            _offlineLibraryMode = true;
            _lastOfflineLibraryStatus = 'Offline cached library loaded.';
          });
        } else {
          setState(() {
            _lastError = error.toString();
            _catalogStatus = fallbackToDemo ? 'Catalog unavailable. Using local demo track. $error' : 'Catalog load failed. $error';
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
      if (autoPlay) await widget.playbackBridge.play();
      unawaited(_saveSession());
      unawaited(_updatePredictivePreloadCandidate());
      unawaited(_maybeAutoCacheNextQueuedTrack());
    });
  }

  Future<void> _loadCatalogTrack({String? trackId, bool autoPlay = false, PlayerOperation operation = PlayerOperation.loadingTrack, String? status, CatalogTrackManifest? prefetchedManifest}) {
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
    await _pushNotificationMetadata(manifest, url: resolvedUrl, source: resolvedUrl.startsWith('file://') ? 'cached' : 'api');
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
  Future<void> _seekTo(double positionMs) => _runOperation(PlayerOperation.seeking, () => widget.playbackBridge.seekTo(positionMs.round()));

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No downloadable asset URL available for this track')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage is clear')));
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
    await _pushNotificationMetadata(manifest, url: manifest.streamUrl, source: manifest.streamUrl.startsWith('file://') ? 'cached' : 'api');
    await _refreshMetrics(allowAutoAdvance: false);
    unawaited(_saveSession());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheCurrentTrack(manifest));
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }

  Future<void> _playNext({bool autoStart = false, QueueAdvanceSource source = QueueAdvanceSource.next}) async {
    final index = _queueIndex;
    if (index < 0 || index >= _queue.length - 1) return;
    await _playQueueTrack(_queue[index + 1], autoStart: autoStart, source: source);
  }

  Future<void> _playPrevious({bool autoStart = false}) async {
    final index = _queueIndex;
    if (index <= 0) return;
    await _playQueueTrack(_queue[index - 1], autoStart: autoStart, source: QueueAdvanceSource.previous);
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
            subtitle: 'A premium playback screen powered only by live engine state.',
          ),
          const SizedBox(height: WzSpacing.md),
          _NowPlayingCard(
            metrics: _metrics,
            manifest: _manifest,
            nextTrack: _upNextQueueTrack,
            qualityLabel: nowQualityLabel,
            effectsSummary: effectsSummary,
            sourceLabel: isDevicePlayback ? 'Device' : _playerSourceLabel(isPlayingFromCache: isPlayingFromCache, offlineReady: _offlineLibraryAvailable, hasTrack: hasPlayerTrack),
            progressValue: progress,
            displayedPositionMs: displayedPositionMs,
            durationMs: durationMs,
            controlsDisabled: _playerDisabled,
            canPlayPrevious: _canPrevious,
            canPlayNext: _canNext,
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
            subtitle: 'Browse catalog tracks, select playback assets, and manage local cache.',
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
          if (_developerMode) ...[
            const SizedBox(height: WzSpacing.md),
            _TrackSetupCard(titleController: _titleController, urlController: _urlController, apiBaseUrlController: _apiBaseUrlController, catalogStatus: _catalogStatus, loading: _manualDisabled, onLoadCatalog: () => _loadCatalogTrack(), onLoadTrack: _loadManualTrack),
          ],
        ],
      ),
      _CollectionsPage(
        collections: _collections,
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
          const WzSectionHeader(title: 'Device Music', subtitle: 'Android MediaStore import diagnostics.', icon: Icons.perm_media),
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
      appMode: _appMode,
      onDeveloperModeChanged: (enabled) => _setAppMode(enabled ? _AppMode.developer : _AppMode.consumer),
      onOpenEngine: _developerMode ? () => _navigateTo(_AppTab.engine) : null,
      onManageStorage: () => _navigateTo(_AppTab.storage),
      legalTracks: _libraryTracks,
    );

    final destinations = _developerMode ? _developerShellDestinations : _consumerShellDestinations;
    final currentTab = _selectedTab == _AppTab.engine && !_developerMode ? _AppTab.home : _selectedTab;
    final currentIndex = destinations.indexWhere((destination) => destination.tab == currentTab);
    final selectedDestination = destinations[currentIndex < 0 ? 0 : currentIndex];
    final selectedTabLabel = switch (_selectedTab) {
      _AppTab.settings => 'Settings',
      _AppTab.storage => 'Storage Manager',
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
      _AppTab.downloads => pages[6],
      _AppTab.storage => pages[7],
      _AppTab.settings => settingsPage,
      _AppTab.engine => pages[8],
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
            BottomNavigationBar(
              currentIndex: currentIndex < 0 ? 0 : currentIndex,
              onTap: (i) => _navigateTo(destinations[i].tab),
              backgroundColor: widget.themeConfig.surfaceMuted,
              selectedItemColor: widget.themeConfig.accent,
              unselectedItemColor: _WzTokens.textMuted,
              type: BottomNavigationBarType.fixed,
              items: destinations
                  .map((destination) => BottomNavigationBarItem(
                        icon: Icon(destination.icon),
                        label: destination.label,
                      ))
                  .toList(growable: false),
            ),
            const Divider(height: 1, color: _WzTokens.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: _MiniPlayer(metrics: _metrics, manifest: _manifest),
            ),
          ],
        ),
      ),
    );
  }
}

enum QueueAdvanceSource { manual, next, previous, auto }

enum _LibrarySourceFilter { all, api, device, downloads }

extension _LibrarySourceFilterLabel on _LibrarySourceFilter {
  String get label => switch (this) {
        _LibrarySourceFilter.all => 'All',
        _LibrarySourceFilter.api => 'API Catalog',
        _LibrarySourceFilter.device => 'Device Music',
        _LibrarySourceFilter.downloads => 'Downloads / Cached',
      };
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
    required this.appMode,
    required this.onDeveloperModeChanged,
    required this.onOpenEngine,
    required this.onManageStorage,
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
  final _AppMode appMode;
  final ValueChanged<bool> onDeveloperModeChanged;
  final VoidCallback? onOpenEngine;
  final VoidCallback onManageStorage;
  final List<CatalogTrackSummary> legalTracks;

  @override
  Widget build(BuildContext context) => WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'Customize WaveZero and manage user-facing playback, storage, device music, and app mode preferences.',
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
          const WzSectionHeader(title: 'Playback', subtitle: 'User-friendly quality and effect preferences.', icon: Icons.graphic_eq),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
          const WzSectionHeader(title: 'Downloads & Storage', subtitle: 'Downloaded and cached-for-offline music on this device.', icon: Icons.offline_pin),
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
          const WzSectionHeader(title: 'Device Music', subtitle: 'Local Android MediaStore import status.', icon: Icons.perm_media),
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
                if (deviceLastError != null) Text('Last message: $deviceLastError', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
                const SizedBox(height: WzSpacing.md),
                Wrap(
                  spacing: WzSpacing.sm,
                  runSpacing: WzSpacing.sm,
                  children: [
                    WzPrimaryAction(label: 'Import Device Music', icon: Icons.library_add, onPressed: controlsDisabled ? null : () => unawaited(onImportDeviceMusic())),
                    OutlinedButton.icon(onPressed: controlsDisabled ? null : () => unawaited(onImportDeviceMusic()), icon: const Icon(Icons.refresh), label: const Text('Rescan Device Music')),
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
          const WzSectionHeader(title: 'About', subtitle: 'WaveZero app information.', icon: Icons.info_outline),
          WzPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('WaveZero', style: WzText.title),
                const SizedBox(height: WzSpacing.xs),
                const Text('A smart music experience engine for native playback, offline listening, queue intelligence, and premium now-playing UX.', style: WzText.body),
                const SizedBox(height: WzSpacing.xs),
                const Text('Version/build: 0.1.0+1', style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                const Text('WaveZero does not claim rights for local/device files. Production catalog tracks require verified rights metadata.', style: WzText.caption),
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
              if (devicePlayback) const WzStatusPill(label: 'Source: Device', active: true, icon: Icons.phone_android),
              if (playingFromCache) const WzStatusPill(label: 'Playing from cache', active: true, icon: Icons.offline_pin),
              if (offlineReady) const WzStatusPill(label: 'Offline Ready', active: true, icon: Icons.download_done),
              WzStatusPill(label: 'Device Library: $deviceTrackCount', active: deviceTrackCount > 0, icon: Icons.perm_media),
              WzStatusPill(label: 'Permission: $devicePermissionStatus', active: devicePermissionStatus == 'granted', warning: devicePermissionStatus.contains('denied'), icon: Icons.privacy_tip),
            ],
          ),
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
            const WzSectionHeader(title: 'Smart engine', subtitle: 'Product-facing summary of engine foundations.', icon: Icons.auto_awesome),
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
            const WzSectionHeader(title: 'Quick actions', subtitle: 'Jump into the core WaveZero workflows.', icon: Icons.bolt),
            Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzPrimaryAction(label: 'Go to Library', icon: Icons.library_music, onPressed: () => onNavigate(_AppTab.library)),
                WzPrimaryAction(label: 'Collections', icon: Icons.playlist_play, onPressed: () => onNavigate(_AppTab.collections)),
                WzPrimaryAction(label: 'Go to Now', icon: Icons.play_circle_fill, onPressed: () => onNavigate(_AppTab.now)),
                WzPrimaryAction(label: 'Go to Queue', icon: Icons.queue_music, onPressed: () => onNavigate(_AppTab.queue)),
                WzPrimaryAction(label: 'Go to Downloads', icon: Icons.download_done, onPressed: () => onNavigate(_AppTab.downloads)),
                WzPrimaryAction(label: 'Settings', icon: Icons.settings, onPressed: () => onNavigate(_AppTab.settings)),
                if (showDeveloperTools) WzPrimaryAction(label: 'Go to Engine', icon: Icons.engineering, onPressed: () => onNavigate(_AppTab.engine)),
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
          detail: devicePlayback ? 'Source: Device. The active asset is streamed directly from its MediaStore content URI.' : playingFromCache ? 'The active asset is a local cached file.' : offlineReady ? 'Cached library exists; current playback is not marked as cache.' : 'No cached library state is active for this player context.',
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

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({
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
              final art = _NowHeroArtwork(artworkUrl: manifest?.artworkUrl, size: artSize);
              final identity = _NowTrackIdentity(title: title, subtitle: subtitle, status: status);
              if (stacked) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Center(child: art), const SizedBox(height: WzSpacing.xl), identity]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [art, const SizedBox(width: WzSpacing.xxl), Expanded(child: identity)]);
            },
          ),
          const SizedBox(height: WzSpacing.lg),
          _NowPlaybackBadges(qualityLabel: qualityLabel, effectsSummary: effectsSummary, sourceLabel: sourceLabel, upNextTitle: nextTrack?.title),
          const SizedBox(height: WzSpacing.xl),
          _NowProgressSection(progressValue: progressValue, displayedPositionMs: displayedPositionMs, durationMs: durationMs, onSeekChanged: onSeekChanged, onSeekEnd: onSeekEnd),
          const SizedBox(height: WzSpacing.xl),
          _NowActionRow(isPlaying: metrics.isPlaying, controlsDisabled: controlsDisabled, canPlayPrevious: canPlayPrevious, canPlayNext: canPlayNext, onPlayPause: onPlayPause, onStop: onStop, onRetry: onRetry, onPrevious: onPrevious, onNext: onNext),
          const SizedBox(height: WzSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            children: [
              OutlinedButton.icon(onPressed: canSaveTrack ? onToggleLike : null, icon: Icon(liked ? Icons.favorite : Icons.favorite_border), label: Text(liked ? 'Liked' : 'Like')),
              OutlinedButton.icon(onPressed: canSaveTrack ? onAddToCollection : null, icon: const Icon(Icons.playlist_add), label: const Text('Add to collection')),
            ],
          ),
          const SizedBox(height: WzSpacing.lg),
          _UpNextPreviewCard(nextTrack: nextTrack),
        ],
      ),
    );
  }
}

class _NowHeroArtwork extends StatelessWidget {
  const _NowHeroArtwork({this.artworkUrl, required this.size});

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

class _NowPlaybackBadges extends StatelessWidget {
  const _NowPlaybackBadges({required this.qualityLabel, required this.effectsSummary, required this.sourceLabel, required this.upNextTitle});

  final String qualityLabel;
  final String effectsSummary;
  final String sourceLabel;
  final String? upNextTitle;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: WzSpacing.sm,
        runSpacing: WzSpacing.sm,
        children: [
          WzStatusPill(label: 'Quality: ${_productQualityLabel(qualityLabel)}', active: qualityLabel != 'unknown', icon: Icons.high_quality),
          WzStatusPill(label: 'Effects: $effectsSummary', active: effectsSummary == 'Applied', warning: effectsSummary == 'Pending' || effectsSummary == 'Failed', icon: Icons.tune),
          WzStatusPill(label: 'Source: $sourceLabel', active: sourceLabel == 'Cache' || sourceLabel == 'Offline Ready', icon: Icons.offline_pin),
          WzStatusPill(label: upNextTitle == null ? 'Up next: none' : 'Up next: $upNextTitle', active: upNextTitle != null, icon: Icons.skip_next),
        ],
      );
}

class _NowProgressSection extends StatelessWidget {
  const _NowProgressSection({required this.progressValue, required this.displayedPositionMs, required this.durationMs, required this.onSeekChanged, required this.onSeekEnd});

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

class _NowActionRow extends StatelessWidget {
  const _NowActionRow({required this.isPlaying, required this.controlsDisabled, required this.canPlayPrevious, required this.canPlayNext, required this.onPlayPause, required this.onStop, required this.onRetry, required this.onPrevious, required this.onNext});

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

class _UpNextPreviewCard extends StatelessWidget {
  const _UpNextPreviewCard({required this.nextTrack});

  final CatalogTrackSummary? nextTrack;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(WzSpacing.md),
        decoration: BoxDecoration(color: WzColors.surfaceMuted.withOpacity(0.72), borderRadius: BorderRadius.circular(WzRadius.lg), border: Border.all(color: WzColors.borderSoft)),
        child: Row(
          children: [
            Icon(Icons.queue_music, color: nextTrack == null ? WzColors.textSubtle : WzColors.accentAlt),
            const SizedBox(width: WzSpacing.sm),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Up next', style: WzText.eyebrow), const SizedBox(height: WzSpacing.xxs), Text(nextTrack?.title ?? 'Add more tracks to Queue for continuous playback.', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle), if (nextTrack != null) Text(nextTrack!.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption)])),
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
  if (isPlayingFromCache) return 'Cache';
  if (hasTrack) return 'Remote';
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
            const _EmptyCatalogMessage(message: 'Queue is empty. Add tracks from the catalog.')
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
        const WzPageHeader(
          icon: Icons.storage,
          title: 'Storage Manager',
          subtitle: 'Manage downloaded and cached tracks for offline playback.',
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
                  WzStatusPill(label: smartDownloadsEnabled ? 'Smart downloads on' : 'Smart downloads off', active: smartDownloadsEnabled, icon: Icons.auto_awesome),
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
                  Text(downloads.isEmpty ? 'Storage is clear' : '${downloads.length} downloaded • ${_formatCacheBytes(cacheBytes)}', style: WzText.body),
                  OutlinedButton.icon(
                    onPressed: controlsDisabled || downloads.isEmpty ? null : () => unawaited(onClearAll()),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear all downloads'),
                  ),
                ],
              ),
              const SizedBox(height: WzSpacing.md),
              if (downloads.isEmpty)
                const _EmptyCatalogMessage(message: 'No downloads yet. Download a track manually or turn on Smart Downloads to fill this list.')
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
              const _EmptyCatalogMessage(message: 'No downloaded tracks yet. Cache a track manually or let Smart Downloads fill this list.')
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
    required this.onOpen,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  final List<WzCollection> collections;
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
          trailing: WzPrimaryAction(label: 'Create', icon: Icons.add, onPressed: onCreate),
        ),
        const SizedBox(height: WzSpacing.md),
        _CollectionCard(collection: liked, onOpen: () => onOpen(liked), onRename: null, onDelete: null),
        const SizedBox(height: WzSpacing.md),
        const WzSectionHeader(title: 'Your collections', subtitle: 'Local playlists stored on this device.', icon: Icons.queue_music),
        if (userCollections.isEmpty)
          const WzPanel(
            child: Text('No collections yet. Save tracks from Library or Now Playing.', style: WzText.body),
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
            const WzPanel(child: Text('This collection is empty. Save tracks from Library or Now Playing.', style: WzText.body))
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
            if (!available) const WzStatusPill(label: 'Unavailable now', warning: true, icon: Icons.cloud_off),
          ]),
          const SizedBox(height: WzSpacing.xs),
          Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xs, children: [
            OutlinedButton.icon(onPressed: available ? onPlay : onPlay, icon: const Icon(Icons.play_arrow), label: const Text('Play')),
            OutlinedButton.icon(onPressed: available ? onAddToQueue : onAddToQueue, icon: const Icon(Icons.queue_music), label: const Text('Add to Queue')),
            OutlinedButton.icon(onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline), label: const Text('Remove')),
          ]),
        ]),
      );
}

String _collectionSourceLabel(WzCollectionTrackSource source) => switch (source) {
      WzCollectionTrackSource.api => 'API',
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
                    Text('Browse API Catalog, Device Music, Downloads, or everything together.', style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13)),
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
                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'API Catalog', detail: '$apiTrackCount tracks', status: status, icon: Icons.cloud_queue, active: librarySourceFilter == _LibrarySourceFilter.api)),
                  SizedBox(width: cardWidth, child: _LibrarySourceSummaryCard(title: 'Device Music', detail: '$deviceTrackCount imported', status: 'Permission $devicePermissionStatus • $deviceScanStatus', icon: Icons.phone_android, active: librarySourceFilter == _LibrarySourceFilter.device)),
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
                label: Text(deviceTrackCount == 0 ? 'Import Device Music' : 'Rescan Device Music'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenCollections,
                icon: const Icon(Icons.playlist_play),
                label: const Text('Collections / Playlists'),
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
                      Text('Local or unknown tracks are not for production distribution until rights are verified.', style: WzText.caption),
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
                  const WzPanel(child: Text('No catalog entries are loaded yet.', style: WzText.body))
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
    final source = license.sourceName ?? (_isDeviceCatalogTrack(track) ? 'Device Music' : _isCachedCatalogTrack(track) ? 'Cached copy' : 'API Catalog');
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
              Text('Track id: ${track.trackId} • source: ${track.source}', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
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

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.metrics, required this.manifest});

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            color: _WzTokens.surfaceMuted,
            border: Border(top: BorderSide(color: _WzTokens.borderSoft)),
          ),
          child: Row(
            children: [
              const Icon(Icons.album, color: _WzTokens.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  metrics.trackTitle ?? manifest?.title ?? 'No track loaded',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Text(_formatTime(metrics.currentPositionMs), style: _timeStyle),
            ],
          ),
        ),
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

