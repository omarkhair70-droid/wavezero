package com.wavezero.player.playback

import android.content.Context
import android.content.Intent
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

        val appContext = context.applicationContext
        return AudioPlayerManager(
            context = appContext,
            appStartedAtMs = appStartedAtMs,
        ).also { manager = it }
    }

    fun startMediaSessionService(context: Context) {
        val appContext = context.applicationContext
        val intent = Intent(appContext, WaveZeroMediaSessionService::class.java)
        appContext.startService(intent)
    }

    @Synchronized
    fun release() {
        manager?.release()
        manager = null
    }
}
