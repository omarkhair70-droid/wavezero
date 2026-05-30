package com.wavezero.flutter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import com.wavezero.player.playback.AudioPlayerManager
import com.wavezero.player.playback.WaveZeroPlaybackSession
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var appStartedAtMs: Long = 0L
    private var audioPlayerManager: AudioPlayerManager? = null

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
                context = applicationContext,
                audioPlayerManager = manager,
            ),
        )
    }

    override fun onDestroy() {
        audioPlayerManager = null
        super.onDestroy()
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
    }
}

class PlaybackMethodChannelHandler(
    private val context: Context,
    private val audioPlayerManager: AudioPlayerManager,
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

                "metricsSnapshot" -> result.success(audioPlayerManager.metricsSnapshotMap())

                else -> result.notImplemented()
            }
        } catch (error: IllegalArgumentException) {
            result.error("invalid_arguments", error.message, null)
        } catch (error: IllegalStateException) {
            result.error("playback_state_error", error.message, null)
        }
    }

    companion object {
        const val CHANNEL_NAME = "wavezero/playback"
    }
}
