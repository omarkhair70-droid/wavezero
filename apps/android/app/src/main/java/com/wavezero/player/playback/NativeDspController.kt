package com.wavezero.player.playback

import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import androidx.media3.exoplayer.ExoPlayer
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Session-scoped native sound engine for WaveZero.
 *
 * EQ and ReplayGain normalization are deliberately owned together because both
 * affect the final gain stage. EQ headroom and negative ReplayGain are combined
 * through ExoPlayer volume, while positive ReplayGain uses Android's
 * session-scoped LoudnessEnhancer with a conservative cap supplied by
 * ReplayGainInfo.
 */
class NativeDspController {
    private var equalizer: Equalizer? = null
    private var equalizerAudioSessionId: Int? = null
    private var loudnessEnhancer: LoudnessEnhancer? = null
    private var loudnessAudioSessionId: Int? = null
    private var activeProfile: NativeEqProfile = NativeEqProfile.off()
    private var lastResult: NativeDspApplyResult = NativeDspApplyResult.off()
    private var normalizationEnabled: Boolean = false
    private var replayGainInfo: ReplayGainInfo? = null
    private var appliedNormalizationGainDb: Double = 0.0
    private var normalizationMessage: String = "Loudness normalization is off."

    fun setProfile(profile: NativeEqProfile, player: ExoPlayer): NativeDspApplyResult {
        activeProfile = profile
        lastResult = applyToPrimaryPlayer(player)
        return lastResult
    }

    fun setLoudnessNormalizationEnabled(enabled: Boolean, player: ExoPlayer): Map<String, Any?> {
        normalizationEnabled = enabled
        applyGainStages(player, player.audioSessionId)
        return normalizationStatusMap()
    }

    fun setReplayGain(info: ReplayGainInfo?, player: ExoPlayer): Map<String, Any?> {
        replayGainInfo = info
        applyGainStages(player, player.audioSessionId)
        return normalizationStatusMap()
    }

    fun clearReplayGain(player: ExoPlayer): Map<String, Any?> = setReplayGain(null, player)

    fun onAudioSessionChanged(audioSessionId: Int, player: ExoPlayer): NativeDspApplyResult {
        lastResult = applyToSession(audioSessionId, player)
        return lastResult
    }

    fun onPrimaryPlayerChanged(player: ExoPlayer): NativeDspApplyResult {
        releaseEqualizer()
        releaseLoudnessEnhancer()
        lastResult = applyToPrimaryPlayer(player)
        return lastResult
    }

    fun statusMap(): Map<String, Any?> = lastResult.toMap() + mapOf(
        "profileId" to activeProfile.id,
        "audioSessionId" to equalizerAudioSessionId,
    ) + normalizationStatusMap()

    fun release() {
        releaseEqualizer()
        releaseLoudnessEnhancer()
        activeProfile = NativeEqProfile.off()
        normalizationEnabled = false
        replayGainInfo = null
        appliedNormalizationGainDb = 0.0
        normalizationMessage = "Loudness normalization is off."
        lastResult = NativeDspApplyResult.off()
    }

    private fun applyToPrimaryPlayer(player: ExoPlayer): NativeDspApplyResult {
        return applyToSession(player.audioSessionId, player)
    }

    private fun applyToSession(audioSessionId: Int, player: ExoPlayer): NativeDspApplyResult {
        if (audioSessionId <= 0) {
            releaseEqualizer()
            releaseLoudnessEnhancer()
            applyGainStages(player, audioSessionId)
            return if (activeProfile.isOff) {
                NativeDspApplyResult.off()
            } else {
                NativeDspApplyResult.pending(
                    "${activeProfile.label} is waiting for the Media3 audio session.",
                )
            }
        }

        val eqResult = if (activeProfile.isOff) {
            releaseEqualizer()
            NativeDspApplyResult.off()
        } else {
            applyEqualizer(audioSessionId)
        }
        applyGainStages(player, audioSessionId)
        return eqResult
    }

    private fun applyEqualizer(audioSessionId: Int): NativeDspApplyResult {
        try {
            val eq = if (equalizer != null && equalizerAudioSessionId == audioSessionId) {
                equalizer!!
            } else {
                releaseEqualizer()
                Equalizer(PRIORITY, audioSessionId).also {
                    equalizer = it
                    equalizerAudioSessionId = audioSessionId
                }
            }

            eq.enabled = false
            val range = eq.bandLevelRange
            val minLevel = range[0].toInt()
            val maxLevel = range[1].toInt()
            val bandCount = eq.numberOfBands.toInt()
            val appliedBands = ArrayList<Map<String, Any?>>(bandCount)

            for (index in 0 until bandCount) {
                val band = index.toShort()
                val centerHz = eq.getCenterFreq(band) / 1000
                val requestedDb = activeProfile.gainForFrequencyHz(centerHz)
                val requestedMb = (requestedDb * 100.0).roundToInt()
                val appliedMb = requestedMb.coerceIn(minLevel, maxLevel)
                eq.setBandLevel(band, appliedMb.toShort())
                appliedBands.add(
                    mapOf(
                        "band" to index,
                        "centerHz" to centerHz,
                        "gainDb" to appliedMb / 100.0,
                    ),
                )
            }

            eq.enabled = true
            return NativeDspApplyResult.applied(
                message = "${activeProfile.label} is active on $bandCount native EQ bands.",
                audioSessionId = audioSessionId,
                preampLinear = null,
                bands = appliedBands,
            )
        } catch (error: UnsupportedOperationException) {
            releaseEqualizer()
            return NativeDspApplyResult.unsupported(
                "This Android audio output does not expose a usable Equalizer: ${error.message ?: error.javaClass.simpleName}",
            )
        } catch (error: IllegalArgumentException) {
            releaseEqualizer()
            return NativeDspApplyResult.failed(
                "Could not attach EQ to audio session $audioSessionId: ${error.message ?: error.javaClass.simpleName}",
            )
        } catch (error: RuntimeException) {
            releaseEqualizer()
            return NativeDspApplyResult.failed(
                "Native EQ failed safely: ${error.message ?: error.javaClass.simpleName}",
            )
        }
    }

    private fun applyGainStages(player: ExoPlayer, audioSessionId: Int) {
        val requestedNormalizationDb = if (normalizationEnabled) {
            replayGainInfo?.preferredTrackGainDb() ?: 0.0
        } else {
            0.0
        }
        appliedNormalizationGainDb = requestedNormalizationDb

        val attenuationDb = activeProfile.preampGainDb + min(requestedNormalizationDb, 0.0)
        player.volume = dbToLinear(attenuationDb)

        val positiveGainDb = max(requestedNormalizationDb, 0.0)
        if (!normalizationEnabled) {
            releaseLoudnessEnhancer()
            normalizationMessage = "Loudness normalization is off."
            return
        }
        if (replayGainInfo == null) {
            releaseLoudnessEnhancer()
            normalizationMessage = "No ReplayGain tag found; playback level is unchanged."
            return
        }
        if (positiveGainDb <= 0.0) {
            releaseLoudnessEnhancer()
            normalizationMessage = "ReplayGain ${formatDb(requestedNormalizationDb)} applied as safe attenuation."
            return
        }
        if (audioSessionId <= 0) {
            releaseLoudnessEnhancer()
            normalizationMessage = "ReplayGain is waiting for the Media3 audio session."
            return
        }

        try {
            val enhancer = if (loudnessEnhancer != null && loudnessAudioSessionId == audioSessionId) {
                loudnessEnhancer!!
            } else {
                releaseLoudnessEnhancer()
                LoudnessEnhancer(audioSessionId).also {
                    loudnessEnhancer = it
                    loudnessAudioSessionId = audioSessionId
                }
            }
            enhancer.enabled = false
            enhancer.setTargetGain((positiveGainDb * 100.0).roundToInt())
            enhancer.enabled = true
            normalizationMessage = "ReplayGain ${formatDb(requestedNormalizationDb)} applied with native loudness gain."
        } catch (_: RuntimeException) {
            releaseLoudnessEnhancer()
            appliedNormalizationGainDb = 0.0
            normalizationMessage = "ReplayGain boost unavailable on this output; original level preserved."
        }
    }

    private fun normalizationStatusMap(): Map<String, Any?> = mapOf(
        "loudnessNormalizationEnabled" to normalizationEnabled,
        "replayGainTrackDb" to replayGainInfo?.trackGainDb,
        "replayGainAlbumDb" to replayGainInfo?.albumGainDb,
        "replayGainTrackPeak" to replayGainInfo?.trackPeak,
        "appliedNormalizationGainDb" to appliedNormalizationGainDb,
        "loudnessEnhancerActive" to (loudnessEnhancer?.enabled == true),
        "loudnessNormalizationMessage" to normalizationMessage,
    )

    private fun releaseEqualizer() {
        try {
            equalizer?.enabled = false
        } catch (_: RuntimeException) {
        }
        try {
            equalizer?.release()
        } catch (_: RuntimeException) {
        }
        equalizer = null
        equalizerAudioSessionId = null
    }

    private fun releaseLoudnessEnhancer() {
        try {
            loudnessEnhancer?.enabled = false
        } catch (_: RuntimeException) {
        }
        try {
            loudnessEnhancer?.release()
        } catch (_: RuntimeException) {
        }
        loudnessEnhancer = null
        loudnessAudioSessionId = null
    }

    private fun dbToLinear(db: Double): Float {
        if (db >= 0.0) return 1f
        return 10.0.pow(db / 20.0).toFloat().coerceIn(0f, 1f)
    }

    private fun formatDb(db: Double): String = "${if (db >= 0.0) "+" else ""}${"%.2f".format(db)} dB"

    private companion object {
        const val PRIORITY = 0
    }
}

data class NativeEqBand(
    val frequencyHz: Int,
    val gainDb: Double,
)

data class NativeEqProfile(
    val id: String,
    val label: String,
    val bassGainDb: Double,
    val midGainDb: Double,
    val trebleGainDb: Double,
    val preampGainDb: Double,
    val customBands: List<NativeEqBand> = emptyList(),
) {
    val isOff: Boolean get() = id == "off"
    val isCustom: Boolean get() = id == "custom" && customBands.isNotEmpty()

    fun gainForFrequencyHz(frequencyHz: Int): Double {
        if (!isCustom) {
            return when {
                frequencyHz < 250 -> bassGainDb
                frequencyHz < 5000 -> midGainDb
                else -> trebleGainDb
            }
        }

        val sorted = customBands.sortedBy { it.frequencyHz }
        if (frequencyHz <= sorted.first().frequencyHz) return sorted.first().gainDb
        if (frequencyHz >= sorted.last().frequencyHz) return sorted.last().gainDb

        val upperIndex = sorted.indexOfFirst { frequencyHz <= it.frequencyHz }
        val lower = sorted[upperIndex - 1]
        val upper = sorted[upperIndex]
        val lowerLog = ln(lower.frequencyHz.toDouble())
        val upperLog = ln(upper.frequencyHz.toDouble())
        val frequencyLog = ln(frequencyHz.toDouble())
        val span = upperLog - lowerLog
        if (span <= 0.0) return lower.gainDb
        val ratio = ((frequencyLog - lowerLog) / span).coerceIn(0.0, 1.0)
        return lower.gainDb + ((upper.gainDb - lower.gainDb) * ratio)
    }

    companion object {
        fun off() = NativeEqProfile(
            id = "off",
            label = "Off / Original",
            bassGainDb = 0.0,
            midGainDb = 0.0,
            trebleGainDb = 0.0,
            preampGainDb = 0.0,
        )
    }
}

data class NativeDspApplyResult(
    val status: String,
    val message: String,
    val audioSessionId: Int? = null,
    val preampLinear: Float? = null,
    val bands: List<Map<String, Any?>> = emptyList(),
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "status" to status,
        "message" to message,
        "audioSessionId" to audioSessionId,
        "preampLinear" to preampLinear,
        "bands" to bands,
    )

    companion object {
        fun off() = NativeDspApplyResult(
            status = "off",
            message = "Audio effects are off; native playback is original/no-effect.",
        )

        fun pending(message: String) = NativeDspApplyResult(status = "pending", message = message)

        fun unsupported(message: String) = NativeDspApplyResult(status = "unsupported", message = message)

        fun failed(message: String) = NativeDspApplyResult(status = "failed", message = message)

        fun applied(
            message: String,
            audioSessionId: Int,
            preampLinear: Float?,
            bands: List<Map<String, Any?>>,
        ) = NativeDspApplyResult(
            status = "applied",
            message = message,
            audioSessionId = audioSessionId,
            preampLinear = preampLinear,
            bands = bands,
        )
    }
}
