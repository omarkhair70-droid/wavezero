package com.wavezero.player.playback

import androidx.media3.common.Metadata
import androidx.media3.extractor.metadata.id3.TextInformationFrame
import androidx.media3.extractor.metadata.vorbis.VorbisComment
import kotlin.math.log10
import kotlin.math.min

/** ReplayGain values extracted from static or in-stream media metadata. */
data class ReplayGainInfo(
    val trackGainDb: Double? = null,
    val albumGainDb: Double? = null,
    val trackPeak: Double? = null,
    val albumPeak: Double? = null,
) {
    fun preferredTrackGainDb(): Double? {
        val requested = trackGainDb ?: albumGainDb ?: return null
        val peak = if (trackGainDb != null) trackPeak else albumPeak
        val capped = requested.coerceIn(MIN_GAIN_DB, MAX_GAIN_DB)
        if (peak == null || !peak.isFinite() || peak <= 0.0) return capped
        val peakSafeGainDb = -20.0 * log10(peak)
        return min(capped, peakSafeGainDb).coerceIn(MIN_GAIN_DB, MAX_GAIN_DB)
    }

    companion object {
        const val MIN_GAIN_DB = -12.0
        const val MAX_GAIN_DB = 6.0
    }
}

object ReplayGainMetadata {
    private const val TRACK_GAIN = "REPLAYGAIN_TRACK_GAIN"
    private const val ALBUM_GAIN = "REPLAYGAIN_ALBUM_GAIN"
    private const val TRACK_PEAK = "REPLAYGAIN_TRACK_PEAK"
    private const val ALBUM_PEAK = "REPLAYGAIN_ALBUM_PEAK"

    fun parse(metadata: Metadata?): ReplayGainInfo? {
        if (metadata == null) return null
        var trackGainDb: Double? = null
        var albumGainDb: Double? = null
        var trackPeak: Double? = null
        var albumPeak: Double? = null

        for (index in 0 until metadata.length()) {
            when (val entry = metadata[index]) {
                is VorbisComment -> {
                    when (entry.key.uppercase()) {
                        TRACK_GAIN -> trackGainDb = parseGainDb(entry.value) ?: trackGainDb
                        ALBUM_GAIN -> albumGainDb = parseGainDb(entry.value) ?: albumGainDb
                        TRACK_PEAK -> trackPeak = parsePeak(entry.value) ?: trackPeak
                        ALBUM_PEAK -> albumPeak = parsePeak(entry.value) ?: albumPeak
                    }
                }

                is TextInformationFrame -> {
                    if (!entry.id.equals("TXXX", ignoreCase = true)) continue
                    val key = entry.description?.trim()?.uppercase() ?: continue
                    val value = entry.values.firstOrNull() ?: continue
                    when (key) {
                        TRACK_GAIN -> trackGainDb = parseGainDb(value) ?: trackGainDb
                        ALBUM_GAIN -> albumGainDb = parseGainDb(value) ?: albumGainDb
                        TRACK_PEAK -> trackPeak = parsePeak(value) ?: trackPeak
                        ALBUM_PEAK -> albumPeak = parsePeak(value) ?: albumPeak
                    }
                }
            }
        }

        if (trackGainDb == null && albumGainDb == null) return null
        return ReplayGainInfo(
            trackGainDb = trackGainDb,
            albumGainDb = albumGainDb,
            trackPeak = trackPeak,
            albumPeak = albumPeak,
        )
    }

    private fun parseGainDb(value: String): Double? {
        val normalized = value
            .trim()
            .removeSuffix("dB")
            .removeSuffix("DB")
            .removeSuffix("db")
            .trim()
        return normalized.toDoubleOrNull()?.takeIf { it.isFinite() }
    }

    private fun parsePeak(value: String): Double? = value
        .trim()
        .toDoubleOrNull()
        ?.takeIf { it.isFinite() && it > 0.0 }
}
