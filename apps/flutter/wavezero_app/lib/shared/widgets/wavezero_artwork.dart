import 'dart:math' as math;

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
