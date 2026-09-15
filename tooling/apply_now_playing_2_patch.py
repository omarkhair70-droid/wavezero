from pathlib import Path

consumer_path = Path('apps/flutter/wavezero_app/lib/features/playback/consumer_player.dart')
artwork_path = Path('apps/flutter/wavezero_app/lib/shared/widgets/wavezero_artwork.dart')
test_path = Path('apps/flutter/wavezero_app/test/features/playback/now_playing_interaction_test.dart')

consumer = consumer_path.read_text(encoding='utf-8')
consumer = consumer.replace("import 'dart:ui' as ui;\n", '', 1)

old_shell = r'''class _WzConsumerNowPlayingPageState extends State<WzConsumerNowPlayingPage> {
  late final Ticker _ticker;
  Duration _lastRefresh = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((elapsed) {
      if (!mounted) return;
      if (elapsed - _lastRefresh < const Duration(milliseconds: 250)) return;
      _lastRefresh = elapsed;
      setState(() {});
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
                      onPressed:
                          widget.onClose ??
                          () => Navigator.of(context).maybePop(),
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

new_shell = r'''class _WzConsumerNowPlayingPageState extends State<WzConsumerNowPlayingPage> {
  late final Ticker _ticker;
  Duration _lastRefresh = Duration.zero;
  int? _dragPointer;
  Offset? _dragOrigin;
  double _dismissOffset = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((elapsed) {
      if (!mounted) return;
      if (elapsed - _lastRefresh < const Duration(milliseconds: 250)) return;
      _lastRefresh = elapsed;
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _closePlayer() {
    if (_closing) return;
    _closing = true;
    HapticFeedback.selectionClick();
    final close = widget.onClose;
    if (close != null) {
      close();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_closing || _dragPointer != null) return;
    _dragPointer = event.pointer;
    _dragOrigin = event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_dragPointer != event.pointer || _dragOrigin == null || _closing) return;
    final delta = event.position - _dragOrigin!;
    if (delta.dy <= 0) {
      if (_dismissOffset != 0) setState(() => _dismissOffset = 0);
      return;
    }
    if (delta.dy < delta.dx.abs() * 0.8) return;
    final next = delta.dy.clamp(0.0, 240.0).toDouble();
    if ((next - _dismissOffset).abs() < 0.5) return;
    setState(() => _dismissOffset = next);
  }

  void _onPointerEnd(PointerEvent event) {
    if (_dragPointer != event.pointer) return;
    final shouldClose = _dismissOffset >= 92;
    _dragPointer = null;
    _dragOrigin = null;
    if (shouldClose) {
      _closePlayer();
      return;
    }
    if (_dismissOffset != 0 && mounted) setState(() => _dismissOffset = 0);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: WzColors.canvas,
    body: Stack(
      children: [
        const Positioned.fill(child: _PlayerBackdrop()),
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerEnd,
          onPointerCancel: _onPointerEnd,
          child: AnimatedContainer(
            duration: _dragPointer == null
                ? const Duration(milliseconds: 180)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _dismissOffset, 0),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 7),
                  Center(
                    child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: WzColors.textSubtle.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 5, 18, 4),
                    child: Row(
                      children: [
                        WzSculptedIconButton(
                          icon: Icons.keyboard_arrow_down_rounded,
                          tooltip: 'Close player',
                          size: 42,
                          iconSize: 23,
                          onPressed: _closePlayer,
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
                        const SizedBox(width: 42),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                      child: widget.surfaceBuilder(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
'''

if old_shell not in consumer:
    raise SystemExit('Now Playing shell block not found')
consumer = consumer.replace(old_shell, new_shell, 1)

old_art = r'''class _SculptedArtwork extends StatelessWidget {
  const _SculptedArtwork({
    required this.size,
    required this.artworkUrl,
    required this.trackId,
    required this.title,
    required this.artist,
  });

  final double size;
  final String? artworkUrl;
  final String? trackId;
  final String? title;
  final String? artist;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 0.94,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(86),
                topRight: Radius.circular(126),
                bottomLeft: Radius.circular(122),
                bottomRight: Radius.circular(74),
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF8FFFFFF), Color(0xEAF3F8FC)],
              ),
              border: Border.all(color: const Color(0xEFFFFFFF), width: 1.4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x160D2A40),
                  blurRadius: 46,
                  offset: Offset(0, 20),
                ),
                BoxShadow(
                  color: Color(0xE6FFFFFF),
                  blurRadius: 14,
                  offset: Offset(-4, -7),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: size * 0.07,
          top: size * 0.045,
          right: size * 0.04,
          bottom: size * 0.045,
          child: ClipPath(
            clipper: _OrganicArtworkClipper(),
            child: WzArtwork(
              artworkUrl: artworkUrl,
              size: size,
              trackId: trackId,
              title: title,
              artist: artist,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _RibbonPainter())),
        ),
      ],
    ),
  );
}

class _OrganicArtworkClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * .20, size.height * .02);
    path.cubicTo(
      size.width * .62,
      size.height * -.03,
      size.width * .96,
      size.height * .14,
      size.width * .98,
      size.height * .43,
    );
    path.cubicTo(
      size.width * 1.00,
      size.height * .72,
      size.width * .77,
      size.height * .99,
      size.width * .45,
      size.height * .98,
    );
    path.cubicTo(
      size.width * .13,
      size.height * .98,
      size.width * -.02,
      size.height * .76,
      size.width * .03,
      size.height * .47,
    );
    path.cubicTo(
      size.width * .07,
      size.height * .22,
      size.width * .04,
      size.height * .08,
      size.width * .20,
      size.height * .02,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        Offset(size.width * .04, size.height * .15),
        Offset(size.width * .96, size.height * .82),
        const [Color(0xE6FFFFFF), Color(0x59FFFFFF), Color(0xCFFFFFFF)],
        const [0.0, 0.52, 1.0],
      );
    final path = Path()
      ..moveTo(size.width * .02, size.height * .54)
      ..cubicTo(
        size.width * .30,
        size.height * .34,
        size.width * .48,
        size.height * .78,
        size.width * .96,
        size.height * .46,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
'''

new_art = r'''class _SculptedArtwork extends StatelessWidget {
  const _SculptedArtwork({
    required this.size,
    required this.artworkUrl,
    required this.trackId,
    required this.title,
    required this.artist,
  });

  final double size;
  final String? artworkUrl;
  final String? trackId;
  final String? title;
  final String? artist;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(42),
      color: Colors.white.withValues(alpha: 0.58),
      border: Border.all(color: Colors.white.withValues(alpha: 0.88), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x160D2A40),
          blurRadius: 38,
          offset: Offset(0, 18),
        ),
        BoxShadow(
          color: Color(0xCFFFFFFF),
          blurRadius: 12,
          offset: Offset(-3, -5),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(35),
      child: WzArtwork(
        artworkUrl: artworkUrl,
        size: size,
        trackId: trackId,
        title: title,
        artist: artist,
        fit: BoxFit.cover,
      ),
    ),
  );
}
'''

if old_art not in consumer:
    raise SystemExit('Artwork sculpture block not found')
consumer = consumer.replace(old_art, new_art, 1)
consumer = consumer.replace('final artSize = math.min(390.0, constraints.maxWidth);', 'final artSize = math.min(356.0, constraints.maxWidth);', 1)
consumer = consumer.replace('        const SizedBox(height: 28),\n        Row(', '        const SizedBox(height: 24),\n        Row(', 1)

old_queue = r'''class _UpNextHandle extends StatelessWidget {
  const _UpNextHandle({
    required this.nextTrack,
    required this.onTap,
    required this.onAddToQueue,
  });

  final CatalogTrackSummary? nextTrack;
  final VoidCallback onTap;
  final VoidCallback? onAddToQueue;

  @override
  Widget build(BuildContext context) => WzPressableSurface(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    radius: 30,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xF8FFFFFF), Color(0xEEF5F8FA)],
      ),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: const Color(0xE6FFFFFF)),
      boxShadow: WzSurface.softShadows,
    ),
    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
    child: Row(
      children: [
        WzSculptedIcon(
          icon: Icons.queue_music_rounded,
          size: 44,
          iconSize: 19,
          color: WzColors.accent,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Up next', style: WzText.eyebrow),
              const SizedBox(height: 2),
              Text(
                nextTrack?.title ?? 'Nothing queued yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WzText.sectionTitle,
              ),
              if (nextTrack?.artistName != null)
                Text(
                  nextTrack!.artistName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WzText.caption,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.keyboard_arrow_up_rounded, color: WzColors.textMuted),
      ],
    ),
  );
}
'''

new_queue = r'''class _UpNextHandle extends StatelessWidget {
  const _UpNextHandle({
    required this.nextTrack,
    required this.onTap,
    required this.onAddToQueue,
  });

  final CatalogTrackSummary? nextTrack;
  final VoidCallback onTap;
  final VoidCallback? onAddToQueue;

  @override
  Widget build(BuildContext context) {
    final track = nextTrack;
    return WzPressableSurface(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      radius: 30,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        boxShadow: WzSurface.softShadows,
      ),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Row(
        children: [
          if (track != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: WzArtwork(
                artworkUrl: track.artworkUrl,
                size: 48,
                trackId: track.trackId,
                title: track.title,
                artist: track.artistName,
              ),
            )
          else
            const WzSculptedIcon(
              icon: Icons.queue_music_rounded,
              size: 48,
              iconSize: 20,
              color: WzColors.accent,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track == null ? 'Queue is empty' : 'Up next', style: WzText.eyebrow),
                const SizedBox(height: 3),
                Text(
                  track?.title ?? 'Pick something from Library or Search',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WzText.sectionTitle,
                ),
                Text(
                  track?.artistName ?? 'Tap to open your queue',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WzText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, size: 19, color: WzColors.textMuted),
        ],
      ),
    );
  }
}
'''

if old_queue not in consumer:
    raise SystemExit('Up next block not found')
consumer = consumer.replace(old_queue, new_queue, 1)
consumer_path.write_text(consumer, encoding='utf-8')

artwork_path.write_text(r'''import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';

class WzWaveZeroCoverArt extends StatelessWidget {
  const WzWaveZeroCoverArt({
    super.key,
    this.trackId,
    this.title,
    this.artist,
    this.mood,
    required this.size,
    this.compact = false,
  });

  final String? trackId;
  final String? title;
  final String? artist;
  final String? mood;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final seedText = [trackId, title, artist, mood].whereType<String>().join('|');
    final seed = _stableArtworkSeed(seedText.isEmpty ? 'wavezero' : seedText);
    final palette = _coverColors(seed, mood ?? title ?? 'wavezero');
    final ink = palette.last;
    final cleanTitle = title?.trim();
    final cleanArtist = artist?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.take(3).toList(growable: false),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _WaveZeroCoverPainter(seed: seed, color: ink),
            ),
          ),
          Positioned(
            left: size * 0.10,
            top: size * 0.10,
            child: Container(
              width: size * (compact ? 0.28 : 0.22),
              height: size * (compact ? 0.28 : 0.22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(size * 0.07),
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                size: size * (compact ? 0.16 : 0.12),
                color: ink.withValues(alpha: 0.78),
              ),
            ),
          ),
          if (!compact)
            Positioned(
              left: size * 0.10,
              right: size * 0.10,
              bottom: size * 0.10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cleanTitle != null && cleanTitle.isNotEmpty)
                    Text(
                      cleanTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.90),
                        fontSize: math.max(13, size * 0.072),
                        height: 1.04,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                      ),
                    ),
                  if (cleanArtist != null && cleanArtist.isNotEmpty) ...[
                    SizedBox(height: size * 0.025),
                    Text(
                      cleanArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.56),
                        fontSize: math.max(9, size * 0.041),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class WzArtwork extends StatelessWidget {
  const WzArtwork({
    super.key,
    this.artworkUrl,
    this.size = 118,
    this.trackId,
    this.title,
    this.artist,
    this.mood,
    this.fit = BoxFit.cover,
  });

  final String? artworkUrl;
  final double size;
  final String? trackId;
  final String? title;
  final String? artist;
  final String? mood;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size > 60 ? 28 : 14),
        color: WzColors.surfaceElevated,
        border: Border.all(color: WzColors.borderSoft),
      ),
      child: url == null || url.trim().isEmpty
          ? WzWaveZeroCoverArt(
              trackId: trackId,
              title: title,
              artist: artist,
              mood: mood,
              size: size,
              compact: size < 70,
            )
          : Image.network(
              url,
              fit: fit,
              errorBuilder: (_, __, ___) => WzWaveZeroCoverArt(
                trackId: trackId,
                title: title,
                artist: artist,
                mood: mood,
                size: size,
                compact: size < 70,
              ),
            ),
    );
  }
}

class _WaveZeroCoverPainter extends CustomPainter {
  const _WaveZeroCoverPainter({required this.seed, required this.color});

  final int seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final wash = Paint()..color = color.withValues(alpha: 0.055);
    final accent = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.012)
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
      Offset(size.width * (0.75 + (seed % 5) * 0.012), size.height * 0.24),
      size.width * 0.30,
      wash,
    );
    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.76),
      size.width * 0.20,
      Paint()..color = Colors.white.withValues(alpha: 0.32),
    );

    final path = Path()
      ..moveTo(size.width * 0.09, size.height * 0.58)
      ..cubicTo(
        size.width * 0.30,
        size.height * (0.48 + (seed % 4) * 0.018),
        size.width * 0.52,
        size.height * 0.68,
        size.width * 0.91,
        size.height * 0.45,
      );
    canvas.drawPath(path, accent);

    final dot = Paint()..color = color.withValues(alpha: 0.23);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.62),
      math.max(2.5, size.width * 0.022),
      dot,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveZeroCoverPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.color != color;
}

int _stableArtworkSeed(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

List<Color> _coverColors(int seed, String hint) {
  final normalized = hint.toLowerCase();
  if (normalized.contains('folk') || normalized.contains('acoustic') || normalized.contains('calm')) {
    return const [Color(0xFFF8F3E9), Color(0xFFECE4D2), Color(0xFFD6E2D7), Color(0xFF26362E)];
  }
  if (normalized.contains('hip') || normalized.contains('beat')) {
    return const [Color(0xFFF6F0FF), Color(0xFFE6DDF8), Color(0xFFF5DDE5), Color(0xFF332B46)];
  }
  if (normalized.contains('ambient') || normalized.contains('focus') || normalized.contains('instrumental')) {
    return const [Color(0xFFF0F8FC), Color(0xFFDDECF4), Color(0xFFE8F0FA), Color(0xFF203744)];
  }
  final palettes = const <List<Color>>[
    [Color(0xFFF7F4FF), Color(0xFFECE7FA), Color(0xFFF4EEF8), Color(0xFF342E45)],
    [Color(0xFFF0F8FC), Color(0xFFDCECF4), Color(0xFFEEF5F8), Color(0xFF243B48)],
    [Color(0xFFFFF5EF), Color(0xFFF8E4D9), Color(0xFFF7EEE8), Color(0xFF4A342D)],
    [Color(0xFFF1F8F4), Color(0xFFDDEEE5), Color(0xFFF0F6F2), Color(0xFF294038)],
  ];
  return palettes[seed % palettes.length];
}
''', encoding='utf-8')

test_path.parent.mkdir(parents=True, exist_ok=True)
test_path.write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/playback/consumer_player.dart';
import 'package:wavezero_app/shared/widgets/wavezero_artwork.dart';

void main() {
  testWidgets('Now Playing collapses after a deliberate downward drag from content', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WzConsumerNowPlayingPage(
          onClose: () => closeCount += 1,
          surfaceBuilder: (_) => const SizedBox(
            height: 650,
            child: Center(child: Text('player surface')),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('player surface')));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(closeCount, 1);
  });

  testWidgets('short downward movement snaps back instead of closing', (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WzConsumerNowPlayingPage(
          onClose: () => closeCount += 1,
          surfaceBuilder: (_) => const SizedBox(
            height: 650,
            child: Center(child: Text('player surface')),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.text('player surface')));
    await gesture.moveBy(const Offset(0, 38));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 220));

    expect(closeCount, 0);
    expect(find.text('Now Playing'), findsOneWidget);
  });

  testWidgets('generated artwork is light identity art without legacy WZ mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WzArtwork(
            size: 240,
            trackId: 'device-audio-42',
            title: 'Aloomek',
            artist: 'Marwan Moussa',
          ),
        ),
      ),
    );

    expect(find.text('WZ'), findsNothing);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    expect(find.text('Aloomek'), findsOneWidget);
    expect(find.text('Marwan Moussa'), findsOneWidget);
  });
}
''', encoding='utf-8')

print('Now Playing 2.0 patch applied')
