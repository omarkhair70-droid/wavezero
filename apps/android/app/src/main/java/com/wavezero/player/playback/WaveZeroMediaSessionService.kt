package com.wavezero.player.playback

import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

@OptIn(UnstableApi::class)
class WaveZeroMediaSessionService : MediaSessionService() {
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return WaveZeroPlaybackSession.getOrCreate(applicationContext).mediaSession
    }

    override fun onDestroy() {
        WaveZeroPlaybackSession.release()
        super.onDestroy()
    }
}
