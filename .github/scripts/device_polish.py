from pathlib import Path
import re

repo = Path(__file__).resolve().parents[2]
app_path = repo / 'apps/flutter/wavezero_app/lib/app/wavezero_app.dart'
player_path = repo / 'apps/flutter/wavezero_app/lib/features/playback/consumer_player.dart'
test_path = repo / 'apps/flutter/wavezero_app/test/features/playback/consumer_player_test.dart'

app = app_path.read_text()
player = player_path.read_text()
tests = test_path.read_text()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, got {count}')
    return text.replace(old, new, 1)


def regex_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one regex match, got {count}')
    return updated


app = replace_once(
    app,
    '  WzAppTab _selectedTab = WzAppTab.home;\n',
    '  WzAppTab _selectedTab = WzAppTab.home;\n  final List<WzAppTab> _navigationHistory = <WzAppTab>[];\n',
    'navigation history field',
)

app = regex_once(
    app,
    r'  CatalogTrackSummary\? get _currentKnownTrack \{.*?\n  \}\n\n  List<CatalogTrackSummary> get _deviceCatalogTracks',
    '''  CatalogTrackSummary? get _currentKnownTrack {
    final id = _manifest?.trackId ?? _metrics.currentTrackId ?? _queueCurrentTrackId ?? _selectedTrackId;
    if (id == null || id.isEmpty) return null;

    final candidates = <CatalogTrackSummary>[
      ..._queue,
      ..._catalog,
      ..._deviceCatalogTracks,
      ..._cachedCatalogTracks,
      if (_developerMode) ..._cloudCatalogTracks,
    ];
    for (final track in candidates) {
      if (track.trackId == id) return track;
    }

    final manifest = _manifest;
    if (manifest != null && manifest.trackId == id) {
      return CatalogTrackSummary(
        trackId: manifest.trackId,
        title: manifest.title,
        artistId: manifest.artistId,
        artistName: manifest.artistName,
        durationMs: manifest.durationMs,
        artworkUrl: manifest.artworkUrl,
        source: isWzDeviceTrackId(manifest.trackId) ? 'device' : 'api',
        license: manifest.license,
      );
    }
    return null;
  }

  List<CatalogTrackSummary> get _deviceCatalogTracks''',
    'current known track resolver',
)

app = replace_once(
    app,
    '''  void _openSearch({String? query}) {
    if (query != null) _fullSearchController.text = query;
    setState(() => _selectedTab = WzAppTab.search);
  }
''',
    '''  void _openSearch({String? query}) {
    if (query != null) _fullSearchController.text = query;
    _navigateTo(WzAppTab.search);
  }
''',
    'search navigation',
)

app = replace_once(
    app,
    '''  void _navigateTo(WzAppTab tab) {
    if (tab == WzAppTab.engine && !_developerMode) return;
    setState(() => _selectedTab = tab);
  }
''',
    '''  void _navigateTo(WzAppTab tab, {bool remember = true}) {
    if (tab == WzAppTab.engine && !_developerMode) return;
    if (tab == _selectedTab) return;
    setState(() {
      if (remember && (_navigationHistory.isEmpty || _navigationHistory.last != _selectedTab)) {
        _navigationHistory.add(_selectedTab);
      }
      _selectedTab = tab;
    });
  }

  void _navigateBack({WzAppTab fallback = WzAppTab.home}) {
    setState(() {
      while (_navigationHistory.isNotEmpty) {
        final previous = _navigationHistory.removeLast();
        if (previous == WzAppTab.engine && !_developerMode) continue;
        if (previous == _selectedTab) continue;
        _selectedTab = previous;
        return;
      }
      _selectedTab = fallback;
    });
  }

  bool get _hasInternalBack => _navigationHistory.isNotEmpty || _selectedTab != WzAppTab.home;
''',
    'navigation methods',
)

app, back_count = re.subn(
    r'onBack: \(\) => _navigateTo\(WzAppTab\.([A-Za-z]+)\),',
    r'onBack: () => _navigateBack(fallback: WzAppTab.\1),',
    app,
)
if back_count < 5:
    raise SystemExit(f'back callbacks: expected at least 5 replacements, got {back_count}')

new_player_method = '''  Future<void> _showPremiumPlayerSheet() async {
    if (_manifest == null && _metrics.trackTitle == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x33788792),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 1,
        child: WzConsumerNowPlayingPage(
          onClose: () => Navigator.of(sheetContext).maybePop(),
          surfaceBuilder: (_) {
            final durationMs = _metrics.durationMs ?? _manifest?.durationMs;
            final displayedPositionMs = (_dragPositionMs ?? _metrics.currentPositionMs.toDouble()).round();
            final progress = durationMs == null || durationMs <= 0
                ? 0.0
                : (displayedPositionMs / durationMs).clamp(0.0, 1.0).toDouble();
            final currentTrack = _currentKnownTrack;
            return WzConsumerPlayerSurface(
              metrics: _metrics,
              manifest: _manifest,
              nextTrack: _upNextQueueTrack,
              progressValue: progress,
              displayedPositionMs: displayedPositionMs,
              durationMs: durationMs,
              controlsDisabled: _playerDisabled,
              canPlayPrevious: _canPrevious,
              canPlayNext: _canPlayNextControl,
              onPlayPause: _playPause,
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
              canSaveTrack: currentTrack != null,
              liked: currentTrack == null ? false : _isLiked(currentTrack.trackId),
              onToggleLike: currentTrack == null ? null : () => _toggleLikedTrack(currentTrack),
              onAddToCollection: currentTrack == null ? null : () => _showAddToCollectionSheet(currentTrack),
              onAddToQueue: currentTrack == null ? null : () => _addToQueue(currentTrack),
              onOpenQueue: _showQueueSheet,
              shuffleEnabled: _shuffleEnabled,
              repeatMode: _repeatMode,
              sleepTimerActive: _sleepTimerDeadline != null,
              onShuffleChanged: _setShuffleEnabled,
              onCycleRepeatMode: _cycleRepeatMode,
              onOpenSleepTimer: _showSleepTimerPicker,
            );
          },
        ),
      ),
    );
  }
'''
app = regex_once(
    app,
    r'  Future<void> _showPremiumPlayerSheet\(\) async \{.*?\n  \}\n\n  @override\n  Widget build',
    new_player_method + '\n  @override\n  Widget build',
    'now playing route',
)

app = replace_once(
    app,
    '''    return Scaffold(
      backgroundColor: widget.themeConfig.canvas,
''',
    '''    return PopScope(
      canPop: !_hasInternalBack,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasInternalBack) _navigateBack();
      },
      child: Scaffold(
        backgroundColor: widget.themeConfig.canvas,
''',
    'root PopScope start',
)

app = replace_once(
    app,
    '''          : null,
    );
  }
}

enum QueueAdvanceSource''',
    '''          : null,
      ),
    );
  }
}

enum QueueAdvanceSource''',
    'root PopScope close',
)

player = replace_once(
    player,
    '''class _WzConsumerNowPlayingPageState extends State<WzConsumerNowPlayingPage> {
  late final Ticker _ticker;
''',
    '''class _WzConsumerNowPlayingPageState extends State<WzConsumerNowPlayingPage> {
  late final Ticker _ticker;
  Duration _lastRefresh = Duration.zero;
''',
    'player refresh accumulator field',
)

player = replace_once(
    player,
    '''    _ticker = Ticker((elapsed) {
      if (!mounted) return;
      if (elapsed.inMilliseconds % 250 < 17) setState(() {});
    })..start();
''',
    '''    _ticker = Ticker((elapsed) {
      if (!mounted) return;
      if (elapsed - _lastRefresh < const Duration(milliseconds: 250)) return;
      _lastRefresh = elapsed;
      setState(() {});
    })..start();
''',
    'player refresh cadence',
)

player = replace_once(
    player,
    '''        _SculptedProgress(
          value: progressValue,
          positionMs: displayedPositionMs,
          durationMs: durationMs,
          onChanged: onSeekChanged,
          onChangeEnd: onSeekEnd,
        ),
''',
    '''        _SculptedProgress(
          value: progressValue,
          positionMs: displayedPositionMs,
          durationMs: durationMs,
          isPlaying: metrics.isPlaying,
          onChanged: onSeekChanged,
          onChangeEnd: onSeekEnd,
        ),
''',
    'smooth progress call site',
)

smooth_progress = '''class _SculptedProgress extends StatefulWidget {
  const _SculptedProgress({
    required this.value,
    required this.positionMs,
    required this.durationMs,
    required this.isPlaying,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final int positionMs;
  final int? durationMs;
  final bool isPlaying;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<_SculptedProgress> createState() => _SculptedProgressState();
}

class _SculptedProgressState extends State<_SculptedProgress> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _tickerElapsed = Duration.zero;
  Duration _anchorElapsed = Duration.zero;
  late int _anchorPositionMs;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _anchorPositionMs = widget.positionMs;
    _ticker = createTicker((elapsed) {
      _tickerElapsed = elapsed;
      if (mounted && widget.isPlaying && _dragValue == null) setState(() {});
    })..start();
  }

  @override
  void didUpdateWidget(covariant _SculptedProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionMs != widget.positionMs ||
        oldWidget.durationMs != widget.durationMs ||
        oldWidget.isPlaying != widget.isPlaying) {
      _anchorPositionMs = widget.positionMs;
      _anchorElapsed = _tickerElapsed;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  int get _displayPositionMs {
    final duration = widget.durationMs;
    final drag = _dragValue;
    if (drag != null && duration != null && duration > 0) {
      return (drag * duration).round().clamp(0, duration);
    }
    final elapsedMs = widget.isPlaying ? (_tickerElapsed - _anchorElapsed).inMilliseconds : 0;
    final estimated = _anchorPositionMs + elapsedMs;
    if (duration == null || duration <= 0) return estimated < 0 ? 0 : estimated;
    return estimated.clamp(0, duration);
  }

  double get _displayValue {
    final drag = _dragValue;
    if (drag != null) return drag.clamp(0.0, 1.0);
    final duration = widget.durationMs;
    if (duration == null || duration <= 0) return widget.value.clamp(0.0, 1.0);
    return (_displayPositionMs / duration).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.4,
              activeTrackColor: WzColors.textPrimary,
              inactiveTrackColor: WzColors.border,
              thumbColor: Colors.white,
              overlayColor: WzColors.accent.withValues(alpha: 0.08),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 4),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: _displayValue,
              onChanged: widget.onChanged == null
                  ? null
                  : (value) {
                      setState(() => _dragValue = value);
                      widget.onChanged!(value);
                    },
              onChangeEnd: widget.onChangeEnd == null
                  ? null
                  : (value) {
                      final duration = widget.durationMs;
                      setState(() {
                        _dragValue = null;
                        if (duration != null && duration > 0) _anchorPositionMs = (value * duration).round();
                        _anchorElapsed = _tickerElapsed;
                      });
                      widget.onChangeEnd!(value);
                    },
            ),
          ),
          Row(
            children: [
              Text(_formatTime(_displayPositionMs), style: WzText.caption),
              const Spacer(),
              Text(_formatTime(widget.durationMs ?? 0), style: WzText.caption),
            ],
          ),
        ],
      );
}
'''
player = regex_once(
    player,
    r'class _SculptedProgress extends StatelessWidget \{.*?\n\}\n\nclass _PrimaryControls',
    smooth_progress + '\nclass _PrimaryControls',
    'smooth progress widget',
)

progress_test = '''

  testWidgets('consumer player interpolates progress between playback snapshots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WzConsumerPlayerSurface(
              metrics: const PlaybackMetrics(
                trackTitle: 'Smooth track',
                isPlaying: true,
                currentPositionMs: 1000,
                durationMs: 10000,
              ),
              manifest: null,
              nextTrack: null,
              progressValue: .1,
              displayedPositionMs: 1000,
              durationMs: 10000,
              controlsDisabled: false,
              canPlayPrevious: false,
              canPlayNext: false,
              onPlayPause: () {},
              onPrevious: () {},
              onNext: () {},
              onSeekChanged: (_) {},
              onSeekEnd: (_) {},
              canSaveTrack: false,
              liked: false,
              onToggleLike: null,
              onAddToCollection: null,
              onAddToQueue: null,
              onOpenQueue: () {},
              shuffleEnabled: false,
              repeatMode: WzRepeatMode.off,
              sleepTimerActive: false,
              onShuffleChanged: (_) {},
              onCycleRepeatMode: () {},
              onOpenSleepTimer: () {},
            ),
          ),
        ),
      ),
    );

    final before = tester.widget<Slider>(find.byType(Slider)).value;
    await tester.pump(const Duration(milliseconds: 500));
    final after = tester.widget<Slider>(find.byType(Slider)).value;

    expect(before, closeTo(.1, .01));
    expect(after, greaterThan(.13));
    expect(after, lessThan(.18));
  });
'''
if 'consumer player interpolates progress between playback snapshots' in tests:
    raise SystemExit('progress interpolation test already present')
final_close = tests.rfind('\n}')
if final_close < 0:
    raise SystemExit('consumer player test closing brace missing')
tests = tests[:final_close] + progress_test + tests[final_close:]

app_path.write_text(app)
player_path.write_text(player)
test_path.write_text(tests)
