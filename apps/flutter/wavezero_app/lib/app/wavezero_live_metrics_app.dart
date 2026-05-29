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
      home: _LiveMetricsScreen(
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

class _LiveMetricsScreen extends StatefulWidget {
  const _LiveMetricsScreen({required this.playbackBridge});

  final PlaybackBridge playbackBridge;

  @override
  State<_LiveMetricsScreen> createState() => _LiveMetricsScreenState();
}

class _LiveMetricsScreenState extends State<_LiveMetricsScreen> {
  static const _refreshInterval = Duration(milliseconds: 500);

  late final TextEditingController _urlController;
  Timer? _poller;
  PlaybackMetrics _metrics = const PlaybackMetrics();
  String _trackTitle = waveZeroTestTrack.title;
  bool _busy = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: waveZeroTestTrack.url);
    _poller = Timer.periodic(_refreshInterval, (_) => _refreshMetrics());
    _runCommand(() {
      return widget.playbackBridge.loadTrack(
        title: _trackTitle,
        url: _urlController.text,
      );
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A12),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'WaveZero',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Live playback metrics proof: Flutter UI commanding native Media3.',
                    style: TextStyle(color: Color(0xFF9BA3B4), fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: TextEditingController(text: _trackTitle),
                          decoration: const InputDecoration(labelText: 'Title'),
                          onChanged: (value) => _trackTitle = value,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _urlController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'HLS URL'),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: _busy
                              ? null
                              : () => _runCommand(() {
                                    return widget.playbackBridge.loadTrack(
                                      title: _trackTitle,
                                      url: _urlController.text,
                                    );
                                  }),
                          icon: const Icon(Icons.library_music_outlined),
                          label: const Text('Load Track'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _runCommand(
                                  _metrics.isPlaying
                                      ? widget.playbackBridge.pause
                                      : widget.playbackBridge.play,
                                ),
                        icon: Icon(_metrics.isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_metrics.isPlaying ? 'Pause' : 'Play'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _runCommand(widget.playbackBridge.stop),
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _runCommand(widget.playbackBridge.retry),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _runCommand(widget.playbackBridge.resetMetrics),
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset Metrics'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _copyMetrics,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy Metrics'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Metrics Snapshot',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          _metrics.toDisplayText(),
                          style: const TextStyle(
                            color: Color(0xFFD7DDF0),
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111521),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF273048)),
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
