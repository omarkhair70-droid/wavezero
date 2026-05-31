import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog/catalog_client.dart';
import '../catalog/catalog_track_manifest.dart';
import '../playback/playback_bridge.dart';
import '../playback/playback_metrics.dart';
import '../playback/test_track.dart';
import '../cache/cache_service.dart';
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

  // Cache service and diagnostics
  final CacheService _cacheService = CacheService();
  int _cachedTrackCount = 0;
  int _cacheBytes = 0;
  String? _lastCacheResult;
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
  }

  Future<void> _initCache() async {
    try {
      await _cacheService.init();
      await _refreshCacheStats();
    } catch (_) {}
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
                    primaryAsset: null,
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
    if (prefetchedManifest?.trackId == trackId) {
      manifest = prefetchedManifest!;
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
        );
        if (mounted) {
          setState(() {
            _catalogStatus = 'Loaded offline cached track: ${manifest.title}';
          });
        }
      } else {
        try {
          manifest = await client.fetchTrackManifest(trackId: trackId);
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
            );
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
      _catalogStatus = status ?? (_catalogStatus.startsWith('Loaded offline') ? _catalogStatus : 'Loaded from catalog API: ${manifest.title}');
    });
    final resolvedUrl = await _cacheService.cachedOrRemoteUrl(manifest.trackId, manifest.streamUrl);
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
      final manifest = await client.fetchTrackManifest(trackId: candidate.trackId);
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
    final assetUrl = track.primaryAsset?.manifestUrl;
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
        ),
      );
      await _refreshCacheStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Cached ${track.title}' : 'Cache failed for ${track.title}')));
    } finally {
      if (mounted) setState(() => _operation = PlayerOperation.idle);
    }
  }

  Future<void> _clearCache() async {
    if (_operation != PlayerOperation.idle) return;
    setState(() => _operation = PlayerOperation.loadingCatalog);
    try {
      await _cacheService.clearCache();
      await _refreshCacheStats();
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
    if (_upNextQueueTrack != null) unawaited(_updatePredictivePreloadCandidate());
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

    // Build per-tab pages using existing widgets — keep behavior unchanged.
    final pages = <Widget>[
      // Home: identity + compact status and health
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TopBar(),
            const SizedBox(height: 18),
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
            const SizedBox(height: 12),
            _StatusStrip(status: _statusText, detail: _statusDetail, operation: _operation.label, refreshingMetrics: _refreshingMetrics),
            const SizedBox(height: 8),
            _SessionStrip(status: _sessionStatus),
            const SizedBox(height: 12),
            _HealthStrip(metrics: _metrics),
          ],
        ),
      ),
      // Now Playing: focused player controls
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 6),
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
          const SizedBox(height: 12),
          _MetricsToggle(showMetrics: _showMetrics, operationBusy: _operation != PlayerOperation.idle, onToggle: () => setState(() => _showMetrics = !_showMetrics), onCopyMetrics: _copyMetrics, onResetMetrics: _resetMetrics),
          if (_showMetrics) ...[const SizedBox(height: 14), _MetricsPanel(metrics: _metrics)],
        ]),
      ),
      // Queue: queue card and Smart Queue reason
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
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
            onRemoveTrack: _removeFromQueue,
            onClearQueue: _clearQueue,
          ),
          const SizedBox(height: 16),
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
        ]),
      ),
      // Library: catalog/search/track list
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
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
          const SizedBox(height: 16),
          _TrackSetupCard(titleController: _titleController, urlController: _urlController, apiBaseUrlController: _apiBaseUrlController, catalogStatus: _catalogStatus, loading: _manualDisabled, onLoadCatalog: () => _loadCatalogTrack(), onLoadTrack: _loadManualTrack),
        ]),
      ),
      // Engine: smart preload, baseline, raw metrics
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          _Panel(
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Cache', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Cached tracks: $_cachedTrackCount • ${(_cacheBytes / 1024).toStringAsFixed(1)} KB', style: _WzTokens.caption),
                    Text('Offline cached library: ${_offlineLibraryAvailable ? 'available' : 'unavailable'}', style: _WzTokens.caption),
                    Text('Offline cache items: $_offlineCachedTrackCount', style: _WzTokens.caption),
                    Text('Offline status: $_lastOfflineLibraryStatus', style: _WzTokens.caption),
                    if (_lastCacheResult != null) Text('Last: $_lastCacheResult', style: _WzTokens.caption),
                  ]),
                ),
                FilledButton.tonalIcon(onPressed: _queueDisabled ? null : () async { await _clearCache(); }, icon: const Icon(Icons.clear_all), label: const Text('Clear cache'))
              ],
            ),
          ),
          const SizedBox(height: 16),
          _MetricsToggle(showMetrics: _showMetrics, operationBusy: _operation != PlayerOperation.idle, onToggle: () => setState(() => _showMetrics = !_showMetrics), onCopyMetrics: _copyMetrics, onResetMetrics: _resetMetrics),
          if (_showMetrics) ...[const SizedBox(height: 14), _MetricsPanel(metrics: _metrics)],
        ]),
      ),
    ];

    return Scaffold(
      backgroundColor: _WzTokens.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: pages[_selectedIndex],
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

  static const Color canvas = Color(0xFF060810);
  static const Color surface = Color(0xFF101521);
  static const Color surfaceElevated = Color(0xFF151B2A);
  static const Color surfaceMuted = Color(0xFF0B0F19);
  static const Color border = Color(0xFF252E43);
  static const Color borderSoft = Color(0xFF1C2435);
  static const Color accent = Color(0xFF9A8CFF);
  static const Color accentSoft = Color(0x1F9A8CFF);
  static const Color success = Color(0xFF38D996);
  static const Color successSoft = Color(0x1838D996);
  static const Color warning = Color(0xFFFFC46B);
  static const Color warningSoft = Color(0x1AFFC46B);
  static const Color textPrimary = Color(0xFFF3F5FB);
  static const Color textMuted = Color(0xFFA4ADC1);
  static const Color textSubtle = Color(0xFF7F899F);

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

String _prefetchResultLabel(bool? value) {
  if (value == null) return 'none';
  return value ? 'hit' : 'miss';
}

class _QueueCard extends StatelessWidget { const _QueueCard({required this.queue, required this.currentTrackId, required this.currentIndex, required this.status, required this.controlsDisabled, required this.autoAdvanceEnabled, required this.autoAdvanceCount, required this.smartQueueCandidateTrackId, required this.smartQueueReason, required this.onToggleAutoAdvance, required this.onPlayTrack, required this.onRemoveTrack, required this.onClearQueue}); final List<CatalogTrackSummary> queue; final String? currentTrackId; final int currentIndex; final String status; final bool controlsDisabled; final bool autoAdvanceEnabled; final int autoAdvanceCount; final String? smartQueueCandidateTrackId; final String smartQueueReason; final ValueChanged<bool> onToggleAutoAdvance; final ValueChanged<CatalogTrackSummary> onPlayTrack; final ValueChanged<CatalogTrackSummary> onRemoveTrack; final VoidCallback onClearQueue; @override Widget build(BuildContext context) { final nextTrack = currentIndex >= 0 && currentIndex < queue.length - 1 ? queue[currentIndex + 1] : null; return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Queue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Current, up next, auto-advance, and recovery.', style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13))])), Text('${queue.length} tracks', style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)), const SizedBox(width: 8), IconButton.outlined(onPressed: queue.isEmpty || controlsDisabled ? null : onClearQueue, icon: const Icon(Icons.clear_all))]), const SizedBox(height: 12), Row(children: [Expanded(child: Text(nextTrack == null ? 'No next track yet.' : 'Auto-advance to ${nextTrack.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFD7DDF0), fontSize: 12))), Text('$autoAdvanceCount auto', style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 11)), Switch(value: autoAdvanceEnabled, onChanged: controlsDisabled ? null : onToggleAutoAdvance)]), const SizedBox(height: 8), Text('smartQueueReason: $smartQueueReason • candidate: ${smartQueueCandidateTrackId ?? 'none'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)), const SizedBox(height: 8), Text(status, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)), const SizedBox(height: 12), if (queue.isEmpty) const _EmptyCatalogMessage(message: 'Queue is empty. Add tracks from the catalog.') else ...queue.indexed.map((entry) => _QueueRow(track: entry.$2, index: entry.$1, current: entry.$2.trackId == currentTrackId, upNext: entry.$1 == currentIndex + 1, disabled: controlsDisabled, onPlay: () => onPlayTrack(entry.$2), onRemove: () => onRemoveTrack(entry.$2)))])); }}

class _QueueRow extends StatelessWidget { const _QueueRow({required this.track, required this.index, required this.current, required this.upNext, required this.disabled, required this.onPlay, required this.onRemove}); final CatalogTrackSummary track; final int index; final bool current; final bool upNext; final bool disabled; final VoidCallback onPlay; final VoidCallback onRemove; @override Widget build(BuildContext context) { final label = current ? 'Now' : upNext ? 'Up next' : '#${index + 1}'; return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: current ? const Color(0x227C5CFF) : const Color(0xFF0B0E18), borderRadius: BorderRadius.circular(18), border: Border.all(color: current ? const Color(0xFF8D7CFF) : const Color(0xFF20273A))), child: Row(children: [Icon(current ? Icons.equalizer : Icons.queue_music, color: const Color(0xFF8D7CFF)), const SizedBox(width: 12), Expanded(child: Text('${track.title}  $label', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))), IconButton(onPressed: disabled ? null : onPlay, icon: Icon(current ? Icons.check_circle : Icons.play_arrow, color: const Color(0xFF8D7CFF))), IconButton(onPressed: disabled ? null : onRemove, icon: const Icon(Icons.close, color: Color(0xFF98A1B8)))])); }}

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
String _trackSubtitle(CatalogTrackSummary track) { final asset = track.primaryAsset; final parts = <String>[track.subtitle]; if (asset?.codec != null) parts.add(asset!.codec!); if (asset?.bitrateKbps != null) parts.add('${asset!.bitrateKbps}kbps'); return parts.join(' • '); }
String _statusFromEvent(String? event) { switch (event) { case 'track_loaded': case 'buffering_started': return 'Preparing'; case 'ready': case 'buffering_ended': case 'manifest_loaded': return 'Ready'; case 'not_playing': return 'Paused'; case 'stopped': return 'Paused'; case 'ended': case 'playback_ended': return 'Ended'; default: return 'Ready'; } }
String _formatMetric(int? valueMs) => valueMs == null ? '—' : '${valueMs}ms';
String _formatTime(int? valueMs) { if (valueMs == null || valueMs < 0) return '—:—'; final totalSeconds = (valueMs / 1000).floor(); final minutes = totalSeconds ~/ 60; final seconds = totalSeconds % 60; return '$minutes:${seconds.toString().padLeft(2, '0')}'; }
const _timeStyle = TextStyle(color: Color(0xFF9BA3B4), fontSize: 12);
