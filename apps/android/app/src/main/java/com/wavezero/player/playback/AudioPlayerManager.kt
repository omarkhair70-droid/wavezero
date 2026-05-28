package com.wavezero.player.playback

import android.content.Context
import android.os.SystemClock
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.LoadEventInfo
import androidx.media3.exoplayer.source.MediaLoadData
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
    private val hlsUrl: String = DemoTrack.hlsUrl,
    private val appStartedAtMs: Long = SystemClock.elapsedRealtime(),
) {
    private val managerJob = SupervisorJob()
    private val scope = CoroutineScope(managerJob + Dispatchers.Main.immediate)
    private val metricsTracker = PlaybackMetricsTracker(nowMs = SystemClock::elapsedRealtime)
    private var positionJob: Job? = null

    private val player: ExoPlayer = ExoPlayer.Builder(context).build().apply {
        setMediaItem(MediaItem.fromUri(hlsUrl))
        addListener(playerListener)
        addAnalyticsListener(analyticsListener)
    }

    private val mutablePlaybackState = MutableStateFlow(PlaybackState())
    val playbackState: StateFlow<PlaybackState> = mutablePlaybackState.asStateFlow()

    private val mutableMetrics = MutableStateFlow(metricsTracker.snapshot())
    val metrics: StateFlow<PlaybackMetrics> = mutableMetrics.asStateFlow()

    fun markScreenReady() {
        publish(metricsTracker.markScreenReady(appStartedAtMs))
    }

    fun play() {
        publish(metricsTracker.markPlayTapped())
        player.prepare()
        player.playWhenReady = true
        startPositionUpdates()
    }

    fun pause() {
        player.pause()
        publish(metricsTracker.markNotPlaying(player.currentPosition))
        mutablePlaybackState.value = PlaybackState(status = PlaybackStatus.Paused)
    }

    fun togglePlayPause() {
        if (player.isPlaying) {
            pause()
        } else {
            play()
        }
    }

    fun stop() {
        player.stop()
        player.clearMediaItems()
        player.setMediaItem(MediaItem.fromUri(hlsUrl))
        positionJob?.cancel()
        publish(metricsTracker.resetForStop())
        mutablePlaybackState.value = PlaybackState(status = PlaybackStatus.Stopped)
    }

    fun release() {
        positionJob?.cancel()
        player.removeListener(playerListener)
        player.removeAnalyticsListener(analyticsListener)
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

    private fun publish(nextMetrics: PlaybackMetrics) {
        mutableMetrics.value = nextMetrics
    }

    private val playerListener = object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_BUFFERING -> {
                    publish(metricsTracker.markBufferingStarted())
                    mutablePlaybackState.value = PlaybackState(status = PlaybackStatus.Buffering)
                }

                Player.STATE_READY -> {
                    publish(metricsTracker.markBufferingEnded())
                    mutablePlaybackState.value = PlaybackState(
                        status = if (player.isPlaying) PlaybackStatus.Playing else PlaybackStatus.Ready,
                    )
                }

                Player.STATE_ENDED -> {
                    publish(metricsTracker.markNotPlaying(player.currentPosition))
                    mutablePlaybackState.value = PlaybackState(status = PlaybackStatus.Ended)
                }

                Player.STATE_IDLE -> mutablePlaybackState.value = PlaybackState(status = PlaybackStatus.Idle)
            }
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
            if (isPlaying) {
                publish(metricsTracker.markPlaying(player.currentPosition))
                mutablePlaybackState.value = PlaybackState(status = PlaybackStatus.Playing)
            } else {
                publish(metricsTracker.markNotPlaying(player.currentPosition))
                if (mutablePlaybackState.value.status == PlaybackStatus.Playing) {
                    mutablePlaybackState.value = PlaybackState(status = PlaybackStatus.Paused)
                }
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            publish(metricsTracker.markError(error.message ?: error.errorCodeName))
            mutablePlaybackState.value = PlaybackState(status = PlaybackStatus.Error)
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

    private companion object {
        const val POSITION_UPDATE_MS = 250L
    }
}
