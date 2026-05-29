package com.wavezero.player.playback

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

class PlaybackMetricsMapTest {
    @Test
    fun toMapIncludesFlutterBridgeContractFields() {
        val metrics = PlaybackMetrics(
            appScreenReadyMs = 10L,
            tapToFirstAudioMs = 20L,
            manifestLoadMs = 30L,
            bufferCount = 2,
            isPlaying = true,
            currentPositionMs = 250L,
            playbackError = null,
            sessionId = "session-1",
            attemptId = 3,
            tapToReadyMs = 12L,
            tapToIsPlayingMs = 18L,
            tapToPositionAdvanceMs = 24L,
            startupBufferMs = 90L,
            rebufferCount = 1,
            rebufferMs = 40L,
            totalBufferMs = 130L,
            lastEvent = "playing",
            trackTitle = "Title",
            trackUrl = "https://example.test/stream.m3u8",
        )

        val map = metrics.toMap()

        assertEquals(10L, map["appScreenReadyMs"])
        assertEquals(20L, map["tapToFirstAudioMs"])
        assertEquals(30L, map["manifestLoadMs"])
        assertEquals(2, map["bufferCount"])
        assertEquals(true, map["isPlaying"])
        assertEquals(250L, map["currentPositionMs"])
        assertNull(map["playbackError"])
        assertEquals("session-1", map["sessionId"])
        assertEquals(3, map["attemptId"])
        assertEquals(12L, map["tapToReadyMs"])
        assertEquals(18L, map["tapToIsPlayingMs"])
        assertEquals(24L, map["tapToPositionAdvanceMs"])
        assertEquals(90L, map["startupBufferMs"])
        assertEquals(1, map["rebufferCount"])
        assertEquals(40L, map["rebufferMs"])
        assertEquals(130L, map["totalBufferMs"])
        assertEquals("playing", map["lastEvent"])
        assertEquals("Title", map["trackTitle"])
        assertEquals("https://example.test/stream.m3u8", map["trackUrl"])
    }

    @Test
    fun resetTransientMetricsKeepsLoadedTrackIdentity() {
        var nowMs = 1_000L
        val tracker = PlaybackMetricsTracker(nowMs = { nowMs })
        tracker.loadTrack("Loaded", "https://example.test/loaded.m3u8")
        tracker.markPlayTapped()
        nowMs += 100L
        tracker.markPlaying(positionMs = 42L)
        tracker.markBufferingStarted()
        nowMs += 50L
        tracker.markBufferingEnded()

        val reset = tracker.resetTransientMetrics()

        assertEquals("Loaded", reset.trackTitle)
        assertEquals("https://example.test/loaded.m3u8", reset.trackUrl)
        assertNull(reset.tapToFirstAudioMs)
        assertEquals(0L, reset.currentPositionMs)
        assertFalse(reset.isPlaying)
        assertEquals(0, reset.bufferCount)
        assertEquals(0L, reset.startupBufferMs)
        assertEquals(0, reset.rebufferCount)
        assertEquals(0L, reset.rebufferMs)
        assertEquals(0L, reset.totalBufferMs)
    }

    @Test
    fun metricsTrackAttemptStartupBufferPositionAdvanceAndRebuffer() {
        var nowMs = 1_000L
        val tracker = PlaybackMetricsTracker(nowMs = { nowMs })
        tracker.loadTrack("Loaded", "https://example.test/loaded.m3u8")

        val attempt = tracker.markPlayTapped()
        assertEquals(1, attempt.attemptId)
        assertNull(attempt.tapToFirstAudioMs)
        assertEquals(0, attempt.bufferCount)

        tracker.markBufferingStarted()
        nowMs += 250L
        val startupEnded = tracker.markBufferingEnded()
        assertEquals(1, startupEnded.bufferCount)
        assertEquals(250L, startupEnded.startupBufferMs)
        assertEquals(0, startupEnded.rebufferCount)
        assertEquals(0L, startupEnded.rebufferMs)
        assertEquals(250L, startupEnded.totalBufferMs)

        nowMs += 50L
        val ready = tracker.markReady()
        assertEquals(300L, ready.tapToReadyMs)

        val playingWithoutPositionAdvance = tracker.markPlaying(positionMs = 0L)
        assertEquals(300L, playingWithoutPositionAdvance.tapToIsPlayingMs)
        assertNull(playingWithoutPositionAdvance.tapToFirstAudioMs)
        assertNull(playingWithoutPositionAdvance.tapToPositionAdvanceMs)

        nowMs += 300L
        val advanced = tracker.markPosition(positionMs = 350L)
        assertEquals(600L, advanced.tapToPositionAdvanceMs)
        assertEquals(600L, advanced.tapToFirstAudioMs)

        tracker.markBufferingStarted()
        nowMs += 150L
        val rebufferEnded = tracker.markBufferingEnded()
        assertEquals(2, rebufferEnded.bufferCount)
        assertEquals(250L, rebufferEnded.startupBufferMs)
        assertEquals(1, rebufferEnded.rebufferCount)
        assertEquals(150L, rebufferEnded.rebufferMs)
        assertEquals(400L, rebufferEnded.totalBufferMs)
    }
}
