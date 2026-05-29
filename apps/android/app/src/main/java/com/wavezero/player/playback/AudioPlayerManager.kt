package com.wavezero.player.playback

import android.content.Context
import android.os.SystemClock
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
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
    private var currentTrackTitle: String = DemoTrack.title
    private var currentHlsUrl: String = hlsUrl
    private var playCommandInFlight = false

    private val appContext = context.applicationContext

    private val player: ExoPlayer = ExoPlayer.Builder(appContext).build().also { exoPlayer ->
        exoPlayer.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(C.USAGE_MEDIA)
                .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                .build(),
            /* handleAudioFocus = */ true,
        )
        exoPlayer.setHandleAudioBecomingNoisy(true)
    }

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
                    publish(metricsTracker.markNotPlaying(player.currentPosition))
                    mutablePlaybackState.value = PlaybackState(
                        status = PlaybackStatus.Ended,
                        trackTitle = currentTrackTitle,
                    )
                }

                Player.STATE_IDLE -> mutablePlaybackState.value = PlaybackState(
                    status = PlaybackStatus.Idle,
                    trackTitle = currentTrackTitle,
                )
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
                playCommandInFlight = false
                publish(metricsTracker.markPlaying(player.currentPosition))
                mutablePlaybackState.value = PlaybackState(
                    status = PlaybackStatus.Playing,
                    trackTitle = currentTrackTitle,
                )
            } else {
                publish(metricsTracker.markNotPlaying(player.currentPosition))
                if (mutablePlaybackState.value.status == PlaybackStatus.Playing) {
                    mutablePlaybackState.value = PlaybackState(
                        status = PlaybackStatus.Paused,
                        trackTitle = currentTrackTitle,
                    )
                }
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            playCommandInFlight = false
            publish(metricsTracker.markError(error.message ?: error.errorCodeName))
            mutablePlaybackState.value = PlaybackState(
                status = PlaybackStatus.Error,
                trackTitle = currentTrackTitle,
            )
        }
    }

    private val analyticsListener = object : AnalyticsListener {
        override fun onLoadCompleted(
            eventTime: AnalyticsListener.EventTime,
            loadEventInfo: LoadEventInfo,
            mediaLoadData: MediaLoadData,
        ) {
            if (mediaLoadData.dataType == C.DATA_TYPE_MANIFEST) {
                publish(metricsTracker.markManifestLoaded(loadEventInfo.loadDurationMs))
            }
        }
    }

    init {
        player.setMediaItem(mediaItemFor(currentTrackTitle, currentHlsUrl))
        publish(metricsTracker.loadTrack(currentTrackTitle, currentHlsUrl))
        player.addListener(playerListener)
        player.addAnalyticsListener(analyticsListener)
    }

    fun markScreenReady() {
        publish(metricsTracker.markScreenReady(appStartedAtMs))
    }

    fun loadTrack(title: String, hlsUrl: String) {
        currentTrackTitle = title.ifBlank { DemoTrack.title }
        currentHlsUrl = hlsUrl
        playCommandInFlight = false
        positionJob?.cancel()
        player.stop()
        player.clearMediaItems()
        player.setMediaItem(mediaItemFor(currentTrackTitle, currentHlsUrl))
        publish(metricsTracker.loadTrack(currentTrackTitle, currentHlsUrl))
        mutablePlaybackState.value = PlaybackState(
            status = PlaybackStatus.Buffering,
            trackTitle = currentTrackTitle,
        )
        player.prepare()
    }

    fun play() {
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
        playCommandInFlight = false
        player.pause()
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

    fun stop() {
        playCommandInFlight = false
        player.stop()
        player.clearMediaItems()
        player.setMediaItem(mediaItemFor(currentTrackTitle, currentHlsUrl))
        positionJob?.cancel()
        publish(metricsTracker.resetForStop())
        mutablePlaybackState.value = PlaybackState(
            status = PlaybackStatus.Stopped,
            trackTitle = currentTrackTitle,
        )
    }

    fun retry() {
        stop()
        play()
    }

    fun seekTo(positionMs: Long) {
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

    fun metricsSnapshotMap(): Map<String, Any?> {
        val durationMs = player.duration.takeIf { it != C.TIME_UNSET && it > 0 }
        return metricsTracker.snapshot().toMap() + mapOf("durationMs" to durationMs)
    }

    fun release() {
        positionJob?.cancel()
        player.removeListener(playerListener)
        player.removeAnalyticsListener(analyticsListener)
        mediaSession?.release()
        player.release()
        managerJob.cancel()
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

    private fun mediaItemFor(title: String, hlsUrl: String): MediaItem = MediaItem.Builder()
        .setUri(hlsUrl)
        .setMediaMetadata(
            MediaMetadata.Builder()
                .setTitle(title)
                .setArtist(DemoTrack.artist)
                .build(),
        )
        .build()

    private fun publish(nextMetrics: PlaybackMetrics) {
        mutableMetrics.value = nextMetrics
    }

    private companion object {
        const val POSITION_UPDATE_MS = 250L
        const val MEDIA_SESSION_ID = "wavezero-playback"
    }
}
