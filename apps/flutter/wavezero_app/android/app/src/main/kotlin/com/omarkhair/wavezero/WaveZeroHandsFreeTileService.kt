package com.omarkhair.wavezero

import android.Manifest
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class WaveZeroHandsFreeTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        refreshTile()
    }

    override fun onClick() {
        super.onClick()
        if (WaveZeroVoiceService.isEnabled(this)) {
            WaveZeroVoiceService.stop(this)
            qsTile?.state = Tile.STATE_INACTIVE
            qsTile?.updateTile()
            return
        }

        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            WaveZeroVoiceService.start(this)
            qsTile?.state = Tile.STATE_ACTIVE
            qsTile?.updateTile()
            return
        }

        val permissionIntent = Intent(this, WaveZeroHandsFreePermissionActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pendingIntent = PendingIntent.getActivity(
                this,
                3,
                permissionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            startActivityAndCollapse(pendingIntent)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(permissionIntent)
        }
    }

    private fun refreshTile() {
        val enabled = WaveZeroVoiceService.isEnabled(this)
        qsTile?.apply {
            state = if (enabled) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            label = "WaveZero voice"
            subtitle = if (enabled) "Listening" else "Off"
            updateTile()
        }
    }
}
