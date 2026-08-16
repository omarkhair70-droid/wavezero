import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../audio/audio_effects.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../playback/playback_metrics.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import 'playback_modes.dart';

class WzNowContextPanel extends StatelessWidget {
  const WzNowContextPanel({
    required this.qualityLabel,
    required this.effectsSummary,
    required this.playingFromCache,
    required this.devicePlayback,
    required this.offlineReady,
    required this.nextTrack,
    required this.manifest,
    required this.selectedEffectProfile,
    required this.nativeAudioEffectStatus,
    required this.queueIndex,
    required this.queueLength,
  });

  final String qualityLabel;
  final String effectsSummary;
  final bool playingFromCache;
  final bool devicePlayback;
  final bool offlineReady;
  final CatalogTrackSummary? nextTrack;
  final CatalogTrackManifest? manifest;
  final AudioEffectProfile selectedEffectProfile;
  final NativeAudioEffectStatus nativeAudioEffectStatus;
  final int queueIndex;
  final int queueLength;

  @override
  Widget build(BuildContext context) {
    final currentPosition = queueIndex >= 0 && queueLength > 0 ? '${queueIndex + 1} / $queueLength' : 'No active queue';
    final bitrate = manifest?.bitrateKbps == null ? 'Bitrate unknown' : '${manifest!.bitrateKbps} kbps';
    final codec = manifest?.codec ?? 'Codec unknown';
    final localLabel = devicePlayback
        ? 'On this device'
        : playingFromCache
            ? 'Downloaded'
            : offlineReady
                ? 'Offline ready'
                : 'Streaming';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WzSectionHeader(
          title: 'Listening context',
          subtitle: 'The technical details stay close, without getting in the way.',
          icon: Icons.graphic_eq,
        ),
        WzGlassCard(
          borderRadius: WzRadius.xl,
          child: Wrap(
            spacing: WzSpacing.sm,
            runSpacing: WzSpacing.sm,
            children: [
              _ContextTile(icon: Icons.high_quality, label: 'Quality', value: wzProductQualityLabel(qualityLabel), detail: '$codec • $bitrate'),
              _ContextTile(icon: Icons.tune, label: 'Sound', value: selectedEffectProfile.label, detail: '${wzEffectStatusLabel(nativeAudioEffectStatus)} • $effectsSummary'),
              _ContextTile(icon: Icons.offline_pin, label: 'Source', value: localLabel, detail: devicePlayback ? 'Device music' : playingFromCache ? 'Local cached audio' : 'WaveZero playback'),
              _ContextTile(icon: Icons.queue_music, label: 'Queue', value: currentPosition, detail: nextTrack == null ? 'Nothing waiting after this track' : 'Next: ${nextTrack!.title}'),
            ],
          ),
        ),
      ],
    );
  }
}

class WzPremiumPlayerSheet extends StatelessWidget {
  const WzPremiumPlayerSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.74,
        minChildSize: 0.34,
        maxChildSize: 0.97,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(42)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFAFFFFFF), Color(0xF4F7FAFC)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(42)),
                border: Border(top: BorderSide(color: Color(0xFFFFFFFF))),
                boxShadow: [BoxShadow(color: Color(0x1A183447), blurRadius: 34, offset: Offset(0, -10))],
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(WzSpacing.md, WzSpacing.sm, WzSpacing.md, WzSpacing.xl),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: WzSpacing.sm),
                        decoration: BoxDecoration(color: WzColors.border, borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                    Row(
                      children: [
                        WzSculptedIconButton(
                          icon: Icons.keyboard_arrow_down,
                          tooltip: 'Close player',
                          size: 42,
                          iconSize: 22,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xCCFFFFFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: WzColors.borderSoft),
                          ),
                          child: const Text('Now Playing', style: TextStyle(color: WzColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const Spacer(),
                        const SizedBox(width: 42),
                      ],
                    ),
                    const SizedBox(height: WzSpacing.sm),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class WzPremiumPlayerSurface extends StatelessWidget {
  const WzPremiumPlayerSurface({
    required this.metrics,
    required this.manifest,
    required this.nextTrack,
    required this.qualityLabel,
    required this.effectsSummary,
    required this.sourceLabel,
    required this.progressValue,
    required this.displayedPositionMs,
    required this.durationMs,
    required this.controlsDisabled,
    required this.canPlayPrevious,
    required this.canPlayNext,
    required this.onPlayPause,
    required this.onStop,
    required this.onRetry,
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
    required this.offlineReady,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerLabel,
    required this.sleepTimerActive,
    required this.onShuffleChanged,
    required this.onCycleRepeatMode,
    required this.onOpenSleepTimer,
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final CatalogTrackSummary? nextTrack;
  final String qualityLabel;
  final String effectsSummary;
  final String sourceLabel;
  final double progressValue;
  final int displayedPositionMs;
  final int? durationMs;
  final bool controlsDisabled;
  final bool canPlayPrevious;
  final bool canPlayNext;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onRetry;
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
  final bool offlineReady;
  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final String sleepTimerLabel;
  final bool sleepTimerActive;
  final ValueChanged<bool> onShuffleChanged;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback onOpenSleepTimer;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? 'No track loaded';
    final subtitle = manifest?.subtitle ?? 'Choose a track and let the voice come closer.';
    final status = metrics.isPlaying ? 'Playing' : _statusFromEvent(metrics.lastEvent);

    return WzGlassCard(
      padding: const EdgeInsets.fromLTRB(WzSpacing.md, WzSpacing.lg, WzSpacing.md, WzSpacing.lg),
      gradient: WzColors.heroGradient,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(top: -80, right: -70, child: _AmbientBlob(size: 210, color: Color(0x557FC4EF))),
          const Positioned(bottom: 120, left: -90, child: _AmbientBlob(size: 180, color: Color(0x33F0C8A8))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 620;
                  final artSize = stacked ? math.min(310.0, constraints.maxWidth - 10) : 300.0;
                  final art = _PorcelainArtworkHero(
                    artworkUrl: manifest?.artworkUrl,
                    size: artSize,
                    trackId: manifest?.trackId,
                    title: manifest?.title,
                    artist: manifest?.artistName,
                  );
                  final identity = _NowTrackIdentity(
                    title: title,
                    subtitle: subtitle,
                    status: status,
                    centered: stacked,
                    liked: liked,
                    canSaveTrack: canSaveTrack,
                    onToggleLike: onToggleLike,
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: art),
                        const SizedBox(height: WzSpacing.lg),
                        identity,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      art,
                      const SizedBox(width: WzSpacing.xxl),
                      Expanded(child: identity),
                    ],
                  );
                },
              ),
              const SizedBox(height: WzSpacing.lg),
              _PlayerContextBadges(
                qualityLabel: qualityLabel,
                effectsSummary: effectsSummary,
                sourceLabel: sourceLabel,
                upNextTitle: nextTrack?.title,
                offlineReady: offlineReady,
                status: status,
              ),
              const SizedBox(height: WzSpacing.lg),
              _PlayerProgressBlock(
                progressValue: progressValue,
                displayedPositionMs: displayedPositionMs,
                durationMs: durationMs,
                onSeekChanged: onSeekChanged,
                onSeekEnd: onSeekEnd,
              ),
              const SizedBox(height: WzSpacing.md),
              _PlayerPrimaryControls(
                isPlaying: metrics.isPlaying,
                controlsDisabled: controlsDisabled,
                canPlayPrevious: canPlayPrevious,
                canPlayNext: canPlayNext,
                onPlayPause: onPlayPause,
                onStop: onStop,
                onRetry: onRetry,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
              const SizedBox(height: WzSpacing.lg),
              _PlaybackModesCard(
                shuffleEnabled: shuffleEnabled,
                repeatMode: repeatMode,
                sleepTimerLabel: sleepTimerLabel,
                sleepTimerActive: sleepTimerActive,
                controlsDisabled: controlsDisabled,
                onShuffleChanged: onShuffleChanged,
                onCycleRepeatMode: onCycleRepeatMode,
                onOpenSleepTimer: onOpenSleepTimer,
              ),
              const SizedBox(height: WzSpacing.md),
              _PlayerLibraryActions(
                canSaveTrack: canSaveTrack,
                liked: liked,
                onToggleLike: onToggleLike,
                onAddToCollection: onAddToCollection,
                onAddToQueue: onAddToQueue,
                onOpenQueue: onOpenQueue,
              ),
              const SizedBox(height: WzSpacing.lg),
              _PlayerUpNextPreview(nextTrack: nextTrack),
            ],
          ),
        ],
      ),
    );
  }
}

class WzPremiumMiniPlayer extends StatelessWidget {
  const WzPremiumMiniPlayer({
    required this.metrics,
    required this.manifest,
    required this.progressValue,
    required this.sourceLabel,
    required this.offlineReady,
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerBadge,
    required this.controlsDisabled,
    required this.onTap,
    required this.onPlayPause,
  });

  final PlaybackMetrics metrics;
  final CatalogTrackManifest? manifest;
  final double progressValue;
  final String sourceLabel;
  final bool offlineReady;
  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final String? sleepTimerBadge;
  final bool controlsDisabled;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final title = metrics.trackTitle ?? manifest?.title ?? 'Current track';
    final subtitle = manifest?.subtitle ?? (metrics.isPlaying ? 'Playing from WaveZero' : 'Paused in WaveZero');

    return SafeArea(
      top: false,
      bottom: false,
      child: WzPressableSurface(
        onTap: onTap,
        radius: 30,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF5F9FC)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFFFFFFF)),
          boxShadow: WzSurface.liftedShadows,
        ),
        padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
        child: Row(
          children: [
            _MiniArtwork(
              artworkUrl: manifest?.artworkUrl,
              trackId: manifest?.trackId,
              title: manifest?.title,
              artist: manifest?.artistName,
            ),
            const SizedBox(width: WzSpacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14))),
                      const SizedBox(width: WzSpacing.xs),
                      _MiniBadge(label: sourceLabel),
                    ],
                  ),
                  const SizedBox(height: 3),
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
                  if (offlineReady || shuffleEnabled || repeatMode != WzRepeatMode.off || sleepTimerBadge != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (offlineReady) const _MiniBadge(label: 'Offline'),
                        if (shuffleEnabled) const _MiniBadge(label: 'Shuffle'),
                        if (repeatMode != WzRepeatMode.off) _MiniBadge(label: repeatMode == WzRepeatMode.one ? 'Repeat 1' : 'Repeat'),
                        if (sleepTimerBadge != null) _MiniBadge(label: sleepTimerBadge!),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: WzSpacing.sm),
            WzSculptedIconButton(
              tooltip: metrics.isPlaying ? 'Pause' : 'Play',
              icon: metrics.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 52,
              iconSize: 26,
              onPressed: controlsDisabled ? null : onPlayPause,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        ),
      );
}

class _PorcelainArtworkHero extends StatelessWidget {
  const _PorcelainArtworkHero({this.artworkUrl, required this.size, this.trackId, this.title, this.artist});

  final String? artworkUrl;
  final double size;
  final String? trackId;
  final String? title;
  final String? artist;

  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _PorcelainOrbitPainter())),
          Padding(
            padding: EdgeInsets.all(size * 0.075),
            child: Container(
              decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x251A405C), blurRadius: 38, offset: Offset(0, 18))]),
              child: ClipPath(
                clipper: _OrganicArtworkClipper(),
                child: SizedBox.expand(
                  child: url == null || url.trim().isEmpty
                      ? WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, size: size)
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, size: size),
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            right: size * 0.045,
            bottom: size * 0.12,
            child: const WzSculptedIcon(icon: Icons.graphic_eq_rounded, size: 48, iconSize: 21, color: WzColors.accent),
          ),
        ],
      ),
    );
  }
}

class _OrganicArtworkClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.18, h * 0.03)
      ..cubicTo(w * 0.52, -h * 0.02, w * 0.88, h * 0.07, w * 0.96, h * 0.31)
      ..cubicTo(w * 1.04, h * 0.56, w * 0.90, h * 0.89, w * 0.63, h * 0.97)
      ..cubicTo(w * 0.35, h * 1.05, w * 0.05, h * 0.91, w * 0.02, h * 0.62)
      ..cubicTo(-w * 0.02, h * 0.35, w * 0.01, h * 0.10, w * 0.18, h * 0.03)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PorcelainOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width * 0.035, size.height * 0.12, size.width * 0.93, size.height * 0.72);
    final white = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(4, size.width * 0.025)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.74);
    final blue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, size.width * 0.011)
      ..strokeCap = StrokeCap.round
      ..color = WzColors.accentAlt.withValues(alpha: 0.24);
    canvas.drawArc(rect, -0.42, math.pi * 1.14, false, white);
    canvas.drawArc(rect.shift(Offset(0, size.height * 0.045)), 2.20, math.pi * 0.92, false, blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NowTrackIdentity extends StatelessWidget {
  const _NowTrackIdentity({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.centered,
    required this.liked,
    required this.canSaveTrack,
    required this.onToggleLike,
  });

  final String title;
  final String subtitle;
  final String status;
  final bool centered;
  final bool liked;
  final bool canSaveTrack;
  final VoidCallback? onToggleLike;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          WzStatusPill(label: status, active: status == 'Playing', icon: status == 'Playing' ? Icons.graphic_eq_rounded : Icons.pause_rounded),
          const SizedBox(height: WzSpacing.sm),
          Row(
            mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: centered ? TextAlign.center : TextAlign.start,
                  style: WzText.display.copyWith(fontSize: 34),
                ),
              ),
              if (canSaveTrack) ...[
                const SizedBox(width: WzSpacing.sm),
                WzSculptedIconButton(
                  tooltip: liked ? 'Unlike' : 'Like',
                  icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  selected: liked,
                  size: 46,
                  iconSize: 21,
                  onPressed: onToggleLike,
                ),
              ],
            ],
          ),
          const SizedBox(height: WzSpacing.xs),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: WzText.body.copyWith(fontSize: 15),
          ),
        ],
      );
}

class _PlayerContextBadges extends StatelessWidget {
  const _PlayerContextBadges({
    required this.qualityLabel,
    required this.effectsSummary,
    required this.sourceLabel,
    required this.upNextTitle,
    required this.offlineReady,
    required this.status,
  });

  final String qualityLabel;
  final String effectsSummary;
  final String sourceLabel;
  final String? upNextTitle;
  final bool offlineReady;
  final String status;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.center,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: WzSpacing.xs,
          runSpacing: WzSpacing.xs,
          children: [
            WzStatusPill(label: wzProductQualityLabel(qualityLabel), active: qualityLabel != 'unknown', icon: Icons.high_quality_rounded),
            WzStatusPill(label: sourceLabel, active: sourceLabel == 'Downloaded' || sourceLabel == 'Offline Ready' || sourceLabel == 'Device', icon: Icons.radio_rounded),
            if (offlineReady) const WzStatusPill(label: 'Offline', active: true, icon: Icons.download_done_rounded),
            if (effectsSummary != 'Off') WzStatusPill(label: effectsSummary, active: effectsSummary == 'Applied', warning: effectsSummary == 'Pending' || effectsSummary == 'Failed', icon: Icons.tune_rounded),
            if (upNextTitle != null) WzStatusPill(label: 'Next • $upNextTitle', icon: Icons.skip_next_rounded),
          ],
        ),
      );
}

class _PlayerProgressBlock extends StatelessWidget {
  const _PlayerProgressBlock({
    required this.progressValue,
    required this.displayedPositionMs,
    required this.durationMs,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  final double progressValue;
  final int displayedPositionMs;
  final int? durationMs;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;

  @override
  Widget build(BuildContext context) {
    final remainingMs = durationMs == null ? null : math.max(0, durationMs! - displayedPositionMs);
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: WzColors.textPrimary,
            inactiveTrackColor: WzColors.border,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 4),
            overlayColor: WzColors.accent.withValues(alpha: 0.08),
          ),
          child: Slider(
            value: progressValue.clamp(0.0, 1.0),
            onChanged: onSeekChanged,
            onChangeEnd: onSeekEnd,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(_formatTime(displayedPositionMs), style: WzText.caption.copyWith(color: WzColors.textMuted)),
              const Spacer(),
              Text(remainingMs == null ? '—:—' : '-${_formatTime(remainingMs)}', style: WzText.caption),
              const Spacer(),
              Text(_formatTime(durationMs), style: WzText.caption.copyWith(color: WzColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerPrimaryControls extends StatelessWidget {
  const _PlayerPrimaryControls({
    required this.isPlaying,
    required this.controlsDisabled,
    required this.canPlayPrevious,
    required this.canPlayNext,
    required this.onPlayPause,
    required this.onStop,
    required this.onRetry,
    required this.onPrevious,
    required this.onNext,
  });

  final bool isPlaying;
  final bool controlsDisabled;
  final bool canPlayPrevious;
  final bool canPlayNext;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;
  final VoidCallback onRetry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WzSculptedIconButton(
                tooltip: 'Previous',
                icon: Icons.skip_previous_rounded,
                size: 56,
                iconSize: 27,
                onPressed: controlsDisabled || !canPlayPrevious ? null : onPrevious,
              ),
              const SizedBox(width: WzSpacing.lg),
              _PrimaryPlayButton(
                isPlaying: isPlaying,
                disabled: controlsDisabled,
                onPressed: onPlayPause,
              ),
              const SizedBox(width: WzSpacing.lg),
              WzSculptedIconButton(
                tooltip: 'Next',
                icon: Icons.skip_next_rounded,
                size: 56,
                iconSize: 27,
                onPressed: controlsDisabled || !canPlayNext ? null : onNext,
              ),
            ],
          ),
          const SizedBox(height: WzSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WzSculptedIconButton(tooltip: 'Stop', icon: Icons.stop_rounded, size: 40, iconSize: 18, onPressed: controlsDisabled ? null : onStop),
              const SizedBox(width: WzSpacing.sm),
              WzSculptedIconButton(tooltip: 'Retry', icon: Icons.replay_rounded, size: 40, iconSize: 18, onPressed: controlsDisabled ? null : onRetry),
            ],
          ),
        ],
      );
}

class _PrimaryPlayButton extends StatelessWidget {
  const _PrimaryPlayButton({required this.isPlaying, required this.disabled, required this.onPressed});

  final bool isPlaying;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 82,
        height: 82,
        child: WzPressableSurface(
          onTap: disabled ? null : onPressed,
          radius: 41,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(center: Alignment(-0.25, -0.35), radius: 1.1, colors: [Color(0xFFFFFFFF), Color(0xFFF2F5F7)]),
            border: Border.all(color: Colors.white, width: 1.4),
            boxShadow: const [
              BoxShadow(color: Color(0x21143147), blurRadius: 30, offset: Offset(0, 14)),
              BoxShadow(color: Color(0xFFFFFFFF), blurRadius: 12, offset: Offset(-4, -5)),
            ],
          ),
          child: Center(
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 38,
              color: disabled ? WzColors.textSubtle : WzColors.textPrimary,
            ),
          ),
        ),
      );
}

class _PlaybackModesCard extends StatelessWidget {
  const _PlaybackModesCard({
    required this.shuffleEnabled,
    required this.repeatMode,
    required this.sleepTimerLabel,
    required this.sleepTimerActive,
    required this.controlsDisabled,
    required this.onShuffleChanged,
    required this.onCycleRepeatMode,
    required this.onOpenSleepTimer,
  });

  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final String sleepTimerLabel;
  final bool sleepTimerActive;
  final bool controlsDisabled;
  final ValueChanged<bool> onShuffleChanged;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback onOpenSleepTimer;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ModeButton(
            icon: Icons.shuffle_rounded,
            label: 'Shuffle',
            selected: shuffleEnabled,
            onPressed: controlsDisabled ? null : () => onShuffleChanged(!shuffleEnabled),
          ),
          _ModeButton(
            icon: repeatMode.icon,
            label: repeatMode == WzRepeatMode.off ? 'Repeat' : repeatMode.label,
            selected: repeatMode != WzRepeatMode.off,
            onPressed: controlsDisabled ? null : onCycleRepeatMode,
          ),
          _ModeButton(
            icon: sleepTimerActive ? Icons.bedtime_rounded : Icons.timer_outlined,
            label: sleepTimerActive ? sleepTimerLabel : 'Timer',
            selected: sleepTimerActive,
            onPressed: controlsDisabled ? null : onOpenSleepTimer,
          ),
        ],
      );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.icon, required this.label, required this.selected, required this.onPressed});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WzSculptedIconButton(icon: icon, selected: selected, size: 46, iconSize: 19, onPressed: onPressed),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(color: selected ? WzColors.textPrimary : WzColors.textSubtle)),
          ],
        ),
      );
}

class _PlayerLibraryActions extends StatelessWidget {
  const _PlayerLibraryActions({
    required this.canSaveTrack,
    required this.liked,
    required this.onToggleLike,
    required this.onAddToCollection,
    required this.onAddToQueue,
    required this.onOpenQueue,
  });

  final bool canSaveTrack;
  final bool liked;
  final VoidCallback? onToggleLike;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onAddToQueue;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: WzSpacing.sm,
        runSpacing: WzSpacing.sm,
        children: [
          WzSculptedIconButton(tooltip: liked ? 'Unlike' : 'Like', icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, selected: liked, onPressed: canSaveTrack ? onToggleLike : null),
          WzSculptedIconButton(tooltip: 'Add to collection', icon: Icons.playlist_add_rounded, onPressed: canSaveTrack ? onAddToCollection : null),
          WzSculptedIconButton(tooltip: 'Add up next', icon: Icons.queue_music_rounded, onPressed: canSaveTrack ? onAddToQueue : null),
          WzSculptedIconButton(tooltip: 'Open queue', icon: Icons.format_list_bulleted_rounded, onPressed: onOpenQueue),
        ],
      );
}

class _PlayerUpNextPreview extends StatelessWidget {
  const _PlayerUpNextPreview({required this.nextTrack});

  final CatalogTrackSummary? nextTrack;

  @override
  Widget build(BuildContext context) => WzGlassCard(
        borderRadius: WzRadius.lg,
        padding: const EdgeInsets.symmetric(horizontal: WzSpacing.md, vertical: WzSpacing.sm),
        child: Row(
          children: [
            const WzSculptedIcon(icon: Icons.skip_next_rounded, size: 42, iconSize: 19, color: WzColors.accent),
            const SizedBox(width: WzSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Up next', style: WzText.eyebrow),
                  const SizedBox(height: 2),
                  Text(nextTrack?.title ?? 'Nothing queued yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14)),
                  Text(nextTrack?.subtitle ?? 'Add something when you want the music to continue.', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ContextTile extends StatelessWidget {
  const _ContextTile({required this.icon, required this.label, required this.value, required this.detail});

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        width: 250,
        padding: const EdgeInsets.all(WzSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xAFFFFFFF),
          borderRadius: BorderRadius.circular(WzRadius.lg),
          border: Border.all(color: WzColors.borderSoft),
        ),
        child: Row(
          children: [
            WzSculptedIcon(icon: icon, size: 42, iconSize: 18, color: WzColors.accent),
            const SizedBox(width: WzSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: WzText.caption),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14)),
                  Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({this.artworkUrl, this.trackId, this.title, this.artist});

  final String? artworkUrl;
  final String? trackId;
  final String? title;
  final String? artist;

  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: WzColors.borderSoft),
        boxShadow: WzSurface.softShadows,
      ),
      child: ClipOval(
        child: url == null || url.trim().isEmpty
            ? WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, size: 48, compact: true)
            : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, size: 48, compact: true)),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xBFFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: WzColors.borderSoft),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(fontSize: 10, color: WzColors.textMuted)),
      );
}

String wzEffectStatusLabel(NativeAudioEffectStatus status) {
  switch (status) {
    case NativeAudioEffectStatus.applied:
      return 'Applied';
    case NativeAudioEffectStatus.unsupported:
      return 'Unsupported';
    case NativeAudioEffectStatus.pending:
      return 'Pending';
    case NativeAudioEffectStatus.failed:
      return 'Failed';
    case NativeAudioEffectStatus.off:
      return 'Off';
  }
}

String wzPlayerSourceLabel({required bool isPlayingFromCache, required bool offlineReady, required bool hasTrack}) {
  if (isPlayingFromCache) return 'Downloaded';
  if (hasTrack) return 'Catalog';
  if (offlineReady) return 'Offline Ready';
  return 'Not cached';
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
    case 'stopped':
      return 'Paused';
    case 'ended':
    case 'playback_ended':
      return 'Ended';
    default:
      return 'Ready';
  }
}

String _formatTime(int? valueMs) {
  if (valueMs == null || valueMs < 0) return '—:—';
  final totalSeconds = (valueMs / 1000).floor();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
