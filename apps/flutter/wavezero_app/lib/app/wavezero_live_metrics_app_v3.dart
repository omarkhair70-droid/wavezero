import 'dart:async';

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
import 'player_operation_state.dart';
import 'queue_session_store.dart';
import 'smart_queue_policy.dart';

class WaveZeroLiveMetricsApp extends StatelessWidget {
  const WaveZeroLiveMetricsApp({super.key, PlaybackBridge? playbackBridge, QueueSessionStore? sessionStore})
      : _playbackBridge = playbackBridge,
        _sessionStore = sessionStore;

  final PlaybackBridge? _playbackBridge;
  final QueueSessionStore? _sessionStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaveZero',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _WzTokens.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _WzTokens.accent,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _WzTokens.surfaceMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_WzTokens.radiusMd),
            borderSide: const BorderSide(color: _WzTokens.border),
          ),
        ),
        useMaterial3: true,
      ),
      home: _PlayerScreen(
        playbackBridge: _playbackBridge ?? _defaultBridge(),
        sessionStore: _sessionStore ?? QueueSessionStore(),
      ),
    );
  }

  PlaybackBridge _defaultBridge() {
    if (defaultTargetPlatform == TargetPlatform.android) return PlatformChannelPlaybackBridge();
    return MockPlaybackBridge();
  }
}

class _PlayerScreen extends StatefulWidget {
  const _PlayerScreen({required this.playbackBridge, required this.sessionStore});

  final PlaybackBridge playbackBridge;
  final QueueSessionStore sessionStore;

  @override
  State<_PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<_PlayerScreen> {
  static const _refreshInterval = Duration(milliseconds: 500);
  static const _autoAdvanceThresholdMs = 1200;
  static const _audioEffectPreferenceKey = 'wavezero.selected_audio_effect_profile';
  static const _tabLabels = ['Home', 'Now', 'Queue', 'Library', 'Downloads', 'Engine'];

  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _searchController;

  Timer? _poller;
  PlaybackMetrics _metrics = const PlaybackMetrics();
  CatalogTrackManifest? _manifest;
  List<CatalogTrackSummary> _catalog = const [];
  List<CatalogTrackSummary> _queue = const [];

  PlayerOperation _operation = PlayerOperation.idle;
  bool _refreshingMetrics = false;
  bool _showMetrics = false;
  int _selectedIndex = 0;
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

  List<CatalogTrackSummary> get _filteredCatalog => _catalog.where((track) => track.matchesQuery(_catalogQuery)).toList(growable: false);

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

  String get _statusText {
    if ((_lastError ?? _metrics.playbackError) != null) return 'Error';
    if (_operation != PlayerOperation.idle) return _operation.displayName;
    if (_metrics.isPlaying) return 'Playing';
    if (_manifest != null || _metrics.trackTitle != null) return 'Paused / Ready';
    return 'Ready';
  }

  String get _statusDetail {
    final error = _lastError ?? _metrics.playbackError;
    if (error != null && error.isNotEmpty) return error;
    if (_refreshingMetrics) return 'Metrics refresh is running without blocking controls.';
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
      });
      if (allowAutoAdvance) await _maybeAutoAdvance(next);
    } finally {
      _refreshingMetrics = false;
    }
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

  Future<void> _loadCatalogTrack({String? trackId, bool autoPlay = false, PlayerOperation operation = PlayerOperation.loadingTrack, String? status, CatalogTrackManifest? prefetchedManifest}) {
    final id = trackId ?? _selectedTrackId ?? (_catalog.isNotEmpty ? _catalog.first.trackId : null);
    if (id == null) return Future<void>.value();
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
      await widget.playbackBridge.loadTrack(title: title, url: _urlController.text.trim());
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
        ),
      );
      await _refreshCacheStats();
      if (!mounted) return;
      _lastQualityFallbackReason = 'manual cache: ${selection?.fallbackReason ?? 'quality unknown'}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Cached ${track.title} (${selectedAsset?.qualityLabel ?? 'unknown'})' : 'Cache failed for ${track.title}')));
    } finally {
      if (mounted) setState(() => _operation = PlayerOperation.idle);
    }
  }

  Future<void> _deleteCachedTrack(CachedTrackMetadata track) async {
    if (_operation != PlayerOperation.idle) return;
    setState(() => _operation = PlayerOperation.loadingCatalog);
    try {
      final ok = await _cacheService.deleteCachedTrack(track.trackId);
      _lastCacheDeleteResult = ok ? 'deleted:${track.trackId}' : 'delete failed:${track.trackId}';
      await _refreshCacheStats();
      _refreshOfflineLibraryIfNeeded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Deleted cached ${track.title}' : 'Delete failed for ${track.title}')),
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
      _lastCacheDeleteResult = 'cleared all cache';
      await _refreshCacheStats();
      _refreshOfflineLibraryIfNeeded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
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

    final qualityLabel = _manifest?.qualityLabel ?? _currentCachedQuality ?? _preferredAudioQuality.label;
    final isPlayingFromCache = _currentCachedQuality != null || (_currentAssetUrl?.startsWith('file://') ?? false);
    final effectsSummary = _nativeAudioEffectStatus == NativeAudioEffectStatus.applied
        ? 'Applied'
        : _nativeAudioEffectStatus == NativeAudioEffectStatus.unsupported
            ? 'Unsupported'
            : _selectedAudioEffectProfile == AudioEffectProfile.off
                ? 'Off'
                : _nativeAudioEffectStatus.name;
    final engineSummary = '${_smartDownloadsEnabled ? 'Smart Downloads on' : 'Smart Downloads off'} • '
        '${_prefetchEnabled ? 'Instant Next on' : 'Instant Next off'} • '
        '${_offlineLibraryAvailable ? 'Offline Ready' : 'Offline empty'}';

    // Build per-tab pages using existing widgets — keep behavior unchanged.
    final pages = <Widget>[
      WzPageScaffold(
        children: [
          _HomeHero(engineSummary: engineSummary),
          const SizedBox(height: WzSpacing.md),
          _CurrentListeningCard(
            metrics: _metrics,
            manifest: _manifest,
            qualityLabel: qualityLabel,
            playingFromCache: isPlayingFromCache,
            offlineReady: _offlineLibraryAvailable,
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
          _HomeQuickActions(onNavigate: (index) => setState(() => _selectedIndex = index)),
          const SizedBox(height: WzSpacing.md),
          _StatusStrip(status: _statusText, detail: _statusDetail, operation: _operation.label, refreshingMetrics: _refreshingMetrics),
          const SizedBox(height: WzSpacing.sm),
          _SessionStrip(status: _sessionStatus),
        ],
      ),
      WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.play_circle_fill,
            title: 'Now Playing',
            subtitle: 'Focused playback controls with current quality and effects context.',
          ),
          const SizedBox(height: WzSpacing.md),
          _NowPlayingCard(
            metrics: _metrics,
            manifest: _manifest,
            nextTrack: _upNextQueueTrack,
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
          ),
          const SizedBox(height: WzSpacing.md),
          _NowContextPanel(
            qualityLabel: qualityLabel,
            effectsSummary: effectsSummary,
            playingFromCache: isPlayingFromCache,
            offlineReady: _offlineLibraryAvailable,
            nextTrack: _upNextQueueTrack,
          ),
          const SizedBox(height: WzSpacing.md),
          _MetricsToggle(showMetrics: _showMetrics, operationBusy: _operation != PlayerOperation.idle, onToggle: () => setState(() => _showMetrics = !_showMetrics), onCopyMetrics: _copyMetrics, onResetMetrics: _resetMetrics),
          if (_showMetrics) ...[const SizedBox(height: WzSpacing.md), _MetricsPanel(metrics: _metrics)],
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
            onToggle: (v) => setState(() { _smartDownloadsEnabled = v; }),
          ),
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
            totalTrackCount: _catalog.length,
            selectedTrackId: _selectedTrackId,
            status: _catalogStatus,
            loading: _operation == PlayerOperation.loadingCatalog,
            refreshDisabled: _catalogRefreshDisabled,
            addToQueueDisabled: _operation.isTrackLoading || _operation.isQueueAdvancing,
            searchController: _searchController,
            onClearSearch: () => _searchController.clear(),
            onRefresh: () => _loadCatalog(),
            onSelectTrack: (track) => _loadCatalogTrack(trackId: track.trackId),
            onAddToQueue: _addToQueue,
            onCache: (track) => _toggleCache(track),
            offlineMode: _catalogStatus.toLowerCase().contains('offline'),
          ),
          const SizedBox(height: WzSpacing.md),
          _TrackSetupCard(titleController: _titleController, urlController: _urlController, apiBaseUrlController: _apiBaseUrlController, catalogStatus: _catalogStatus, loading: _manualDisabled, onLoadCatalog: () => _loadCatalogTrack(), onLoadTrack: _loadManualTrack),
        ],
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
          ),
        ],
      ),
      WzPageScaffold(
        children: [
          const WzPageHeader(
            icon: Icons.engineering,
            title: 'Engine diagnostics',
            subtitle: 'Advanced playback, preload, cache, quality, and effects diagnostics remain available.',
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

    return Scaffold(
      backgroundColor: _WzTokens.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                _ProductShellHeader(
                  selectedTabLabel: _tabLabels[_selectedIndex],
                  status: _statusText,
                  engineSummary: engineSummary,
                  offlineReady: _offlineLibraryAvailable,
                ),
                Expanded(child: pages[_selectedIndex]),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: _WzTokens.surfaceMuted,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              backgroundColor: _WzTokens.surfaceMuted,
              selectedItemColor: _WzTokens.accent,
              unselectedItemColor: _WzTokens.textMuted,
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.play_circle_fill), label: 'Now'),
                BottomNavigationBarItem(icon: Icon(Icons.queue_music), label: 'Queue'),
                BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
                BottomNavigationBarItem(icon: Icon(Icons.download_done), label: 'Downloads'),
                BottomNavigationBarItem(icon: Icon(Icons.engineering), label: 'Engine'),
              ],
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
  });

  final String selectedTabLabel;
  final String status;
  final String engineSummary;
  final bool offlineReady;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
        child: WzPanel(
          padding: const EdgeInsets.symmetric(horizontal: WzSpacing.md, vertical: WzSpacing.sm),
          gradient: WzColors.heroGradient,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: WzColors.accentGradient,
                  borderRadius: BorderRadius.circular(WzRadius.md),
                ),
                child: const Icon(Icons.graphic_eq, color: Colors.white),
              ),
              const SizedBox(width: WzSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WaveZero', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                    const SizedBox(height: WzSpacing.xxs),
                    Text('$selectedTabLabel • $engineSummary', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  ],
                ),
              ),
              const SizedBox(width: WzSpacing.sm),
              WzStatusPill(label: status, active: status == 'Playing', warning: status == 'Error', icon: Icons.radio_button_checked),
              const SizedBox(width: WzSpacing.xs),
              WzStatusPill(label: offlineReady ? 'Offline Ready' : 'Online catalog', active: offlineReady, icon: Icons.offline_pin),
            ],
          ),
        ),
      );
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.engineSummary});

  final String engineSummary;

  @override
  Widget build(BuildContext context) => WzPanel(
        padding: const EdgeInsets.all(WzSpacing.xl),
        gradient: WzColors.heroGradient,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WaveZero', style: WzText.display),
            const SizedBox(height: WzSpacing.xs),
            const Text('A smart music experience engine.', style: TextStyle(fontSize: 17, color: WzColors.textMuted, height: 1.35)),
            const SizedBox(height: WzSpacing.lg),
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
    required this.offlineReady,
    required this.status,
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final String qualityLabel;
  final bool playingFromCache;
  final bool offlineReady;
  final String status;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? 'No track loaded';
    return WzPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WzSectionHeader(title: 'Current listening', subtitle: 'Real playback state from the engine.', icon: Icons.album),
          Row(
            children: [
              _Artwork(artworkUrl: manifest?.artworkUrl),
              const SizedBox(width: WzSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.title),
                    const SizedBox(height: WzSpacing.xs),
                    Text(manifest?.subtitle ?? 'Choose a track from Library to start listening.', maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.body),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: WzSpacing.md),
          Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: [
              WzStatusPill(label: status, active: metrics.isPlaying, warning: status == 'Error', icon: metrics.isPlaying ? Icons.play_arrow : Icons.pause),
              WzStatusPill(label: 'Quality: ${_productQualityLabel(qualityLabel)}', active: qualityLabel != 'unknown', icon: Icons.high_quality),
              if (playingFromCache) const WzStatusPill(label: 'Playing from cache', active: true, icon: Icons.offline_pin),
              if (offlineReady) const WzStatusPill(label: 'Offline Ready', active: true, icon: Icons.download_done),
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
  const _HomeQuickActions({required this.onNavigate});

  final ValueChanged<int> onNavigate;

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
                WzPrimaryAction(label: 'Go to Library', icon: Icons.library_music, onPressed: () => onNavigate(3)),
                WzPrimaryAction(label: 'Go to Queue', icon: Icons.queue_music, onPressed: () => onNavigate(2)),
                WzPrimaryAction(label: 'Go to Downloads', icon: Icons.download_done, onPressed: () => onNavigate(4)),
                WzPrimaryAction(label: 'Go to Engine', icon: Icons.engineering, onPressed: () => onNavigate(5)),
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
    required this.offlineReady,
    required this.nextTrack,
  });

  final String qualityLabel;
  final String effectsSummary;
  final bool playingFromCache;
  final bool offlineReady;
  final CatalogTrackSummary? nextTrack;

  @override
  Widget build(BuildContext context) => WzPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WzSectionHeader(title: 'Listening context', subtitle: 'Quality, effects, cache, and up-next state.', icon: Icons.tune),
            Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              children: [
                WzMiniMetric(label: 'Quality', value: _productQualityLabel(qualityLabel), active: qualityLabel != 'unknown', icon: Icons.high_quality),
                WzMiniMetric(label: 'Effects', value: effectsSummary, active: effectsSummary == 'Applied', icon: Icons.tune),
                WzMiniMetric(label: 'Cache', value: playingFromCache ? 'Playing from cache' : offlineReady ? 'Offline Ready' : 'Streaming / ready', active: playingFromCache || offlineReady, icon: Icons.offline_pin),
                WzMiniMetric(label: 'Up next', value: nextTrack?.title ?? 'Queue empty', active: nextTrack != null, icon: Icons.skip_next),
              ],
            ),
          ],
        ),
      );
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
          SegmentedButton<AudioQualityTier>(
            segments: const [
              ButtonSegment(value: AudioQualityTier.standard, label: Text('Standard')),
              ButtonSegment(value: AudioQualityTier.high, label: Text('High')),
              ButtonSegment(value: AudioQualityTier.original, label: Text('Original')),
            ],
            selected: {preferredAudioQuality},
            onSelectionChanged: controlsDisabled ? null : onSelected,
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
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _PanelHeader(icon: Icons.offline_pin, title: 'Cache / Offline', subtitle: 'Offline Ready plus raw cache counters.'),
                const SizedBox(height: 10),
                Text('Cached tracks: $cachedTrackCount • ${(cacheBytes / 1024).toStringAsFixed(1)} KB', style: _WzTokens.caption),
                Text('Offline cached library: ${offlineLibraryAvailable ? 'available' : 'unavailable'}', style: _WzTokens.caption),
                Text('Offline cache items: $offlineCachedTrackCount', style: _WzTokens.caption),
                Text('downloadedTrackCount: $cachedTrackCount', style: _WzTokens.caption),
                Text('totalCacheBytes: $cacheBytes', style: _WzTokens.caption),
                Text('manualDownloadedCount: $manualDownloadedCount', style: _WzTokens.caption),
                Text('smartDownloadedCount: $smartDownloadedCount', style: _WzTokens.caption),
                Text('Offline status: $lastOfflineLibraryStatus', style: _WzTokens.caption),
                if (lastCacheResult != null) Text('Last: $lastCacheResult', style: _WzTokens.caption),
                if (lastCacheDeleteResult != null) Text('lastCacheDeleteResult: $lastCacheDeleteResult', style: _WzTokens.caption),
              ]),
            ),
            FilledButton.tonalIcon(onPressed: controlsDisabled ? null : () async { await onClearCache(); }, icon: const Icon(Icons.clear_all), label: const Text('Clear cache')),
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
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final CatalogTrackSummary? nextTrack;
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

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? waveZeroTestTrack.title;
    final subtitle = manifest?.subtitle ?? 'WaveZero playback proof';
    final status = metrics.isPlaying ? 'Playing' : _statusFromEvent(metrics.lastEvent);
    return _Panel(
      padding: const EdgeInsets.all(_WzTokens.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Artwork(artworkUrl: manifest?.artworkUrl),
              const SizedBox(width: _WzTokens.space5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status.toUpperCase(), style: _WzTokens.eyebrow),
                    const SizedBox(height: _WzTokens.space2),
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: _WzTokens.space2),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _WzTokens.body),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: _WzTokens.space6),
          Slider(value: progressValue, onChanged: onSeekChanged, onChangeEnd: onSeekEnd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(_formatTime(displayedPositionMs), style: _timeStyle), Text(_formatTime(durationMs), style: _timeStyle)],
          ),
          if (nextTrack != null) ...[
            const SizedBox(height: 10),
            Text(
              'Up next: ${nextTrack!.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _WzTokens.caption,
            ),
          ],
          const SizedBox(height: _WzTokens.space6),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: _WzTokens.space3,
            runSpacing: _WzTokens.space3,
            children: [
              IconButton.filledTonal(
                tooltip: 'Previous',
                onPressed: controlsDisabled || !canPlayPrevious ? null : onPrevious,
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton.filledTonal(
                tooltip: 'Retry',
                onPressed: controlsDisabled ? null : onRetry,
                icon: const Icon(Icons.replay),
              ),
              SizedBox(
                width: 70,
                height: 70,
                child: FilledButton(
                  onPressed: controlsDisabled ? null : onPlayPause,
                  style: FilledButton.styleFrom(shape: const CircleBorder()),
                  child: Icon(metrics.isPlaying ? Icons.pause : Icons.play_arrow, size: 36),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Stop',
                onPressed: controlsDisabled ? null : onStop,
                icon: const Icon(Icons.stop),
              ),
              IconButton.filledTonal(
                tooltip: 'Next',
                onPressed: controlsDisabled || !canPlayNext ? null : onNext,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
              _QueueStateChip(label: 'Auto', value: '$autoAdvanceCount advances', active: autoAdvanceEnabled),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(status, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12))),
              Switch(value: autoAdvanceEnabled, onChanged: controlsDisabled ? null : onToggleAutoAdvance),
            ],
          ),
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
      child: Row(
        children: [
          Icon(current ? Icons.equalizer : upNext ? Icons.next_plan : Icons.queue_music, color: current || upNext ? const Color(0xFF8D7CFF) : const Color(0xFF98A1B8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(label, style: _WzTokens.caption),
              ],
            ),
          ),
          IconButton(tooltip: 'Play/select', onPressed: disabled ? null : onPlay, icon: Icon(current ? Icons.check_circle : Icons.play_arrow, color: const Color(0xFF8D7CFF))),
          IconButton(tooltip: 'Move up', onPressed: disabled || !canMoveUp ? null : onMoveUp, icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF98A1B8))),
          IconButton(tooltip: 'Move down', onPressed: disabled || !canMoveDown ? null : onMoveDown, icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF98A1B8))),
          IconButton(tooltip: 'Play next', onPressed: disabled || current || upNext ? null : onPlayNext, icon: const Icon(Icons.low_priority, color: Color(0xFF38D996))),
          IconButton(tooltip: 'Remove', onPressed: disabled ? null : onRemove, icon: const Icon(Icons.close, color: Color(0xFF98A1B8))),
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
  });

  final List<CachedTrackMetadata> downloads;
  final int cacheBytes;
  final bool controlsDisabled;
  final ValueChanged<CachedTrackMetadata> onPlay;
  final ValueChanged<CachedTrackMetadata> onDelete;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Downloads', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('Cached tracks available for offline playback.', style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13)),
                    ],
                  ),
                ),
                Text('${downloads.length} • ${(cacheBytes / 1024).toStringAsFixed(1)} KB', style: _WzTokens.caption),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Clear all cache',
                  onPressed: downloads.isEmpty || controlsDisabled ? null : onClearAll,
                  icon: const Icon(Icons.clear_all),
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
        child: Row(
          children: [
            _Artwork(artworkUrl: track.artworkUrl, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${track.subtitle} • ${track.qualityLabel}${track.codec == null ? '' : ' • ${track.codec}'}${track.bitrateKbps == null ? '' : ' • ${track.bitrateKbps}kbps'} • source: ${_downloadSourceLabel(track.downloadSource)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _WzTokens.caption),
                ],
              ),
            ),
            IconButton(tooltip: 'Play cached track', onPressed: disabled ? null : onPlay, icon: const Icon(Icons.play_arrow, color: Color(0xFF8D7CFF))),
            IconButton(tooltip: 'Delete cached track', onPressed: disabled ? null : onDelete, icon: const Icon(Icons.delete_outline, color: Color(0xFFFF8F8F))),
          ],
        ),
      );
}

String _downloadSourceLabel(String source) {
  switch (source) {
    case 'manual':
      return 'manual';
    case 'smart_current':
      return 'smart current';
    case 'smart_up_next':
      return 'smart up-next';
    default:
      return 'unknown';
  }
}

class _CatalogListCard extends StatelessWidget {
  const _CatalogListCard({
    required this.tracks,
    required this.totalTrackCount,
    required this.selectedTrackId,
    required this.status,
    required this.loading,
    required this.refreshDisabled,
    required this.addToQueueDisabled,
    required this.searchController,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onSelectTrack,
    required this.onAddToQueue,
    required this.onCache,
    this.offlineMode = false,
  });

  final List<CatalogTrackSummary> tracks;
  final int totalTrackCount;
  final String? selectedTrackId;
  final String status;
  final bool loading;
  final bool refreshDisabled;
  final bool addToQueueDisabled;
  final TextEditingController searchController;
  final VoidCallback onClearSearch;
  final VoidCallback onRefresh;
  final ValueChanged<CatalogTrackSummary> onSelectTrack;
  final ValueChanged<CatalogTrackSummary> onAddToQueue;
  final ValueChanged<CatalogTrackSummary> onCache;
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
                    Text('Catalog', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Search stays usable while playback is running.', style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13)),
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
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Search catalog',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasQuery ? IconButton(onPressed: onClearSearch, icon: const Icon(Icons.close)) : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery ? '$status Showing ${tracks.length} of $totalTrackCount.' : status,
            style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (totalTrackCount == 0)
            _EmptyCatalogMessage(
              message: offlineMode ? 'No cached tracks available offline.' : 'No catalog tracks loaded yet.',
            )
          else if (tracks.isEmpty)
            const _EmptyCatalogMessage(message: 'No tracks match this search.')
          else ...tracks.map((track) => _CatalogRow(
                track: track,
                selected: track.trackId == selectedTrackId,
                addDisabled: addToQueueDisabled,
                onTap: () => onSelectTrack(track),
                onAdd: () => onAddToQueue(track),
                onCache: () => onCache(track),
              )),
        ],
      ),
    );
  }
}
class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.track,
    required this.selected,
    required this.addDisabled,
    required this.onTap,
    required this.onAdd,
    required this.onCache,
  });

  final CatalogTrackSummary track;
  final bool selected;
  final bool addDisabled;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onCache;

  @override
  Widget build(BuildContext context) {
    final status = CacheService().statusForTrack(track.trackId);
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
        child: Row(children: [
          _Artwork(artworkUrl: track.artworkUrl, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                if (status == TrackCacheStatus.cached)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF173626), borderRadius: BorderRadius.circular(10)),
                    child: const Text('Cached', style: TextStyle(color: Color(0xFF38D996), fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(_trackSubtitle(track), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
            ]),
          ),
          Text(_formatTime(track.durationMs), style: _timeStyle),
          IconButton(onPressed: addDisabled ? null : onAdd, icon: const Icon(Icons.playlist_add, color: Color(0xFF8D7CFF))),
          IconButton(onPressed: onCache, icon: cacheIcon),
          Icon(selected ? Icons.check_circle : Icons.play_circle_outline, color: const Color(0xFF8D7CFF)),
        ]),
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
String _trackSubtitle(CatalogTrackSummary track) { final asset = track.primaryAsset; final parts = <String>[track.subtitle]; if (asset?.qualityLabel != null) parts.add(asset!.qualityLabel!); if (asset?.codec != null) parts.add(asset!.codec!); if (asset?.bitrateKbps != null) parts.add('${asset!.bitrateKbps}kbps'); return parts.join(' • '); }
String _statusFromEvent(String? event) { switch (event) { case 'track_loaded': case 'buffering_started': return 'Preparing'; case 'ready': case 'buffering_ended': case 'manifest_loaded': return 'Ready'; case 'not_playing': return 'Paused'; case 'stopped': return 'Paused'; case 'ended': case 'playback_ended': return 'Ended'; default: return 'Ready'; } }
String _formatMetric(int? valueMs) => valueMs == null ? '—' : '${valueMs}ms';
String _formatTime(int? valueMs) { if (valueMs == null || valueMs < 0) return '—:—'; final totalSeconds = (valueMs / 1000).floor(); final minutes = totalSeconds ~/ 60; final seconds = totalSeconds % 60; return '$minutes:${seconds.toString().padLeft(2, '0')}'; }
const _timeStyle = TextStyle(color: Color(0xFF9BA3B4), fontSize: 12);
