package com.wavezero.player.playback

import android.content.Context
import android.os.SystemClock

object WaveZeroPlaybackSession {
    @Volatile
    private var manager: AudioPlayerManager? = null

    @Synchronized
    fun getOrCreate(
        context: Context,
        appStartedAtMs: Long = SystemClock.elapsedRealtime(),
    ): AudioPlayerManager {
        val existing = manager
        if (existing != null) return existing

        return AudioPlayerManager(
            context = context.applicationContext,
            appStartedAtMs = appStartedAtMs,
        ).also { manager = it }
    }

    @Synchronized
    fun release() {
        manager?.release()
        manager = null
    }
}
