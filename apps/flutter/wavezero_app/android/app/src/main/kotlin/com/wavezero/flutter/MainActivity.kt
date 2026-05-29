package com.wavezero.flutter

import android.os.Bundle
import android.os.SystemClock
import com.wavezero.player.playback.AudioPlayerManager
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
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val manager = AudioPlayerManager(
            context = applicationContext,
            appStartedAtMs = appStartedAtMs,
        )
        audioPlayerManager = manager
        manager.markScreenReady()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PlaybackMethodChannelHandler.CHANNEL_NAME,
        ).setMethodCallHandler(PlaybackMethodChannelHandler(manager))
    }

    override fun onDestroy() {
        audioPlayerManager?.release()
        audioPlayerManager = null
        super.onDestroy()
    }
}

class PlaybackMethodChannelHandler(
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

                "play" -> {
                    audioPlayerManager.play()
                    result.success(null)
                }

                "pause" -> {
                    audioPlayerManager.pause()
                    result.success(null)
                }

                "stop" -> {
                    audioPlayerManager.stop()
                    result.success(null)
                }

                "retry" -> {
                    audioPlayerManager.retry()
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
