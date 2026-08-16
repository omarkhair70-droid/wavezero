package com.wavezero.player.playback

import android.content.Context
import android.content.Intent
import android.os.SystemClock

/**
 * Process-scoped owner for WaveZero's native playback engine.
 *
 * Both the Flutter activity bridge and [WaveZeroMediaSessionService] use this
 * same [AudioPlayerManager]. A service instance can be stopped or recreated
 * while the Flutter activity is still alive, so service teardown must not
 * release this manager out from under the activity's MethodChannel handler.
 * Android process death remains the normal final cleanup boundary for the
 * long-lived playback session; [release] is reserved for explicit process/test
 * teardown where no client can still hold the manager.
 */
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
