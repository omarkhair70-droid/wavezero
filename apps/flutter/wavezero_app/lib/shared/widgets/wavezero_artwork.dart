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
    final colors = _coverColors(seed, mood ?? title ?? 'wavezero');
    final initials = _coverInitials(title, artist);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _WaveZeroCoverPainter(
                seed: seed,
                color: Colors.white.withOpacity(compact ? 0.13 : 0.16),
              ),
            ),
          ),
          Positioned(
            top: -size * 0.14,
            right: -size * 0.12,
            child: Icon(
              Icons.graphic_eq,
              size: size * 0.48,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
          Positioned(
            left: size * 0.10,
            top: size * 0.10,
            child: Text(
              'WZ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.42),
                fontSize: math.max(8, size * 0.09),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Center(
            child: Container(
              width: size * (compact ? 0.50 : 0.46),
              height: size * (compact ? 0.50 : 0.46),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.22),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Text(
                initials,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: math.max(13, size * (compact ? 0.20 : 0.16)),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          if (!compact && mood != null && mood!.trim().isNotEmpty)
            Positioned(
              left: size * 0.09,
              right: size * 0.09,
              bottom: size * 0.08,
              child: Text(
                mood!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: math.max(9, size * 0.08),
                  fontWeight: FontWeight.w700,
                ),
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
  });

  final String? artworkUrl;
  final double size;
  final String? trackId;
  final String? title;
  final String? artist;
  final String? mood;

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
              fit: BoxFit.cover,
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
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;
    final bars = 9 + (seed % 7);
    final width = size.width / (bars * 1.8);
    for (var i = 0; i < bars; i++) {
      final value = ((seed >> (i % 16)) & 0x0F) / 15.0;
      final height = size.height * (0.16 + value * 0.42);
      final x = size.width * 0.12 + i * width * 1.65;
      final y = size.height * 0.72;
      paint.strokeWidth = math.max(2, width * 0.52);
      canvas.drawLine(Offset(x, y), Offset(x, y - height), paint);
    }
    final ringPaint = Paint()
      ..color = color.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width * 0.012);
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.22),
      size.width * (0.12 + (seed % 5) * 0.015),
      ringPaint,
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
  if (normalized.contains('folk') ||
      normalized.contains('acoustic') ||
      normalized.contains('calm')) {
    return const [Color(0xFF243B30), Color(0xFF0B1019), Color(0xFFB98E54)];
  }
  if (normalized.contains('hip') || normalized.contains('beat')) {
    return const [Color(0xFF311B52), Color(0xFF070A13), Color(0xFFFF7A59)];
  }
  if (normalized.contains('ambient') ||
      normalized.contains('focus') ||
      normalized.contains('instrumental')) {
    return const [Color(0xFF102A43), Color(0xFF070A13), Color(0xFF36D7FF)];
  }
  final palettes = const <List<Color>>[
    [Color(0xFF2D1B5F), Color(0xFF070A13), Color(0xFF36D7FF)],
    [Color(0xFF12243D), Color(0xFF070A13), Color(0xFF9A8CFF)],
    [Color(0xFF3A1935), Color(0xFF080A12), Color(0xFFFF6B8A)],
    [Color(0xFF18362F), Color(0xFF070A13), Color(0xFF38D996)],
  ];
  return palettes[seed % palettes.length];
}

String _coverInitials(String? title, String? artist) {
  String firstLetter(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  final result = '${firstLetter(title)}${firstLetter(artist)}';
  return result.trim().isEmpty ? 'WZ' : result;
}
