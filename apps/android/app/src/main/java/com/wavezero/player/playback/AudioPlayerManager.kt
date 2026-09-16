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
    private val managerJob = SupervisorJob()
    private val scope = CoroutineScope(managerJob + Dispatchers.Main.immediate)
    private val metricsTracker = PlaybackMetricsTracker(nowMs = SystemClock::elapsedRealtime)
    private var positionJob: Job? = null
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
                    publish(metricsTracker.markNotPlaying(player.currentPosition))
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
            applyReplayGainFromTracks(tracks)
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
                    val startedAt = nativePrebufferStartedAtMs ?: SystemClock.elapsedRealtime()
                    publish(metricsTracker.markNativePrebufferReady(trackId, SystemClock.elapsedRealtime() - startedAt))
                }

                Player.STATE_ENDED, Player.STATE_IDLE -> Unit
                Player.STATE_BUFFERING -> Unit
            }
        }

        override fun onPlayerError(error: PlaybackException) {
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

    fun metricsSnapshotMap(): Map<String, Any?> {
        val durationMs = currentTrack.durationMs ?: player.duration.takeIf { it != C.TIME_UNSET && it > 0 }
        val dspStatus = nativeDspController.statusMap()
        val channelStatus = channelAudioState.statusMap()
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
        )
    }

    fun release() {
        positionJob?.cancel()
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

        // Keep the old primary audible while the already-prepared player is
        // promoted. Detach old callbacks first so pausing it cannot publish a
        // false Paused state for the incoming track.
        previousPrimaryPlayer.removeListener(playerListener)
        previousPrimaryPlayer.removeAnalyticsListener(analyticsListener)

        // ReplayGain metadata belongs to the outgoing track. Clear that state
        // before attaching the incoming session so an untagged next track can
        // never inherit the previous track's gain.
        nativeDspController.clearReplayGain(previousPrimaryPlayer)

        preparedPlayer.removeListener(prebufferListener)
        configurePrimaryPlayer(preparedPlayer)
        preparedPlayer.addListener(playerListener)
        preparedPlayer.addAnalyticsListener(analyticsListener)

        player = preparedPlayer
        prebufferPlayer = previousPrimaryPlayer
        mediaSession?.setPlayer(player)
        applyReplayGainFromTracks(player.currentTracks)

        publish(metricsTracker.loadTrack(currentTrackTitle, currentHlsUrl))
        publish(metricsTracker.markPlayTapped())
        publish(metricsTracker.markReady())
        publish(
            metricsTracker.markNativePrebufferHandoffSucceeded(
                trackId = safeTrackId,
                explicitNext = source == PreparedHandoffSource.ExplicitNext,
            ),
        )
        if (source == PreparedHandoffSource.AutoAdvance) {
            publish(metricsTracker.markAutoAdvancePreparedSucceeded(safeTrackId))
        }

        // This is the actual cutover. Everything expensive is already done:
        // the incoming player is READY, owns primary playback behaviour, has
        // the active EQ/ReplayGain/channel state and is attached to MediaSession.
        // Keep the silence window down to the two adjacent playback commands.
        previousPrimaryPlayer.playWhenReady = false
        previousPrimaryPlayer.pause()
        player.playWhenReady = true
        mutablePlaybackState.value = PlaybackState(
            status = PlaybackStatus.Ready,
            trackTitle = currentTrackTitle,
        )
        startPositionUpdates()

        // Only recycle the old primary after the incoming player has been told
        // to play. This avoids the old stop()/clearMediaItems() work becoming an
        // artificial gap before the prepared track starts.
        configurePrebufferPlayer(prebufferPlayer)
        prebufferPlayer.addListener(prebufferListener)
        clearNativePrebufferState()
        return true
    }

    private fun clearNativePrebuffer(reason: NativePrebufferClearReason) {
        clearNativePrebufferState()
        publish(metricsTracker.markNativePrebufferCleared(reason = reason.value))
    }

    private fun clearNativePrebufferState() {
        nativePrebufferTrackId = null
        nativePrebufferTitle = null
        nativePrebufferUrl = null
        nativePrebufferStartedAtMs = null
        prebufferPlayer.playWhenReady = false
        prebufferPlayer.stop()
        prebufferPlayer.clearMediaItems()
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

    private fun applyReplayGainFromTracks(tracks: Tracks) {
        for (group in tracks.groups) {
            if (group.type != C.TRACK_TYPE_AUDIO || !group.isSelected) continue
            for (index in 0 until group.length) {
                if (!group.isTrackSelected(index)) continue
                val info = ReplayGainMetadata.parse(group.getTrackFormat(index).metadata) ?: continue
                nativeDspController.setReplayGain(info, player)
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

    private fun configurePrimaryPlayer(exoPlayer: ExoPlayer) {
        exoPlayer.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                .build(),
            /* handleAudioFocus = */ true,
        )
        exoPlayer.setHandleAudioBecomingNoisy(true)
        exoPlayer.volume = 1f
        nativeDspController.onPrimaryPlayerChanged(exoPlayer)
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
        exoPlayer.volume = 0f
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
        const val MEDIA_SESSION_ID = "wavezero-playback"
        const val SOUND_ENGINE_PREFS = "wavezero_sound_engine"
        const val LOUDNESS_NORMALIZATION_KEY = "loudness_normalization_enabled"
        const val CHANNEL_BALANCE_KEY = "channel_balance"
        const val MONO_OUTPUT_KEY = "mono_output_enabled"
        const val PREPARED_HANDOFF_STRATEGY = "prepared_player_min_gap"
    }
}
