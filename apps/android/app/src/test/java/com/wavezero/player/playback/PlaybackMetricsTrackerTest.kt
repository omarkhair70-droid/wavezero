package com.wavezero.player.playback

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PlaybackMetricsTrackerTest {
    private var nowMs = 1_000L
    private val tracker = PlaybackMetricsTracker(nowMs = { nowMs })

    @Test
    fun markScreenReadyUsesElapsedTimeSinceAppStart() {
        val metrics = tracker.markScreenReady(appStartedAtMs = 250L)

        assertEquals(750L, metrics.appScreenReadyMs)
    }

    @Test
    fun firstPlayingTransitionRecordsTapToFirstAudioOnce() {
        tracker.markPlayTapped()
        nowMs += 325L

        val first = tracker.markPlaying(positionMs = 12L)
        nowMs += 500L
        val second = tracker.markPlaying(positionMs = 520L)

        assertEquals(325L, first.tapToFirstAudioMs)
        assertEquals(325L, second.tapToFirstAudioMs)
        assertEquals(520L, second.currentPositionMs)
        assertTrue(second.isPlaying)
    }

    @Test
    fun bufferingCountOnlyIncrementsForNewBufferingSpan() {
        tracker.markBufferingStarted()
        tracker.markBufferingStarted()
        tracker.markBufferingEnded()
        val metrics = tracker.markBufferingStarted()

        assertEquals(2, metrics.bufferCount)
    }

    @Test
    fun stopResetsTransientPlaybackMetricsButKeepsStartupMetrics() {
        tracker.markScreenReady(appStartedAtMs = 900L)
        tracker.markPlayTapped()
        nowMs += 100L
        tracker.markPlaying(positionMs = 42L)
        tracker.markError("boom")

        val metrics = tracker.resetForStop()

        assertEquals(100L, metrics.appScreenReadyMs)
        assertNull(metrics.tapToFirstAudioMs)
        assertEquals(0L, metrics.currentPositionMs)
        assertFalse(metrics.isPlaying)
        assertNull(metrics.playbackError)
    }

    @Test
    fun stopKeepsPreparedPrebufferAndRebufferMetricsHonest() {
        tracker.loadTrack("Song 3", "https://example.com/song3.m3u8")
        tracker.markBufferingStarted()
        nowMs += 40L
        tracker.markBufferingEnded()
        tracker.markReady()
        tracker.markPlayTapped()
        tracker.markPlaying(positionMs = 1_200L)
        tracker.markBufferingStarted()
        val beforeStop = tracker.snapshot()
        tracker.markError("temporary failure")

        val stopped = tracker.resetForStop()

        assertEquals("Song 3", stopped.trackTitle)
        assertEquals("https://example.com/song3.m3u8", stopped.trackUrl)
        assertEquals(1, stopped.prebufferCount)
        assertEquals(40L, stopped.prebufferMs)
        assertEquals(beforeStop.rebufferCount, stopped.rebufferCount)
        assertEquals(0L, stopped.currentPositionMs)
        assertFalse(stopped.isPlaying)
        assertNull(stopped.playbackError)
        assertEquals("stopped", stopped.lastEvent)
    }

}
