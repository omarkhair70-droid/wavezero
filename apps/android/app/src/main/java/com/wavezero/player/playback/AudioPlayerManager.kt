package com.wavezero.player.playback

import android.content.Context
import android.os.SystemClock
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Metadata
import androidx.media3.common.Tracks
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.LoadEventInfo
import androidx.media3.exoplayer.source.MediaLoadData
import androidx.media3.session.MediaSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@OptIn(UnstableApi::class)
class AudioPlayerManager(
    context: Context,
    hlsUrl: String = DemoTrack.hlsUrl,
    private val appStartedAtMs: Long = SystemClock.elapsedRealtime(),
    enableMediaSession: Boolean = true,
) {
    private data class ActiveCrossfade(
        val trackId: String,
        val title: String,
        val url: String,
        val outgoing: ExoPlayer,
        val incoming: ExoPlayer,
        val durationMs: Long,
        var progress: Float = 0f,
        var acknowledged: Boolean = false,
    )

    private data class PendingPrebuffer(
        val trackId: String,
        val title: String,
        val url: String,
    )

    private val managerJob = SupervisorJob()
    private val scope = CoroutineScope(managerJob + Dispatchers.Main.immediate)
    private val metricsTracker = PlaybackMetricsTracker(nowMs = SystemClock::elapsedRealtime)
    private var positionJob: Job? = null
    private var crossfadeJob: Job? = null
    private var activeCrossfade: ActiveCrossfade? = null
    private var pendingPrebuffer: PendingPrebuffer? = null
    private var currentTrack = NotificationTrackSnapshot.manual(DemoTrack.title, hlsUrl)
    private var currentTrackTitle: String = currentTrack.title
    private var currentHlsUrl: String = currentTrack.url
    private var notificationQueueSnapshot: List<NotificationTrackSnapshot> = emptyList()
    private var currentTrackLoaded = false
    private var mediaNotificationShown = false
    private var lastNotificationAction: String = "none"
    private var lastNotificationActionResult: String = "none"
    private var lastNotificationActionTrackId: String? = null
    private var artworkStatus: String = if (currentTrack.artworkUrl.isNullOrBlank()) "none" else "uri_set"
    private var playCommandInFlight = false
    private var softStopped = false
    private var nativePrebufferTrackId: String? = null
    private var nativePrebufferTitle: String? = null
    private var nativePrebufferUrl: String? = null
    private var nativePrebufferStartedAtMs: Long? = null
    private val nativeDspController = NativeDspController()

    private val appContext = context.applicationContext
    private val soundEnginePreferences = appContext.getSharedPreferences(SOUND_ENGINE_PREFS, Context.MODE_PRIVATE)
    private var loudnessNormalizationEnabled = soundEnginePreferences.getBoolean(LOUDNESS_NORMALIZATION_KEY, false)
    private var crossfadeDurationMs = soundEnginePreferences
        .getLong(CROSSFADE_DURATION_KEY, CROSSFADE_OFF_MS)
        .takeIf(ALLOWED_CROSSFADE_DURATIONS::contains)
        ?: CROSSFADE_OFF_MS
    private val channelAudioState = WaveZeroChannelAudioState(
        initialBalance = soundEnginePreferences.getFloat(CHANNEL_BALANCE_KEY, 0f).toDouble(),
        initialMono = soundEnginePreferences.getBoolean(MONO_OUTPUT_KEY, false),
    )

    private var player: ExoPlayer = buildPrimaryPlayer()

    private var prebufferPlayer: ExoPlayer = buildPrebufferPlayer()

    val mediaSession: MediaSession? = if (enableMediaSession) {
        MediaSession.Builder(appContext, player)
            .setId(MEDIA_SESSION_ID)
            .build()
    } else {
        null
    }

    private val mutablePlaybackState = MutableStateFlow(PlaybackState())
    val playbackState: StateFlow<PlaybackState> = mutablePlaybackState.asStateFlow()

    private val mutableMetrics = MutableStateFlow(metricsTracker.snapshot())
    val metrics: StateFlow<PlaybackMetrics> = mutableMetrics.asStateFlow()

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            if (softStopped) {
                playCommandInFlight = false
                mutablePlaybackState.value = PlaybackState(
                    status = PlaybackStatus.Paused,
                    trackTitle = currentTrackTitle,
                )
                return
            }

            when (playbackState) {
                Player.STATE_BUFFERING -> {
                    publish(metricsTracker.markBufferingStarted())
                    mutablePlaybackState.value = PlaybackState(
                        status = PlaybackStatus.Buffering,
                        trackTitle = currentTrackTitle,
                    )
                }

                Player.STATE_READY -> {
                    playCommandInFlight = false
                    publish(metricsTracker.markBufferingEnded())
                    publish(metricsTracker.markReady())
                    mutablePlaybackState.value = PlaybackState(
                        status = if (player.isPlaying) PlaybackStatus.Playing else PlaybackStatus.Ready,
                        trackTitle = currentTrackTitle,
                    )
                }

                Player.STATE_ENDED -> {
                    playCommandInFlight = false
                    positionJob?.cancel()
                    publish(metricsTracker.markEnded(player.currentPosition))
                    mutablePlaybackState.value = PlaybackState(
                        status = PlaybackStatus.Ended,
                        trackTitle = currentTrackTitle,
                    )
                }

                Player.STATE_IDLE -> {
                    if (!player.playWhenReady) positionJob?.cancel()
                    mutablePlaybackState.value = PlaybackState(
                        status = PlaybackStatus.Idle,
                        trackTitle = currentTrackTitle,
                    )
                }
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (softStopped) {
                playCommandInFlight = false
                return
            }

            if (isPlaying) {
                playCommandInFlight = false
                publish(metricsTracker.markPlaying(player.currentPosition))
                mutablePlaybackState.value = PlaybackState(
                    status = PlaybackStatus.Playing,
                    trackTitle = currentTrackTitle,
                )
            } else {
                if (player.playbackState == Player.STATE_ENDED) return
                if (!player.playWhenReady) positionJob?.cancel()
                publish(metricsTracker.markNotPlaying(player.currentPosition))
                if (mutablePlaybackState.value.status == PlaybackStatus.Playing) {
                    mutablePlaybackState.value = PlaybackState(
                        status = PlaybackStatus.Paused,
                        trackTitle = currentTrackTitle,
                    )
                }
            }
        }

        override fun onTracksChanged(tracks: Tracks) {
            applyReplayGainFromTracks(tracks, player)
        }

        override fun onMetadata(metadata: Metadata) {
            ReplayGainMetadata.parse(metadata)?.let { info ->
                nativeDspController.setReplayGain(info, player)
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            if (softStopped) {
                playCommandInFlight = false
                return
            }

            cancelActiveCrossfade(keepAcknowledgedIncoming = true)
            positionJob?.cancel()
            clearNativePrebuffer(NativePrebufferClearReason.NativePlaybackError)
            playCommandInFlight = false
            publish(metricsTracker.markError(error.message ?: error.errorCodeName))
            mutablePlaybackState.value = PlaybackState(
                status = PlaybackStatus.Error,
                trackTitle = currentTrackTitle,
            )
        }
    }

    private val prebufferListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            val trackId = nativePrebufferTrackId ?: return
            when (playbackState) {
                Player.STATE_READY -> {
                    if (
                        prebufferPlayer.playbackState != Player.STATE_READY ||
                        prebufferPlayer.currentMediaItem?.mediaId != trackId
                    ) {
                        return
                    }
                    nativeDspController.onAudioSessionChanged(prebufferPlayer.audioSessionId, prebufferPlayer)
                    applyReplayGainFromTracks(prebufferPlayer.currentTracks, prebufferPlayer)
                    val startedAt = nativePrebufferStartedAtMs ?: SystemClock.elapsedRealtime()
                    publish(metricsTracker.markNativePrebufferReady(trackId, SystemClock.elapsedRealtime() - startedAt))
                }

                Player.STATE_ENDED, Player.STATE_IDLE -> Unit
                Player.STATE_BUFFERING -> Unit
            }
        }

        override fun onTracksChanged(tracks: Tracks) {
            applyReplayGainFromTracks(tracks, prebufferPlayer)
        }

        override fun onMetadata(metadata: Metadata) {
            ReplayGainMetadata.parse(metadata)?.let { info ->
                nativeDspController.setReplayGain(info, prebufferPlayer)
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            if (activeCrossfade?.incoming === prebufferPlayer) {
                cancelActiveCrossfade(keepAcknowledgedIncoming = false)
            }
            clearNativePrebuffer(NativePrebufferClearReason.NativePlaybackError)
        }
    }

    private val analyticsListener = object : AnalyticsListener {
        override fun onAudioSessionIdChanged(
            eventTime: AnalyticsListener.EventTime,
            audioSessionId: Int,
        ) {
            nativeDspController.onAudioSessionChanged(audioSessionId, player)
        }

        override fun onLoadCompleted(
            eventTime: AnalyticsListener.EventTime,
            loadEventInfo: LoadEventInfo,
            mediaLoadData: MediaLoadData,
        ) {
            if (softStopped) return

            if (mediaLoadData.dataType == C.DATA_TYPE_MANIFEST) {
                publish(metricsTracker.markManifestLoaded(loadEventInfo.loadDurationMs))
            }
        }
    }

    init {
        player.setMediaItem(mediaItemFor(currentTrack))
        publish(metricsTracker.loadTrack(currentTrackTitle, currentHlsUrl))
        player.addListener(playerListener)
        player.addAnalyticsListener(analyticsListener)
        prebufferPlayer.addListener(prebufferListener)
        nativeDspController.setLoudnessNormalizationEnabled(loudnessNormalizationEnabled, player)
    }

    fun markScreenReady() {
        publish(metricsTracker.markScreenReady(appStartedAtMs))
    }

    fun loadTrack(title: String, hlsUrl: String) {
        loadTrack(NotificationTrackSnapshot.manual(title, hlsUrl))
    }

    fun loadTrack(track: NotificationTrackSnapshot) {
        cancelActiveCrossfade(keepAcknowledgedIncoming = true)
        clearNativePrebuffer(NativePrebufferClearReason.TrackLoaded)
        nativeDspController.clearReplayGain(player)
        applyCurrentTrack(track)
        currentTrackLoaded = true
        playCommandInFlight = false
        softStopped = false
        positionJob?.cancel()
        player.stop()
        player.clearMediaItems()
        player.setMediaItem(mediaItemFor(currentTrack))
        publish(metricsTracker.loadTrack(currentTrackTitle, currentHlsUrl))
        mutablePlaybackState.value = PlaybackState(
            status = PlaybackStatus.Buffering,
            trackTitle = currentTrackTitle,
        )
        player.prepare()
    }

    fun updateMediaNotificationMetadata(track: NotificationTrackSnapshot) {
        applyCurrentTrack(track)
        currentTrackLoaded = true
        if (player.mediaItemCount > 0) {
            player.replaceMediaItem(player.currentMediaItemIndex.coerceAtLeast(0), mediaItemFor(currentTrack))
        } else {
            player.setMediaItem(mediaItemFor(currentTrack))
        }
    }

    fun updateNotificationQueueSnapshot(queue: List<NotificationTrackSnapshot>) {
        notificationQueueSnapshot = queue.filter { it.hasPlayableUrl() }
        lastNotificationActionResult = "queue_updated"
    }

    fun shouldRefreshMediaControlsForQueueSnapshotUpdate(): Boolean = currentTrackLoaded || mediaNotificationShown

    fun markMediaNotificationShown() {
        mediaNotificationShown = true
    }

    fun markMediaNotificationDismissed() {
        mediaNotificationShown = false
    }

    fun prepareNextTrack(trackId: String, title: String, hlsUrl: String) {
        val safeTrackId = trackId.trim()
        val safeTitle = title.ifBlank { "Up next" }
        if (safeTrackId.isBlank() || hlsUrl.isBlank()) {
            clearNativePrebuffer(NativePrebufferClearReason.InvalidCandidate)
            return
        }

        val crossfade = activeCrossfade
        if (crossfade != null) {
            if (crossfade.trackId == safeTrackId && crossfade.url == hlsUrl) return
            if (crossfade.acknowledged) {
                pendingPrebuffer = PendingPrebuffer(safeTrackId, safeTitle, hlsUrl)
                return
            }
        }

        if (
            nativePrebufferTrackId == safeTrackId &&
            nativePrebufferUrl == hlsUrl &&
            (prebufferPlayer.playbackState == Player.STATE_BUFFERING || prebufferPlayer.playbackState == Player.STATE_READY)
        ) {
            return
        }

        nativePrebufferTrackId = safeTrackId
        nativePrebufferTitle = safeTitle
        nativePrebufferUrl = hlsUrl
        nativePrebufferStartedAtMs = SystemClock.elapsedRealtime()
        nativeDspController.onSecondaryPlayerChanged(prebufferPlayer)
        prebufferPlayer.playWhenReady = false
        prebufferPlayer.stop()
        prebufferPlayer.clearMediaItems()
        prebufferPlayer.setMediaItem(mediaItemFor(NotificationTrackSnapshot(trackId = safeTrackId, title = safeTitle, url = hlsUrl)))
        publish(metricsTracker.markNativePrebufferStarted(safeTrackId, safeTitle))
        prebufferPlayer.prepare()
    }

    fun playPreparedNextTrackIfReady(trackId: String, title: String, hlsUrl: String): Boolean {
        return playPreparedNextTrackIfReady(
            trackId = trackId,
            title = title,
            hlsUrl = hlsUrl,
            source = PreparedHandoffSource.ExplicitNext,
        )
    }

    fun playPreparedAutoAdvanceTrackIfReady(trackId: String, title: String, hlsUrl: String): Boolean {
        return playPreparedNextTrackIfReady(
            trackId = trackId,
            title = title,
            hlsUrl = hlsUrl,
            source = PreparedHandoffSource.AutoAdvance,
        )
    }

    fun clearNextTrackPrebuffer() {
        if (activeCrossfade?.acknowledged != true) {
            cancelActiveCrossfade(keepAcknowledgedIncoming = false)
        }
        clearNativePrebuffer(NativePrebufferClearReason.FlutterRequested)
    }

    fun recordNextTrackPrebufferOutcome(trackId: String, usedPreparedPath: Boolean) {
        if (trackId.isBlank()) return
        publish(metricsTracker.markNativePrebufferOutcome(trackId, usedPreparedPath))
    }

    fun recordAutoAdvancePreparedFallback(trackId: String) {
        val safeTrackId = trackId.trim()
        if (safeTrackId.isBlank()) return
        publish(metricsTracker.markAutoAdvancePreparedAttempted())
        recordNextTrackPrebufferOutcome(safeTrackId, usedPreparedPath = false)
        publish(metricsTracker.markAutoAdvancePreparedFallback(safeTrackId))
    }

    fun play() {
        softStopped = false
        ensureCurrentMediaItemLoaded()

        if (player.playbackState == Player.STATE_IDLE) {
            player.prepare()
        } else if (player.playbackState == Player.STATE_ENDED) {
            player.seekTo(0)
        }

        if (player.isPlaying || player.playWhenReady || playCommandInFlight) {
            player.playWhenReady = true
            startPositionUpdates()
            return
        }

        playCommandInFlight = true
        publish(metricsTracker.markPlayTapped())
        if (player.playbackState == Player.STATE_READY) {
            publish(metricsTracker.markReady())
        } else {
            player.prepare()
        }
        player.playWhenReady = true
        startPositionUpdates()
    }

    fun pause() {
        cancelActiveCrossfade(keepAcknowledgedIncoming = true)
        softStopped = false
        playCommandInFlight = false
        player.pause()
        positionJob?.cancel()
        publish(metricsTracker.markNotPlaying(player.currentPosition))
        mutablePlaybackState.value = PlaybackState(
            status = PlaybackStatus.Paused,
            trackTitle = currentTrackTitle,
        )
    }

    fun togglePlayPause() {
        if (player.isPlaying) {
            pause()
        } else {
            play()
        }
    }

    fun playPreviousFromNotification(): Boolean = playQueueOffsetFromNotification(-1, "previous")

    fun playNextFromNotification(): Boolean = playQueueOffsetFromNotification(1, "next")

    fun stop() {
        cancelActiveCrossfade(keepAcknowledgedIncoming = true)
        softStopped = true
        playCommandInFlight = false
        player.playWhenReady = false
        player.pause()
        ensureCurrentMediaItemLoaded()
        player.seekTo(0)
        positionJob?.cancel()
        clearNativePrebuffer(NativePrebufferClearReason.Stop)
        publish(metricsTracker.resetForStop())
        mutablePlaybackState.value = PlaybackState(
            status = PlaybackStatus.Paused,
            trackTitle = currentTrackTitle,
        )
    }

    fun retry() {
        cancelActiveCrossfade(keepAcknowledgedIncoming = true)
        softStopped = false
        clearNativePrebuffer(NativePrebufferClearReason.Retry)
        nativeDspController.clearReplayGain(player)
        player.stop()
        player.clearMediaItems()
        player.setMediaItem(mediaItemFor(currentTrack))
        playCommandInFlight = false
        positionJob?.cancel()
        publish(metricsTracker.resetTransientMetrics())
        play()
    }

    fun seekTo(positionMs: Long) {
        cancelActiveCrossfade(keepAcknowledgedIncoming = true)
        softStopped = false
        val durationMs = player.duration.takeIf { it != C.TIME_UNSET && it > 0 }
        val safePosition = if (durationMs == null) {
            positionMs.coerceAtLeast(0L)
        } else {
            positionMs.coerceIn(0L, durationMs)
        }
        publish(metricsTracker.markSeekStarted(safePosition))
        player.seekTo(safePosition)
        publish(metricsTracker.markPosition(player.currentPosition))
        startPositionUpdates()
    }

    fun resetMetrics() {
        publish(metricsTracker.resetTransientMetrics())
        if (player.isPlaying) {
            publish(metricsTracker.markPlaying(player.currentPosition))
        } else {
            publish(metricsTracker.markNotPlaying(player.currentPosition))
        }
    }

    fun setAudioEffectProfile(profile: NativeEqProfile): Map<String, Any?> {
        return nativeDspController.setProfile(profile, player).toMap() + mapOf(
            "profileId" to profile.id,
        )
    }

    fun audioEffectStatusMap(): Map<String, Any?> = nativeDspController.statusMap()

    fun setLoudnessNormalizationEnabled(enabled: Boolean): Map<String, Any?> {
        loudnessNormalizationEnabled = enabled
        soundEnginePreferences.edit().putBoolean(LOUDNESS_NORMALIZATION_KEY, enabled).apply()
        return nativeDspController.setLoudnessNormalizationEnabled(enabled, player)
    }

    fun loudnessNormalizationStatusMap(): Map<String, Any?> = nativeDspController.statusMap()

    fun setChannelBalance(balance: Double): Map<String, Any?> {
        val safeBalance = balance.coerceIn(-1.0, 1.0)
        channelAudioState.setBalance(safeBalance)
        soundEnginePreferences.edit().putFloat(CHANNEL_BALANCE_KEY, safeBalance.toFloat()).apply()
        return channelAudioState.statusMap()
    }

    fun setMonoOutput(enabled: Boolean): Map<String, Any?> {
        channelAudioState.setMono(enabled)
        soundEnginePreferences.edit().putBoolean(MONO_OUTPUT_KEY, enabled).apply()
        return channelAudioState.statusMap()
    }

    fun channelAudioStatusMap(): Map<String, Any?> = channelAudioState.statusMap()

    fun setCrossfadeDurationMs(durationMs: Long): Map<String, Any?> {
        require(ALLOWED_CROSSFADE_DURATIONS.contains(durationMs)) {
            "Crossfade duration must be Off, 2s, 4s, or 6s."
        }
        crossfadeDurationMs = durationMs
        soundEnginePreferences.edit().putLong(CROSSFADE_DURATION_KEY, durationMs).apply()
        return crossfadeStatusMap()
    }

    fun crossfadeStatusMap(): Map<String, Any?> {
        val active = activeCrossfade
        return mapOf(
            "enabled" to (crossfadeDurationMs > 0L),
            "durationMs" to crossfadeDurationMs,
            "active" to (active != null),
            "progress" to (active?.progress ?: 0f),
            "incomingTrackId" to active?.trackId,
            "acknowledged" to (active?.acknowledged ?: false),
            "autoMode" to "prepared_natural_end",
            "manualSkipMode" to "immediate_prepared",
            "gainComposition" to "dsp_base_x_transition_envelope",
        )
    }

    fun metricsSnapshotMap(): Map<String, Any?> {
        val durationMs = currentTrack.durationMs ?: player.duration.takeIf { it != C.TIME_UNSET && it > 0 }
        val dspStatus = nativeDspController.statusMap()
        val channelStatus = channelAudioState.statusMap()
        val crossfadeStatus = crossfadeStatusMap()
        return metricsTracker.snapshot().toMap() + mapOf(
            "durationMs" to durationMs,
            "currentTrackId" to currentTrack.trackId,
            "currentTrackUrl" to currentTrack.url,
            "currentTrackTitle" to currentTrack.title,
            "currentTrackArtist" to currentTrack.artistName,
            "currentTrackAlbum" to currentTrack.albumName,
            "currentTrackSource" to currentTrack.source,
            "notificationMetadataTitle" to currentTrack.title,
            "notificationSource" to currentTrack.source,
            "notificationQueueSnapshotCount" to notificationQueueSnapshot.size,
            "notificationPreviousAvailable" to (queueOffsetTarget(-1) != null),
            "notificationNextAvailable" to (queueOffsetTarget(1) != null),
            "lastNotificationAction" to lastNotificationAction,
            "lastNotificationActionResult" to lastNotificationActionResult,
            "lastNotificationActionTrackId" to lastNotificationActionTrackId,
            "notificationArtworkStatus" to artworkStatus,
            "mediaSessionStatus" to if (mediaSession == null) "disabled" else "active",
            "mediaNotificationShown" to mediaNotificationShown,
            "currentTrackLoaded" to currentTrackLoaded,
            "nativeAudioEffectStatus" to dspStatus["status"],
            "nativeAudioEffectProfileId" to dspStatus["profileId"],
            "nativeAudioEffectMessage" to dspStatus["message"],
            "nativeAudioEffectSessionId" to dspStatus["audioSessionId"],
            "nativeDspPlayerCount" to dspStatus["activeDspPlayerCount"],
            "nativeTransitionGain" to dspStatus["transitionGain"],
            "loudnessNormalizationEnabled" to dspStatus["loudnessNormalizationEnabled"],
            "replayGainTrackDb" to dspStatus["replayGainTrackDb"],
            "replayGainAlbumDb" to dspStatus["replayGainAlbumDb"],
            "appliedNormalizationGainDb" to dspStatus["appliedNormalizationGainDb"],
            "loudnessEnhancerActive" to dspStatus["loudnessEnhancerActive"],
            "loudnessNormalizationMessage" to dspStatus["loudnessNormalizationMessage"],
            "channelBalance" to channelStatus["balance"],
            "monoOutputEnabled" to channelStatus["mono"],
            "channelPcmStereoConfigured" to channelStatus["pcmStereoConfigured"],
            "channelProcessorFormat" to channelStatus["channelProcessorFormat"],
            "nativePreparedHandoffStrategy" to PREPARED_HANDOFF_STRATEGY,
            "nativeGaplessGuarantee" to false,
            "crossfadeEnabled" to crossfadeStatus["enabled"],
            "crossfadeDurationMs" to crossfadeStatus["durationMs"],
            "crossfadeActive" to crossfadeStatus["active"],
            "crossfadeProgress" to crossfadeStatus["progress"],
            "crossfadeIncomingTrackId" to crossfadeStatus["incomingTrackId"],
            "crossfadeManualSkipMode" to crossfadeStatus["manualSkipMode"],
            "crossfadeGainComposition" to crossfadeStatus["gainComposition"],
        )
    }

    fun release() {
        positionJob?.cancel()
        crossfadeJob?.cancel()
        nativeDspController.release()
        player.removeListener(playerListener)
        player.removeAnalyticsListener(analyticsListener)
        prebufferPlayer.removeListener(prebufferListener)
        mediaSession?.release()
        player.release()
        prebufferPlayer.release()
        managerJob.cancel()
    }

    private fun playPreparedNextTrackIfReady(
        trackId: String,
        title: String,
        hlsUrl: String,
        source: PreparedHandoffSource,
    ): Boolean {
        val safeTrackId = trackId.trim()
        val safeTitle = title.ifBlank { nativePrebufferTitle ?: "Up next" }
        publish(metricsTracker.markNativePrebufferHandoffAttempted())
        if (source == PreparedHandoffSource.AutoAdvance) {
            publish(metricsTracker.markAutoAdvancePreparedAttempted())
        }

        val crossfade = activeCrossfade
        if (crossfade != null && crossfade.trackId == safeTrackId && crossfade.url == hlsUrl) {
            return promoteActiveCrossfade(crossfade, source, forceComplete = source == PreparedHandoffSource.ExplicitNext)
        }

        if (!isPreparedNextTrackReady(safeTrackId, hlsUrl)) {
            recordNextTrackPrebufferOutcome(safeTrackId, usedPreparedPath = false)
            if (source == PreparedHandoffSource.AutoAdvance) {
                publish(metricsTracker.markAutoAdvancePreparedFallback(safeTrackId))
            }
            return false
        }

        val preparedPlayer = prebufferPlayer
        val previousPrimaryPlayer = player
        positionJob?.cancel()
        softStopped = false
        playCommandInFlight = true
        applyCurrentTrack(NotificationTrackSnapshot(trackId = safeTrackId, title = safeTitle, url = hlsUrl))
        currentTrackLoaded = true

        previousPrimaryPlayer.removeListener(playerListener)
        previousPrimaryPlayer.removeAnalyticsListener(analyticsListener)

        preparedPlayer.removeListener(prebufferListener)
        configurePrimaryPlayer(preparedPlayer)
        preparedPlayer.addListener(playerListener)
        preparedPlayer.addAnalyticsListener(analyticsListener)

        player = preparedPlayer
        prebufferPlayer = previousPrimaryPlayer
        mediaSession?.setPlayer(player)
        applyReplayGainFromTracks(player.currentTracks, player)

        publishPreparedHandoffSuccess(safeTrackId, source)

        previousPrimaryPlayer.playWhenReady = false
        previousPrimaryPlayer.pause()
        player.playWhenReady = true
        nativeDspController.clearReplayGain(previousPrimaryPlayer)
        mutablePlaybackState.value = PlaybackState(
            status = PlaybackStatus.Ready,
            trackTitle = currentTrackTitle,
        )
        startPositionUpdates()

        configurePrebufferPlayer(prebufferPlayer)
        prebufferPlayer.addListener(prebufferListener)
        clearNativePrebufferState()
        return true
    }

    private fun maybeStartNaturalCrossfade() {
        if (crossfadeDurationMs <= 0L || activeCrossfade != null || !player.isPlaying) return
        val trackId = nativePrebufferTrackId ?: return
        val title = nativePrebufferTitle ?: "Up next"
        val url = nativePrebufferUrl ?: return
        if (!isPreparedNextTrackReady(trackId, url)) return

        val durationMs = player.duration.takeIf { it != C.TIME_UNSET && it > 0 } ?: return
        val positionMs = player.currentPosition.coerceAtLeast(0L)
        if (positionMs <= 0L) return
        val remainingMs = (durationMs - positionMs).coerceAtLeast(0L)
        if (remainingMs <= 0L || remainingMs > crossfadeDurationMs) return

        startNaturalCrossfade(trackId, title, url, remainingMs.coerceAtMost(crossfadeDurationMs))
    }

    private fun startNaturalCrossfade(trackId: String, title: String, url: String, durationMs: Long) {
        if (activeCrossfade != null || durationMs <= 0L) return
        if (!isPreparedNextTrackReady(trackId, url)) return

        val outgoing = player
        val incoming = prebufferPlayer
        nativeDspController.onAudioSessionChanged(incoming.audioSessionId, incoming)
        applyReplayGainFromTracks(incoming.currentTracks, incoming)
        nativeDspController.setTransitionGain(outgoing, 1f)
        nativeDspController.setTransitionGain(incoming, 0f)

        val transition = ActiveCrossfade(
            trackId = trackId,
            title = title,
            url = url,
            outgoing = outgoing,
            incoming = incoming,
            durationMs = durationMs.coerceAtLeast(CROSSFADE_TICK_MS),
        )
        activeCrossfade = transition
        incoming.playWhenReady = true
        crossfadeJob = scope.launch {
            val startedAtMs = SystemClock.elapsedRealtime()
            while (isActive && activeCrossfade === transition) {
                val elapsedMs = (SystemClock.elapsedRealtime() - startedAtMs).coerceAtLeast(0L)
                val progress = (elapsedMs.toDouble() / transition.durationMs.toDouble())
                    .coerceIn(0.0, 1.0)
                    .toFloat()
                transition.progress = progress
                nativeDspController.setTransitionGain(outgoing, 1f - progress)
                nativeDspController.setTransitionGain(incoming, progress)
                if (progress >= 1f) break
                delay(CROSSFADE_TICK_MS)
            }
            if (activeCrossfade !== transition) return@launch
            transition.progress = 1f
            nativeDspController.setTransitionGain(outgoing, 0f)
            nativeDspController.setTransitionGain(incoming, 1f)
            outgoing.playWhenReady = false
            outgoing.pause()
            crossfadeJob = null
            if (transition.acknowledged) {
                completeAcknowledgedCrossfade(transition)
            }
        }
    }

    private fun promoteActiveCrossfade(
        transition: ActiveCrossfade,
        source: PreparedHandoffSource,
        forceComplete: Boolean,
    ): Boolean {
        if (activeCrossfade !== transition) return false
        if (transition.acknowledged) return true

        positionJob?.cancel()
        softStopped = false
        playCommandInFlight = false
        applyCurrentTrack(
            NotificationTrackSnapshot(
                trackId = transition.trackId,
                title = transition.title,
                url = transition.url,
            ),
        )
        currentTrackLoaded = true

        transition.outgoing.removeListener(playerListener)
        transition.outgoing.removeAnalyticsListener(analyticsListener)
        transition.incoming.removeListener(prebufferListener)
        configurePrimaryPlayer(transition.incoming, preserveTransitionGain = true)
        transition.incoming.addListener(playerListener)
        transition.incoming.addAnalyticsListener(analyticsListener)

        player = transition.incoming
        prebufferPlayer = transition.outgoing
        mediaSession?.setPlayer(player)
        applyReplayGainFromTracks(player.currentTracks, player)
        transition.acknowledged = true
        clearNativePrebufferMetadata()
        publishPreparedHandoffSuccess(transition.trackId, source)
        publish(metricsTracker.markPlaying(player.currentPosition))
        mutablePlaybackState.value = PlaybackState(
            status = PlaybackStatus.Playing,
            trackTitle = currentTrackTitle,
        )
        startPositionUpdates()

        if (forceComplete) {
            crossfadeJob?.cancel()
            crossfadeJob = null
            transition.progress = 1f
            nativeDspController.setTransitionGain(transition.outgoing, 0f)
            nativeDspController.setTransitionGain(transition.incoming, 1f)
            transition.outgoing.playWhenReady = false
            transition.outgoing.pause()
            completeAcknowledgedCrossfade(transition)
        } else if (transition.progress >= 1f || crossfadeJob == null) {
            completeAcknowledgedCrossfade(transition)
        }
        return true
    }

    private fun publishPreparedHandoffSuccess(trackId: String, source: PreparedHandoffSource) {
        publish(metricsTracker.loadTrack(currentTrackTitle, currentHlsUrl))
        publish(metricsTracker.markPlayTapped())
        publish(metricsTracker.markReady())
        publish(
            metricsTracker.markNativePrebufferHandoffSucceeded(
                trackId = trackId,
                explicitNext = source == PreparedHandoffSource.ExplicitNext,
            ),
        )
        if (source == PreparedHandoffSource.AutoAdvance) {
            publish(metricsTracker.markAutoAdvancePreparedSucceeded(trackId))
        }
    }

    private fun completeAcknowledgedCrossfade(transition: ActiveCrossfade) {
        if (activeCrossfade !== transition || !transition.acknowledged) return
        transition.outgoing.playWhenReady = false
        transition.outgoing.pause()
        transition.outgoing.stop()
        transition.outgoing.clearMediaItems()
        nativeDspController.releasePlayer(transition.outgoing)
        configurePrebufferPlayer(transition.outgoing)
        if (prebufferPlayer === transition.outgoing) {
            prebufferPlayer.removeListener(prebufferListener)
            prebufferPlayer.addListener(prebufferListener)
        }
        activeCrossfade = null
        crossfadeJob = null
        val pending = pendingPrebuffer
        pendingPrebuffer = null
        if (pending != null) {
            prepareNextTrack(pending.trackId, pending.title, pending.url)
        }
    }

    private fun cancelActiveCrossfade(keepAcknowledgedIncoming: Boolean) {
        val transition = activeCrossfade ?: return
        crossfadeJob?.cancel()
        crossfadeJob = null

        if (transition.acknowledged && keepAcknowledgedIncoming) {
            nativeDspController.setTransitionGain(transition.incoming, 1f)
            nativeDspController.setTransitionGain(transition.outgoing, 0f)
            transition.outgoing.playWhenReady = false
            transition.outgoing.pause()
            completeAcknowledgedCrossfade(transition)
            return
        }

        nativeDspController.setTransitionGain(transition.outgoing, 1f)
        nativeDspController.setTransitionGain(transition.incoming, 0f)
        transition.incoming.playWhenReady = false
        transition.incoming.pause()
        transition.incoming.stop()
        transition.incoming.clearMediaItems()
        nativeDspController.releasePlayer(transition.incoming)
        if (prebufferPlayer === transition.incoming) {
            configurePrebufferPlayer(prebufferPlayer)
        }
        activeCrossfade = null
        pendingPrebuffer = null
        clearNativePrebufferMetadata()
    }

    private fun clearNativePrebuffer(reason: NativePrebufferClearReason) {
        clearNativePrebufferState()
        publish(metricsTracker.markNativePrebufferCleared(reason = reason.value))
    }

    private fun clearNativePrebufferState() {
        clearNativePrebufferMetadata()
        if (activeCrossfade?.outgoing === prebufferPlayer) return
        prebufferPlayer.playWhenReady = false
        prebufferPlayer.stop()
        prebufferPlayer.clearMediaItems()
        nativeDspController.onSecondaryPlayerChanged(prebufferPlayer)
    }

    private fun clearNativePrebufferMetadata() {
        nativePrebufferTrackId = null
        nativePrebufferTitle = null
        nativePrebufferUrl = null
        nativePrebufferStartedAtMs = null
    }

    private fun isPreparedNextTrackReady(trackId: String, hlsUrl: String): Boolean {
        if (trackId.isBlank() || hlsUrl.isBlank()) return false
        return nativePrebufferTrackId == trackId &&
            nativePrebufferUrl == hlsUrl &&
            metricsTracker.snapshot().nativePrebufferReady &&
            prebufferPlayer.playbackState == Player.STATE_READY &&
            prebufferPlayer.mediaItemCount > 0 &&
            prebufferPlayer.currentMediaItem?.mediaId == trackId
    }

    private fun applyReplayGainFromTracks(tracks: Tracks, targetPlayer: ExoPlayer) {
        nativeDspController.clearReplayGain(targetPlayer)
        for (group in tracks.groups) {
            if (group.type != C.TRACK_TYPE_AUDIO || !group.isSelected) continue
            for (index in 0 until group.length) {
                if (!group.isTrackSelected(index)) continue
                val info = ReplayGainMetadata.parse(group.getTrackFormat(index).metadata) ?: continue
                nativeDspController.setReplayGain(info, targetPlayer)
                return
            }
        }
    }

    private fun ensureCurrentMediaItemLoaded() {
        if (player.mediaItemCount == 0 || player.currentMediaItem == null) {
            player.setMediaItem(mediaItemFor(currentTrack))
        }
    }

    private fun startPositionUpdates() {
        if (positionJob?.isActive == true) return
        positionJob = scope.launch {
            while (isActive) {
                publish(metricsTracker.markPosition(player.currentPosition))
                maybeStartNaturalCrossfade()
                delay(POSITION_UPDATE_MS)
            }
        }
    }

    private fun buildPrimaryPlayer(): ExoPlayer = ExoPlayer.Builder(
        appContext,
        WaveZeroAudioRenderersFactory(appContext, channelAudioState),
    ).build().also(::configurePrimaryPlayer)

    private fun buildPrebufferPlayer(): ExoPlayer = ExoPlayer.Builder(
        appContext,
        WaveZeroAudioRenderersFactory(appContext, channelAudioState),
    ).build().also(::configurePrebufferPlayer)

    private fun configurePrimaryPlayer(exoPlayer: ExoPlayer, preserveTransitionGain: Boolean = false) {
        exoPlayer.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                .build(),
            /* handleAudioFocus = */ true,
        )
        exoPlayer.setHandleAudioBecomingNoisy(true)
        if (preserveTransitionGain) {
            nativeDspController.promoteSecondaryPlayer(exoPlayer)
        } else {
            nativeDspController.onPrimaryPlayerChanged(exoPlayer)
        }
    }

    private fun configurePrebufferPlayer(exoPlayer: ExoPlayer) {
        exoPlayer.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                .build(),
            /* handleAudioFocus = */ false,
        )
        exoPlayer.setHandleAudioBecomingNoisy(false)
        exoPlayer.playWhenReady = false
        nativeDspController.onSecondaryPlayerChanged(exoPlayer)
    }

    private fun mediaItemFor(track: NotificationTrackSnapshot): MediaItem {
        val metadata = MediaMetadata.Builder()
            .setTitle(track.title)
            .setArtist(track.artistName ?: DemoTrack.artist)
            .setAlbumTitle(track.albumName)
            .setArtworkUri(track.artworkUri)
            .build()
        return MediaItem.Builder()
            .setMediaId(track.trackId ?: track.url)
            .setUri(track.url)
            .setMediaMetadata(metadata)
            .build()
    }

    private fun applyCurrentTrack(track: NotificationTrackSnapshot) {
        currentTrack = track.copy(
            title = track.title.ifBlank { DemoTrack.title },
            artistName = track.artistName?.takeIf { it.isNotBlank() } ?: DemoTrack.artist,
            source = normalizeSource(track.source),
        )
        currentTrackTitle = currentTrack.title
        currentHlsUrl = currentTrack.url
        artworkStatus = if (currentTrack.artworkUrl.isNullOrBlank()) "none" else if (currentTrack.artworkUri == null) "failed" else "uri_set"
    }

    private fun normalizeSource(source: String): String {
        return when (source) {
            NotificationTrackSnapshot.SOURCE_API,
            NotificationTrackSnapshot.SOURCE_DEVICE,
            NotificationTrackSnapshot.SOURCE_CACHED,
            NotificationTrackSnapshot.SOURCE_MANUAL -> source
            else -> NotificationTrackSnapshot.SOURCE_UNKNOWN
        }
    }

    private fun queueOffsetTarget(offset: Int): NotificationTrackSnapshot? {
        if (notificationQueueSnapshot.isEmpty()) return null
        val currentId = currentTrack.trackId
        val currentUrl = currentTrack.url
        val currentIndex = notificationQueueSnapshot.indexOfFirst {
            (!currentId.isNullOrBlank() && it.trackId == currentId) || it.url == currentUrl
        }
        if (currentIndex < 0) return null
        val targetIndex = currentIndex + offset
        return notificationQueueSnapshot.getOrNull(targetIndex)?.takeIf { it.hasPlayableUrl() }
    }

    private fun playQueueOffsetFromNotification(offset: Int, action: String): Boolean {
        lastNotificationAction = action
        val target = queueOffsetTarget(offset)
        lastNotificationActionTrackId = target?.trackId
        if (target == null) {
            lastNotificationActionResult = "no_target"
            return false
        }
        loadTrack(target)
        play()
        lastNotificationActionResult = "played"
        return true
    }

    private fun publish(nextMetrics: PlaybackMetrics) {
        mutableMetrics.value = nextMetrics
    }

    private enum class PreparedHandoffSource {
        ExplicitNext,
        AutoAdvance,
    }

    private enum class NativePrebufferClearReason(val value: String) {
        FlutterRequested("flutter_requested"),
        InvalidCandidate("invalid_candidate"),
        NativePlaybackError("native_playback_error"),
        Retry("retry"),
        Stop("stop"),
        TrackLoaded("track_loaded"),
    }

    private companion object {
        const val POSITION_UPDATE_MS = 250L
        const val CROSSFADE_TICK_MS = 50L
        const val MEDIA_SESSION_ID = "wavezero-playback"
        const val SOUND_ENGINE_PREFS = "wavezero_sound_engine"
        const val LOUDNESS_NORMALIZATION_KEY = "loudness_normalization_enabled"
        const val CHANNEL_BALANCE_KEY = "channel_balance"
        const val MONO_OUTPUT_KEY = "mono_output_enabled"
        const val CROSSFADE_DURATION_KEY = "crossfade_duration_ms"
        const val CROSSFADE_OFF_MS = 0L
        const val PREPARED_HANDOFF_STRATEGY = "prepared_player_min_gap"
        val ALLOWED_CROSSFADE_DURATIONS = setOf(0L, 2_000L, 4_000L, 6_000L)
    }
}
