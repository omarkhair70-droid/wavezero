package com.wavezero.player.playback

import java.util.UUID

data class PlaybackMetrics(
    val appScreenReadyMs: Long? = null,
    val tapToFirstAudioMs: Long? = null,
    val manifestLoadMs: Long? = null,
    val bufferCount: Int = 0,
    val isPlaying: Boolean = false,
    val currentPositionMs: Long = 0,
    val playbackError: String? = null,
    val sessionId: String = UUID.randomUUID().toString(),
    val attemptId: Int = 0,
    val tapToReadyMs: Long? = null,
    val tapToIsPlayingMs: Long? = null,
    val tapToPositionAdvanceMs: Long? = null,
    val lastEvent: String = "initialized",
    val trackTitle: String = DemoTrack.title,
    val trackUrl: String = DemoTrack.hlsUrl,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "appScreenReadyMs" to appScreenReadyMs,
        "tapToFirstAudioMs" to tapToFirstAudioMs,
        "manifestLoadMs" to manifestLoadMs,
        "bufferCount" to bufferCount,
        "isPlaying" to isPlaying,
        "currentPositionMs" to currentPositionMs,
        "playbackError" to playbackError,
        "sessionId" to sessionId,
        "attemptId" to attemptId,
        "tapToReadyMs" to tapToReadyMs,
        "tapToIsPlayingMs" to tapToIsPlayingMs,
        "tapToPositionAdvanceMs" to tapToPositionAdvanceMs,
        "lastEvent" to lastEvent,
        "trackTitle" to trackTitle,
        "trackUrl" to trackUrl,
    )
}

class PlaybackMetricsTracker(
    private val nowMs: () -> Long,
) {
    private var playTappedAtMs: Long? = null
    private var firstAudioObserved = false
    private var positionAdvanceObserved = false
    private var isBuffering = false
    private var metrics = PlaybackMetrics()

    fun snapshot(): PlaybackMetrics = metrics

    fun markScreenReady(appStartedAtMs: Long): PlaybackMetrics = update("screen_ready") {
        copy(appScreenReadyMs = (nowMs() - appStartedAtMs).coerceAtLeast(0))
    }

    fun loadTrack(title: String, hlsUrl: String): PlaybackMetrics {
        playTappedAtMs = null
        firstAudioObserved = false
        positionAdvanceObserved = false
        isBuffering = false
        return update("track_loaded") {
            copy(
                tapToFirstAudioMs = null,
                manifestLoadMs = null,
                bufferCount = 0,
                isPlaying = false,
                currentPositionMs = 0,
                playbackError = null,
                attemptId = 0,
                tapToReadyMs = null,
                tapToIsPlayingMs = null,
                tapToPositionAdvanceMs = null,
                trackTitle = title,
                trackUrl = hlsUrl,
            )
        }
    }

    fun markPlayTapped(): PlaybackMetrics {
        playTappedAtMs = nowMs()
        firstAudioObserved = false
        positionAdvanceObserved = false
        return update("play_tapped") {
            copy(
                playbackError = null,
                attemptId = attemptId + 1,
                tapToFirstAudioMs = null,
                tapToReadyMs = null,
                tapToIsPlayingMs = null,
                tapToPositionAdvanceMs = null,
            )
        }
    }

    fun markReady(): PlaybackMetrics = update("ready") {
        copy(tapToReadyMs = tapToReadyMs ?: elapsedSincePlayTap())
    }

    fun markPlaying(positionMs: Long): PlaybackMetrics {
        val elapsed = elapsedSincePlayTap()
        val firstAudioMs = if (!firstAudioObserved) {
            firstAudioObserved = true
            elapsed
        } else {
            metrics.tapToFirstAudioMs
        }
        val positionAdvanceMs = if (!positionAdvanceObserved && positionMs > 0L) {
            positionAdvanceObserved = true
            elapsed
        } else {
            metrics.tapToPositionAdvanceMs
        }

        return update("playing") {
            copy(
                tapToFirstAudioMs = firstAudioMs,
                tapToIsPlayingMs = tapToIsPlayingMs ?: elapsed,
                tapToPositionAdvanceMs = positionAdvanceMs,
                isPlaying = true,
                currentPositionMs = positionMs.coerceAtLeast(0),
            )
        }
    }

    fun markNotPlaying(positionMs: Long): PlaybackMetrics = update("not_playing") {
        copy(isPlaying = false, currentPositionMs = positionMs.coerceAtLeast(0))
    }

    fun markBufferingStarted(): PlaybackMetrics {
        if (!isBuffering) {
            isBuffering = true
            return update("buffering_started") { copy(bufferCount = bufferCount + 1) }
        }
        return metrics
    }

    fun markBufferingEnded(): PlaybackMetrics {
        isBuffering = false
        return update("buffering_ended") { this }
    }

    fun markManifestLoaded(loadDurationMs: Long): PlaybackMetrics = update("manifest_loaded") {
        copy(manifestLoadMs = loadDurationMs.coerceAtLeast(0))
    }

    fun markPosition(positionMs: Long): PlaybackMetrics {
        val positionAdvanceMs = if (!positionAdvanceObserved && positionMs > 0L) {
            positionAdvanceObserved = true
            elapsedSincePlayTap()
        } else {
            metrics.tapToPositionAdvanceMs
        }
        return update("position") {
            copy(
                currentPositionMs = positionMs.coerceAtLeast(0),
                tapToPositionAdvanceMs = positionAdvanceMs,
            )
        }
    }

    fun markError(message: String): PlaybackMetrics = update("error") {
        copy(playbackError = message, isPlaying = false)
    }

    fun resetTransientMetrics(): PlaybackMetrics {
        playTappedAtMs = null
        firstAudioObserved = false
        positionAdvanceObserved = false
        isBuffering = false
        return update("metrics_reset") {
            copy(
                tapToFirstAudioMs = null,
                manifestLoadMs = null,
                bufferCount = 0,
                isPlaying = false,
                currentPositionMs = 0,
                playbackError = null,
                tapToReadyMs = null,
                tapToIsPlayingMs = null,
                tapToPositionAdvanceMs = null,
            )
        }
    }

    fun resetForStop(): PlaybackMetrics = resetTransientMetrics().copy(lastEvent = "stopped").also {
        metrics = it
    }

    private fun elapsedSincePlayTap(): Long? = playTappedAtMs?.let { (nowMs() - it).coerceAtLeast(0) }

    private fun update(eventName: String, block: PlaybackMetrics.() -> PlaybackMetrics): PlaybackMetrics {
        metrics = metrics.block().copy(lastEvent = eventName)
        return metrics
    }
}
