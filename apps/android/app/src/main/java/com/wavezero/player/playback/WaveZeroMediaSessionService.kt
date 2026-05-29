package com.wavezero.player.playback

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.ServiceInfo
import android.content.Intent
import android.os.Build
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

@OptIn(UnstableApi::class)
class WaveZeroMediaSessionService : MediaSessionService() {
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return WaveZeroPlaybackSession.getOrCreate(applicationContext).mediaSession
    }

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = WaveZeroPlaybackSession.getOrCreate(applicationContext)
        when (intent?.action) {
            ACTION_TOGGLE_PLAYBACK -> manager.togglePlayPause()
            ACTION_STOP_AND_DISMISS -> {
                manager.stop()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
        }

        showForegroundMediaNotification(manager)
        return START_STICKY
    }

    override fun onDestroy() {
        WaveZeroPlaybackSession.release()
        super.onDestroy()
    }

    private fun showForegroundMediaNotification(manager: AudioPlayerManager) {
        val snapshot = manager.metricsSnapshotMap()
        val isPlaying = snapshot["isPlaying"] as? Boolean ?: false
        val title = snapshot["trackTitle"] as? String ?: DemoTrack.title
        val playPauseLabel = if (isPlaying) "Pause" else "Play"
        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play

        val notification = Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText("WaveZero")
            .setOngoing(isPlaying)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .addAction(
                Notification.Action.Builder(
                    playPauseIcon,
                    playPauseLabel,
                    servicePendingIntent(ACTION_TOGGLE_PLAYBACK),
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Stop",
                    servicePendingIntent(ACTION_STOP_AND_DISMISS),
                ).build(),
            )
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun servicePendingIntent(action: String): PendingIntent {
        val intent = Intent(this, WaveZeroMediaSessionService::class.java).setAction(action)
        return PendingIntent.getService(
            this,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "WaveZero playback",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "WaveZero playback controls"
            setShowBadge(false)
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_SHOW_NOTIFICATION = "com.wavezero.player.playback.SHOW_NOTIFICATION"
        const val ACTION_TOGGLE_PLAYBACK = "com.wavezero.player.playback.TOGGLE_PLAYBACK"
        const val ACTION_STOP_AND_DISMISS = "com.wavezero.player.playback.STOP_AND_DISMISS"

        private const val NOTIFICATION_CHANNEL_ID = "wavezero_playback"
        private const val NOTIFICATION_ID = 4207
    }
}
