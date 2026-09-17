package com.omarkhair.wavezero

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.MediaStore
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import com.wavezero.player.playback.NotificationTrackSnapshot
import com.wavezero.player.playback.WaveZeroPlaybackSession
import java.util.Locale

class WaveZeroVoiceService : Service(), RecognitionListener {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var listening = false
    private var destroyed = false
    private var armedForCommand = false
    private var lastTranscript: String? = null

    private val player by lazy { WaveZeroPlaybackSession.getOrCreate(applicationContext) }
    private val audioManager by lazy { getSystemService(Context.AUDIO_SERVICE) as AudioManager }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            stopSelf()
            return
        }
        recognizer = SpeechRecognizer.createSpeechRecognizer(this).also { it.setRecognitionListener(this) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                setEnabled(false)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START, null -> Unit
            else -> return START_NOT_STICKY
        }

        if (!hasRecordAudioPermission()) {
            setEnabled(false)
            stopSelf()
            return START_NOT_STICKY
        }

        setEnabled(true)
        startForeground(NOTIFICATION_ID, buildNotification("Listening for “Wave Zero”"))
        restartListening(100L)
        return START_STICKY
    }

    override fun onDestroy() {
        destroyed = true
        listening = false
        mainHandler.removeCallbacksAndMessages(null)
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        setEnabled(false)
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onReadyForSpeech(params: Bundle?) {
        listening = true
    }

    override fun onBeginningOfSpeech() = Unit
    override fun onRmsChanged(rmsdB: Float) = Unit
    override fun onBufferReceived(buffer: ByteArray?) = Unit
    override fun onEndOfSpeech() {
        listening = false
    }

    override fun onError(error: Int) {
        listening = false
        if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
            setEnabled(false)
            stopSelf()
            return
        }
        val delay = when (error) {
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> 1_200L
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> 1_500L
            else -> 450L
        }
        restartListening(delay)
    }

    override fun onResults(results: Bundle?) {
        listening = false
        val candidates = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            .orEmpty()
        val transcript = candidates.firstOrNull { it.isNotBlank() }
        if (transcript != null && transcript != lastTranscript) {
            lastTranscript = transcript
            handleTranscript(transcript)
        }
        restartListening(250L)
    }

    override fun onPartialResults(partialResults: Bundle?) = Unit
    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    private fun handleTranscript(raw: String) {
        val (containsWake, remainder) = WaveZeroVoiceCommandParser.splitWakePhrase(raw)
        if (containsWake) {
            if (remainder.isBlank()) {
                armedForCommand = true
                updateNotification("Yes — listening for your command")
                return
            }
            armedForCommand = false
            execute(WaveZeroVoiceCommandParser.parse(remainder))
            return
        }

        if (!armedForCommand) return
        armedForCommand = false
        execute(WaveZeroVoiceCommandParser.parse(raw))
    }

    private fun execute(command: WaveZeroVoiceCommand) {
        when (command) {
            WaveZeroVoiceCommand.Play -> {
                player.play()
                WaveZeroPlaybackSession.showMediaControls(this)
                feedback("Playing")
            }
            WaveZeroVoiceCommand.Pause -> {
                player.pause()
                WaveZeroPlaybackSession.showMediaControls(this)
                feedback("Paused")
            }
            WaveZeroVoiceCommand.Next -> {
                val moved = player.playNextFromNotification()
                if (moved) WaveZeroPlaybackSession.showMediaControls(this)
                feedback(if (moved) "Next track" else "No next track in the current queue")
            }
            WaveZeroVoiceCommand.Previous -> {
                val moved = player.playPreviousFromNotification()
                if (moved) WaveZeroPlaybackSession.showMediaControls(this)
                feedback(if (moved) "Previous track" else "No previous track in the current queue")
            }
            WaveZeroVoiceCommand.VolumeUp -> {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, 0)
                feedback("Volume up")
            }
            WaveZeroVoiceCommand.VolumeDown -> {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, 0)
                feedback("Volume down")
            }
            is WaveZeroVoiceCommand.SeekBy -> {
                val currentMs = (player.metricsSnapshotMap()["currentPositionMs"] as? Number)?.toLong() ?: 0L
                player.seekTo((currentMs + command.deltaMs).coerceAtLeast(0L))
                val seconds = kotlin.math.abs(command.deltaMs / 1000L)
                feedback(if (command.deltaMs < 0) "Back $seconds seconds" else "Forward $seconds seconds")
            }
            is WaveZeroVoiceCommand.PlayLocalTrack -> {
                val match = findLocalTrack(command.query)
                if (match == null) {
                    feedback("Not found on this device: ${command.query}")
                } else {
                    player.loadTrack(match)
                    player.play()
                    WaveZeroPlaybackSession.showMediaControls(this)
                    feedback("Playing ${match.title}")
                }
            }
            is WaveZeroVoiceCommand.Unknown -> feedback("I didn't catch that command")
        }
    }

    private fun findLocalTrack(query: String): NotificationTrackSnapshot? {
        if (!hasDeviceAudioPermission()) return null
        val normalizedQuery = WaveZeroVoiceCommandParser.normalize(query)
        if (normalizedQuery.isBlank()) return null

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
        )
        var best: NotificationTrackSnapshot? = null
        var bestScore = 0

        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            "${MediaStore.Audio.Media.IS_MUSIC} != 0",
            null,
            null,
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val title = cursor.getString(titleColumn).orEmpty()
                val artist = cursor.getString(artistColumn).orEmpty()
                val album = cursor.getString(albumColumn)
                val duration = cursor.getLong(durationColumn).takeIf { it > 0L }
                val score = scoreTrack(normalizedQuery, title, artist)
                if (score <= bestScore) continue

                val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                bestScore = score
                best = NotificationTrackSnapshot(
                    trackId = "device:$id",
                    title = title.ifBlank { "Device track" },
                    artistName = artist.takeIf { it.isNotBlank() && it != "<unknown>" },
                    albumName = album,
                    url = uri.toString(),
                    durationMs = duration,
                    source = NotificationTrackSnapshot.SOURCE_DEVICE,
                )
            }
        }
        return best?.takeIf { bestScore >= 45 }
    }

    private fun scoreTrack(query: String, title: String, artist: String): Int {
        val normalizedTitle = WaveZeroVoiceCommandParser.normalize(title)
        val normalizedArtist = WaveZeroVoiceCommandParser.normalize(artist)
        if (normalizedTitle == query) return 120
        var score = 0
        if (normalizedTitle.startsWith(query)) score += 90
        else if (normalizedTitle.contains(query)) score += 70
        if (normalizedArtist == query) score += 55
        else if (normalizedArtist.contains(query)) score += 30

        val queryTokens = query.split(' ').filter { it.length > 1 }.toSet()
        val candidateTokens = "$normalizedTitle $normalizedArtist".split(' ').toSet()
        score += queryTokens.count(candidateTokens::contains) * 12
        return score
    }

    private fun restartListening(delayMs: Long) {
        if (destroyed || !hasRecordAudioPermission()) return
        mainHandler.removeCallbacks(restartRunnable)
        mainHandler.postDelayed(restartRunnable, delayMs)
    }

    private val restartRunnable = Runnable {
        if (destroyed || listening) return@Runnable
        val speechRecognizer = recognizer ?: return@Runnable
        runCatching {
            speechRecognizer.startListening(
                Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale("ar", "EG").toLanguageTag())
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, Locale("ar", "EG").toLanguageTag())
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                },
            )
            listening = true
        }.onFailure {
            listening = false
            if (!destroyed) restartListening(1_000L)
        }
    }

    private fun feedback(message: String) {
        updateNotification(message)
        mainHandler.postDelayed({
            if (!destroyed) updateNotification("Listening for “Wave Zero”")
        }, 2_000L)
    }

    private fun updateNotification(message: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(message))
    }

    private fun buildNotification(message: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, WaveZeroVoiceService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("WaveZero hands-free")
            .setContentText(message)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .addAction(Notification.Action.Builder(null, "Stop", stopIntent).build())
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "WaveZero hands-free",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps WaveZero ready for local voice playback commands."
                setShowBadge(false)
            },
        )
    }

    private fun hasRecordAudioPermission(): Boolean {
        return checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasDeviceAudioPermission(): Boolean {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        return checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun setEnabled(enabled: Boolean) {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(PREF_ENABLED, enabled)
            .apply()
    }

    companion object {
        const val ACTION_START = "com.omarkhair.wavezero.handsfree.START"
        const val ACTION_STOP = "com.omarkhair.wavezero.handsfree.STOP"
        private const val CHANNEL_ID = "wavezero_handsfree"
        private const val NOTIFICATION_ID = 7202
        private const val PREFS = "wavezero_handsfree"
        private const val PREF_ENABLED = "enabled"

        fun isEnabled(context: Context): Boolean {
            return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(PREF_ENABLED, false)
        }

        fun start(context: Context) {
            val intent = Intent(context, WaveZeroVoiceService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.startService(Intent(context, WaveZeroVoiceService::class.java).setAction(ACTION_STOP))
        }
    }
}
