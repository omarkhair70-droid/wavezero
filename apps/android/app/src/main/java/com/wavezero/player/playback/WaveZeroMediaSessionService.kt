package com.wavezero.player.playback

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.annotation.OptIn
import androidx.media3.common.Player
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
            ACTION_PREVIOUS -> skipPlayback(manager, manager::playPreviousFromNotification)
            ACTION_TOGGLE_PLAYBACK -> togglePlayback(manager)
            ACTION_NEXT -> skipPlayback(manager, manager::playNextFromNotification)
            ACTION_STOP_AND_DISMISS -> {
                manager.stop()
                manager.markMediaNotificationDismissed()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
        }

        showForegroundMediaNotification(manager)
        return START_STICKY
    }

    private fun togglePlayback(manager: AudioPlayerManager) {
        if (playbackRequested(manager)) {
            manager.pause()
        } else {
            manager.play()
        }
    }

    private fun skipPlayback(
        manager: AudioPlayerManager,
        skip: () -> Boolean,
    ) {
        val shouldResume = playbackRequested(manager)
        val changedTrack = skip()
        if (changedTrack && !shouldResume) {
            manager.pause()
        }
    }

    private fun playbackRequested(manager: AudioPlayerManager): Boolean {
        val sessionPlayer = manager.mediaSession?.player ?: return false
        return sessionPlayer.playbackState != Player.STATE_ENDED &&
            (sessionPlayer.isPlaying || sessionPlayer.playWhenReady)
    }

    private fun showForegroundMediaNotification(manager: AudioPlayerManager) {
        val snapshot = manager.metricsSnapshotMap()
        val isPlaying = playbackRequested(manager)
        val title = snapshot["currentTrackTitle"] as? String ?: snapshot["trackTitle"] as? String ?: DemoTrack.title
        val subtitle = snapshot["currentTrackArtist"] as? String ?: snapshot["currentTrackSource"] as? String ?: "WaveZero"
        val playPauseLabel = if (isPlaying) "Pause" else "Play"
        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play

        val notification = Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setSubText(snapshot["currentTrackAlbum"] as? String)
            .setOngoing(isPlaying)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_previous,
                    "Previous",
                    servicePendingIntent(ACTION_PREVIOUS),
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    playPauseIcon,
                    playPauseLabel,
                    servicePendingIntent(ACTION_TOGGLE_PLAYBACK),
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_next,
                    "Next",
                    servicePendingIntent(ACTION_NEXT),
                ).build(),
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Stop",
                    servicePendingIntent(ACTION_STOP_AND_DISMISS),
                ).build(),
            )
            .setStyle(Notification.MediaStyle().setShowActionsInCompactView(0, 1, 2))
            .build()

        manager.markMediaNotificationShown()

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
        const val ACTION_PREVIOUS = "com.wavezero.player.playback.PREVIOUS"
        const val ACTION_TOGGLE_PLAYBACK = "com.wavezero.player.playback.TOGGLE_PLAYBACK"
        const val ACTION_NEXT = "com.wavezero.player.playback.NEXT"
        const val ACTION_STOP_AND_DISMISS = "com.wavezero.player.playback.STOP_AND_DISMISS"

        private const val NOTIFICATION_CHANNEL_ID = "wavezero_playback"
        private const val NOTIFICATION_ID = 4207
    }
}
