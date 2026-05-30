import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog/catalog_client.dart';
import '../catalog/catalog_track_manifest.dart';
import '../playback/playback_bridge.dart';
import '../playback/playback_metrics.dart';
import '../playback/test_track.dart';
import 'player_operation_state.dart';

class WaveZeroLiveMetricsApp extends StatelessWidget {
  const WaveZeroLiveMetricsApp({super.key, PlaybackBridge? playbackBridge})
      : _playbackBridge = playbackBridge;

  final PlaybackBridge? _playbackBridge;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WaveZero',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C5CFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _PlayerScreen(playbackBridge: _playbackBridge ?? _defaultBridge()),
    );
  }

  PlaybackBridge _defaultBridge() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformChannelPlaybackBridge();
    }
    return MockPlaybackBridge();
  }
}

class _PlayerScreen extends StatefulWidget {
  const _PlayerScreen({required this.playbackBridge});

  final PlaybackBridge playbackBridge;

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
  bool _autoAdvanceEnabled = true;
  int _autoAdvanceCount = 0;
  double? _dragPositionMs;

  String? _selectedTrackId;
  String? _queueCurrentTrackId;
  String? _lastAutoAdvanceTrackId;
  String? _lastError;
  String _catalogQuery = '';
  String _catalogStatus = 'Catalog not loaded yet.';
  String _queueStatus = 'Queue is ready.';

  List<CatalogTrackSummary> get _filteredCatalog => _catalog
      .where((track) => track.matchesQuery(_catalogQuery))
      .toList(growable: false);

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

  CatalogTrackSummary? get _nextQueueTrack {
    final index = _queueIndex;
    if (index < 0 || index >= _queue.length - 1) return null;
    return _queue[index + 1];
  }

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
    if (_nextQueueTrack != null) return 'Up next: ${_nextQueueTrack!.title}';
    return _queueStatus;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: waveZeroTestTrack.title);
    _urlController = TextEditingController(text: waveZeroTestTrack.url);
    _apiBaseUrlController = TextEditingController(text: CatalogClient.defaultBaseUrl);
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (mounted) setState(() => _catalogQuery = _searchController.text);
    });
    _poller = Timer.periodic(_refreshInterval, (_) => _refreshMetrics());
    _loadCatalog(fallbackToDemo: true);
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

  Future<void> _runOperation(
    PlayerOperation operation,
    Future<void> Function() body, {
    bool refreshAfter = true,
  }) async {
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
      setState(() => _metrics = next);
      if (allowAutoAdvance) await _maybeAutoAdvance(next);
    } finally {
      _refreshingMetrics = false;
    }
  }

  Future<void> _maybeAutoAdvance(PlaybackMetrics metrics) async {
    if (!_autoAdvanceEnabled || _operation != PlayerOperation.idle || !_canNext) return;
    final durationMs = metrics.durationMs ?? _manifest?.durationMs;
    if (durationMs == null || durationMs <= 0) return;
    final remainingMs = durationMs - metrics.currentPositionMs;
    final nearEnd = metrics.currentPositionMs > 0 && remainingMs <= _autoAdvanceThresholdMs;
    final ended = metrics.lastEvent == 'ended' || metrics.lastEvent == 'playback_ended';
    if (!nearEnd && !ended) {
      if (metrics.currentPositionMs < durationMs - (_autoAdvanceThresholdMs * 2)) {
        _lastAutoAdvanceTrackId = null;
      }
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
        final preferred = _findTrack(catalog.tracks, _selectedTrackId) ??
            (catalog.tracks.isEmpty ? null : catalog.tracks.first);
        if (!mounted) return;
        setState(() {
          _catalog = catalog.tracks;
          _queue = _queue.isEmpty
              ? catalog.tracks
              : _queue
                  .map((track) => _findTrack(catalog.tracks, track.trackId) ?? track)
                  .toList(growable: false);
          _selectedTrackId = preferred?.trackId;
          _queueCurrentTrackId ??= preferred?.trackId;
          _catalogStatus = catalog.tracks.isEmpty
              ? 'Catalog API returned no tracks.'
              : 'Loaded ${catalog.tracks.length} catalog tracks.';
          _queueStatus = _queue.isEmpty ? 'Queue is empty.' : 'Queue synced with catalog.';
        });
        if (preferred == null) throw const FormatException('Catalog API returned no playable tracks');
        await _loadManifestAndNativeTrack(preferred.trackId, client: client);
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _lastError = error.toString();
          _catalogStatus = fallbackToDemo
              ? 'Catalog unavailable. Using local demo track. $error'
              : 'Catalog load failed. $error';
        });
        if (fallbackToDemo) {
          await widget.playbackBridge.loadTrack(
            title: waveZeroTestTrack.title,
            url: waveZeroTestTrack.url,
          );
        }
      } finally {
        client.close();
      }
    });
  }

  Future<void> _loadCatalogTrack({
    String? trackId,
    bool autoPlay = false,
    PlayerOperation operation = PlayerOperation.loadingTrack,
    String? status,
  }) {
    final id = trackId ?? _selectedTrackId ?? (_catalog.isNotEmpty ? _catalog.first.trackId : null);
    if (id == null) return Future<void>.value();
    return _runOperation(operation, () async {
      final client = CatalogClient(baseUrl: _apiBaseUrlController.text);
      try {
        await _loadManifestAndNativeTrack(id, client: client, autoPlay: autoPlay, status: status);
      } finally {
        client.close();
      }
    });
  }

  Future<void> _loadManifestAndNativeTrack(
    String trackId, {
    required CatalogClient client,
    bool autoPlay = false,
    String? status,
  }) async {
    if (!mounted) return;
    setState(() {
      _catalogStatus = 'Loading catalog manifest...';
      _selectedTrackId = trackId;
      _queueCurrentTrackId = trackId;
      _lastAutoAdvanceTrackId = trackId;
    });
    final manifest = await client.fetchTrackManifest(trackId: trackId);
    if (!mounted) return;
    _titleController.text = manifest.title;
    _urlController.text = manifest.streamUrl;
    setState(() {
      _manifest = manifest;
      _selectedTrackId = manifest.trackId;
      _queueCurrentTrackId = manifest.trackId;
      _catalogStatus = status ?? 'Loaded from catalog API: ${manifest.title}';
    });
    await widget.playbackBridge.loadTrack(title: manifest.title, url: manifest.streamUrl);
    if (autoPlay) await widget.playbackBridge.play();
  }

  Future<void> _loadManualTrack() {
    return _runOperation(PlayerOperation.loadingManualTrack, () async {
      final title = _titleController.text.trim().isEmpty
          ? waveZeroTestTrack.title
          : _titleController.text.trim();
      await widget.playbackBridge.loadTrack(title: title, url: _urlController.text.trim());
      if (mounted) setState(() => _catalogStatus = 'Manual track loaded.');
    });
  }

  Future<void> _playPause() {
    return _runOperation(PlayerOperation.playbackCommand, () async {
      if (_metrics.isPlaying) {
        await widget.playbackBridge.pause();
      } else {
        await widget.playbackBridge.play();
      }
    });
  }

  Future<void> _stop() => _runOperation(PlayerOperation.playbackCommand, widget.playbackBridge.stop);
  Future<void> _retry() => _runOperation(PlayerOperation.playbackCommand, widget.playbackBridge.retry);
  Future<void> _seekTo(double positionMs) => _runOperation(
        PlayerOperation.seeking,
        () => widget.playbackBridge.seekTo(positionMs.round()),
      );

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

  Future<void> _resetMetrics() => _runOperation(PlayerOperation.resettingMetrics, widget.playbackBridge.resetMetrics);

  void _addToQueue(CatalogTrackSummary track) {
    final exists = _queue.any((item) => item.trackId == track.trackId);
    setState(() {
      if (!exists) _queue = [..._queue, track];
      _queueCurrentTrackId ??= track.trackId;
      _queueStatus = exists ? '${track.title} is already in queue.' : '${track.title} added to queue.';
    });
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
    });
  }

  void _clearQueue() {
    if (_queueDisabled) return;
    setState(() {
      _queue = const [];
      _queueCurrentTrackId = null;
      _lastAutoAdvanceTrackId = null;
      _queueStatus = 'Queue cleared.';
    });
  }

  Future<void> _playQueueTrack(
    CatalogTrackSummary track, {
    bool autoStart = false,
    QueueAdvanceSource source = QueueAdvanceSource.manual,
  }) async {
    final operation = source == QueueAdvanceSource.auto
        ? PlayerOperation.autoAdvance
        : PlayerOperation.queueAdvance;
    final status = switch (source) {
      QueueAdvanceSource.auto => 'Auto-advanced to ${track.title}.',
      QueueAdvanceSource.next => 'Skipped to next: ${track.title}.',
      QueueAdvanceSource.previous => 'Returned to previous: ${track.title}.',
      QueueAdvanceSource.manual => 'Queue selected: ${track.title}.',
    };
    if (source == QueueAdvanceSource.auto) setState(() => _autoAdvanceCount += 1);
    setState(() {
      _queueCurrentTrackId = track.trackId;
      _queueStatus = status;
    });
    await _loadCatalogTrack(
      trackId: track.trackId,
      autoPlay: autoStart,
      operation: operation,
      status: status,
    );
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
    final progress = durationMs == null || durationMs <= 0
        ? 0.0
        : (displayedPositionMs / durationMs).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF060810),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TopBar(),
                  const SizedBox(height: 22),
                  _NowPlayingCard(
                    metrics: _metrics,
                    manifest: _manifest,
                    nextTrack: _nextQueueTrack,
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
                    onSeekChanged: durationMs == null || durationMs <= 0 || _operation == PlayerOperation.seeking
                        ? null
                        : (value) => setState(() => _dragPositionMs = value * durationMs),
                    onSeekEnd: durationMs == null || durationMs <= 0 || _operation == PlayerOperation.seeking
                        ? null
                        : (value) async {
                            final target = value * durationMs;
                            setState(() => _dragPositionMs = null);
                            await _seekTo(target);
                          },
                  ),
                  const SizedBox(height: 12),
                  _StatusStrip(
                    status: _statusText,
                    detail: _statusDetail,
                    operation: _operation.label,
                    refreshingMetrics: _refreshingMetrics,
                  ),
                  const SizedBox(height: 16),
                  _QueueCard(
                    queue: _queue,
                    currentTrackId: _queueCurrentTrackId,
                    currentIndex: _queueIndex,
                    status: _queueStatus,
                    controlsDisabled: _queueDisabled,
                    autoAdvanceEnabled: _autoAdvanceEnabled,
                    autoAdvanceCount: _autoAdvanceCount,
                    onToggleAutoAdvance: (value) => setState(() {
                      _autoAdvanceEnabled = value;
                      _queueStatus = value ? 'Auto-advance enabled.' : 'Auto-advance disabled.';
                    }),
                    onPlayTrack: (track) => _playQueueTrack(track, autoStart: _metrics.isPlaying),
                    onRemoveTrack: _removeFromQueue,
                    onClearQueue: _clearQueue,
                  ),
                  const SizedBox(height: 16),
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
                  ),
                  const SizedBox(height: 16),
                  _TrackSetupCard(
                    titleController: _titleController,
                    urlController: _urlController,
                    apiBaseUrlController: _apiBaseUrlController,
                    catalogStatus: _catalogStatus,
                    loading: _manualDisabled,
                    onLoadCatalog: () => _loadCatalogTrack(),
                    onLoadTrack: _loadManualTrack,
                  ),
                  const SizedBox(height: 16),
                  _HealthStrip(metrics: _metrics),
                  const SizedBox(height: 16),
                  _MetricsToggle(
                    showMetrics: _showMetrics,
                    operationBusy: _operation != PlayerOperation.idle,
                    onToggle: () => setState(() => _showMetrics = !_showMetrics),
                    onCopyMetrics: _copyMetrics,
                    onResetMetrics: _resetMetrics,
                  ),
                  if (_showMetrics) ...[
                    const SizedBox(height: 14),
                    _MetricsPanel(metrics: _metrics),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _MiniPlayer(metrics: _metrics, manifest: _manifest),
    );
  }
}

enum QueueAdvanceSource { manual, next, previous, auto }

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WaveZero', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.1)),
              SizedBox(height: 4),
              Text('Native playback. Clear state. Real local catalog.', style: TextStyle(color: Color(0xFF98A1B8), fontSize: 14)),
            ],
          ),
        ),
        Icon(Icons.graphic_eq, color: Color(0xFF8D7CFF)),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.status, required this.detail, required this.operation, required this.refreshingMetrics});

  final String status;
  final String detail;
  final String operation;
  final bool refreshingMetrics;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(refreshingMetrics ? Icons.sync : Icons.radio_button_checked, color: const Color(0xFF8D7CFF), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(operation, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 11)),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Artwork(artworkUrl: manifest?.artworkUrl),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status, style: const TextStyle(color: Color(0xFF8D7CFF), fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                    const SizedBox(height: 8),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFA6AEC2))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Slider(value: progressValue, onChanged: onSeekChanged, onChangeEnd: onSeekEnd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(_formatTime(displayedPositionMs), style: _timeStyle), Text(_formatTime(durationMs), style: _timeStyle)],
          ),
          if (nextTrack != null) ...[
            const SizedBox(height: 10),
            Text('Up next: ${nextTrack!.title}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(onPressed: controlsDisabled || !canPlayPrevious ? null : onPrevious, icon: const Icon(Icons.skip_previous)),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: controlsDisabled ? null : onRetry, icon: const Icon(Icons.replay)),
              const SizedBox(width: 14),
              SizedBox(
                width: 72,
                height: 72,
                child: FilledButton(
                  onPressed: controlsDisabled ? null : onPlayPause,
                  style: FilledButton.styleFrom(shape: const CircleBorder()),
                  child: Icon(metrics.isPlaying ? Icons.pause : Icons.play_arrow, size: 36),
                ),
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(onPressed: controlsDisabled ? null : onStop, icon: const Icon(Icons.stop)),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: controlsDisabled || !canPlayNext ? null : onNext, icon: const Icon(Icons.skip_next)),
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
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7C5CFF), Color(0xFF14182A), Color(0xFF00D4FF)]),
      ),
      child: url == null || url.trim().isEmpty
          ? Icon(Icons.music_note_rounded, size: size * 0.4, color: Colors.white)
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.music_note_rounded, size: size * 0.4, color: Colors.white)),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.queue, required this.currentTrackId, required this.currentIndex, required this.status, required this.controlsDisabled, required this.autoAdvanceEnabled, required this.autoAdvanceCount, required this.onToggleAutoAdvance, required this.onPlayTrack, required this.onRemoveTrack, required this.onClearQueue});

  final List<CatalogTrackSummary> queue;
  final String? currentTrackId;
  final int currentIndex;
  final String status;
  final bool controlsDisabled;
  final bool autoAdvanceEnabled;
  final int autoAdvanceCount;
  final ValueChanged<bool> onToggleAutoAdvance;
  final ValueChanged<CatalogTrackSummary> onPlayTrack;
  final ValueChanged<CatalogTrackSummary> onRemoveTrack;
  final VoidCallback onClearQueue;

  @override
  Widget build(BuildContext context) {
    final nextTrack = currentIndex >= 0 && currentIndex < queue.length - 1 ? queue[currentIndex + 1] : null;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Queue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Current, up next, and auto-advance.', style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13))])),
            Text('${queue.length} tracks', style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
            const SizedBox(width: 8),
            IconButton.outlined(onPressed: queue.isEmpty || controlsDisabled ? null : onClearQueue, icon: const Icon(Icons.clear_all)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text(nextTrack == null ? 'No next track yet.' : 'Auto-advance to ${nextTrack.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFD7DDF0), fontSize: 12))),
            Text('$autoAdvanceCount auto', style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 11)),
            Switch(value: autoAdvanceEnabled, onChanged: controlsDisabled ? null : onToggleAutoAdvance),
          ]),
          Text(status, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
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
                  onPlay: () => onPlayTrack(entry.$2),
                  onRemove: () => onRemoveTrack(entry.$2),
                )),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.track, required this.index, required this.current, required this.upNext, required this.disabled, required this.onPlay, required this.onRemove});

  final CatalogTrackSummary track;
  final int index;
  final bool current;
  final bool upNext;
  final bool disabled;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = current ? 'Now' : upNext ? 'Up next' : '#${index + 1}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: current ? const Color(0x227C5CFF) : const Color(0xFF0B0E18), borderRadius: BorderRadius.circular(18), border: Border.all(color: current ? const Color(0xFF8D7CFF) : const Color(0xFF20273A))),
      child: Row(children: [
        Icon(current ? Icons.equalizer : Icons.queue_music, color: const Color(0xFF8D7CFF)),
        const SizedBox(width: 12),
        Expanded(child: Text('${track.title}  $label', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
        IconButton(onPressed: disabled ? null : onPlay, icon: Icon(current ? Icons.check_circle : Icons.play_arrow, color: const Color(0xFF8D7CFF))),
        IconButton(onPressed: disabled ? null : onRemove, icon: const Icon(Icons.close, color: Color(0xFF98A1B8))),
      ]),
    );
  }
}

class _CatalogListCard extends StatelessWidget {
  const _CatalogListCard({required this.tracks, required this.totalTrackCount, required this.selectedTrackId, required this.status, required this.loading, required this.refreshDisabled, required this.addToQueueDisabled, required this.searchController, required this.onClearSearch, required this.onRefresh, required this.onSelectTrack, required this.onAddToQueue});

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

  @override
  Widget build(BuildContext context) {
    final hasQuery = searchController.text.trim().isNotEmpty;
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Catalog', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), SizedBox(height: 4), Text('Search stays usable while playback is running.', style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13))])),
          IconButton.outlined(onPressed: refreshDisabled ? null : onRefresh, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: searchController, decoration: InputDecoration(labelText: 'Search catalog', prefixIcon: const Icon(Icons.search), suffixIcon: hasQuery ? IconButton(onPressed: onClearSearch, icon: const Icon(Icons.close)) : null)),
        const SizedBox(height: 10),
        Text(hasQuery ? '$status Showing ${tracks.length} of $totalTrackCount.' : status, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
        const SizedBox(height: 12),
        if (totalTrackCount == 0)
          const _EmptyCatalogMessage(message: 'No catalog tracks loaded yet.')
        else if (tracks.isEmpty)
          const _EmptyCatalogMessage(message: 'No tracks match this search.')
        else
          ...tracks.map((track) => _CatalogRow(track: track, selected: track.trackId == selectedTrackId, addDisabled: addToQueueDisabled, onTap: () => onSelectTrack(track), onAdd: () => onAddToQueue(track))),
      ]),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.track, required this.selected, required this.addDisabled, required this.onTap, required this.onAdd});

  final CatalogTrackSummary track;
  final bool selected;
  final bool addDisabled;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(_trackSubtitle(track), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12))])),
          Text(_formatTime(track.durationMs), style: _timeStyle),
          IconButton(onPressed: addDisabled ? null : onAdd, icon: const Icon(Icons.playlist_add, color: Color(0xFF8D7CFF))),
          Icon(selected ? Icons.check_circle : Icons.play_circle_outline, color: const Color(0xFF8D7CFF)),
        ]),
      ),
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
  Widget build(BuildContext context) {
    return _Panel(
      child: ExpansionTile(
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
      ),
    );
  }
}

class _HealthStrip extends StatelessWidget {
  const _HealthStrip({required this.metrics});
  final PlaybackMetrics metrics;
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _HealthChip(label: 'Tap to audio', value: _formatMetric(metrics.tapToFirstAudioMs), good: metrics.tapToFirstAudioMs != null && metrics.tapToFirstAudioMs! < 800),
      _HealthChip(label: 'Preload ready', value: _formatMetric(metrics.loadToReadyMs), good: metrics.preparedBeforePlay),
      _HealthChip(label: 'Rebuffers', value: metrics.rebufferCount.toString(), good: metrics.rebufferCount == 0),
      _HealthChip(label: 'Error', value: metrics.playbackError == null ? 'None' : 'Check', good: metrics.playbackError == null),
    ]);
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.label, required this.value, required this.good});
  final String label;
  final String value;
  final bool good;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: good ? const Color(0x1725D882) : const Color(0x22FFB020), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: const TextStyle(color: Color(0xFF9BA3B4), fontSize: 12)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
    );
  }
}

class _MetricsToggle extends StatelessWidget {
  const _MetricsToggle({required this.showMetrics, required this.operationBusy, required this.onToggle, required this.onCopyMetrics, required this.onResetMetrics});
  final bool showMetrics;
  final bool operationBusy;
  final VoidCallback onToggle;
  final VoidCallback onCopyMetrics;
  final VoidCallback onResetMetrics;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: OutlinedButton.icon(onPressed: onToggle, icon: Icon(showMetrics ? Icons.expand_less : Icons.analytics_outlined), label: Text(showMetrics ? 'Hide metrics' : 'Show metrics'))),
      const SizedBox(width: 10),
      IconButton.outlined(onPressed: operationBusy ? null : onCopyMetrics, icon: const Icon(Icons.copy)),
      const SizedBox(width: 10),
      IconButton.outlined(onPressed: operationBusy ? null : onResetMetrics, icon: const Icon(Icons.restart_alt)),
    ]);
  }
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.metrics});
  final PlaybackMetrics metrics;
  @override
  Widget build(BuildContext context) {
    return _Panel(child: SelectableText(metrics.toDisplayText(), style: const TextStyle(color: Color(0xFFD7DDF0), fontFamily: 'monospace', height: 1.45)));
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.metrics, required this.manifest});
  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  @override
  Widget build(BuildContext context) {
    return SafeArea(top: false, child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), color: const Color(0xFF0B0E18), child: Row(children: [const Icon(Icons.album, color: Color(0xFF8D7CFF)), const SizedBox(width: 12), Expanded(child: Text(metrics.trackTitle ?? manifest?.title ?? 'No track loaded', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))), const SizedBox(width: 12), Text(_formatTime(metrics.currentPositionMs), style: _timeStyle)])));
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(decoration: BoxDecoration(color: const Color(0xFF111521), borderRadius: BorderRadius.circular(26), border: Border.all(color: const Color(0xFF273048))), child: Padding(padding: padding, child: child));
  }
}

class _EmptyCatalogMessage extends StatelessWidget {
  const _EmptyCatalogMessage({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF0B0E18), borderRadius: BorderRadius.circular(18)), child: Text(message, style: const TextStyle(color: Color(0xFF98A1B8))));
}

CatalogTrackSummary? _findTrack(List<CatalogTrackSummary> tracks, String? trackId) {
  if (trackId == null) return null;
  for (final track in tracks) {
    if (track.trackId == trackId) return track;
  }
  return null;
}

String _trackSubtitle(CatalogTrackSummary track) {
  final asset = track.primaryAsset;
  final parts = <String>[track.subtitle];
  if (asset?.codec != null) parts.add(asset!.codec!);
  if (asset?.bitrateKbps != null) parts.add('${asset!.bitrateKbps}kbps');
  return parts.join(' • ');
}

String _statusFromEvent(String? event) {
  switch (event) {
    case 'track_loaded':
    case 'buffering_started':
      return 'Preparing';
    case 'ready':
    case 'buffering_ended':
    case 'manifest_loaded':
      return 'Ready';
    case 'not_playing':
      return 'Paused';
    case 'stopped':
      return 'Stopped';
    case 'ended':
    case 'playback_ended':
      return 'Ended';
    default:
      return 'Ready';
  }
}

String _formatMetric(int? valueMs) => valueMs == null ? '—' : '${valueMs}ms';

String _formatTime(int? valueMs) {
  if (valueMs == null || valueMs < 0) return '—:—';
  final totalSeconds = (valueMs / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

const _timeStyle = TextStyle(color: Color(0xFF9BA3B4), fontSize: 12);
