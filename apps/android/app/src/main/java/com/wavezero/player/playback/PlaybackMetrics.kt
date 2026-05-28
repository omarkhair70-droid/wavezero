package com.wavezero.player.playback

data class PlaybackMetrics(
    val appScreenReadyMs: Long? = null,
    val tapToFirstAudioMs: Long? = null,
    val manifestLoadMs: Long? = null,
    val bufferCount: Int = 0,
    val isPlaying: Boolean = false,
    val currentPositionMs: Long = 0,
    val playbackError: String? = null,
)

class PlaybackMetricsTracker(
    private val nowMs: () -> Long,
) {
    private var playTappedAtMs: Long? = null
    private var firstAudioObserved = false
    private var isBuffering = false
    private var metrics = PlaybackMetrics()

    fun snapshot(): PlaybackMetrics = metrics

    fun markScreenReady(appStartedAtMs: Long): PlaybackMetrics = update {
        copy(appScreenReadyMs = (nowMs() - appStartedAtMs).coerceAtLeast(0))
    }

    fun markPlayTapped(): PlaybackMetrics {
        playTappedAtMs = nowMs()
        firstAudioObserved = false
        return update { copy(playbackError = null) }
    }

    fun markPlaying(positionMs: Long): PlaybackMetrics {
        val firstAudioMs = if (!firstAudioObserved) {
            firstAudioObserved = true
            playTappedAtMs?.let { (nowMs() - it).coerceAtLeast(0) }
        } else {
            metrics.tapToFirstAudioMs
        }

        return update {
            copy(
                tapToFirstAudioMs = firstAudioMs,
                isPlaying = true,
                currentPositionMs = positionMs.coerceAtLeast(0),
            )
        }
    }

    fun markNotPlaying(positionMs: Long): PlaybackMetrics = update {
        copy(isPlaying = false, currentPositionMs = positionMs.coerceAtLeast(0))
    }

    fun markBufferingStarted(): PlaybackMetrics {
        if (!isBuffering) {
            isBuffering = true
            return update { copy(bufferCount = bufferCount + 1) }
        }
        return metrics
    }

    fun markBufferingEnded(): PlaybackMetrics {
        isBuffering = false
        return metrics
    }

    fun markManifestLoaded(loadDurationMs: Long): PlaybackMetrics = update {
        copy(manifestLoadMs = loadDurationMs.coerceAtLeast(0))
    }

    fun markPosition(positionMs: Long): PlaybackMetrics = update {
        copy(currentPositionMs = positionMs.coerceAtLeast(0))
    }

    fun markError(message: String): PlaybackMetrics = update {
        copy(playbackError = message, isPlaying = false)
    }

    fun resetForStop(): PlaybackMetrics {
        playTappedAtMs = null
        firstAudioObserved = false
        isBuffering = false
        return update {
            copy(
                tapToFirstAudioMs = null,
                isPlaying = false,
                currentPositionMs = 0,
                playbackError = null,
            )
        }
    }

    private fun update(block: PlaybackMetrics.() -> PlaybackMetrics): PlaybackMetrics {
        metrics = metrics.block()
        return metrics
    }
}
