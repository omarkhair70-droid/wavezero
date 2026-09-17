package com.omarkhair.wavezero

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.speech.SpeechRecognizer
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
