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

        val reset = tracker.resetTransientMetrics()

        assertEquals("Loaded", reset.trackTitle)
        assertEquals("https://example.test/loaded.m3u8", reset.trackUrl)
        assertNull(reset.tapToFirstAudioMs)
        assertEquals(0L, reset.currentPositionMs)
        assertFalse(reset.isPlaying)
    }
}
