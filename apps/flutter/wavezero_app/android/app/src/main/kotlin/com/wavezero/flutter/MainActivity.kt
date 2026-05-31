package com.wavezero.flutter

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.MediaStore
import com.wavezero.player.playback.AudioPlayerManager
import com.wavezero.player.playback.WaveZeroPlaybackSession
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val DEVICE_MUSIC_PERMISSION_PREFS = "wavezero.device_music"
private const val DEVICE_MUSIC_PERMISSION_REQUESTED_KEY = "wavezero.device_music_permission_requested"

class MainActivity : FlutterActivity() {
    private var appStartedAtMs: Long = 0L
    private var audioPlayerManager: AudioPlayerManager? = null
    private var pendingDeviceMusicPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        appStartedAtMs = SystemClock.elapsedRealtime()
        super.onCreate(savedInstanceState)
        requestPostNotificationsIfNeeded()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val manager = WaveZeroPlaybackSession.getOrCreate(
            context = applicationContext,
            appStartedAtMs = appStartedAtMs,
        )
        audioPlayerManager = manager
        manager.markScreenReady()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlaybackMethodChannelHandler.CHANNEL_NAME,
        ).setMethodCallHandler(
            PlaybackMethodChannelHandler(
                activity = this,
                context = applicationContext,
                audioPlayerManager = manager,
                permissionRequester = ::requestDeviceMusicPermissionForResult,
            ),
        )
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_DEVICE_MUSIC_PERMISSION) return
        val result = pendingDeviceMusicPermissionResult ?: return
        pendingDeviceMusicPermissionResult = null
        result.success(deviceMusicPermissionStatusMap())
    }

    override fun onDestroy() {
        pendingDeviceMusicPermissionResult?.success(deviceMusicPermissionStatusMap(message = "Permission request was cancelled."))
        pendingDeviceMusicPermissionResult = null
        audioPlayerManager = null
        super.onDestroy()
    }

    private fun requestDeviceMusicPermissionForResult(result: MethodChannel.Result) {
        if (hasDeviceMusicPermission()) {
            result.success(deviceMusicPermissionStatusMap())
            return
        }
        if (pendingDeviceMusicPermissionResult != null) {
            result.success(deviceMusicPermissionStatusMap(status = "requesting", message = "A device music permission request is already active."))
            return
        }
        pendingDeviceMusicPermissionResult = result
        getSharedPreferences(DEVICE_MUSIC_PERMISSION_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(DEVICE_MUSIC_PERMISSION_REQUESTED_KEY, true)
            .apply()
        requestPermissions(arrayOf(deviceMusicPermissionName()), REQUEST_DEVICE_MUSIC_PERMISSION)
    }

    private fun hasDeviceMusicPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return checkSelfPermission(deviceMusicPermissionName()) == PackageManager.PERMISSION_GRANTED
    }

    private fun deviceMusicPermissionStatusMap(status: String? = null, message: String? = null): Map<String, Any?> {
        val permission = deviceMusicPermissionName()
        val granted = hasDeviceMusicPermission()
        val wasRequested = getSharedPreferences(DEVICE_MUSIC_PERMISSION_PREFS, Context.MODE_PRIVATE)
            .getBoolean(DEVICE_MUSIC_PERMISSION_REQUESTED_KEY, false)
        val resolvedStatus = status ?: if (granted) {
            "granted"
        } else if (wasRequested && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !shouldShowRequestPermissionRationale(permission)) {
            "denied_permanently"
        } else {
            "denied"
        }
        return mapOf(
            "status" to resolvedStatus,
            "permission" to permission,
            "permanentlyDenied" to (resolvedStatus == "denied_permanently"),
            "platformSupported" to true,
            "message" to message,
        )
    }

    private fun deviceMusicPermissionName(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
    }

    private fun requestPostNotificationsIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return

        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_POST_NOTIFICATIONS,
        )
    }

    private companion object {
        const val REQUEST_POST_NOTIFICATIONS = 3001
        const val REQUEST_DEVICE_MUSIC_PERMISSION = 3002
    }
}

class PlaybackMethodChannelHandler(
    private val activity: MainActivity,
    private val context: Context,
    private val audioPlayerManager: AudioPlayerManager,
    private val permissionRequester: (MethodChannel.Result) -> Unit,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "loadTrack" -> {
                    val title = call.argument<String>("title").orEmpty()
                    val url = call.argument<String>("url").orEmpty()
                    if (url.isBlank()) {
                        result.error("invalid_arguments", "loadTrack requires a non-empty url", null)
                        return
                    }
                    audioPlayerManager.loadTrack(title = title, hlsUrl = url)
                    result.success(null)
                }

                "prepareNextTrack" -> {
                    val trackId = call.argument<String>("trackId").orEmpty()
                    val title = call.argument<String>("title").orEmpty()
                    val url = call.argument<String>("url").orEmpty()
                    if (trackId.isBlank() || url.isBlank()) {
                        result.error("invalid_arguments", "prepareNextTrack requires non-empty trackId and url", null)
                        return
                    }
                    audioPlayerManager.prepareNextTrack(trackId = trackId, title = title, hlsUrl = url)
                    result.success(null)
                }

                "clearNextTrackPrebuffer" -> {
                    audioPlayerManager.clearNextTrackPrebuffer()
                    result.success(null)
                }

                "playPreparedNextTrackIfReady" -> {
                    val trackId = call.argument<String>("trackId").orEmpty()
                    val title = call.argument<String>("title").orEmpty()
                    val url = call.argument<String>("url").orEmpty()
                    if (trackId.isBlank() || url.isBlank()) {
                        result.error("invalid_arguments", "playPreparedNextTrackIfReady requires non-empty trackId and url", null)
                        return
                    }
                    val usedPreparedPath = audioPlayerManager.playPreparedNextTrackIfReady(
                        trackId = trackId,
                        title = title,
                        hlsUrl = url,
                    )
                    if (usedPreparedPath) WaveZeroPlaybackSession.showMediaControls(context)
                    result.success(usedPreparedPath)
                }

                "playPreparedAutoAdvanceTrackIfReady" -> {
                    val trackId = call.argument<String>("trackId").orEmpty()
                    val title = call.argument<String>("title").orEmpty()
                    val url = call.argument<String>("url").orEmpty()
                    if (trackId.isBlank() || url.isBlank()) {
                        result.error("invalid_arguments", "playPreparedAutoAdvanceTrackIfReady requires non-empty trackId and url", null)
                        return
                    }
                    val usedPreparedPath = audioPlayerManager.playPreparedAutoAdvanceTrackIfReady(
                        trackId = trackId,
                        title = title,
                        hlsUrl = url,
                    )
                    if (usedPreparedPath) WaveZeroPlaybackSession.showMediaControls(context)
                    result.success(usedPreparedPath)
                }

                "recordNextTrackPrebufferOutcome" -> {
                    val trackId = call.argument<String>("trackId").orEmpty()
                    val usedPreparedPath = call.argument<Boolean>("usedPreparedPath") ?: false
                    if (trackId.isBlank()) {
                        result.error("invalid_arguments", "recordNextTrackPrebufferOutcome requires trackId", null)
                        return
                    }
                    audioPlayerManager.recordNextTrackPrebufferOutcome(
                        trackId = trackId,
                        usedPreparedPath = usedPreparedPath,
                    )
                    result.success(null)
                }

                "recordAutoAdvancePreparedFallback" -> {
                    val trackId = call.argument<String>("trackId").orEmpty()
                    if (trackId.isBlank()) {
                        result.error("invalid_arguments", "recordAutoAdvancePreparedFallback requires trackId", null)
                        return
                    }
                    audioPlayerManager.recordAutoAdvancePreparedFallback(trackId = trackId)
                    result.success(null)
                }

                "play" -> {
                    audioPlayerManager.play()
                    WaveZeroPlaybackSession.showMediaControls(context)
                    result.success(null)
                }

                "pause" -> {
                    audioPlayerManager.pause()
                    WaveZeroPlaybackSession.showMediaControls(context)
                    result.success(null)
                }

                "stop" -> {
                    audioPlayerManager.stop()
                    WaveZeroPlaybackSession.showMediaControls(context)
                    result.success(null)
                }

                "retry" -> {
                    audioPlayerManager.retry()
                    WaveZeroPlaybackSession.showMediaControls(context)
                    result.success(null)
                }

                "seekTo" -> {
                    val positionMs = call.argument<Number>("positionMs")?.toLong()
                    if (positionMs == null) {
                        result.error("invalid_arguments", "seekTo requires positionMs", null)
                        return
                    }
                    audioPlayerManager.seekTo(positionMs)
                    result.success(null)
                }

                "resetMetrics" -> {
                    audioPlayerManager.resetMetrics()
                    result.success(null)
                }

                "setAudioEffectProfile" -> {
                    val profileId = call.argument<String>("id").orEmpty()
                    if (profileId == "off") {
                        result.success(
                            mapOf(
                                "status" to "off",
                                "message" to "Audio effects are off; native playback remains original/no-effect.",
                            ),
                        )
                        return
                    }

                    result.success(
                        mapOf(
                            "status" to "unsupported",
                            "message" to "Native Android DSP is not enabled in this safe foundation build; profile ${profileId.ifBlank { "unknown" }} is stored for diagnostics only.",
                        ),
                    )
                }

                "metricsSnapshot" -> result.success(audioPlayerManager.metricsSnapshotMap())

                "getDeviceMusicPermissionStatus" -> result.success(deviceMusicPermissionStatusMap())

                "requestDeviceMusicPermission" -> permissionRequester(result)

                "scanDeviceAudioLibrary" -> scanDeviceAudioLibrary(result)

                else -> result.notImplemented()
            }
        } catch (error: IllegalArgumentException) {
            result.error("invalid_arguments", error.message, null)
        } catch (error: IllegalStateException) {
            result.error("playback_state_error", error.message, null)
        }
    }


    private fun hasDeviceMusicPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return activity.checkSelfPermission(deviceMusicPermissionName()) == PackageManager.PERMISSION_GRANTED
    }

    private fun deviceMusicPermissionName(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
    }

    private fun deviceMusicPermissionStatusMap(): Map<String, Any?> {
        val permission = deviceMusicPermissionName()
        val granted = hasDeviceMusicPermission()
        val wasRequested = context.getSharedPreferences(DEVICE_MUSIC_PERMISSION_PREFS, Context.MODE_PRIVATE)
            .getBoolean(DEVICE_MUSIC_PERMISSION_REQUESTED_KEY, false)
        val status = if (granted) {
            "granted"
        } else if (wasRequested && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !activity.shouldShowRequestPermissionRationale(permission)) {
            "denied_permanently"
        } else {
            "denied"
        }
        return mapOf(
            "status" to status,
            "permission" to permission,
            "permanentlyDenied" to (status == "denied_permanently"),
            "platformSupported" to true,
        )
    }

    private fun scanDeviceAudioLibrary(result: MethodChannel.Result) {
        if (!hasDeviceMusicPermission()) {
            result.success(
                mapOf(
                    "status" to "permission_denied",
                    "tracks" to emptyList<Map<String, Any?>>(),
                    "count" to 0,
                    "limit" to DEVICE_AUDIO_SCAN_LIMIT,
                    "error" to "Audio permission is required before scanning the Android MediaStore.",
                    "platformSupported" to true,
                ),
            )
            return
        }

        Thread {
            try {
                val tracks = queryDeviceAudioLibrary()
                activity.runOnUiThread {
                    result.success(
                        mapOf(
                            "status" to "success",
                            "tracks" to tracks,
                            "count" to tracks.size,
                            "limit" to DEVICE_AUDIO_SCAN_LIMIT,
                            "scannedAtMs" to System.currentTimeMillis(),
                            "platformSupported" to true,
                        ),
                    )
                }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.success(
                        mapOf(
                            "status" to "error",
                            "tracks" to emptyList<Map<String, Any?>>(),
                            "count" to 0,
                            "limit" to DEVICE_AUDIO_SCAN_LIMIT,
                            "error" to (error.message ?: error.javaClass.simpleName),
                            "platformSupported" to true,
                        ),
                    )
                }
            }
        }.start()
    }

    private fun queryDeviceAudioLibrary(): List<Map<String, Any?>> {
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.IS_MUSIC,
            MediaStore.Audio.Media.ALBUM_ID,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            projection += MediaStore.Audio.Media.BITRATE
        }
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.DURATION} >= ?"
        val selectionArgs = arrayOf(MIN_DEVICE_AUDIO_DURATION_MS.toString())
        val sortOrder = "${MediaStore.Audio.Media.DATE_ADDED} DESC, ${MediaStore.Audio.Media.TITLE} ASC"
        val tracks = mutableListOf<Map<String, Any?>>()
        context.contentResolver.query(collection, projection.toTypedArray(), selection, selectionArgs, sortOrder)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleColumn = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
            val artistColumn = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
            val albumColumn = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
            val durationColumn = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
            val sizeColumn = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
            val mimeColumn = cursor.getColumnIndex(MediaStore.Audio.Media.MIME_TYPE)
            val dateAddedColumn = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)
            val dateModifiedColumn = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_MODIFIED)
            val displayNameColumn = cursor.getColumnIndex(MediaStore.Audio.Media.DISPLAY_NAME)
            val albumIdColumn = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)
            val bitrateColumn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) cursor.getColumnIndex(MediaStore.Audio.Media.BITRATE) else -1
            while (cursor.moveToNext() && tracks.size < DEVICE_AUDIO_SCAN_LIMIT) {
                val id = cursor.getLong(idColumn)
                val contentUri = ContentUris.withAppendedId(collection, id).toString()
                val displayName = cursor.stringOrNull(displayNameColumn)
                val title = cursor.stringOrNull(titleColumn)?.takeUnless { it == MediaStore.UNKNOWN_STRING }
                    ?: displayName
                    ?: "Device audio $id"
                val mimeType = cursor.stringOrNull(mimeColumn)
                val codec = inferCodec(mimeType, displayName)
                val bitrateKbps = cursor.longOrNull(bitrateColumn)?.takeIf { it > 0 }?.let { (it / 1000L).toInt() }
                val albumId = cursor.longOrNull(albumIdColumn)?.takeIf { it > 0 }
                tracks += mapOf(
                    "trackId" to "device-audio-$id",
                    "title" to title,
                    "artistName" to cursor.stringOrNull(artistColumn)?.takeUnless { it == MediaStore.UNKNOWN_STRING },
                    "albumName" to cursor.stringOrNull(albumColumn)?.takeUnless { it == MediaStore.UNKNOWN_STRING },
                    "durationMs" to cursor.longOrNull(durationColumn),
                    "sizeBytes" to cursor.longOrNull(sizeColumn),
                    "mimeType" to mimeType,
                    "contentUri" to contentUri,
                    "dateAdded" to cursor.longOrNull(dateAddedColumn),
                    "dateModified" to cursor.longOrNull(dateModifiedColumn),
                    "displayName" to displayName,
                    "source" to "device",
                    "qualityLabel" to inferQualityLabel(mimeType, displayName, bitrateKbps),
                    "codec" to codec,
                    "bitrateKbps" to bitrateKbps,
                    "artworkUri" to albumId?.let { Uri.parse("content://media/external/audio/albumart").buildUpon().appendPath(it.toString()).build().toString() },
                )
            }
        }
        return tracks
    }

    private fun android.database.Cursor.stringOrNull(column: Int): String? {
        if (column < 0 || isNull(column)) return null
        return getString(column)
    }

    private fun android.database.Cursor.longOrNull(column: Int): Long? {
        if (column < 0 || isNull(column)) return null
        return getLong(column)
    }

    private fun inferCodec(mimeType: String?, displayName: String?): String? {
        val value = (mimeType ?: displayName?.substringAfterLast('.', missingDelimiterValue = ""))?.lowercase()?.trim()
        return when {
            value.isNullOrEmpty() -> null
            value.contains("flac") -> "flac"
            value.contains("wav") || value.contains("wave") -> "wav"
            value.contains("mpeg") || value == "mp3" || value.endsWith(".mp3") -> "mp3"
            value.contains("aac") -> "aac"
            value.contains("mp4") || value == "m4a" || value.endsWith(".m4a") -> "m4a"
            value.contains("ogg") -> "ogg"
            else -> value.substringAfterLast('/').substringBefore(';')
        }
    }

    private fun inferQualityLabel(mimeType: String?, displayName: String?, bitrateKbps: Int?): String {
        val codec = inferCodec(mimeType, displayName) ?: return "unknown"
        return when {
            codec in setOf("flac", "wav") -> "original"
            codec in setOf("mp3", "m4a", "aac") && (bitrateKbps ?: 0) >= 256 -> "high"
            codec in setOf("mp3", "m4a", "aac", "ogg") -> "standard"
            else -> "unknown"
        }
    }

    companion object {
        const val CHANNEL_NAME = "wavezero/playback"
        private const val DEVICE_AUDIO_SCAN_LIMIT = 500
        private const val MIN_DEVICE_AUDIO_DURATION_MS = 30_000L
    }
}
