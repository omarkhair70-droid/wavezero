import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../playback/playback_metrics.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import 'playback_modes.dart';

class WzConsumerNowPlayingPage extends StatelessWidget {
  const WzConsumerNowPlayingPage({
    super.key,
    required this.surface,
    this.onClose,
  });

  final Widget surface;
  final VoidCallback? onClose;

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
                          onPressed: onClose ?? () => Navigator.of(context).maybePop(),
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
                      child: surface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class WzConsumerPlayerSurface extends StatelessWidget {
  const WzConsumerPlayerSurface({
    super.key,
    required this.metrics,
    required this.manifest,
    required this.nextTrack,
    required this.progressValue,
    required this.displayedPositionMs,
    required this.durationMs,
    required this.controlsDisabled,
    required this.canPlayPrevious,
    required this.canPlayNext,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.canSaveTrack,
    required this.liked,
    required this.onToggleLike,
    required this.onAddToCollection,
    required this.onAddToQueue,
    required this.onOpenQueue,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerActive,
    required this.onShuffleChanged,
    required this.onCycleRepeatMode,
    required this.onOpenSleepTimer,
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final CatalogTrackSummary? nextTrack;
  final double progressValue;
  final int displayedPositionMs;
  final int? durationMs;
  final bool controlsDisabled;
  final bool canPlayPrevious;
  final bool canPlayNext;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;
  final bool canSaveTrack;
  final bool liked;
  final VoidCallback? onToggleLike;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onAddToQueue;
  final VoidCallback onOpenQueue;
  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final bool sleepTimerActive;
  final ValueChanged<bool> onShuffleChanged;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback onOpenSleepTimer;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? 'Nothing playing';
    final artist = manifest?.artistName ?? manifest?.subtitle ?? 'Choose something from your Library';
    final hasTrack = manifest != null || metrics.trackTitle != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final artSize = math.min(390.0, constraints.maxWidth);
            return Center(
              child: _SculptedArtwork(
                size: artSize,
                artworkUrl: manifest?.artworkUrl,
                trackId: manifest?.trackId,
                title: manifest?.title,
                artist: manifest?.artistName,
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.pageTitle.copyWith(fontSize: 29, height: 1.1),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.body.copyWith(fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _AnimatedLikeButton(
              enabled: canSaveTrack && onToggleLike != null,
              liked: liked,
              onTap: onToggleLike,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SculptedProgress(
          value: progressValue,
          positionMs: displayedPositionMs,
          durationMs: durationMs,
          onChanged: onSeekChanged,
          onChangeEnd: onSeekEnd,
        ),
        const SizedBox(height: 18),
        _PrimaryControls(
          isPlaying: metrics.isPlaying,
          enabled: hasTrack && !controlsDisabled,
          canPrevious: canPlayPrevious,
          canNext: canPlayNext,
          onPrevious: onPrevious,
          onPlayPause: onPlayPause,
          onNext: onNext,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ModeButton(
              tooltip: 'Shuffle',
              icon: Icons.shuffle_rounded,
              selected: shuffleEnabled,
              onTap: controlsDisabled ? null : () => onShuffleChanged(!shuffleEnabled),
            ),
            _ModeButton(
              tooltip: 'Repeat',
              icon: repeatMode == WzRepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              selected: repeatMode != WzRepeatMode.off,
              onTap: controlsDisabled ? null : onCycleRepeatMode,
            ),
            _ModeButton(
              tooltip: 'Sleep timer',
              icon: Icons.timer_outlined,
              selected: sleepTimerActive,
              onTap: controlsDisabled ? null : onOpenSleepTimer,
            ),
            _ModeButton(
              tooltip: 'Add to collection',
              icon: Icons.playlist_add_rounded,
              selected: false,
              onTap: onAddToCollection,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _UpNextHandle(
          nextTrack: nextTrack,
          onTap: onOpenQueue,
          onAddToQueue: onAddToQueue,
        ),
      ],
    );
  }
}

class WzConsumerMiniPlayer extends StatelessWidget {
  const WzConsumerMiniPlayer({
    super.key,
    required this.metrics,
    required this.manifest,
    required this.progressValue,
    required this.controlsDisabled,
    required this.onTap,
    required this.onPlayPause,
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final double progressValue;
  final bool controlsDisabled;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? 'Current track';
    final subtitle = manifest?.artistName ?? manifest?.subtitle ?? 'WaveZero';

    return WzPressableSurface(
      onTap: onTap,
      radius: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFCFFFFFF), Color(0xF2F7FAFC)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFFFFFFF), width: 1.1),
        boxShadow: WzSurface.liftedShadows,
      ),
      padding: const EdgeInsets.fromLTRB(9, 9, 10, 9),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: WzArtwork(
              artworkUrl: manifest?.artworkUrl,
              size: 54,
              trackId: manifest?.trackId,
              title: manifest?.title,
              artist: manifest?.artistName,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                const SizedBox(height: 7),
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
            ),
          ),
          const SizedBox(width: 12),
          WzSculptedIconButton(
            tooltip: metrics.isPlaying ? 'Pause' : 'Play',
            icon: metrics.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 52,
            iconSize: 27,
            onPressed: controlsDisabled
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onPlayPause();
                  },
          ),
        ],
      ),
    );
  }
}

class _SculptedArtwork extends StatelessWidget {
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
                    BoxShadow(color: Color(0x160D2A40), blurRadius: 46, offset: Offset(0, 20)),
                    BoxShadow(color: Color(0xE6FFFFFF), blurRadius: 14, offset: Offset(-4, -7)),
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
              child: IgnorePointer(
                child: CustomPaint(painter: _RibbonPainter()),
              ),
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
    path.cubicTo(size.width * .62, size.height * -.03, size.width * .96, size.height * .14, size.width * .98, size.height * .43);
    path.cubicTo(size.width * 1.00, size.height * .72, size.width * .77, size.height * .99, size.width * .45, size.height * .98);
    path.cubicTo(size.width * .13, size.height * .98, size.width * -.02, size.height * .76, size.width * .03, size.height * .47);
    path.cubicTo(size.width * .07, size.height * .22, size.width * .04, size.height * .08, size.width * .20, size.height * .02);
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
      );
    final path = Path()
      ..moveTo(size.width * .02, size.height * .54)
      ..cubicTo(size.width * .30, size.height * .34, size.width * .48, size.height * .78, size.width * .96, size.height * .46);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SculptedProgress extends StatelessWidget {
  const _SculptedProgress({
    required this.value,
    required this.positionMs,
    required this.durationMs,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final int positionMs;
  final int? durationMs;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

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
              value: value.clamp(0.0, 1.0),
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
          Row(
            children: [
              Text(_formatTime(positionMs), style: WzText.caption),
              const Spacer(),
              Text(_formatTime(durationMs ?? 0), style: WzText.caption),
            ],
          ),
        ],
      );
}

class _PrimaryControls extends StatelessWidget {
  const _PrimaryControls({
    required this.isPlaying,
    required this.enabled,
    required this.canPrevious,
    required this.canNext,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
  });

  final bool isPlaying;
  final bool enabled;
  final bool canPrevious;
  final bool canNext;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          WzSculptedIconButton(
            icon: Icons.skip_previous_rounded,
            tooltip: 'Previous',
            size: 54,
            iconSize: 25,
            onPressed: enabled && canPrevious ? onPrevious : null,
          ),
          _PrimaryPlayButton(
            isPlaying: isPlaying,
            enabled: enabled,
            onTap: onPlayPause,
          ),
          WzSculptedIconButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Next',
            size: 54,
            iconSize: 25,
            onPressed: enabled && canNext ? onNext : null,
          ),
        ],
      );
}

class _PrimaryPlayButton extends StatelessWidget {
  const _PrimaryPlayButton({required this.isPlaying, required this.enabled, required this.onTap});

  final bool isPlaying;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 88,
        height: 88,
        child: WzPressableSurface(
          onTap: enabled
              ? () {
                  HapticFeedback.mediumImpact();
                  onTap();
                }
              : null,
          radius: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-.28, -.34),
              radius: 1.18,
              colors: [Color(0xFFFFFFFF), Color(0xFFF4F7FA), Color(0xFFE7EEF3)],
            ),
            border: Border.all(color: const Color(0xFFFFFFFF), width: 1.4),
            boxShadow: const [
              BoxShadow(color: Color(0x1A0D2A40), blurRadius: 34, offset: Offset(0, 15)),
              BoxShadow(color: Color(0xEFFFFFFF), blurRadius: 12, offset: Offset(-4, -5)),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: WzMotion.normal,
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(isPlaying),
                color: enabled ? WzColors.textPrimary : WzColors.textSubtle,
                size: 42,
              ),
            ),
          ),
        ),
      );
}

class _AnimatedLikeButton extends StatelessWidget {
  const _AnimatedLikeButton({required this.enabled, required this.liked, required this.onTap});

  final bool enabled;
  final bool liked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => WzPressableSurface(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap?.call();
              }
            : null,
        radius: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: liked ? const Color(0xFFFFF2F3) : const Color(0xF7FFFFFF),
          border: Border.all(color: liked ? const Color(0x33D85C6A) : WzColors.borderSoft),
          boxShadow: WzSurface.softShadows,
        ),
        padding: const EdgeInsets.all(14),
        child: AnimatedSwitcher(
          duration: WzMotion.normal,
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: Icon(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(liked),
            size: 24,
            color: liked ? const Color(0xFFD85C6A) : WzColors.textPrimary,
          ),
        ),
      );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.tooltip, required this.icon, required this.selected, required this.onTap});

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => WzSculptedIconButton(
        tooltip: tooltip,
        icon: icon,
        selected: selected,
        size: 48,
        iconSize: 20,
        onPressed: onTap,
      );
}

class _UpNextHandle extends StatelessWidget {
  const _UpNextHandle({required this.nextTrack, required this.onTap, required this.onAddToQueue});

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
          gradient: const LinearGradient(colors: [Color(0xF8FFFFFF), Color(0xEEF5F8FA)]),
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
                    Text(nextTrack!.artistName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_up_rounded, color: WzColors.textMuted),
          ],
        ),
      );
}

class _PlayerBackdrop extends StatelessWidget {
  const _PlayerBackdrop();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: WzColors.canvasGradient),
        child: Stack(
          children: [
            Positioned(
              left: -90,
              top: 160,
              child: Container(
                width: 260,
                height: 260,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x1A9DCBE8), Color(0x009DCBE8)]),
                ),
              ),
            ),
            Positioned(
              right: -100,
              bottom: 90,
              child: Container(
                width: 280,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x15E7CBB8), Color(0x00E7CBB8)]),
                ),
              ),
            ),
          ],
        ),
      );
}

String _formatTime(int milliseconds) {
  final totalSeconds = math.max(0, milliseconds ~/ 1000);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
