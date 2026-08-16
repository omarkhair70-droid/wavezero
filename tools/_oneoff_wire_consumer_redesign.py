from pathlib import Path
import re

root = Path.cwd()
player_path = root / 'apps/flutter/wavezero_app/lib/features/playback/consumer_player.dart'
app_path = root / 'apps/flutter/wavezero_app/lib/app/wavezero_app.dart'
workflow_path = root / '.github/workflows/_oneoff_wire_consumer_redesign.yml'
script_path = root / 'tools/_oneoff_wire_consumer_redesign.py'


def replace_span(text: str, start: str, end: str, replacement: str) -> str:
    a = text.find(start)
    if a < 0:
        raise SystemExit(f'missing start marker: {start!r}')
    b = text.find(end, a)
    if b < 0:
        raise SystemExit(f'missing end marker: {end!r}')
    return text[:a] + replacement + text[b:]

# Make the full-screen player rebuild locally while it is open so playback
# progress and play/pause state remain live even though it sits on a route.
player = player_path.read_text(encoding='utf-8')
page_start = 'class WzConsumerNowPlayingPage extends StatelessWidget {'
page_end = 'class WzConsumerPlayerSurface extends StatelessWidget {'
page_replacement = '''class WzConsumerNowPlayingPage extends StatefulWidget {
  const WzConsumerNowPlayingPage({
    super.key,
    required this.surfaceBuilder,
    this.onClose,
  });

  final WidgetBuilder surfaceBuilder;
  final VoidCallback? onClose;

  @override
  State<WzConsumerNowPlayingPage> createState() => _WzConsumerNowPlayingPageState();
}

class _WzConsumerNowPlayingPageState extends State<WzConsumerNowPlayingPage> {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((elapsed) {
      if (!mounted) return;
      if (elapsed.inMilliseconds % 250 < 17) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: WzColors.canvas,
        body: Stack(
          children: [
            const Positioned.fill(child: _PlayerBackdrop()),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                    child: Row(
                      children: [
                        WzSculptedIconButton(
                          icon: Icons.keyboard_arrow_down_rounded,
                          tooltip: 'Close player',
                          size: 44,
                          iconSize: 24,
                          onPressed: widget.onClose ?? () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        const Text(
                          'Now Playing',
                          style: TextStyle(
                            color: WzColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                      child: widget.surfaceBuilder(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

'''
player = replace_span(player, page_start, page_end, page_replacement)
if "package:flutter/scheduler.dart" not in player:
    player = player.replace("import 'package:flutter/material.dart';\n", "import 'package:flutter/material.dart';\nimport 'package:flutter/scheduler.dart';\n", 1)
player_path.write_text(player, encoding='utf-8')

app = app_path.read_text(encoding='utf-8')
if "../features/playback/consumer_player.dart" not in app:
    app = app.replace("import '../features/playback/player_presentation.dart';\n", "import '../features/playback/player_presentation.dart';\nimport '../features/playback/consumer_player.dart';\n", 1)

method_start = '  Future<void> _showPremiumPlayerSheet() async {'
method_end = '  @override\n  Widget build(BuildContext context) {'
new_methods = '''  Future<void> _showQueueSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x55788792),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
          child: Material(
            color: const Color(0xFFF8FAFC),
            child: StatefulBuilder(
              builder: (context, refreshSheet) => ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(color: WzColors.border, borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('Up next', style: WzText.pageTitle.copyWith(fontSize: 24)),
                      const Spacer(),
                      Text('${_queue.length} tracks', style: WzText.caption),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                    showDeveloperDetails: false,
                    onToggleAutoAdvance: (value) {
                      setState(() {
                        _autoAdvanceEnabled = value;
                        _queueStatus = value ? 'Auto-advance enabled.' : 'Auto-advance disabled.';
                        _sessionStatus = 'Session saved.';
                      });
                      unawaited(_saveSession());
                      unawaited(_updatePredictivePreloadCandidate());
                      refreshSheet(() {});
                    },
                    onPlayTrack: (track) async {
                      await _playQueueTrack(track, autoStart: _metrics.isPlaying);
                      if (sheetContext.mounted) refreshSheet(() {});
                    },
                    onMoveUp: (track) {
                      _moveQueueTrack(track, -1);
                      refreshSheet(() {});
                    },
                    onMoveDown: (track) {
                      _moveQueueTrack(track, 1);
                      refreshSheet(() {});
                    },
                    onPlayNext: (track) {
                      _playTrackNext(track);
                      refreshSheet(() {});
                    },
                    onRemoveTrack: (track) {
                      _removeFromQueue(track);
                      refreshSheet(() {});
                    },
                    onClearQueue: () {
                      _clearQueue();
                      refreshSheet(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPremiumPlayerSheet() async {
    if (_manifest == null && _metrics.trackTitle == null) return;
    final currentTrack = _currentKnownTrack;

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (routeContext, animation, secondaryAnimation) => WzConsumerNowPlayingPage(
          surfaceBuilder: (_) {
            final durationMs = _metrics.durationMs ?? _manifest?.durationMs;
            final displayedPositionMs = (_dragPositionMs ?? _metrics.currentPositionMs.toDouble()).round();
            final progress = durationMs == null || durationMs <= 0 ? 0.0 : (displayedPositionMs / durationMs).clamp(0.0, 1.0).toDouble();
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
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

'''
app = replace_span(app, method_start, method_end, new_methods)
app = app.replace('              onOpenNow: () => _navigateTo(WzAppTab.now),', '              onOpenNow: _showPremiumPlayerSheet,', 1)

pattern = re.compile(r"\? WzPremiumMiniPlayer\(\n(?P<body>.*?)\n\s*\)\n\s*: null,", re.S)
match = pattern.search(app)
if not match:
    raise SystemExit('mini player block not found')
replacement = '''? WzConsumerMiniPlayer(
                metrics: _metrics,
                manifest: _manifest,
                progressValue: progress,
                controlsDisabled: _playerDisabled,
                onTap: _showPremiumPlayerSheet,
                onPlayPause: _playPause,
              )
            : null,'''
app = app[:match.start()] + replacement + app[match.end():]
app_path.write_text(app, encoding='utf-8')

# Remove one-off machinery from the resulting commit.
for path in (workflow_path, script_path):
    if path.exists():
        path.unlink()
