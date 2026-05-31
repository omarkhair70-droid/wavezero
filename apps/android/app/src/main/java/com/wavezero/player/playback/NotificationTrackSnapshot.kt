package com.wavezero.player.playback

import android.net.Uri

/** Lightweight source-aware metadata used by Android media notifications. */
data class NotificationTrackSnapshot(
    val trackId: String? = null,
    val title: String,
    val artistName: String? = null,
    val albumName: String? = null,
    val url: String,
    val artworkUrl: String? = null,
    val durationMs: Long? = null,
    val source: String = SOURCE_UNKNOWN,
    val qualityLabel: String? = null,
    val codec: String? = null,
) {
    fun hasPlayableUrl(): Boolean = url.isNotBlank()

    val artworkUri: Uri?
        get() = artworkUrl?.takeIf { it.isNotBlank() }?.let { runCatching { Uri.parse(it) }.getOrNull() }

    companion object {
        const val SOURCE_API = "api"
        const val SOURCE_DEVICE = "device"
        const val SOURCE_CACHED = "cached"
        const val SOURCE_MANUAL = "manual"
        const val SOURCE_UNKNOWN = "unknown"

        fun manual(title: String, url: String): NotificationTrackSnapshot {
            return NotificationTrackSnapshot(
                title = title.ifBlank { DemoTrack.title },
                artistName = DemoTrack.artist,
                url = url,
                source = SOURCE_MANUAL,
            )
        }
    }
}
