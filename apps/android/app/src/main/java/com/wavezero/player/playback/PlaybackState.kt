package com.wavezero.player.playback

enum class PlaybackStatus {
    Idle,
    Buffering,
    Ready,
    Playing,
    Paused,
    Stopped,
    Ended,
    Error,
}

data class PlaybackState(
    val status: PlaybackStatus = PlaybackStatus.Idle,
    val trackTitle: String = DemoTrack.title,
    val artistName: String = DemoTrack.artist,
)

object DemoTrack {
    const val title: String = "Apple BipBop HLS Demo"
    const val artist: String = "WaveZero Phase 0B"
    const val hlsUrl: String =
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear0/prog_index.m3u8"
}
