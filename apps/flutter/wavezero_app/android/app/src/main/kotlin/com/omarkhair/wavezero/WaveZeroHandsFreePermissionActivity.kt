package com.omarkhair.wavezero

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Bundle

class WaveZeroHandsFreePermissionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            WaveZeroVoiceService.start(this)
            finish()
            return
        }
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_RECORD_AUDIO)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (
            requestCode == REQUEST_RECORD_AUDIO &&
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        ) {
            WaveZeroVoiceService.start(this)
        }
        finish()
    }

    private companion object {
        const val REQUEST_RECORD_AUDIO = 7201
    }
}
