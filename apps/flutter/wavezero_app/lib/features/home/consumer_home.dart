import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/wavezero_theme.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../playback/playback_metrics.dart';
import '../../shared/widgets/wavezero_artwork.dart';

class WzConsumerHomeHero extends StatelessWidget {
  const WzConsumerHomeHero({super.key, required this.themeConfig});

  final WzThemeConfig themeConfig;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 250),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFCFFFFFF), Color(0xF4F9FCFF), Color(0xF8FFF9F4)],
            stops: [0.0, 0.58, 1.0],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(44),
            topRight: Radius.circular(76),
            bottomLeft: Radius.circular(66),
            bottomRight: Radius.circular(38),
          ),
          border: Border.all(color: const Color(0xF2FFFFFF), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x130D2A40), blurRadius: 38, offset: Offset(0, 17)),
            BoxShadow(color: Color(0xDFFFFFFF), blurRadius: 12, offset: Offset(-4, -5)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _HomeRibbonPainter(accent: themeConfig.accent))),
            Positioned(
              right: -34,
              top: -24,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [themeConfig.accent.withValues(alpha: 0.15), themeConfig.accent.withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 28, 26, 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('WaveZero', style: WzText.eyebrow.copyWith(color: themeConfig.accent)),
                    const SizedBox(height: 16),
                    Text(
                      'The voice is close.\nThe music is with you.',
                      style: WzText.display.copyWith(fontSize: 38, height: 1.05, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'الصوت قريب منك. الموسيقى معاك.',
                      textDirection: TextDirection.rtl,
                      style: WzText.body.copyWith(fontSize: 15, color: WzColors.textMuted),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xDFFFFFFF),
                        border: Border.all(color: const Color(0xFFFFFFFF)),
                        boxShadow: WzSurface.softShadows,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.graphic_eq_rounded, color: themeConfig.accent, size: 25),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class WzConsumerNowCard extends StatelessWidget {
  const WzConsumerNowCard({
    super.key,
    required this.metrics,
    required this.manifest,
    required this.progressValue,
    required this.onOpen,
    required this.onPlayPause,
    required this.controlsDisabled,
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final double progressValue;
  final VoidCallback onOpen;
  final VoidCallback onPlayPause;
  final bool controlsDisabled;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? 'Your music, when you are ready';
    final subtitle = manifest?.artistName ?? manifest?.subtitle ?? 'Choose something from Library';
    final hasTrack = metrics.trackTitle != null || manifest != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(hasTrack ? 'With you now' : 'Ready for you', style: WzText.eyebrow),
        ),
        const SizedBox(height: 10),
        WzPressableSurface(
          onTap: hasTrack ? onOpen : null,
          radius: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFCFFFFFF), Color(0xF2F6FAFC)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(38),
              topRight: Radius.circular(52),
              bottomLeft: Radius.circular(48),
              bottomRight: Radius.circular(34),
            ),
            border: Border.all(color: const Color(0xF2FFFFFF), width: 1.1),
            boxShadow: WzSurface.softShadows,
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              _HomeArtwork(
                artworkUrl: manifest?.artworkUrl,
                trackId: manifest?.trackId,
                title: manifest?.title,
                artist: manifest?.artistName,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.title.copyWith(fontSize: 18)),
                    const SizedBox(height: 5),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.body),
                    if (hasTrack) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progressValue.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: WzColors.borderSoft,
                          valueColor: const AlwaysStoppedAnimation<Color>(WzColors.textPrimary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              if (hasTrack)
                WzSculptedIconButton(
                  tooltip: metrics.isPlaying ? 'Pause' : 'Play',
                  icon: metrics.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 58,
                  iconSize: 29,
                  onPressed: controlsDisabled
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onPlayPause();
                        },
                )
              else
                const Icon(Icons.arrow_forward_rounded, color: WzColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeArtwork extends StatelessWidget {
  const _HomeArtwork({required this.artworkUrl, required this.trackId, required this.title, required this.artist});

  final String? artworkUrl;
  final String? trackId;
  final String? title;
  final String? artist;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF4F8FB)]),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(34),
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(22),
          ),
          border: Border.all(color: Colors.white),
          boxShadow: WzSurface.softShadows,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(21),
            topRight: Radius.circular(30),
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(18),
          ),
          child: WzArtwork(
            artworkUrl: artworkUrl,
            size: 78,
            trackId: trackId,
            title: title,
            artist: artist,
            fit: BoxFit.cover,
          ),
        ),
      );
}

class _HomeRibbonPainter extends CustomPainter {
  const _HomeRibbonPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * .78, size.height * .36),
        size.shortestSide * .52,
        [accent.withValues(alpha: .10), accent.withValues(alpha: 0)],
      );
    canvas.drawRect(Offset.zero & size, glowPaint);

    for (var i = 0; i < 3; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 - (i * 2)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: .50 - (i * .10));
      final path = Path()
        ..moveTo(-20, size.height * (.62 + i * .045))
        ..cubicTo(
          size.width * .24,
          size.height * (.42 + i * .035),
          size.width * .56,
          size.height * (.88 - i * .03),
          size.width + 30,
          size.height * (.48 + i * .025),
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HomeRibbonPainter oldDelegate) => oldDelegate.accent != accent;
}
