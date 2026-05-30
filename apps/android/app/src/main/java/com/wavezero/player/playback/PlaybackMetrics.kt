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
    val preparedBeforePlay: Boolean = false,
    val loadToManifestMs: Long? = null,
    val loadToReadyMs: Long? = null,
    val prebufferCount: Int = 0,
    val prebufferMs: Long = 0,
    val seekCount: Int = 0,
    val seekBufferMs: Long = 0,
    val lastSeekToMs: Long? = null,
    val nativePrebufferEnabled: Boolean = false,
    val nativePrebufferTrackId: String? = null,
    val nativePrebufferTrackTitle: String? = null,
    val nativePrebufferInFlight: Boolean = false,
    val nativePrebufferReady: Boolean = false,
    val nativePrebufferHitCount: Int = 0,
    val nativePrebufferMissCount: Int = 0,
    val nativePrebufferPrepareMs: Long? = null,
    val lastNativePrebufferTrackId: String? = null,
    val lastNativePrebufferTrackTitle: String? = null,
    val lastNativePrebufferPrepareMs: Long? = null,
    val nativeHandoffToPlayingMs: Long? = null,
    val nativePrebufferHandoffAttempted: Int = 0,
    val nativePrebufferHandoffSucceeded: Int = 0,
    val nativePrebufferHandoffFallback: Int = 0,
    val nextPreparedBeforePlay: Boolean = false,
    val autoAdvancePreparedAttempted: Int = 0,
    val autoAdvancePreparedSucceeded: Int = 0,
    val autoAdvancePreparedFallback: Int = 0,
    val autoAdvancePreparedBeforePlay: Boolean = false,
    val lastAutoAdvancePreparedTrackId: String? = null,
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
        "preparedBeforePlay" to preparedBeforePlay,
        "loadToManifestMs" to loadToManifestMs,
        "loadToReadyMs" to loadToReadyMs,
        "prebufferCount" to prebufferCount,
        "prebufferMs" to prebufferMs,
        "seekCount" to seekCount,
        "seekBufferMs" to seekBufferMs,
        "lastSeekToMs" to lastSeekToMs,
        "nativePrebufferEnabled" to nativePrebufferEnabled,
        "nativePrebufferTrackId" to nativePrebufferTrackId,
        "nativePrebufferTrackTitle" to nativePrebufferTrackTitle,
        "nativePrebufferInFlight" to nativePrebufferInFlight,
        "nativePrebufferReady" to nativePrebufferReady,
        "nativePrebufferHitCount" to nativePrebufferHitCount,
        "nativePrebufferMissCount" to nativePrebufferMissCount,
        "nativePrebufferPrepareMs" to nativePrebufferPrepareMs,
        "lastNativePrebufferTrackId" to lastNativePrebufferTrackId,
        "lastNativePrebufferTrackTitle" to lastNativePrebufferTrackTitle,
        "lastNativePrebufferPrepareMs" to lastNativePrebufferPrepareMs,
        "nativeHandoffToPlayingMs" to nativeHandoffToPlayingMs,
        "nativePrebufferHandoffAttempted" to nativePrebufferHandoffAttempted,
        "nativePrebufferHandoffSucceeded" to nativePrebufferHandoffSucceeded,
        "nativePrebufferHandoffFallback" to nativePrebufferHandoffFallback,
        "nextPreparedBeforePlay" to nextPreparedBeforePlay,
        "autoAdvancePreparedAttempted" to autoAdvancePreparedAttempted,
        "autoAdvancePreparedSucceeded" to autoAdvancePreparedSucceeded,
        "autoAdvancePreparedFallback" to autoAdvancePreparedFallback,
        "autoAdvancePreparedBeforePlay" to autoAdvancePreparedBeforePlay,
        "lastAutoAdvancePreparedTrackId" to lastAutoAdvancePreparedTrackId,
        "lastEvent" to lastEvent,
        "trackTitle" to trackTitle,
        "trackUrl" to trackUrl,
    )
}

class PlaybackMetricsTracker(
    private val nowMs: () -> Long,
) {
    private var trackLoadedAtMs: Long? = null
    private var playTappedAtMs: Long? = null
    private var playStartPositionMs: Long = 0L
    private var positionAdvanceObserved = false
    private var isBuffering = false
    private var bufferStartedAtMs: Long? = null
    private var bufferPhase: BufferPhase? = null
    private var lastSeekAtMs: Long? = null
    private var nativeHandoffStartedAtMs: Long? = null
    private var metrics = PlaybackMetrics()

    fun snapshot(): PlaybackMetrics = metrics

    fun markScreenReady(appStartedAtMs: Long): PlaybackMetrics = update("screen_ready") {
        copy(appScreenReadyMs = (nowMs() - appStartedAtMs).coerceAtLeast(0))
    }

    fun loadTrack(title: String, hlsUrl: String): PlaybackMetrics {
        trackLoadedAtMs = nowMs()
        playTappedAtMs = null
        playStartPositionMs = 0L
        positionAdvanceObserved = false
        isBuffering = false
        bufferStartedAtMs = null
        bufferPhase = null
        lastSeekAtMs = null
        nativeHandoffStartedAtMs = null
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
                preparedBeforePlay = false,
                loadToManifestMs = null,
                loadToReadyMs = null,
                prebufferCount = 0,
                prebufferMs = 0,
                seekCount = 0,
                seekBufferMs = 0,
                lastSeekToMs = null,
                nextPreparedBeforePlay = false,
                autoAdvancePreparedBeforePlay = false,
                trackTitle = title,
                trackUrl = hlsUrl,
            )
        }
    }

    fun markPlayTapped(): PlaybackMetrics {
        val tappedAt = nowMs()
        val wasPrebuffering = isBuffering && bufferPhase == BufferPhase.Prebuffer
        val prebufferDurationMs = if (wasPrebuffering) {
            bufferStartedAtMs?.let { (tappedAt - it).coerceAtLeast(0) } ?: 0L
        } else {
            0L
        }

        playTappedAtMs = tappedAt
        playStartPositionMs = metrics.currentPositionMs.coerceAtLeast(0)
        positionAdvanceObserved = false

        if (wasPrebuffering) {
            isBuffering = true
            bufferStartedAtMs = tappedAt
            bufferPhase = BufferPhase.Startup
        } else {
            isBuffering = false
            bufferStartedAtMs = null
            bufferPhase = null
        }

        return update("play_tapped") {
            copy(
                playbackError = null,
                attemptId = attemptId + 1,
                tapToFirstAudioMs = null,
                bufferCount = if (wasPrebuffering) 1 else 0,
                tapToReadyMs = null,
                tapToIsPlayingMs = null,
                tapToPositionAdvanceMs = null,
                startupBufferMs = 0,
                rebufferCount = 0,
                rebufferMs = 0,
                totalBufferMs = 0,
                prebufferMs = prebufferMs + prebufferDurationMs,
            )
        }
    }

    fun markReady(): PlaybackMetrics {
        val elapsed = elapsedSincePlayTap()
        return update("ready") {
            if (elapsed == null) {
                copy(
                    preparedBeforePlay = true,
                    loadToReadyMs = loadToReadyMs ?: elapsedSinceTrackLoad(),
                )
            } else {
                copy(tapToReadyMs = tapToReadyMs ?: elapsed)
            }
        }
    }

    fun markPlaying(positionMs: Long): PlaybackMetrics {
        val position = positionMs.coerceAtLeast(0)
        val elapsed = elapsedSincePlayTap()
        val handoffElapsed = nativeHandoffStartedAtMs?.let { (nowMs() - it).coerceAtLeast(0) }
        nativeHandoffStartedAtMs = null

        return update("playing") {
            copy(
                tapToIsPlayingMs = tapToIsPlayingMs ?: elapsed,
                nativeHandoffToPlayingMs = handoffElapsed ?: nativeHandoffToPlayingMs,
                isPlaying = true,
                currentPositionMs = position,
            )
        }
    }

    fun markNotPlaying(positionMs: Long): PlaybackMetrics {
        nativeHandoffStartedAtMs = null
        return update("not_playing") {
            copy(isPlaying = false, currentPositionMs = positionMs.coerceAtLeast(0))
        }
    }

    fun markSeekStarted(targetPositionMs: Long): PlaybackMetrics {
        lastSeekAtMs = nowMs()
        return update("seek_started") {
            copy(
                seekCount = seekCount + 1,
                lastSeekToMs = targetPositionMs.coerceAtLeast(0),
                playbackError = null,
            )
        }
    }

    fun markBufferingStarted(): PlaybackMetrics {
        if (!isBuffering) {
            val startedAt = nowMs()
            isBuffering = true
            bufferStartedAtMs = startedAt
            bufferPhase = when {
                playTappedAtMs == null -> BufferPhase.Prebuffer
                isRecentSeek(startedAt) -> BufferPhase.Seek
                positionAdvanceObserved || metrics.currentPositionMs > playStartPositionMs -> BufferPhase.Rebuffer
                else -> BufferPhase.Startup
            }

            return update("buffering_started") {
                when (bufferPhase) {
                    BufferPhase.Prebuffer -> copy(prebufferCount = prebufferCount + 1)
                    BufferPhase.Seek -> this
                    BufferPhase.Rebuffer -> copy(
                        bufferCount = bufferCount + 1,
                        rebufferCount = rebufferCount + 1,
                    )
                    BufferPhase.Startup -> copy(bufferCount = bufferCount + 1)
                    null -> this
                }
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
            when (phase) {
                BufferPhase.Prebuffer -> copy(prebufferMs = prebufferMs + durationMs)
                BufferPhase.Seek -> copy(seekBufferMs = seekBufferMs + durationMs)
                BufferPhase.Startup -> copy(
                    startupBufferMs = startupBufferMs + durationMs,
                    totalBufferMs = totalBufferMs + durationMs,
                )
                BufferPhase.Rebuffer -> copy(
                    rebufferMs = rebufferMs + durationMs,
                    totalBufferMs = totalBufferMs + durationMs,
                )
            }
        }
    }

    fun markManifestLoaded(loadDurationMs: Long): PlaybackMetrics {
        if (metrics.lastEvent == "stopped") return metrics

        return update("manifest_loaded") {
            copy(
                manifestLoadMs = loadDurationMs.coerceAtLeast(0),
                loadToManifestMs = loadToManifestMs ?: elapsedSinceTrackLoad(),
            )
        }
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
        lastSeekAtMs = null
        nativeHandoffStartedAtMs = null
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
                preparedBeforePlay = false,
                loadToManifestMs = null,
                loadToReadyMs = null,
                prebufferCount = 0,
                prebufferMs = 0,
                seekCount = 0,
                seekBufferMs = 0,
                lastSeekToMs = null,
                nextPreparedBeforePlay = false,
                autoAdvancePreparedBeforePlay = false,
            )
        }
    }

    fun resetForStop(): PlaybackMetrics {
        playTappedAtMs = null
        playStartPositionMs = 0L
        positionAdvanceObserved = false
        isBuffering = false
        bufferStartedAtMs = null
        bufferPhase = null
        lastSeekAtMs = null
        nativeHandoffStartedAtMs = null
        return update("stopped") {
            copy(
                tapToFirstAudioMs = null,
                isPlaying = false,
                currentPositionMs = 0,
                playbackError = null,
                tapToReadyMs = null,
                tapToIsPlayingMs = null,
                tapToPositionAdvanceMs = null,
                lastSeekToMs = null,
                nextPreparedBeforePlay = false,
                autoAdvancePreparedBeforePlay = false,
            )
        }
    }

    fun markNativePrebufferStarted(trackId: String, title: String): PlaybackMetrics = update("native_prebuffer_started") {
        copy(
            nativePrebufferEnabled = true,
            nativePrebufferTrackId = trackId,
            nativePrebufferTrackTitle = title,
            nativePrebufferInFlight = true,
            nativePrebufferReady = false,
            nativePrebufferPrepareMs = null,
        )
    }

    fun markNativePrebufferReady(trackId: String, prepareMs: Long): PlaybackMetrics {
        if (metrics.nativePrebufferTrackId != trackId) return metrics
        return update("native_prebuffer_ready") {
            copy(
                nativePrebufferEnabled = true,
                nativePrebufferInFlight = false,
                nativePrebufferReady = true,
                nativePrebufferPrepareMs = prepareMs.coerceAtLeast(0),
                lastNativePrebufferTrackId = trackId,
                lastNativePrebufferTrackTitle = nativePrebufferTrackTitle,
                lastNativePrebufferPrepareMs = prepareMs.coerceAtLeast(0),
            )
        }
    }

    fun markNativePrebufferCleared(nextPreparedBeforePlay: Boolean = false): PlaybackMetrics = update("native_prebuffer_cleared") {
        copy(
            nativePrebufferEnabled = false,
            nativePrebufferTrackId = null,
            nativePrebufferTrackTitle = null,
            nativePrebufferInFlight = false,
            nativePrebufferReady = false,
            nativePrebufferPrepareMs = null,
            nextPreparedBeforePlay = nextPreparedBeforePlay,
            autoAdvancePreparedBeforePlay = false,
        )
    }

    fun markNativePrebufferOutcome(trackId: String, usedPreparedPath: Boolean): PlaybackMetrics {
        val matchedReady = metrics.nativePrebufferTrackId == trackId && metrics.nativePrebufferReady
        val succeeded = usedPreparedPath && matchedReady
        if (!succeeded) nativeHandoffStartedAtMs = null
        return update("native_prebuffer_outcome") {
            copy(
                nativePrebufferHitCount = if (succeeded) nativePrebufferHitCount + 1 else nativePrebufferHitCount,
                nativePrebufferMissCount = if (succeeded) nativePrebufferMissCount else nativePrebufferMissCount + 1,
                nativePrebufferHandoffFallback = if (succeeded) nativePrebufferHandoffFallback else nativePrebufferHandoffFallback + 1,
                nextPreparedBeforePlay = succeeded,
            )
        }
    }

    fun markAutoAdvancePreparedAttempted(): PlaybackMetrics = update("auto_advance_prepared_attempted") {
        copy(
            autoAdvancePreparedAttempted = autoAdvancePreparedAttempted + 1,
            autoAdvancePreparedBeforePlay = false,
        )
    }

    fun markAutoAdvancePreparedFallback(trackId: String): PlaybackMetrics = update("auto_advance_prepared_fallback") {
        copy(
            autoAdvancePreparedFallback = autoAdvancePreparedFallback + 1,
            autoAdvancePreparedBeforePlay = false,
            lastAutoAdvancePreparedTrackId = trackId.takeIf { it.isNotBlank() } ?: lastAutoAdvancePreparedTrackId,
        )
    }

    fun markAutoAdvancePreparedSucceeded(trackId: String): PlaybackMetrics = update("auto_advance_prepared_succeeded") {
        copy(
            autoAdvancePreparedSucceeded = autoAdvancePreparedSucceeded + 1,
            autoAdvancePreparedBeforePlay = true,
            lastAutoAdvancePreparedTrackId = trackId.takeIf { it.isNotBlank() } ?: lastAutoAdvancePreparedTrackId,
        )
    }

    fun markNativePrebufferHandoffAttempted(): PlaybackMetrics = update("native_prebuffer_handoff_attempted") {
        nativeHandoffStartedAtMs = null
        copy(
            nativePrebufferHandoffAttempted = nativePrebufferHandoffAttempted + 1,
            nativeHandoffToPlayingMs = null,
        )
    }

    fun markNativePrebufferHandoffSucceeded(trackId: String): PlaybackMetrics {
        val matchedReady = metrics.nativePrebufferTrackId == trackId && metrics.nativePrebufferReady
        if (matchedReady) nativeHandoffStartedAtMs = nowMs()
        return update("native_prebuffer_handoff_succeeded") {
            copy(
                nativePrebufferEnabled = false,
                nativePrebufferTrackId = null,
                nativePrebufferTrackTitle = null,
                nativePrebufferInFlight = false,
                nativePrebufferReady = false,
                nativePrebufferPrepareMs = null,
                nativePrebufferHitCount = if (matchedReady) nativePrebufferHitCount + 1 else nativePrebufferHitCount,
                nativePrebufferHandoffSucceeded = if (matchedReady) nativePrebufferHandoffSucceeded + 1 else nativePrebufferHandoffSucceeded,
                nextPreparedBeforePlay = matchedReady,
            )
        }
    }

    private fun elapsedSincePlayTap(): Long? = playTappedAtMs?.let { (nowMs() - it).coerceAtLeast(0) }

    private fun elapsedSinceTrackLoad(): Long? = trackLoadedAtMs?.let { (nowMs() - it).coerceAtLeast(0) }

    private fun isRecentSeek(nowMs: Long): Boolean = lastSeekAtMs?.let { nowMs - it <= SEEK_BUFFER_WINDOW_MS } == true

    private fun update(eventName: String, block: PlaybackMetrics.() -> PlaybackMetrics): PlaybackMetrics {
        metrics = metrics.block().copy(lastEvent = eventName)
        return metrics
    }

    private enum class BufferPhase {
        Prebuffer,
        Seek,
        Startup,
        Rebuffer,
    }

    private companion object {
        const val SEEK_BUFFER_WINDOW_MS = 2_000L
    }
}
