package com.wavezero.player.playback

import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/**
 * Single app-entry PendingIntent for the Android media notification and MediaSession.
 *
 * The playback implementation is shared between the Flutter consumer host and
 * the standalone Android proof app. Resolve the installed app's launcher activity
 * rather than hard-coding an Activity belonging to either host.
 */
internal object WaveZeroAppLaunchIntent {
    private const val REQUEST_CODE = 4208

    fun pendingIntent(context: Context): PendingIntent? {
        val appContext = context.applicationContext
        val launchIntent = appContext.packageManager
            .getLaunchIntentForPackage(appContext.packageName)
            ?: return null

        launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            appContext,
            REQUEST_CODE,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
