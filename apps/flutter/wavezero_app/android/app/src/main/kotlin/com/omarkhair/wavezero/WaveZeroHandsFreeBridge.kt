package com.omarkhair.wavezero

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.MediaStore
import android.speech.SpeechRecognizer
import com.wavezero.player.playback.NotificationTrackSnapshot
import com.wavezero.player.playback.WaveZeroPlaybackSession
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object WaveZeroHandsFreeBridge {
    const val CHANNEL_NAME = "wavezero/handsfree"

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(status(context))
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (!enabled) {
                        WaveZeroVoiceService.stop(context)
                        result.success(status(context))
                        return@setMethodCallHandler
                    }
                    if (hasMicrophonePermission(context)) {
                        WaveZeroVoiceService.start(context)
                        result.success(status(context) + mapOf("startRequested" to true))
                    } else {
                        context.startActivity(
                            Intent(context, WaveZeroHandsFreePermissionActivity::class.java)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(status(context) + mapOf("permissionRequested" to true))
                    }
                }
                "requestPermission" -> {
                    context.startActivity(
                        Intent(context, WaveZeroHandsFreePermissionActivity::class.java)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(status(context) + mapOf("permissionRequested" to true))
                }
                "peekPendingAcquisition" -> result.success(pendingAcquisition(context, consume = false))
                "consumePendingAcquisition" -> result.success(pendingAcquisition(context, consume = true))
                "playBestLocalMatch" -> {
                    val query = call.argument<String>("query")?.trim().orEmpty()
                    if (query.isBlank()) {
                        result.error("invalid_arguments", "playBestLocalMatch requires query", null)
                        return@setMethodCallHandler
                    }
                    if (!hasDeviceAudioPermission(context)) {
                        result.success(
                            mapOf(
                                "played" to false,
                                "reason" to "device_audio_permission_missing",
                            ),
                        )
                        return@setMethodCallHandler
                    }
                    val match = findLocalTrack(context, query)
                    if (match == null) {
                        result.success(mapOf("played" to false, "reason" to "no_local_match"))
                        return@setMethodCallHandler
                    }
                    val player = WaveZeroPlaybackSession.getOrCreate(context.applicationContext)
                    player.loadTrack(match)
                    player.play()
                    WaveZeroPlaybackSession.showMediaControls(context)
                    result.success(
                        mapOf(
                            "played" to true,
                            "trackId" to match.trackId,
                            "title" to match.title,
                            "artist" to match.artistName,
                        ),
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun status(context: Context): Map<String, Any?> {
        val onDevice = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        return mapOf(
            "enabled" to WaveZeroVoiceService.isEnabled(context),
            "microphoneGranted" to hasMicrophonePermission(context),
            "recognitionAvailable" to SpeechRecognizer.isRecognitionAvailable(context),
            "onDeviceRecognitionAvailable" to onDevice,
            "pendingAcquisition" to pendingAcquisition(context, consume = false),
        )
    }

    private fun hasMicrophonePermission(context: Context): Boolean {
        return context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasDeviceAudioPermission(context: Context): Boolean {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        return context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun findLocalTrack(context: Context, query: String): NotificationTrackSnapshot? {
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

        context.contentResolver.query(
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

    private fun pendingAcquisition(context: Context, consume: Boolean): Map<String, Any?>? {
        val prefs = context.getSharedPreferences(ACQUISITION_PREFS, Context.MODE_PRIVATE)
        val query = prefs.getString(PENDING_ACQUISITION_QUERY, null)?.trim().orEmpty()
        if (query.isBlank()) return null
        val requestedAtMs = prefs.getLong(PENDING_ACQUISITION_AT_MS, 0L)
        val payload = mapOf<String, Any?>(
            "query" to query,
            "requestedAtMs" to requestedAtMs,
        )
        if (consume) {
            prefs.edit()
                .remove(PENDING_ACQUISITION_QUERY)
                .remove(PENDING_ACQUISITION_AT_MS)
                .apply()
        }
        return payload
    }

    private const val ACQUISITION_PREFS = "wavezero_voice_acquisition"
    private const val PENDING_ACQUISITION_QUERY = "pending_query"
    private const val PENDING_ACQUISITION_AT_MS = "pending_at_ms"
}
