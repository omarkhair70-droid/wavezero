import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  Timer? _poller;
  PlaybackMetrics _metrics = const PlaybackMetrics();
  bool _busy = false;
  bool _refreshing = false;
  bool _showMetrics = false;
  double? _dragPositionMs;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: waveZeroTestTrack.title);
    _urlController = TextEditingController(text: waveZeroTestTrack.url);
    _poller = Timer.periodic(_refreshInterval, (_) => _refreshMetrics());
    _loadTrack();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _refreshMetrics() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final nextMetrics = await widget.playbackBridge.metricsSnapshot();
      if (!mounted) return;
      setState(() => _metrics = nextMetrics);
    } finally {
      _refreshing = false;
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

  Future<void> _loadTrack() {
    return _runCommand(() {
      return widget.playbackBridge.loadTrack(
        title: _titleController.text.trim().isEmpty
            ? waveZeroTestTrack.title
            : _titleController.text.trim(),
        url: _urlController.text.trim(),
      );
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

  @override
  Widget build(BuildContext context) {
    final durationMs = _metrics.durationMs;
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
                    progressValue: progressValue,
                    displayedPositionMs: displayedPositionMs,
                    durationMs: durationMs,
                    busy: _busy,
                    onPlayPause: () => _runCommand(
                      _metrics.isPlaying
                          ? widget.playbackBridge.pause
                          : widget.playbackBridge.play,
                    ),
                    onStop: () => _runCommand(widget.playbackBridge.stop),
                    onRetry: () => _runCommand(widget.playbackBridge.retry),
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
                  _TrackSetupCard(
                    titleController: _titleController,
                    urlController: _urlController,
                    busy: _busy,
                    onLoadTrack: _loadTrack,
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
      bottomNavigationBar: _MiniPlayer(metrics: _metrics),
    );
  }
}

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
                'Native playback. Fast start. Real controls.',
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
    required this.progressValue,
    required this.displayedPositionMs,
    required this.durationMs,
    required this.busy,
    required this.onPlayPause,
    required this.onStop,
    required this.onRetry,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  final PlaybackMetrics metrics;
  final double progressValue;
  final int displayedPositionMs;
  final int? durationMs;
  final bool busy;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onRetry;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? waveZeroTestTrack.title;
    final status = metrics.isPlaying ? 'Playing' : _statusFromEvent(metrics.lastEvent);

    return _Panel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Artwork(),
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
                    const Text(
                      'WaveZero playback proof',
                      style: TextStyle(color: Color(0xFFA6AEC2)),
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
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: busy ? null : onRetry,
                icon: const Icon(Icons.replay),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 72,
                height: 72,
                child: FilledButton(
                  onPressed: busy ? null : onPlayPause,
                  style: FilledButton.styleFrom(shape: const CircleBorder()),
                  child: Icon(metrics.isPlaying ? Icons.pause : Icons.play_arrow, size: 36),
                ),
              ),
              const SizedBox(width: 18),
              IconButton.filledTonal(
                onPressed: busy ? null : onStop,
                icon: const Icon(Icons.stop),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
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
      child: const Icon(Icons.music_note_rounded, size: 48, color: Colors.white),
    );
  }
}

class _TrackSetupCard extends StatelessWidget {
  const _TrackSetupCard({
    required this.titleController,
    required this.urlController,
    required this.busy,
    required this.onLoadTrack,
  });

  final TextEditingController titleController;
  final TextEditingController urlController;
  final bool busy;
  final VoidCallback onLoadTrack;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: const Text('Test track setup'),
        subtitle: const Text('Load prepares playback before Play.'),
        children: [
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
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: busy ? null : onLoadTrack,
              icon: const Icon(Icons.bolt),
              label: const Text('Load & Prepare'),
            ),
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
  const _MiniPlayer({required this.metrics});

  final PlaybackMetrics metrics;

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
              child: Text(
                metrics.trackTitle ?? 'No track loaded',
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
