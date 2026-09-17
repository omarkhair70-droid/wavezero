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
    private var recognitionAvailable = true
    private var duckOriginalVolume: Int? = null
    private var activeLoopStartMs: Long? = null
    private var activeLoopEndMs: Long? = null
    private var activeLoopTrackKey: String? = null

    private val player by lazy { WaveZeroPlaybackSession.getOrCreate(applicationContext) }
    private val audioManager by lazy { getSystemService(Context.AUDIO_SERVICE) as AudioManager }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        recognitionAvailable = SpeechRecognizer.isRecognitionAvailable(this)
        if (!recognitionAvailable) return
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

        if (!hasRecordAudioPermission() || !recognitionAvailable) {
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
        armedForCommand = false
        cancelActiveLoop(silent = true)
        restoreListeningDuck()
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
            restoreListeningDuck()
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
            beginListeningDuck()
            if (remainder.isBlank()) {
                armedForCommand = true
                mainHandler.removeCallbacks(commandTimeoutRunnable)
                mainHandler.postDelayed(commandTimeoutRunnable, COMMAND_WINDOW_MS)
                updateNotification("Yes — listening for your command")
                return
            }
            armedForCommand = false
            mainHandler.removeCallbacks(commandTimeoutRunnable)
            restoreListeningDuck()
            execute(WaveZeroVoiceCommandParser.parse(remainder))
            return
        }

        if (!armedForCommand) return
        armedForCommand = false
        mainHandler.removeCallbacks(commandTimeoutRunnable)
        restoreListeningDuck()
        execute(WaveZeroVoiceCommandParser.parse(raw))
    }

    private val commandTimeoutRunnable = Runnable {
        if (!armedForCommand || destroyed) return@Runnable
        armedForCommand = false
        restoreListeningDuck()
        updateNotification("Listening for “Wave Zero”")
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
                cancelActiveLoop(silent = true)
                val moved = player.playNextFromNotification()
                if (moved) WaveZeroPlaybackSession.showMediaControls(this)
                feedback(if (moved) "Next track" else "No next track in the current queue")
            }
            WaveZeroVoiceCommand.Previous -> {
                cancelActiveLoop(silent = true)
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
            WaveZeroVoiceCommand.StopLoop -> cancelActiveLoop(silent = false)
            is WaveZeroVoiceCommand.SeekBy -> {
                val currentMs = currentPositionMs()
                player.seekTo((currentMs + command.deltaMs).coerceAtLeast(0L))
                val seconds = kotlin.math.abs(command.deltaMs / 1000L)
                feedback(if (command.deltaMs < 0) "Back $seconds seconds" else "Forward $seconds seconds")
            }
            is WaveZeroVoiceCommand.PlayLocalTrack -> {
                cancelActiveLoop(silent = true)
                val match = findLocalTrack(command.query)
                if (match == null) {
                    queueWebAcquisition(command.query)
                    feedback("Not on this device — queued for WaveZero Web: ${command.query}")
                } else {
                    player.loadTrack(match)
                    player.play()
                    WaveZeroPlaybackSession.showMediaControls(this)
                    feedback("Playing ${match.title}")
                }
            }
            is WaveZeroVoiceCommand.SaveMoment -> saveMoment(command.name)
            is WaveZeroVoiceCommand.GoToMoment -> goToMoment(command.name)
            is WaveZeroVoiceCommand.LoopFromHere -> startLoopFromHere(command.durationMs)
            is WaveZeroVoiceCommand.Unknown -> feedback("I didn't catch that command")
        }
    }

    private fun beginListeningDuck() {
        if (duckOriginalVolume != null) return
        val current = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        duckOriginalVolume = current
        if (current <= 1) return
        val target = (current * LISTENING_DUCK_PERCENT / 100).coerceAtLeast(1)
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
    }

    private fun restoreListeningDuck() {
        val original = duckOriginalVolume ?: return
        duckOriginalVolume = null
        val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, original.coerceIn(0, max), 0)
    }

    private fun saveMoment(name: String) {
        val metrics = player.metricsSnapshotMap()
        val trackKey = trackIdentity(metrics)
        if (trackKey == null) {
            feedback("No active track to save a moment for")
            return
        }
        val positionMs = (metrics["currentPositionMs"] as? Number)?.toLong()?.coerceAtLeast(0L) ?: 0L
        momentsPrefs().edit()
            .putLong(momentPreferenceKey(trackKey, name), positionMs)
            .apply()
        feedback("Saved ${name.trim()} at ${formatPosition(positionMs)}")
    }

    private fun goToMoment(name: String) {
        val metrics = player.metricsSnapshotMap()
        val trackKey = trackIdentity(metrics)
        if (trackKey == null) {
            feedback("No active track")
            return
        }
        val key = momentPreferenceKey(trackKey, name)
        if (!momentsPrefs().contains(key)) {
            feedback("I don't have a saved moment called ${name.trim()} for this track")
            return
        }
        val positionMs = momentsPrefs().getLong(key, 0L).coerceAtLeast(0L)
        player.seekTo(positionMs)
        feedback("Back to ${name.trim()}")
    }

    private fun startLoopFromHere(durationMs: Long) {
        val metrics = player.metricsSnapshotMap()
        val trackKey = trackIdentity(metrics)
        if (trackKey == null) {
            feedback("No active track to loop")
            return
        }
        val startMs = (metrics["currentPositionMs"] as? Number)?.toLong()?.coerceAtLeast(0L) ?: 0L
        val durationLimit = (metrics["durationMs"] as? Number)?.toLong()?.takeIf { it > 0L }
        val requestedEnd = startMs + durationMs.coerceIn(3_000L, 120_000L)
        val endMs = durationLimit?.let { requestedEnd.coerceAtMost(it) } ?: requestedEnd
        if (endMs - startMs < 1_000L) {
            feedback("There isn't enough track left to loop from here")
            return
        }

        activeLoopStartMs = startMs
        activeLoopEndMs = endMs
        activeLoopTrackKey = trackKey
        mainHandler.removeCallbacks(loopRunnable)
        mainHandler.post(loopRunnable)
        feedback("Looping ${((endMs - startMs) / 1000L).coerceAtLeast(1L)} seconds from here")
    }

    private val loopRunnable = object : Runnable {
        override fun run() {
            if (destroyed) return
            val startMs = activeLoopStartMs ?: return
            val endMs = activeLoopEndMs ?: return
            val expectedTrack = activeLoopTrackKey ?: return
            val metrics = player.metricsSnapshotMap()
            if (trackIdentity(metrics) != expectedTrack) {
                cancelActiveLoop(silent = true)
                return
            }
            val positionMs = (metrics["currentPositionMs"] as? Number)?.toLong() ?: return
            if (positionMs >= endMs - LOOP_REWIND_GUARD_MS) {
                player.seekTo(startMs)
            }
            mainHandler.postDelayed(this, LOOP_POLL_MS)
        }
    }

    private fun cancelActiveLoop(silent: Boolean) {
        val wasActive = activeLoopStartMs != null
        activeLoopStartMs = null
        activeLoopEndMs = null
        activeLoopTrackKey = null
        mainHandler.removeCallbacks(loopRunnable)
        if (!silent) feedback(if (wasActive) "Loop stopped" else "No loop is active")
    }

    private fun currentPositionMs(): Long {
        return (player.metricsSnapshotMap()["currentPositionMs"] as? Number)?.toLong()?.coerceAtLeast(0L) ?: 0L
    }

    private fun trackIdentity(metrics: Map<String, Any?>): String? {
        val id = metrics["currentTrackId"]?.toString()?.takeIf { it.isNotBlank() }
        val url = metrics["currentTrackUrl"]?.toString()?.takeIf { it.isNotBlank() }
        val title = metrics["currentTrackTitle"]?.toString()?.takeIf { it.isNotBlank() }
        return id ?: url ?: title
    }

    private fun momentPreferenceKey(trackKey: String, name: String): String {
        val normalizedName = WaveZeroVoiceCommandParser.normalize(name).ifBlank { "moment" }
        return "moment.${trackKey.hashCode()}.$normalizedName"
    }

    private fun momentsPrefs() = getSharedPreferences(MOMENTS_PREFS, Context.MODE_PRIVATE)

    private fun queueWebAcquisition(query: String) {
        getSharedPreferences(ACQUISITION_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(PENDING_ACQUISITION_QUERY, query.trim())
            .putLong(PENDING_ACQUISITION_AT_MS, System.currentTimeMillis())
            .apply()
    }

    private fun formatPosition(positionMs: Long): String {
        val totalSeconds = (positionMs / 1000L).coerceAtLeast(0L)
        return "%d:%02d".format(totalSeconds / 60L, totalSeconds % 60L)
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
            if (!destroyed && !armedForCommand) updateNotification("Listening for “Wave Zero”")
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
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_pause, "Stop", stopIntent).build())
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
        private const val MOMENTS_PREFS = "wavezero_voice_moments"
        private const val ACQUISITION_PREFS = "wavezero_voice_acquisition"
        private const val PENDING_ACQUISITION_QUERY = "pending_query"
        private const val PENDING_ACQUISITION_AT_MS = "pending_at_ms"
        private const val COMMAND_WINDOW_MS = 7_000L
        private const val LISTENING_DUCK_PERCENT = 18
        private const val LOOP_POLL_MS = 120L
        private const val LOOP_REWIND_GUARD_MS = 100L

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
            context.stopService(Intent(context, WaveZeroVoiceService::class.java))
        }
    }
}
