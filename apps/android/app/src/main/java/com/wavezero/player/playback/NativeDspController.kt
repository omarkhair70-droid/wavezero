package com.wavezero.player.playback

import android.media.audiofx.Equalizer
import androidx.media3.exoplayer.ExoPlayer
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Small lifecycle owner for WaveZero's native Android equalizer.
 *
 * The Equalizer is always attached to WaveZero's own current ExoPlayer audio
 * session. No global/output-capture effect is used. The controller keeps the
 * selected profile so it can re-attach when Media3 creates a new audio session
 * or when the prepared next-player becomes the primary player.
 */
class NativeDspController {
    private var equalizer: Equalizer? = null
    private var attachedAudioSessionId: Int? = null
    private var activeProfile: NativeEqProfile = NativeEqProfile.off()
    private var lastResult: NativeDspApplyResult = NativeDspApplyResult.off()

    fun setProfile(profile: NativeEqProfile, player: ExoPlayer): NativeDspApplyResult {
        activeProfile = profile
        lastResult = applyToPrimaryPlayer(player)
        return lastResult
    }

    fun onAudioSessionChanged(audioSessionId: Int, player: ExoPlayer): NativeDspApplyResult {
        if (activeProfile.isOff) {
            releaseEqualizer()
            player.volume = 1f
            lastResult = NativeDspApplyResult.off()
            return lastResult
        }
        lastResult = applyToSession(audioSessionId, player)
        return lastResult
    }

    fun onPrimaryPlayerChanged(player: ExoPlayer): NativeDspApplyResult {
        releaseEqualizer()
        lastResult = applyToPrimaryPlayer(player)
        return lastResult
    }

    fun statusMap(): Map<String, Any?> = lastResult.toMap() + mapOf(
        "profileId" to activeProfile.id,
        "audioSessionId" to attachedAudioSessionId,
    )

    fun release() {
        releaseEqualizer()
        activeProfile = NativeEqProfile.off()
        lastResult = NativeDspApplyResult.off()
    }

    private fun applyToPrimaryPlayer(player: ExoPlayer): NativeDspApplyResult {
        if (activeProfile.isOff) {
            releaseEqualizer()
            player.volume = 1f
            return NativeDspApplyResult.off()
        }
        return applyToSession(player.audioSessionId, player)
    }

    private fun applyToSession(audioSessionId: Int, player: ExoPlayer): NativeDspApplyResult {
        if (activeProfile.isOff) {
            releaseEqualizer()
            player.volume = 1f
            return NativeDspApplyResult.off()
        }

        // Media3 reports an unset/generated session before AudioTrack is ready.
        // Keep the requested profile and attach as soon as AnalyticsListener gives
        // us a concrete session id.
        if (audioSessionId <= 0) {
            releaseEqualizer()
            player.volume = dbToLinear(activeProfile.preampGainDb)
            return NativeDspApplyResult.pending(
                "${activeProfile.label} is waiting for the Media3 audio session.",
            )
        }

        try {
            val eq = if (equalizer != null && attachedAudioSessionId == audioSessionId) {
                equalizer!!
            } else {
                releaseEqualizer()
                Equalizer(PRIORITY, audioSessionId).also {
                    equalizer = it
                    attachedAudioSessionId = audioSessionId
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
                // Android Equalizer center frequencies are millihertz.
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

            // Existing profiles use non-positive preamp values. Applying the
            // headroom on the primary ExoPlayer avoids clipping after positive EQ
            // boosts without changing the prebuffer player's muted state.
            player.volume = dbToLinear(activeProfile.preampGainDb)
            eq.enabled = true

            return NativeDspApplyResult.applied(
                message = "${activeProfile.label} is active on $bandCount native EQ bands.",
                audioSessionId = audioSessionId,
                preampLinear = player.volume,
                bands = appliedBands,
            )
        } catch (error: UnsupportedOperationException) {
            releaseEqualizer()
            player.volume = 1f
            return NativeDspApplyResult.unsupported(
                "This Android audio output does not expose a usable Equalizer: ${error.message ?: error.javaClass.simpleName}",
            )
        } catch (error: IllegalArgumentException) {
            releaseEqualizer()
            player.volume = 1f
            return NativeDspApplyResult.failed(
                "Could not attach EQ to audio session $audioSessionId: ${error.message ?: error.javaClass.simpleName}",
            )
        } catch (error: RuntimeException) {
            releaseEqualizer()
            player.volume = 1f
            return NativeDspApplyResult.failed(
                "Native EQ failed safely: ${error.message ?: error.javaClass.simpleName}",
            )
        }
    }

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
        attachedAudioSessionId = null
    }

    private fun dbToLinear(db: Double): Float {
        if (db >= 0.0) return 1f
        return 10.0.pow(db / 20.0).toFloat().coerceIn(0f, 1f)
    }

    private companion object {
        const val PRIORITY = 0
    }
}

data class NativeEqProfile(
    val id: String,
    val label: String,
    val bassGainDb: Double,
    val midGainDb: Double,
    val trebleGainDb: Double,
    val preampGainDb: Double,
) {
    val isOff: Boolean get() = id == "off"

    fun gainForFrequencyHz(frequencyHz: Int): Double = when {
        frequencyHz < 250 -> bassGainDb
        frequencyHz < 5000 -> midGainDb
        else -> trebleGainDb
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
            preampLinear: Float,
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
