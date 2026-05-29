import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../playback/playback_bridge.dart';
import '../playback/playback_metrics.dart';
import '../playback/test_track.dart';

class WaveZeroApp extends StatelessWidget {
  const WaveZeroApp({
    super.key,
    PlaybackBridge? playbackBridge,
  }) : _playbackBridge = playbackBridge;

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
      home: PlaybackProofScreen(
        playbackBridge: _playbackBridge ?? MockPlaybackBridge(),
      ),
    );
  }
}

class PlaybackProofScreen extends StatefulWidget {
  const PlaybackProofScreen({
    super.key,
    required this.playbackBridge,
  });

  final PlaybackBridge playbackBridge;

  @override
  State<PlaybackProofScreen> createState() => _PlaybackProofScreenState();
}

class _PlaybackProofScreenState extends State<PlaybackProofScreen> {
  late final TextEditingController _urlController;
  PlaybackMetrics _metrics = const PlaybackMetrics();
  String _trackTitle = waveZeroTestTrack.title;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: waveZeroTestTrack.url);
    _loadInitialTrack();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialTrack() async {
    await _runBridgeCommand(() async {
      await widget.playbackBridge.loadTrack(
        title: _trackTitle,
        url: _urlController.text,
      );
    });
  }

  Future<void> _runBridgeCommand(Future<void> Function() command) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await command();
      final nextMetrics = await widget.playbackBridge.metricsSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _metrics = nextMetrics;
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _copyMetrics() async {
    await Clipboard.setData(ClipboardData(text: _metrics.toDisplayText()));
    if (!mounted) {
      return;
    }
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
                children: <Widget>[
                  const _Header(),
                  const SizedBox(height: 28),
                  _TrackCard(
                    trackTitle: _trackTitle,
                    urlController: _urlController,
                    onTitleChanged: (value) => _trackTitle = value,
                    onLoadTrack: () => _runBridgeCommand(() async {
                      await widget.playbackBridge.loadTrack(
                        title: _trackTitle,
                        url: _urlController.text,
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  _Controls(
                    isPlaying: _metrics.isPlaying,
                    busy: _busy,
                    onPlayPause: () => _runBridgeCommand(() {
                      return _metrics.isPlaying
                          ? widget.playbackBridge.pause()
                          : widget.playbackBridge.play();
                    }),
                    onStop: () => _runBridgeCommand(widget.playbackBridge.stop),
                    onRetry: () => _runBridgeCommand(widget.playbackBridge.retry),
                    onResetMetrics: () =>
                        _runBridgeCommand(widget.playbackBridge.resetMetrics),
                    onCopyMetrics: _copyMetrics,
                  ),
                  const SizedBox(height: 20),
                  _MetricsPanel(metrics: _metrics),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'WaveZero',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Max Stack playback proof: Flutter UI commanding native playback.',
          style: TextStyle(color: Color(0xFF9BA3B4), fontSize: 16),
        ),
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.trackTitle,
    required this.urlController,
    required this.onTitleChanged,
    required this.onLoadTrack,
  });

  final String trackTitle;
  final TextEditingController urlController;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onLoadTrack;

  @override
  Widget build(BuildContext context) {
    return _PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Current Test Track',
            style: TextStyle(fontSize: 13, color: Color(0xFF9BA3B4)),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: trackTitle,
            decoration: const InputDecoration(labelText: 'Title'),
            onChanged: onTitleChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: urlController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'HLS URL'),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onLoadTrack,
            icon: const Icon(Icons.library_music_outlined),
            label: const Text('Load Track'),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.isPlaying,
    required this.busy,
    required this.onPlayPause,
    required this.onStop,
    required this.onRetry,
    required this.onResetMetrics,
    required this.onCopyMetrics,
  });

  final bool isPlaying;
  final bool busy;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onRetry;
  final VoidCallback onResetMetrics;
  final VoidCallback onCopyMetrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        FilledButton.icon(
          onPressed: busy ? null : onPlayPause,
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          label: Text(isPlaying ? 'Pause' : 'Play'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onStop,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : onResetMetrics,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset Metrics'),
        ),
        OutlinedButton.icon(
          onPressed: onCopyMetrics,
          icon: const Icon(Icons.copy),
          label: const Text('Copy Metrics'),
        ),
      ],
    );
  }
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.metrics});

  final PlaybackMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return _PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Metrics Snapshot',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SelectableText(
            metrics.toDisplayText(),
            style: const TextStyle(
              color: Color(0xFFD7DDF0),
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111521),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF273048)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}
