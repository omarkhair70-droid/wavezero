package com.wavezero.player.playback

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
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
            preparedBeforePlay = true,
            loadToManifestMs = 55L,
            loadToReadyMs = 75L,
            prebufferCount = 1,
            prebufferMs = 70L,
            seekCount = 2,
            seekBufferMs = 35L,
            lastSeekToMs = 12_000L,
            nativePrebufferEnabled = true,
            nativePrebufferTrackId = "track-3",
            nativePrebufferTrackTitle = "Song 3",
            nativePrebufferInFlight = false,
            nativePrebufferReady = true,
            nativePrebufferHitCount = 0,
            nativePrebufferMissCount = 1,
            nativePrebufferPrepareMs = 123L,
            lastNativePrebufferTrackId = "track-3",
            lastNativePrebufferTrackTitle = "Song 3",
            lastNativePrebufferPrepareMs = 123L,
            nativeHandoffToPlayingMs = 16L,
            nativePrebufferHandoffAttempted = 1,
            nativePrebufferHandoffSucceeded = 0,
            nativePrebufferHandoffFallback = 1,
            nextPreparedBeforePlay = false,
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
        assertEquals(true, map["preparedBeforePlay"])
        assertEquals(55L, map["loadToManifestMs"])
        assertEquals(75L, map["loadToReadyMs"])
        assertEquals(1, map["prebufferCount"])
        assertEquals(70L, map["prebufferMs"])
        assertEquals(2, map["seekCount"])
        assertEquals(35L, map["seekBufferMs"])
        assertEquals(12_000L, map["lastSeekToMs"])
        assertEquals(true, map["nativePrebufferEnabled"])
        assertEquals("track-3", map["nativePrebufferTrackId"])
        assertEquals("Song 3", map["nativePrebufferTrackTitle"])
        assertEquals(false, map["nativePrebufferInFlight"])
        assertEquals(true, map["nativePrebufferReady"])
        assertEquals(0, map["nativePrebufferHitCount"])
        assertEquals(1, map["nativePrebufferMissCount"])
        assertEquals(123L, map["nativePrebufferPrepareMs"])
        assertEquals("track-3", map["lastNativePrebufferTrackId"])
        assertEquals("Song 3", map["lastNativePrebufferTrackTitle"])
        assertEquals(123L, map["lastNativePrebufferPrepareMs"])
        assertEquals(16L, map["nativeHandoffToPlayingMs"])
        assertEquals(1, map["nativePrebufferHandoffAttempted"])
        assertEquals(0, map["nativePrebufferHandoffSucceeded"])
        assertEquals(1, map["nativePrebufferHandoffFallback"])
        assertEquals(false, map["nextPreparedBeforePlay"])
        assertEquals("playing", map["lastEvent"])
        assertEquals("Title", map["trackTitle"])
        assertEquals("https://example.test/stream.m3u8", map["trackUrl"])
    }

    @Test
    fun resetTransientMetricsKeepsLoadedTrackIdentity() {
        var nowMs = 1_000L
        val tracker = PlaybackMetricsTracker(nowMs = { nowMs })
        tracker.loadTrack("Loaded", "https://example.test/loaded.m3u8")
        tracker.markBufferingStarted()
        nowMs += 50L
        tracker.markBufferingEnded()
        tracker.markReady()
        tracker.markPlayTapped()
        nowMs += 100L
        tracker.markPlaying(positionMs = 42L)
        tracker.markSeekStarted(targetPositionMs = 5_000L)
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
        assertFalse(reset.preparedBeforePlay)
        assertNull(reset.loadToManifestMs)
        assertNull(reset.loadToReadyMs)
        assertEquals(0, reset.prebufferCount)
        assertEquals(0L, reset.prebufferMs)
        assertEquals(0, reset.seekCount)
        assertEquals(0L, reset.seekBufferMs)
        assertNull(reset.lastSeekToMs)
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

    @Test
    fun metricsTrackPreloadManifestReadyAndPrebufferBeforePlay() {
        var nowMs = 1_000L
        val tracker = PlaybackMetricsTracker(nowMs = { nowMs })
        tracker.loadTrack("Loaded", "https://example.test/loaded.m3u8")

        tracker.markBufferingStarted()
        nowMs += 200L
        val prebufferEnded = tracker.markBufferingEnded()
        assertEquals(1, prebufferEnded.prebufferCount)
        assertEquals(200L, prebufferEnded.prebufferMs)
        assertEquals(0, prebufferEnded.bufferCount)
        assertEquals(0L, prebufferEnded.startupBufferMs)

        nowMs += 100L
        val manifest = tracker.markManifestLoaded(loadDurationMs = 90L)
        assertEquals(90L, manifest.manifestLoadMs)
        assertEquals(300L, manifest.loadToManifestMs)

        nowMs += 150L
        val ready = tracker.markReady()
        assertTrue(ready.preparedBeforePlay)
        assertEquals(450L, ready.loadToReadyMs)
        assertNull(ready.tapToReadyMs)

        nowMs += 1_000L
        val attempt = tracker.markPlayTapped()
        assertEquals(1, attempt.attemptId)
        assertEquals(0, attempt.bufferCount)
        assertEquals(200L, attempt.prebufferMs)
        assertTrue(attempt.preparedBeforePlay)
    }

    @Test
    fun seekBufferDoesNotIncrementRebufferCount() {
        var nowMs = 1_000L
        val tracker = PlaybackMetricsTracker(nowMs = { nowMs })
        tracker.loadTrack("Loaded", "https://example.test/loaded.m3u8")
        tracker.markPlayTapped()
        tracker.markReady()
        tracker.markPlaying(positionMs = 1_000L)
        tracker.markPosition(positionMs = 1_250L)

        val seekStarted = tracker.markSeekStarted(targetPositionMs = 30_000L)
        assertEquals(1, seekStarted.seekCount)
        assertEquals(30_000L, seekStarted.lastSeekToMs)

        tracker.markBufferingStarted()
        nowMs += 300L
        val seekEnded = tracker.markBufferingEnded()

        assertEquals(0, seekEnded.rebufferCount)
        assertEquals(0L, seekEnded.rebufferMs)
        assertEquals(0L, seekEnded.totalBufferMs)
        assertEquals(300L, seekEnded.seekBufferMs)
    }
}


class PlaybackMetricsNativePrebufferTest {

    @Test
    fun nativePrebufferMetricsTrackPreparedHandoffOutcome() {
        val tracker = PlaybackMetricsTracker(nowMs = { 1_000L })

        tracker.markNativePrebufferStarted("track-3", "Song 3")
        tracker.markNativePrebufferReady("track-3", 120L)
        tracker.markNativePrebufferHandoffAttempted()
        val handoff = tracker.markNativePrebufferHandoffSucceeded("track-3")

        assertEquals(1, handoff.nativePrebufferHitCount)
        assertEquals(0, handoff.nativePrebufferMissCount)
        assertEquals(1, handoff.nativePrebufferHandoffAttempted)
        assertEquals(1, handoff.nativePrebufferHandoffSucceeded)
        assertEquals(0, handoff.nativePrebufferHandoffFallback)
        assertFalse(handoff.nativePrebufferEnabled)
        assertNull(handoff.nativePrebufferTrackId)
        assertEquals("track-3", handoff.lastNativePrebufferTrackId)
        assertEquals("Song 3", handoff.lastNativePrebufferTrackTitle)
        assertEquals(120L, handoff.lastNativePrebufferPrepareMs)
        assertNull(handoff.nativeHandoffToPlayingMs)
        assertTrue(handoff.nextPreparedBeforePlay)
    }


    @Test
    fun nativeHandoffToPlayingMsIsMeasuredFromSuccessfulHandoffToPlaying() {
        var nowMs = 1_000L
        val tracker = PlaybackMetricsTracker(nowMs = { nowMs })

        tracker.markNativePrebufferStarted("track-3", "Song 3")
        tracker.markNativePrebufferReady("track-3", 120L)
        tracker.markNativePrebufferHandoffAttempted()
        tracker.markNativePrebufferHandoffSucceeded("track-3")
        nowMs += 35L
        val playing = tracker.markPlaying(positionMs = 0L)

        assertEquals(35L, playing.nativeHandoffToPlayingMs)
    }

    @Test
    fun nativePrebufferMetricsTrackReadinessAndSafeFallbackOutcome() {
        var nowMs = 1_000L
        val tracker = PlaybackMetricsTracker(nowMs = { nowMs })

        val started = tracker.markNativePrebufferStarted("track-3", "Song 3")
        assertTrue(started.nativePrebufferEnabled)
        assertEquals("track-3", started.nativePrebufferTrackId)
        assertEquals("Song 3", started.nativePrebufferTrackTitle)
        assertTrue(started.nativePrebufferInFlight)
        assertFalse(started.nativePrebufferReady)

        nowMs += 240L
        val ready = tracker.markNativePrebufferReady("track-3", 240L)
        assertFalse(ready.nativePrebufferInFlight)
        assertTrue(ready.nativePrebufferReady)
        assertEquals(240L, ready.nativePrebufferPrepareMs)
        assertEquals("track-3", ready.lastNativePrebufferTrackId)
        assertEquals("Song 3", ready.lastNativePrebufferTrackTitle)
        assertEquals(240L, ready.lastNativePrebufferPrepareMs)

        tracker.markNativePrebufferHandoffAttempted()
        val fallback = tracker.markNativePrebufferOutcome("track-3", usedPreparedPath = false)
        assertEquals(0, fallback.nativePrebufferHitCount)
        assertEquals(1, fallback.nativePrebufferMissCount)
        assertEquals(1, fallback.nativePrebufferHandoffAttempted)
        assertEquals(0, fallback.nativePrebufferHandoffSucceeded)
        assertEquals(1, fallback.nativePrebufferHandoffFallback)
        assertFalse(fallback.nextPreparedBeforePlay)
    }
}
