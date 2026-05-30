import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog/catalog_client.dart';
import '../catalog/catalog_track_manifest.dart';
import '../playback/playback_bridge.dart';
import '../playback/playback_metrics.dart';
import '../playback/test_track.dart';

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
      home: _PlayerScreen(
        playbackBridge: _playbackBridge ?? _defaultPlaybackBridge(),
      ),
    );
  }

  PlaybackBridge _defaultPlaybackBridge() {
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
  CatalogTrackManifest? _catalogManifest;
  List<CatalogTrackSummary> _catalogTracks = const [];
  List<CatalogTrackSummary> _queue = const [];
  String? _selectedTrackId;
  String? _queueCurrentTrackId;
  String? _lastAutoAdvanceTrackId;
  bool _busy = false;
  bool _refreshing = false;
  bool _showMetrics = false;
  bool _catalogLoading = false;
  bool _catalogListLoading = false;
  bool _autoAdvanceEnabled = true;
  bool _autoAdvancing = false;
  int _autoAdvanceCount = 0;
  String _catalogStatus = 'Catalog not loaded yet.';
  String _catalogListStatus = 'Catalog list not loaded yet.';
  String _queueStatus = 'Queue is ready.';
  String _catalogQuery = '';
  double? _dragPositionMs;

  List<CatalogTrackSummary> get _filteredCatalogTracks => _catalogTracks
      .where((track) => track.matchesQuery(_catalogQuery))
      .toList(growable: false);

  int get _queueCurrentIndex {
    final id = _queueCurrentTrackId ?? _selectedTrackId;
    if (id == null) return -1;
    return _queue.indexWhere((track) => track.trackId == id);
  }

  bool get _canPlayPrevious => _queueCurrentIndex > 0;
  bool get _canPlayNext => _queueCurrentIndex >= 0 && _queueCurrentIndex < _queue.length - 1;

  CatalogTrackSummary? get _currentQueueTrack {
    final index = _queueCurrentIndex;
    if (index < 0 || index >= _queue.length) return null;
    return _queue[index];
  }

  CatalogTrackSummary? get _nextQueueTrack {
    final index = _queueCurrentIndex;
    if (index < 0 || index >= _queue.length - 1) return null;
    return _queue[index + 1];
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: waveZeroTestTrack.title);
    _urlController = TextEditingController(text: waveZeroTestTrack.url);
    _apiBaseUrlController = TextEditingController(text: CatalogClient.defaultBaseUrl);
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() => _catalogQuery = _searchController.text);
    });
    _poller = Timer.periodic(_refreshInterval, (_) => _refreshMetrics());
    _loadCatalogListAndInitialTrack(fallbackToDemo: true);
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

  Future<void> _refreshMetrics() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final nextMetrics = await widget.playbackBridge.metricsSnapshot();
      if (!mounted) return;
      setState(() => _metrics = nextMetrics);
      await _maybeAutoAdvance(nextMetrics);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _maybeAutoAdvance(PlaybackMetrics metrics) async {
    if (!_autoAdvanceEnabled || _autoAdvancing || _busy || _catalogLoading) return;
    if (!_canPlayNext) return;

    final durationMs = metrics.durationMs ?? _catalogManifest?.durationMs;
    if (durationMs == null || durationMs <= 0) return;

    final remainingMs = durationMs - metrics.currentPositionMs;
    final nearEnd = metrics.currentPositionMs > 0 && remainingMs <= _autoAdvanceThresholdMs;
    final endedEvent = metrics.lastEvent == 'ended' || metrics.lastEvent == 'playback_ended';

    if (!nearEnd && !endedEvent) {
      if (metrics.currentPositionMs < durationMs - (_autoAdvanceThresholdMs * 2)) {
        _lastAutoAdvanceTrackId = null;
      }
      return;
    }

    final currentTrackId = _currentQueueTrack?.trackId ?? _queueCurrentTrackId ?? _selectedTrackId;
    if (currentTrackId == null || _lastAutoAdvanceTrackId == currentTrackId) return;

    _lastAutoAdvanceTrackId = currentTrackId;
    setState(() {
      _autoAdvancing = true;
      _queueStatus = 'Auto-advancing to next track...';
    });

    try {
      await _playNextQueueTrack(autoStart: true, source: QueueAdvanceSource.auto);
    } finally {
      if (!mounted) return;
      setState(() => _autoAdvancing = false);
    }
  }

  Future<void> _runCommand(Future<void> Function() command) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await command();
      await _refreshMetrics();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadCatalogListAndInitialTrack({bool fallbackToDemo = false}) async {
    if (_catalogListLoading) return;
    setState(() {
      _catalogListLoading = true;
      _catalogListStatus = 'Loading catalog list...';
      _catalogStatus = 'Loading catalog...';
    });

    final client = CatalogClient(baseUrl: _apiBaseUrlController.text);
    try {
      final catalog = await client.fetchCatalog();
      if (!mounted) return;
      final preferredTrack = _findTrack(catalog.tracks, _selectedTrackId) ??
          (catalog.tracks.isEmpty ? null : catalog.tracks.first);
      setState(() {
        _catalogTracks = catalog.tracks;
        if (_queue.isEmpty) {
          _queue = catalog.tracks;
          _queueCurrentTrackId = preferredTrack?.trackId;
          _queueStatus = catalog.tracks.isEmpty
              ? 'Queue is empty.'
              : 'Queue initialized from catalog.';
        } else {
          _queue = _queue
              .map((queued) => _findTrack(catalog.tracks, queued.trackId) ?? queued)
              .toList(growable: false);
          _queueStatus = 'Queue refreshed with latest catalog metadata.';
        }
        _selectedTrackId = preferredTrack?.trackId;
        _catalogListStatus = catalog.tracks.isEmpty
            ? 'Catalog API returned no tracks.'
            : 'Loaded ${catalog.tracks.length} catalog tracks.';
      });

      if (preferredTrack == null) {
        throw const FormatException('Catalog API returned no playable tracks');
      }
      await _loadCatalogTrack(trackId: preferredTrack.trackId, client: client);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _catalogListStatus = fallbackToDemo
            ? 'Catalog list unavailable. Using local demo track. $error'
            : 'Catalog list load failed. $error';
        _catalogStatus = fallbackToDemo
            ? 'Catalog unavailable. Using local demo track. $error'
            : 'Catalog load failed. $error';
      });
      if (fallbackToDemo) {
        _titleController.text = waveZeroTestTrack.title;
        _urlController.text = waveZeroTestTrack.url;
        await _loadTrack(source: TrackLoadSource.demoFallback);
      }
    } finally {
      client.close();
      if (mounted) setState(() => _catalogListLoading = false);
    }
  }

  Future<void> _loadCatalogTrack({
    String? trackId,
    CatalogClient? client,
    bool closeClient = false,
    bool autoPlay = false,
  }) async {
    if (_catalogLoading) return;
    final targetTrackId = trackId ?? _selectedTrackId ?? 'track-apple-bipbop-hls';
    setState(() {
      _catalogLoading = true;
      _catalogStatus = 'Loading catalog manifest...';
      _selectedTrackId = targetTrackId;
      _queueCurrentTrackId = targetTrackId;
      _lastAutoAdvanceTrackId = targetTrackId;
    });

    final activeClient = client ?? CatalogClient(baseUrl: _apiBaseUrlController.text);
    try {
      final manifest = await activeClient.fetchTrackManifest(trackId: targetTrackId);
      if (!mounted) return;
      _titleController.text = manifest.title;
      _urlController.text = manifest.streamUrl;
      setState(() {
        _catalogManifest = manifest;
        _selectedTrackId = manifest.trackId;
        _queueCurrentTrackId = manifest.trackId;
        _catalogStatus = 'Loaded from catalog API: ${manifest.title}';
      });
      await _loadTrack(source: TrackLoadSource.catalog);
      if (autoPlay) {
        await _runCommand(widget.playbackBridge.play);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _catalogStatus = 'Catalog load failed. $error');
    } finally {
      if (closeClient) activeClient.close();
      if (mounted) setState(() => _catalogLoading = false);
    }
  }

  Future<void> _loadTrack({TrackLoadSource source = TrackLoadSource.manual}) {
    return _runCommand(() async {
      await widget.playbackBridge.loadTrack(
        title: _titleController.text.trim().isEmpty
            ? waveZeroTestTrack.title
            : _titleController.text.trim(),
        url: _urlController.text.trim(),
      );
      if (mounted && source == TrackLoadSource.manual) {
        setState(() => _catalogStatus = 'Manual track loaded.');
      }
    });
  }

  Future<void> _copyMetrics() async {
    final latestMetrics = await widget.playbackBridge.metricsSnapshot();
    if (!mounted) return;
    setState(() => _metrics = latestMetrics);
    await Clipboard.setData(ClipboardData(text: latestMetrics.toDisplayText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Metrics copied')),
    );
  }

  Future<void> _seekTo(double positionMs) {
    return _runCommand(() => widget.playbackBridge.seekTo(positionMs.round()));
  }

  void _addToQueue(CatalogTrackSummary track) {
    final alreadyQueued = _queue.any((queued) => queued.trackId == track.trackId);
    setState(() {
      if (!alreadyQueued) _queue = [..._queue, track];
      _queueCurrentTrackId ??= track.trackId;
      _queueStatus = alreadyQueued
          ? '${track.title} is already in queue.'
          : '${track.title} added to queue.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(alreadyQueued ? '${track.title} is already queued' : '${track.title} added to queue')),
    );
  }

  void _removeFromQueue(CatalogTrackSummary track) {
    setState(() {
      final removedIndex = _queue.indexWhere((queued) => queued.trackId == track.trackId);
      final wasCurrent = track.trackId == _queueCurrentTrackId;
      _queue = _queue.where((queued) => queued.trackId != track.trackId).toList(growable: false);
      if (_queue.isEmpty) {
        _queueCurrentTrackId = null;
        _queueStatus = 'Queue cleared.';
      } else if (wasCurrent) {
        final nextIndex = removedIndex.clamp(0, _queue.length - 1).toInt();
        _queueCurrentTrackId = _queue[nextIndex].trackId;
        _queueStatus = 'Removed current track. Queue moved to ${_queue[nextIndex].title}.';
      } else {
        _queueStatus = '${track.title} removed from queue.';
      }
    });
  }

  void _clearQueue() {
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
    setState(() {
      _queueCurrentTrackId = track.trackId;
      _queueStatus = switch (source) {
        QueueAdvanceSource.auto => 'Auto-advanced to ${track.title}.',
        QueueAdvanceSource.next => 'Skipped to next: ${track.title}.',
        QueueAdvanceSource.previous => 'Returned to previous: ${track.title}.',
        QueueAdvanceSource.manual => 'Queue selected: ${track.title}.',
      };
      if (source == QueueAdvanceSource.auto) _autoAdvanceCount += 1;
    });
    await _loadCatalogTrack(trackId: track.trackId, closeClient: true, autoPlay: autoStart);
  }

  Future<void> _playNextQueueTrack({bool autoStart = false, QueueAdvanceSource source = QueueAdvanceSource.next}) async {
    final index = _queueCurrentIndex;
    if (index < 0 || index >= _queue.length - 1) return;
    await _playQueueTrack(_queue[index + 1], autoStart: autoStart, source: source);
  }

  Future<void> _playPreviousQueueTrack({bool autoStart = false}) async {
    final index = _queueCurrentIndex;
    if (index <= 0) return;
    await _playQueueTrack(_queue[index - 1], autoStart: autoStart, source: QueueAdvanceSource.previous);
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = _metrics.durationMs ?? _catalogManifest?.durationMs;
    final currentPositionMs = _metrics.currentPositionMs;
    final displayedPositionMs = (_dragPositionMs ?? currentPositionMs.toDouble()).round();
    final progressValue = durationMs == null || durationMs <= 0
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
                    manifest: _catalogManifest,
                    nextTrack: _nextQueueTrack,
                    progressValue: progressValue,
                    displayedPositionMs: displayedPositionMs,
                    durationMs: durationMs,
                    busy: _busy,
                    canPlayPrevious: _canPlayPrevious,
                    canPlayNext: _canPlayNext,
                    onPlayPause: () => _runCommand(
                      _metrics.isPlaying
                          ? widget.playbackBridge.pause
                          : widget.playbackBridge.play,
                    ),
                    onStop: () => _runCommand(widget.playbackBridge.stop),
                    onRetry: () => _runCommand(widget.playbackBridge.retry),
                    onPrevious: () => _playPreviousQueueTrack(autoStart: _metrics.isPlaying),
                    onNext: () => _playNextQueueTrack(autoStart: _metrics.isPlaying),
                    onSeekChanged: durationMs == null || durationMs <= 0
                        ? null
                        : (value) => setState(() => _dragPositionMs = value * durationMs),
                    onSeekEnd: durationMs == null || durationMs <= 0
                        ? null
                        : (value) async {
                            final target = value * durationMs;
                            setState(() => _dragPositionMs = null);
                            await _seekTo(target);
                          },
                  ),
                  const SizedBox(height: 16),
                  _QueueCard(
                    queue: _queue,
                    currentTrackId: _queueCurrentTrackId,
                    currentIndex: _queueCurrentIndex,
                    status: _queueStatus,
                    busy: _busy || _catalogLoading || _autoAdvancing,
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
                    tracks: _filteredCatalogTracks,
                    totalTrackCount: _catalogTracks.length,
                    selectedTrackId: _selectedTrackId,
                    status: _catalogListStatus,
                    loading: _catalogListLoading,
                    busy: _busy || _catalogLoading,
                    searchController: _searchController,
                    onClearSearch: () => _searchController.clear(),
                    onRefresh: () => _loadCatalogListAndInitialTrack(),
                    onSelectTrack: (track) => _loadCatalogTrack(
                      trackId: track.trackId,
                      closeClient: true,
                    ),
                    onAddToQueue: _addToQueue,
                  ),
                  const SizedBox(height: 16),
                  _TrackSetupCard(
                    titleController: _titleController,
                    urlController: _urlController,
                    apiBaseUrlController: _apiBaseUrlController,
                    catalogStatus: _catalogStatus,
                    catalogLoading: _catalogLoading,
                    busy: _busy,
                    onLoadCatalog: () => _loadCatalogTrack(closeClient: true),
                    onLoadTrack: () => _loadTrack(),
                  ),
                  const SizedBox(height: 16),
                  _HealthStrip(metrics: _metrics),
                  const SizedBox(height: 16),
                  _MetricsToggle(
                    showMetrics: _showMetrics,
                    onToggle: () => setState(() => _showMetrics = !_showMetrics),
                    onCopyMetrics: _copyMetrics,
                    onResetMetrics: () => _runCommand(widget.playbackBridge.resetMetrics),
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
      bottomNavigationBar: _MiniPlayer(metrics: _metrics, manifest: _catalogManifest),
    );
  }
}

enum TrackLoadSource { catalog, demoFallback, manual }

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
              Text(
                'WaveZero',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Native playback. Fast start. Queue flow.',
                style: TextStyle(color: Color(0xFF98A1B8), fontSize: 14),
              ),
            ],
          ),
        ),
        Icon(Icons.graphic_eq, color: Color(0xFF8D7CFF)),
      ],
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
    required this.busy,
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
  final bool busy;
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
                    Text(
                      status,
                      style: const TextStyle(
                        color: Color(0xFF8D7CFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFA6AEC2)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Slider(
            value: progressValue,
            onChanged: onSeekChanged,
            onChangeEnd: onSeekEnd,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatTime(displayedPositionMs), style: _timeStyle),
              Text(_formatTime(durationMs), style: _timeStyle),
            ],
          ),
          if (nextTrack != null) ...[
            const SizedBox(height: 10),
            Text(
              'Up next: ${nextTrack!.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: busy || !canPlayPrevious ? null : onPrevious,
                icon: const Icon(Icons.skip_previous),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: busy ? null : onRetry,
                icon: const Icon(Icons.replay),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 72,
                height: 72,
                child: FilledButton(
                  onPressed: busy ? null : onPlayPause,
                  style: FilledButton.styleFrom(shape: const CircleBorder()),
                  child: Icon(metrics.isPlaying ? Icons.pause : Icons.play_arrow, size: 36),
                ),
              ),
              const SizedBox(width: 14),
              IconButton.filledTonal(
                onPressed: busy ? null : onStop,
                icon: const Icon(Icons.stop),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: busy || !canPlayNext ? null : onNext,
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C5CFF), Color(0xFF14182A), Color(0xFF00D4FF)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x553C2FFF),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: url == null || url.trim().isEmpty
          ? Icon(Icons.music_note_rounded, size: size * 0.4, color: Colors.white)
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.music_note_rounded,
                    size: size * 0.4,
                    color: Colors.white,
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x33000000), Color(0x66000000)],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.queue,
    required this.currentTrackId,
    required this.currentIndex,
    required this.status,
    required this.busy,
    required this.autoAdvanceEnabled,
    required this.autoAdvanceCount,
    required this.onToggleAutoAdvance,
    required this.onPlayTrack,
    required this.onRemoveTrack,
    required this.onClearQueue,
  });

  final List<CatalogTrackSummary> queue;
  final String? currentTrackId;
  final int currentIndex;
  final String status;
  final bool busy;
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
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Queue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 4),
                    Text('Current, up next, and auto-advance.', style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13)),
                  ],
                ),
              ),
              Text('${queue.length} tracks', style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: queue.isEmpty || busy ? null : onClearQueue,
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF20273A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF8D7CFF), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nextTrack == null
                        ? 'Auto-advance ready. No next track yet.'
                        : 'Auto-advance to ${nextTrack.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFD7DDF0), fontSize: 12),
                  ),
                ),
                Text('$autoAdvanceCount auto', style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 11)),
                Switch(
                  value: autoAdvanceEnabled,
                  onChanged: busy ? null : onToggleAutoAdvance,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(status, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
          const SizedBox(height: 12),
          if (queue.isEmpty)
            const _EmptyCatalogMessage(message: 'Queue is empty. Add tracks from the catalog.')
          else
            ...queue.indexed.map(
              (entry) {
                final index = entry.$1;
                final track = entry.$2;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _QueueTrackTile(
                    track: track,
                    index: index,
                    current: track.trackId == currentTrackId,
                    upNext: index == currentIndex + 1,
                    busy: busy,
                    onPlay: () => onPlayTrack(track),
                    onRemove: () => onRemoveTrack(track),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _QueueTrackTile extends StatelessWidget {
  const _QueueTrackTile({
    required this.track,
    required this.index,
    required this.current,
    required this.upNext,
    required this.busy,
    required this.onPlay,
    required this.onRemove,
  });

  final CatalogTrackSummary track;
  final int index;
  final bool current;
  final bool upNext;
  final bool busy;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = current ? 'Now' : upNext ? 'Up next' : '#${index + 1}';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: current ? const Color(0x227C5CFF) : const Color(0xFF0B0E18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: current ? const Color(0xFF8D7CFF) : const Color(0xFF20273A)),
      ),
      child: Row(
        children: [
          Icon(current ? Icons.equalizer : upNext ? Icons.trending_flat : Icons.queue_music, color: const Color(0xFF8D7CFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    _QueueBadge(label: label),
                  ],
                ),
                const SizedBox(height: 4),
                Text(track.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: busy ? null : onPlay,
            icon: Icon(current ? Icons.check_circle : Icons.play_arrow, color: const Color(0xFF8D7CFF)),
          ),
          IconButton(
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.close, color: Color(0xFF98A1B8)),
          ),
        ],
      ),
    );
  }
}

class _QueueBadge extends StatelessWidget {
  const _QueueBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x227C5CFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x338D7CFF)),
      ),
      child: Text(label, style: const TextStyle(color: Color(0xFFC9BEFF), fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _CatalogListCard extends StatelessWidget {
  const _CatalogListCard({
    required this.tracks,
    required this.totalTrackCount,
    required this.selectedTrackId,
    required this.status,
    required this.loading,
    required this.busy,
    required this.searchController,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onSelectTrack,
    required this.onAddToQueue,
  });

  final List<CatalogTrackSummary> tracks;
  final int totalTrackCount;
  final String? selectedTrackId;
  final String status;
  final bool loading;
  final bool busy;
  final TextEditingController searchController;
  final VoidCallback onClearSearch;
  final VoidCallback onRefresh;
  final ValueChanged<CatalogTrackSummary> onSelectTrack;
  final ValueChanged<CatalogTrackSummary> onAddToQueue;

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
                    Text(
                      'Catalog',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Search, play, or add to queue.',
                      style: TextStyle(color: Color(0xFF98A1B8), fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                onPressed: loading || busy ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Search catalog',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasQuery
                  ? IconButton(
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery ? '$status Showing ${tracks.length} of $totalTrackCount.' : status,
            style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (totalTrackCount == 0)
            const _EmptyCatalogMessage(message: 'No catalog tracks loaded yet.')
          else if (tracks.isEmpty)
            const _EmptyCatalogMessage(message: 'No tracks match this search.')
          else
            ...tracks.map(
              (track) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CatalogTrackTile(
                  track: track,
                  selected: track.trackId == selectedTrackId,
                  busy: busy,
                  onTap: () => onSelectTrack(track),
                  onAddToQueue: () => onAddToQueue(track),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCatalogMessage extends StatelessWidget {
  const _EmptyCatalogMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF20273A)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF98A1B8))),
    );
  }
}

class _CatalogTrackTile extends StatelessWidget {
  const _CatalogTrackTile({
    required this.track,
    required this.selected,
    required this.busy,
    required this.onTap,
    required this.onAddToQueue,
  });

  final CatalogTrackSummary track;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onAddToQueue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0x227C5CFF) : const Color(0xFF0B0E18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF8D7CFF) : const Color(0xFF20273A),
          ),
        ),
        child: Row(
          children: [
            _Artwork(artworkUrl: track.artworkUrl, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _trackSubtitle(track),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(_formatTime(track.durationMs), style: _timeStyle),
            const SizedBox(width: 4),
            IconButton(
              onPressed: busy ? null : onAddToQueue,
              icon: const Icon(Icons.playlist_add, color: Color(0xFF8D7CFF)),
            ),
            Icon(selected ? Icons.check_circle : Icons.play_circle_outline, color: const Color(0xFF8D7CFF)),
          ],
        ),
      ),
    );
  }
}

class _TrackSetupCard extends StatelessWidget {
  const _TrackSetupCard({
    required this.titleController,
    required this.urlController,
    required this.apiBaseUrlController,
    required this.catalogStatus,
    required this.catalogLoading,
    required this.busy,
    required this.onLoadCatalog,
    required this.onLoadTrack,
  });

  final TextEditingController titleController;
  final TextEditingController urlController;
  final TextEditingController apiBaseUrlController;
  final String catalogStatus;
  final bool catalogLoading;
  final bool busy;
  final VoidCallback onLoadCatalog;
  final VoidCallback onLoadTrack;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: const Text('Catalog track setup'),
        subtitle: Text(catalogStatus, maxLines: 2, overflow: TextOverflow.ellipsis),
        children: [
          TextField(
            controller: apiBaseUrlController,
            decoration: const InputDecoration(labelText: 'API base URL'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: urlController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'HLS URL'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: busy || catalogLoading ? null : onLoadCatalog,
                icon: catalogLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download),
                label: const Text('Reload selected/API'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onLoadTrack,
                icon: const Icon(Icons.bolt),
                label: const Text('Load manual track'),
              ),
            ],
          ),
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _HealthChip(
          label: 'Tap to audio',
          value: _formatMetric(metrics.tapToFirstAudioMs),
          good: metrics.tapToFirstAudioMs != null && metrics.tapToFirstAudioMs! < 800,
        ),
        _HealthChip(
          label: 'Preload ready',
          value: _formatMetric(metrics.loadToReadyMs),
          good: metrics.preparedBeforePlay,
        ),
        _HealthChip(
          label: 'Rebuffers',
          value: metrics.rebufferCount.toString(),
          good: metrics.rebufferCount == 0,
        ),
        _HealthChip(
          label: 'Error',
          value: metrics.playbackError == null ? 'None' : 'Check',
          good: metrics.playbackError == null,
        ),
      ],
    );
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
      decoration: BoxDecoration(
        color: good ? const Color(0x1725D882) : const Color(0x22FFB020),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: good ? const Color(0x5525D882) : const Color(0x55FFB020)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9BA3B4), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MetricsToggle extends StatelessWidget {
  const _MetricsToggle({
    required this.showMetrics,
    required this.onToggle,
    required this.onCopyMetrics,
    required this.onResetMetrics,
  });

  final bool showMetrics;
  final VoidCallback onToggle;
  final VoidCallback onCopyMetrics;
  final VoidCallback onResetMetrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onToggle,
            icon: Icon(showMetrics ? Icons.expand_less : Icons.analytics_outlined),
            label: Text(showMetrics ? 'Hide metrics' : 'Show metrics'),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.outlined(onPressed: onCopyMetrics, icon: const Icon(Icons.copy)),
        const SizedBox(width: 10),
        IconButton.outlined(onPressed: onResetMetrics, icon: const Icon(Icons.restart_alt)),
      ],
    );
  }
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.metrics});

  final PlaybackMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: SelectableText(
        metrics.toDisplayText(),
        style: const TextStyle(
          color: Color(0xFFD7DDF0),
          fontFamily: 'monospace',
          height: 1.45,
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.metrics, required this.manifest});

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF0B0E18),
          border: Border(top: BorderSide(color: Color(0xFF20273A))),
        ),
        child: Row(
          children: [
            const Icon(Icons.album, color: Color(0xFF8D7CFF)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metrics.trackTitle ?? manifest?.title ?? 'No track loaded',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (manifest?.artistName != null)
                    Text(
                      manifest!.artistName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF98A1B8), fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(_formatTime(metrics.currentPositionMs), style: _timeStyle),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111521),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF273048)),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 28, offset: Offset(0, 18)),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
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
