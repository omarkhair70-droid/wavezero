import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio/audio_effects.dart';
import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../../playback/playback_metrics.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import 'playback_modes.dart';

class WzNowContextPanel extends StatelessWidget {
  const WzNowContextPanel({required this.qualityLabel, required this.effectsSummary, required this.playingFromCache, required this.devicePlayback, required this.offlineReady, required this.nextTrack, required this.manifest, required this.selectedEffectProfile, required this.nativeAudioEffectStatus, required this.queueIndex, required this.queueLength});
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
    final currentPosition = queueIndex >= 0 && queueLength > 0 ? '${queueIndex + 1} of $queueLength' : 'No active queue item';
    final bitrate = manifest?.bitrateKbps == null ? 'Unknown bitrate' : '${manifest!.bitrateKbps} kbps';
    final codec = manifest?.codec ?? 'Unknown codec';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const WzSectionHeader(title: 'Player context', subtitle: 'Live quality, effects, cache, and queue state.', icon: Icons.dashboard_customize),
      _PlayerSourceCard(icon: Icons.high_quality, title: 'Audio Quality', primary: wzProductQualityLabel(qualityLabel), detail: '$codec • $bitrate', active: qualityLabel != 'unknown'),
      const SizedBox(height: WzSpacing.sm),
      _PlayerSourceCard(icon: Icons.tune, title: 'Audio Effects', primary: selectedEffectProfile.label, detail: 'Native status: ${wzEffectStatusLabel(nativeAudioEffectStatus)} • Badge: $effectsSummary', active: nativeAudioEffectStatus == NativeAudioEffectStatus.applied),
      const SizedBox(height: WzSpacing.sm),
      _PlayerSourceCard(icon: Icons.offline_pin, title: 'Cache / Offline', primary: devicePlayback ? 'Already local' : playingFromCache ? 'Playing from cache' : offlineReady ? 'Offline Ready' : 'Not cached', detail: devicePlayback ? 'Playing from Device music.' : playingFromCache ? 'Playing from Downloaded music.' : offlineReady ? 'Offline Ready music is available.' : 'No downloaded track is active right now.', active: devicePlayback || playingFromCache || offlineReady),
      const SizedBox(height: WzSpacing.sm),
      _PlayerSourceCard(icon: Icons.queue_music, title: 'Queue', primary: currentPosition, detail: nextTrack == null ? 'No up-next track from Queue Engine v2.' : 'Up next: ${nextTrack!.title}', active: nextTrack != null),
    ]);
  }
}

class WzPremiumPlayerSheet extends StatelessWidget {
  const WzPremiumPlayerSheet({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.28,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF181D33), Color(0xFF070A13)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: WzColors.borderSoft)),
            boxShadow: [BoxShadow(color: Color(0xAA000000), blurRadius: 32, offset: Offset(0, -18))],
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(WzSpacing.md, WzSpacing.sm, WzSpacing.md, WzSpacing.xl),
              children: [
                Center(child: Container(width: 46, height: 5, margin: const EdgeInsets.only(bottom: WzSpacing.sm), decoration: BoxDecoration(color: Colors.white.withOpacity(0.28), borderRadius: BorderRadius.circular(999)))),
                Row(children: [
                  const Expanded(child: Text('Now playing', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.eyebrow)),
                  IconButton(tooltip: 'Close player', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.keyboard_arrow_down)),
                ]),
                const SizedBox(height: WzSpacing.xs),
                child,
              ],
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
    final subtitle = manifest?.subtitle ?? 'Choose a track from Library to begin playback.';
    final status = metrics.isPlaying ? 'Playing' : _statusFromEvent(metrics.lastEvent);
    return WzPanel(
      padding: const EdgeInsets.all(WzSpacing.md),
      gradient: WzColors.heroGradient,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 620;
          final artSize = stacked ? math.min(220.0, constraints.maxWidth) : 280.0;
          final art = _PlayerArtworkHero(artworkUrl: manifest?.artworkUrl, size: artSize, trackId: manifest?.trackId, title: manifest?.title, artist: manifest?.artistName);
          final identity = _NowTrackIdentity(title: title, subtitle: subtitle, status: status);
          if (stacked) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Center(child: art), const SizedBox(height: WzSpacing.xl), identity]);
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [art, const SizedBox(width: WzSpacing.xxl), Expanded(child: identity)]);
        }),
        const SizedBox(height: WzSpacing.lg),
        _PlayerContextBadges(qualityLabel: qualityLabel, effectsSummary: effectsSummary, sourceLabel: sourceLabel, upNextTitle: nextTrack?.title, offlineReady: offlineReady, status: status),
        const SizedBox(height: WzSpacing.xl),
        _PlayerProgressBlock(progressValue: progressValue, displayedPositionMs: displayedPositionMs, durationMs: durationMs, onSeekChanged: onSeekChanged, onSeekEnd: onSeekEnd),
        const SizedBox(height: WzSpacing.xl),
        _PlayerPrimaryControls(isPlaying: metrics.isPlaying, controlsDisabled: controlsDisabled, canPlayPrevious: canPlayPrevious, canPlayNext: canPlayNext, onPlayPause: onPlayPause, onStop: onStop, onRetry: onRetry, onPrevious: onPrevious, onNext: onNext),
        const SizedBox(height: WzSpacing.md),
        _PlaybackModesCard(shuffleEnabled: shuffleEnabled, repeatMode: repeatMode, sleepTimerLabel: sleepTimerLabel, sleepTimerActive: sleepTimerActive, controlsDisabled: controlsDisabled, onShuffleChanged: onShuffleChanged, onCycleRepeatMode: onCycleRepeatMode, onOpenSleepTimer: onOpenSleepTimer),
        const SizedBox(height: WzSpacing.sm),
        Wrap(alignment: WrapAlignment.center, spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
          OutlinedButton.icon(onPressed: canSaveTrack ? onToggleLike : null, icon: Icon(liked ? Icons.favorite : Icons.favorite_border), label: Text(liked ? 'Liked' : 'Like')),
          OutlinedButton.icon(onPressed: canSaveTrack ? onAddToCollection : null, icon: const Icon(Icons.playlist_add), label: const Text('Add to collection')),
          OutlinedButton.icon(onPressed: canSaveTrack ? onAddToQueue : null, icon: const Icon(Icons.queue_music), label: const Text('Add up next')),
          OutlinedButton.icon(onPressed: onOpenQueue, icon: const Icon(Icons.open_in_new), label: const Text('Open queue')),
        ]),
        const SizedBox(height: WzSpacing.lg),
        _PlayerUpNextPreview(nextTrack: nextTrack),
      ]),
    );
  }
}

class _PlaybackModesCard extends StatelessWidget {
  const _PlaybackModesCard({required this.shuffleEnabled, required this.repeatMode, required this.sleepTimerLabel, required this.sleepTimerActive, required this.controlsDisabled, required this.onShuffleChanged, required this.onCycleRepeatMode, required this.onOpenSleepTimer});
  final bool shuffleEnabled;
  final WzRepeatMode repeatMode;
  final String sleepTimerLabel;
  final bool sleepTimerActive;
  final bool controlsDisabled;
  final ValueChanged<bool> onShuffleChanged;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback onOpenSleepTimer;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: WzMotion.normal,
        curve: WzMotion.curve,
        padding: const EdgeInsets.all(WzSpacing.sm),
        decoration: BoxDecoration(color: WzColors.surfaceMuted.withOpacity(0.56), borderRadius: BorderRadius.circular(WzRadius.lg), border: Border.all(color: WzColors.borderSoft)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Playback modes', style: WzText.eyebrow),
          const SizedBox(height: WzSpacing.sm),
          Wrap(alignment: WrapAlignment.center, spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
            FilterChip(avatar: const Icon(Icons.shuffle, size: 18), label: Text(shuffleEnabled ? 'Shuffle on' : 'Shuffle'), selected: shuffleEnabled, onSelected: controlsDisabled ? null : onShuffleChanged),
            OutlinedButton.icon(onPressed: controlsDisabled ? null : onCycleRepeatMode, icon: Icon(repeatMode.icon), label: Text(repeatMode.label)),
            OutlinedButton.icon(onPressed: controlsDisabled ? null : onOpenSleepTimer, icon: Icon(sleepTimerActive ? Icons.bedtime : Icons.timer_outlined), label: Text(sleepTimerActive ? sleepTimerLabel : 'Sleep timer')),
          ]),
        ]),
      );
}

class _PlayerArtworkHero extends StatelessWidget {
  const _PlayerArtworkHero({this.artworkUrl, required this.size, this.trackId, this.title, this.artist, this.mood});
  final String? artworkUrl;
  final double size;
  final String? trackId;
  final String? title;
  final String? artist;
  final String? mood;
  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return AnimatedContainer(
      duration: WzMotion.slow,
      curve: WzMotion.curve,
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(WzRadius.xl), gradient: WzColors.accentGradient, border: Border.all(color: WzColors.border), boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 36, offset: Offset(0, 24))]),
      child: url == null || url.trim().isEmpty
          ? WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, mood: mood, size: size)
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, mood: mood, size: size)),
    );
  }
}

class _NowTrackIdentity extends StatelessWidget {
  const _NowTrackIdentity({required this.title, required this.subtitle, required this.status});
  final String title;
  final String subtitle;
  final String status;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WzStatusPill(label: status, active: status == 'Playing', icon: status == 'Playing' ? Icons.play_arrow : Icons.pause),
        const SizedBox(height: WzSpacing.md),
        Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.display.copyWith(fontSize: 34)),
        const SizedBox(height: WzSpacing.sm),
        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.body.copyWith(fontSize: 15)),
      ]);
}

class _PlayerContextBadges extends StatelessWidget {
  const _PlayerContextBadges({required this.qualityLabel, required this.effectsSummary, required this.sourceLabel, required this.upNextTitle, required this.offlineReady, required this.status});
  final String qualityLabel;
  final String effectsSummary;
  final String sourceLabel;
  final String? upNextTitle;
  final bool offlineReady;
  final String status;
  @override
  Widget build(BuildContext context) => Wrap(spacing: WzSpacing.sm, runSpacing: WzSpacing.sm, children: [
        WzStatusPill(label: status, active: status == 'Playing', icon: status == 'Playing' ? Icons.play_arrow : Icons.pause),
        WzStatusPill(label: 'Quality: ${wzProductQualityLabel(qualityLabel)}', active: qualityLabel != 'unknown', icon: Icons.high_quality),
        WzStatusPill(label: 'Effects: $effectsSummary', active: effectsSummary == 'Applied', warning: effectsSummary == 'Pending' || effectsSummary == 'Failed', icon: Icons.tune),
        WzStatusPill(label: 'Source: $sourceLabel', active: sourceLabel == 'Cache' || sourceLabel == 'Offline Ready' || sourceLabel == 'Device', icon: sourceLabel == 'Device' ? Icons.phone_android : Icons.offline_pin),
        if (offlineReady) const WzStatusPill(label: 'Offline Ready', active: true, icon: Icons.download_done),
        WzStatusPill(label: upNextTitle == null ? 'Up next: none' : 'Up next: $upNextTitle', active: upNextTitle != null, icon: Icons.skip_next),
      ]);
}

class _PlayerProgressBlock extends StatelessWidget {
  const _PlayerProgressBlock({required this.progressValue, required this.displayedPositionMs, required this.durationMs, required this.onSeekChanged, required this.onSeekEnd});
  final double progressValue;
  final int displayedPositionMs;
  final int? durationMs;
  final ValueChanged<double>? onSeekChanged;
  final ValueChanged<double>? onSeekEnd;
  @override
  Widget build(BuildContext context) {
    final remainingMs = durationMs == null ? null : (durationMs! - displayedPositionMs).clamp(0, durationMs!).toInt();
    final percent = (progressValue * 100).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: WzSpacing.xs, vertical: WzSpacing.xs), decoration: BoxDecoration(color: WzColors.surfaceMuted.withOpacity(0.46), borderRadius: BorderRadius.circular(WzRadius.lg), border: Border.all(color: WzColors.borderSoft)), child: SliderTheme(data: SliderTheme.of(context).copyWith(trackHeight: 7, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9)), child: Slider(value: progressValue, onChanged: onSeekChanged, onChangeEnd: onSeekEnd))),
      const SizedBox(height: WzSpacing.xs),
      Row(children: [Text(_formatTime(displayedPositionMs), style: WzText.caption.copyWith(color: WzColors.textPrimary)), Expanded(child: Text(durationMs == null ? 'Duration unknown' : '$percent% • -${_formatTime(remainingMs)}', textAlign: TextAlign.center, style: WzText.caption)), Text(_formatTime(durationMs), style: WzText.caption.copyWith(color: WzColors.textPrimary))]),
    ]);
  }
}

class _PlayerPrimaryControls extends StatelessWidget {
  const _PlayerPrimaryControls({required this.isPlaying, required this.controlsDisabled, required this.canPlayPrevious, required this.canPlayNext, required this.onPlayPause, required this.onStop, required this.onRetry, required this.onPrevious, required this.onNext});
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
  Widget build(BuildContext context) => Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: WzSpacing.md, runSpacing: WzSpacing.sm, children: [
        IconButton.outlined(tooltip: 'Retry', onPressed: controlsDisabled ? null : onRetry, icon: const Icon(Icons.replay)),
        IconButton.filledTonal(tooltip: 'Previous', onPressed: controlsDisabled || !canPlayPrevious ? null : onPrevious, icon: const Icon(Icons.skip_previous), iconSize: 30),
        SizedBox(width: 84, height: 84, child: FilledButton(onPressed: controlsDisabled ? null : onPlayPause, style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: WzColors.accent), child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 44))),
        IconButton.filledTonal(tooltip: 'Next', onPressed: controlsDisabled || !canPlayNext ? null : onNext, icon: const Icon(Icons.skip_next), iconSize: 30),
        IconButton.outlined(tooltip: 'Stop', onPressed: controlsDisabled ? null : onStop, icon: const Icon(Icons.stop)),
        IconButton.outlined(tooltip: 'Retry', onPressed: controlsDisabled ? null : onRetry, icon: const Icon(Icons.replay)),
      ]);
}

class _PlayerUpNextPreview extends StatelessWidget {
  const _PlayerUpNextPreview({required this.nextTrack});
  final CatalogTrackSummary? nextTrack;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(WzSpacing.md),
        decoration: BoxDecoration(color: WzColors.surfaceMuted.withOpacity(0.72), borderRadius: BorderRadius.circular(WzRadius.lg), border: Border.all(color: WzColors.borderSoft)),
        child: Row(children: [
          Icon(Icons.queue_music, color: nextTrack == null ? WzColors.textSubtle : WzColors.accentAlt),
          const SizedBox(width: WzSpacing.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Up next', style: WzText.eyebrow),
            const SizedBox(height: WzSpacing.xxs),
            Text(nextTrack?.title ?? 'Add more tracks to Queue', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
            if (nextTrack != null) Text(nextTrack!.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
          ])),
        ]),
      );
}

class _PlayerSourceCard extends StatelessWidget {
  const _PlayerSourceCard({required this.icon, required this.title, required this.primary, required this.detail, required this.active});
  final IconData icon;
  final String title;
  final String primary;
  final String detail;
  final bool active;
  @override
  Widget build(BuildContext context) => WzPanel(
        padding: const EdgeInsets.all(WzSpacing.md),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: active ? WzColors.successSoft : WzColors.accentSoft, borderRadius: BorderRadius.circular(WzRadius.md)), child: Icon(icon, color: active ? WzColors.success : WzColors.accent)),
          const SizedBox(width: WzSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: WzText.caption),
            const SizedBox(height: WzSpacing.xxs),
            Text(primary, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
            Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
          ])),
        ]),
      );
}

class WzPremiumMiniPlayer extends StatelessWidget {
  const WzPremiumMiniPlayer({required this.metrics, required this.manifest, required this.progressValue, required this.sourceLabel, required this.offlineReady, required this.shuffleEnabled, required this.repeatMode, required this.sleepTimerBadge, required this.controlsDisabled, required this.onTap, required this.onPlayPause});
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(WzRadius.xl),
          onTap: onTap,
          child: AnimatedContainer(
            duration: WzMotion.slow,
            curve: WzMotion.curve,
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xEE20263F), Color(0xEE0A0D18)]), borderRadius: BorderRadius.circular(WzRadius.xl), border: Border.all(color: WzColors.borderSoft), boxShadow: const [BoxShadow(color: Color(0x77000000), blurRadius: 24, offset: Offset(0, 12))]),
            child: Row(children: [
              _MiniArtwork(artworkUrl: manifest?.artworkUrl, trackId: manifest?.trackId, title: manifest?.title, artist: manifest?.artistName),
              const SizedBox(width: WzSpacing.sm),
              Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: WzSpacing.xs, runSpacing: WzSpacing.xxs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 14))),
                  _MiniBadge(label: sourceLabel),
                  if (offlineReady) const _MiniBadge(label: 'Offline Ready'),
                  if (shuffleEnabled) const _MiniBadge(label: 'Shuffle'),
                  if (repeatMode != WzRepeatMode.off) _MiniBadge(label: repeatMode == WzRepeatMode.one ? 'Repeat 1' : 'Repeat all'),
                  if (sleepTimerBadge != null) _MiniBadge(label: sleepTimerBadge!),
                ]),
                const SizedBox(height: WzSpacing.xxs),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                const SizedBox(height: WzSpacing.xs),
                ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: progressValue.clamp(0.0, 1.0), minHeight: 3, backgroundColor: Colors.white.withOpacity(0.10), valueColor: const AlwaysStoppedAnimation<Color>(WzColors.accentAlt))),
              ])),
              const SizedBox(width: WzSpacing.xs),
              IconButton.filled(tooltip: metrics.isPlaying ? 'Pause' : 'Play', onPressed: controlsDisabled ? null : onPlayPause, icon: Icon(metrics.isPlaying ? Icons.pause : Icons.play_arrow)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({this.artworkUrl, this.trackId, this.title, this.artist, this.mood});
  final String? artworkUrl;
  final String? trackId;
  final String? title;
  final String? artist;
  final String? mood;
  @override
  Widget build(BuildContext context) {
    final url = artworkUrl;
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: WzColors.accentGradient, borderRadius: BorderRadius.circular(WzRadius.md), border: Border.all(color: Colors.white.withOpacity(0.16))),
      child: url == null || url.trim().isEmpty
          ? WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, mood: mood, size: 48, compact: true)
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => WzWaveZeroCoverArt(trackId: trackId, title: title, artist: artist, mood: mood, size: 48, compact: true)),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.10))),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(fontSize: 10, color: WzColors.textPrimary)),
      );
}

String wzEffectStatusLabel(NativeAudioEffectStatus status) {
  switch (status) {
    case NativeAudioEffectStatus.applied: return 'Applied';
    case NativeAudioEffectStatus.unsupported: return 'Unsupported';
    case NativeAudioEffectStatus.pending: return 'Pending';
    case NativeAudioEffectStatus.failed: return 'Failed';
    case NativeAudioEffectStatus.off: return 'Off';
  }
}

String wzPlayerSourceLabel({required bool isPlayingFromCache, required bool offlineReady, required bool hasTrack}

String _statusFromEvent(String? event) { switch (event) { case 'track_loaded': case 'buffering_started': return 'Preparing'; case 'ready': case 'buffering_ended': case 'manifest_loaded': return 'Ready'; case 'not_playing': return 'Paused'; case 'stopped': return 'Paused'; case 'ended': case 'playback_ended': return 'Ended'; default: return 'Ready'; } }

String _formatTime(int? valueMs) { if (valueMs == null || valueMs < 0) return '—:—'; final totalSeconds = (valueMs / 1000).floor(); final minutes = totalSeconds ~/ 60; final seconds = totalSeconds % 60; return '$minutes:${seconds.toString().padLeft(2, '0')}'; }
