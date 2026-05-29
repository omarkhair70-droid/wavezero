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

    fun showMediaControls(context: Context) {
        startMediaSessionService(context, WaveZeroMediaSessionService.ACTION_SHOW_NOTIFICATION)
    }

    fun dismissMediaControls(context: Context) {
        startMediaSessionService(context, WaveZeroMediaSessionService.ACTION_STOP_AND_DISMISS)
    }

    fun startMediaSessionService(context: Context) {
        startMediaSessionService(context, WaveZeroMediaSessionService.ACTION_SHOW_NOTIFICATION)
    }

    private fun startMediaSessionService(context: Context, action: String) {
        val appContext = context.applicationContext
        val intent = Intent(appContext, WaveZeroMediaSessionService::class.java).setAction(action)
        appContext.startService(intent)
    }

    @Synchronized
    fun release() {
        manager?.release()
        manager = null
    }
}
