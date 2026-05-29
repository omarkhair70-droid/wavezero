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
    val startupBufferMs: Long = 0,
    val rebufferCount: Int = 0,
    val rebufferMs: Long = 0,
    val totalBufferMs: Long = 0,
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
        "startupBufferMs" to startupBufferMs,
        "rebufferCount" to rebufferCount,
        "rebufferMs" to rebufferMs,
        "totalBufferMs" to totalBufferMs,
        "lastEvent" to lastEvent,
        "trackTitle" to trackTitle,
        "trackUrl" to trackUrl,
    )
}

class PlaybackMetricsTracker(
    private val nowMs: () -> Long,
) {
    private var playTappedAtMs: Long? = null
    private var playStartPositionMs: Long = 0L
    private var positionAdvanceObserved = false
    private var isBuffering = false
    private var bufferStartedAtMs: Long? = null
    private var bufferPhase: BufferPhase? = null
    private var metrics = PlaybackMetrics()

    fun snapshot(): PlaybackMetrics = metrics

    fun markScreenReady(appStartedAtMs: Long): PlaybackMetrics = update("screen_ready") {
        copy(appScreenReadyMs = (nowMs() - appStartedAtMs).coerceAtLeast(0))
    }

    fun loadTrack(title: String, hlsUrl: String): PlaybackMetrics {
        playTappedAtMs = null
        playStartPositionMs = 0L
        positionAdvanceObserved = false
        isBuffering = false
        bufferStartedAtMs = null
        bufferPhase = null
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
                startupBufferMs = 0,
                rebufferCount = 0,
                rebufferMs = 0,
                totalBufferMs = 0,
                trackTitle = title,
                trackUrl = hlsUrl,
            )
        }
    }

    fun markPlayTapped(): PlaybackMetrics {
        playTappedAtMs = nowMs()
        playStartPositionMs = metrics.currentPositionMs.coerceAtLeast(0)
        positionAdvanceObserved = false
        isBuffering = false
        bufferStartedAtMs = null
        bufferPhase = null
        return update("play_tapped") {
            copy(
                playbackError = null,
                attemptId = attemptId + 1,
                tapToFirstAudioMs = null,
                manifestLoadMs = null,
                bufferCount = 0,
                tapToReadyMs = null,
                tapToIsPlayingMs = null,
                tapToPositionAdvanceMs = null,
                startupBufferMs = 0,
                rebufferCount = 0,
                rebufferMs = 0,
                totalBufferMs = 0,
            )
        }
    }

    fun markReady(): PlaybackMetrics = update("ready") {
        copy(tapToReadyMs = tapToReadyMs ?: elapsedSincePlayTap())
    }

    fun markPlaying(positionMs: Long): PlaybackMetrics {
        val position = positionMs.coerceAtLeast(0)
        val elapsed = elapsedSincePlayTap()

        return update("playing") {
            copy(
                tapToIsPlayingMs = tapToIsPlayingMs ?: elapsed,
                isPlaying = true,
                currentPositionMs = position,
            )
        }
    }

    fun markNotPlaying(positionMs: Long): PlaybackMetrics = update("not_playing") {
        copy(isPlaying = false, currentPositionMs = positionMs.coerceAtLeast(0))
    }

    fun markBufferingStarted(): PlaybackMetrics {
        if (!isBuffering) {
            isBuffering = true
            bufferStartedAtMs = nowMs()
            bufferPhase = if (positionAdvanceObserved || metrics.currentPositionMs > playStartPositionMs) {
                BufferPhase.Rebuffer
            } else {
                BufferPhase.Startup
            }

            return update("buffering_started") {
                copy(
                    bufferCount = bufferCount + 1,
                    rebufferCount = rebufferCount + if (bufferPhase == BufferPhase.Rebuffer) 1 else 0,
                )
            }
        }
        return metrics
    }

    fun markBufferingEnded(): PlaybackMetrics {
        val startedAt = bufferStartedAtMs
        val phase = bufferPhase
        isBuffering = false
        bufferStartedAtMs = null
        bufferPhase = null

        if (startedAt == null || phase == null) {
            return update("buffering_ended") { this }
        }

        val durationMs = (nowMs() - startedAt).coerceAtLeast(0)
        return update("buffering_ended") {
            copy(
                startupBufferMs = startupBufferMs + if (phase == BufferPhase.Startup) durationMs else 0,
                rebufferMs = rebufferMs + if (phase == BufferPhase.Rebuffer) durationMs else 0,
                totalBufferMs = totalBufferMs + durationMs,
            )
        }
    }

    fun markManifestLoaded(loadDurationMs: Long): PlaybackMetrics = update("manifest_loaded") {
        copy(manifestLoadMs = loadDurationMs.coerceAtLeast(0))
    }

    fun markPosition(positionMs: Long): PlaybackMetrics {
        val position = positionMs.coerceAtLeast(0)
        val elapsed = elapsedSincePlayTap()
        val positionAdvanceMs = if (
            elapsed != null &&
            !positionAdvanceObserved &&
            position > playStartPositionMs
        ) {
            positionAdvanceObserved = true
            elapsed
        } else {
            metrics.tapToPositionAdvanceMs
        }

        return update("position") {
            copy(
                currentPositionMs = position,
                tapToPositionAdvanceMs = positionAdvanceMs,
                tapToFirstAudioMs = tapToFirstAudioMs ?: positionAdvanceMs,
            )
        }
    }

    fun markError(message: String): PlaybackMetrics = update("error") {
        copy(playbackError = message, isPlaying = false)
    }

    fun resetTransientMetrics(): PlaybackMetrics {
        playTappedAtMs = null
        playStartPositionMs = metrics.currentPositionMs.coerceAtLeast(0)
        positionAdvanceObserved = false
        isBuffering = false
        bufferStartedAtMs = null
        bufferPhase = null
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
                startupBufferMs = 0,
                rebufferCount = 0,
                rebufferMs = 0,
                totalBufferMs = 0,
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

    private enum class BufferPhase {
        Startup,
        Rebuffer,
    }
}
