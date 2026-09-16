package com.wavezero.player.playback

import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import androidx.media3.exoplayer.ExoPlayer
import java.util.IdentityHashMap
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Native sound-engine owner for WaveZero.
 *
 * EQ, ReplayGain and the transition envelope are composed here so crossfade
 * never becomes a second absolute-volume owner. During a transition both
 * ExoPlayers may temporarily keep their own session-scoped effects while the
 * global profile and normalization preference remain shared.
 */
class NativeDspController {
    private data class PlayerDspState(
        var equalizer: Equalizer? = null,
        var equalizerAudioSessionId: Int? = null,
        var loudnessEnhancer: LoudnessEnhancer? = null,
        var loudnessAudioSessionId: Int? = null,
        var replayGainInfo: ReplayGainInfo? = null,
        var appliedNormalizationGainDb: Double = 0.0,
        var normalizationMessage: String = "Loudness normalization is off.",
        var transitionGain: Float = 1f,
        var eqResult: NativeDspApplyResult = NativeDspApplyResult.off(),
    )

    private val playerStates = IdentityHashMap<ExoPlayer, PlayerDspState>()
    private var primaryPlayer: ExoPlayer? = null
    private var activeProfile: NativeEqProfile = NativeEqProfile.off()
    private var lastResult: NativeDspApplyResult = NativeDspApplyResult.off()
    private var normalizationEnabled: Boolean = false

    fun setProfile(profile: NativeEqProfile, player: ExoPlayer): NativeDspApplyResult {
        activeProfile = profile
        ensurePrimaryPlayer(player)
        applyToKnownPlayers()
        lastResult = stateFor(player).eqResult
        return lastResult
    }

    fun setLoudnessNormalizationEnabled(enabled: Boolean, player: ExoPlayer): Map<String, Any?> {
        normalizationEnabled = enabled
        ensurePrimaryPlayer(player)
        applyToKnownPlayers()
        return normalizationStatusMap(stateFor(player))
    }

    fun setReplayGain(info: ReplayGainInfo?, player: ExoPlayer): Map<String, Any?> {
        val state = stateFor(player)
        state.replayGainInfo = info
        applyGainStages(player, player.audioSessionId, effectiveProfilePreampDb(state), state)
        return normalizationStatusMap(state)
    }

    fun clearReplayGain(player: ExoPlayer): Map<String, Any?> = setReplayGain(null, player)

    fun onAudioSessionChanged(audioSessionId: Int, player: ExoPlayer): NativeDspApplyResult {
        val result = applyToSession(audioSessionId, player)
        if (player === primaryPlayer) lastResult = result
        return result
    }

    /** Normal promotion: the player should be fully audible. */
    fun onPrimaryPlayerChanged(player: ExoPlayer): NativeDspApplyResult {
        primaryPlayer = player
        val state = stateFor(player)
        state.transitionGain = 1f
        lastResult = applyToPrimaryPlayer(player)
        return lastResult
    }

    /** Crossfade promotion: preserve the envelope already in progress. */
    fun promoteSecondaryPlayer(player: ExoPlayer): NativeDspApplyResult {
        primaryPlayer = player
        lastResult = applyToPrimaryPlayer(player)
        return lastResult
    }

    /** Recycles a player into WaveZero's silent prepared-next role. */
    fun onSecondaryPlayerChanged(player: ExoPlayer) {
        releasePlayer(player)
        val state = stateFor(player)
        state.transitionGain = 0f
        applyGainStages(player, player.audioSessionId, profilePreampGainDb = 0.0, state = state)
    }

    fun setTransitionGain(player: ExoPlayer, gain: Float): Map<String, Any?> {
        val state = stateFor(player)
        state.transitionGain = gain.coerceIn(0f, 1f)
        applyGainStages(player, player.audioSessionId, effectiveProfilePreampDb(state), state)
        return transitionStatusMap(player, state)
    }

    fun transitionGain(player: ExoPlayer): Float = playerStates[player]?.transitionGain ?: 1f

    fun releasePlayer(player: ExoPlayer) {
        val state = playerStates.remove(player) ?: return
        releaseEqualizer(state)
        releaseLoudnessEnhancer(state)
        if (primaryPlayer === player) primaryPlayer = null
    }

    fun statusMap(): Map<String, Any?> {
        val player = primaryPlayer
        val state = player?.let(playerStates::get)
        val result = state?.eqResult ?: lastResult
        return result.toMap() + mapOf(
            "profileId" to activeProfile.id,
            "audioSessionId" to state?.equalizerAudioSessionId,
            "activeDspPlayerCount" to playerStates.size,
            "transitionGain" to (state?.transitionGain ?: 1f),
        ) + normalizationStatusMap(state)
    }

    fun release() {
        playerStates.values.toList().forEach { state ->
            releaseEqualizer(state)
            releaseLoudnessEnhancer(state)
        }
        playerStates.clear()
        primaryPlayer = null
        activeProfile = NativeEqProfile.off()
        normalizationEnabled = false
        lastResult = NativeDspApplyResult.off()
    }

    private fun ensurePrimaryPlayer(player: ExoPlayer) {
        if (primaryPlayer == null) primaryPlayer = player
        stateFor(player)
    }

    private fun stateFor(player: ExoPlayer): PlayerDspState =
        playerStates[player] ?: PlayerDspState().also { playerStates[player] = it }

    private fun applyToKnownPlayers() {
        playerStates.keys.toList().forEach { knownPlayer ->
            val result = applyToSession(knownPlayer.audioSessionId, knownPlayer)
            if (knownPlayer === primaryPlayer) lastResult = result
        }
    }

    private fun applyToPrimaryPlayer(player: ExoPlayer): NativeDspApplyResult {
        return applyToSession(player.audioSessionId, player)
    }

    private fun applyToSession(audioSessionId: Int, player: ExoPlayer): NativeDspApplyResult {
        val state = stateFor(player)
        if (audioSessionId <= 0) {
            releaseEqualizer(state)
            releaseLoudnessEnhancer(state)
            applyGainStages(player, audioSessionId, profilePreampGainDb = 0.0, state = state)
            state.eqResult = if (activeProfile.isOff) {
                NativeDspApplyResult.off()
            } else {
                NativeDspApplyResult.pending(
                    "${activeProfile.label} is waiting for the Media3 audio session.",
                )
            }
            return state.eqResult
        }

        val eqResult = if (activeProfile.isOff) {
            releaseEqualizer(state)
            NativeDspApplyResult.off()
        } else {
            applyEqualizer(audioSessionId, state)
        }
        state.eqResult = eqResult
        val profilePreampGainDb = if (eqResult.status == "applied") {
            activeProfile.preampGainDb
        } else {
            0.0
        }
        applyGainStages(player, audioSessionId, profilePreampGainDb, state)
        return eqResult
    }

    private fun applyEqualizer(audioSessionId: Int, state: PlayerDspState): NativeDspApplyResult {
        try {
            val eq = if (state.equalizer != null && state.equalizerAudioSessionId == audioSessionId) {
                state.equalizer!!
            } else {
                releaseEqualizer(state)
                Equalizer(PRIORITY, audioSessionId).also {
                    state.equalizer = it
                    state.equalizerAudioSessionId = audioSessionId
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
            releaseEqualizer(state)
            return NativeDspApplyResult.unsupported(
                "This Android audio output does not expose a usable Equalizer: ${error.message ?: error.javaClass.simpleName}",
            )
        } catch (error: IllegalArgumentException) {
            releaseEqualizer(state)
            return NativeDspApplyResult.failed(
                "Could not attach EQ to audio session $audioSessionId: ${error.message ?: error.javaClass.simpleName}",
            )
        } catch (error: RuntimeException) {
            releaseEqualizer(state)
            return NativeDspApplyResult.failed(
                "Native EQ failed safely: ${error.message ?: error.javaClass.simpleName}",
            )
        }
    }

    private fun applyGainStages(
        player: ExoPlayer,
        audioSessionId: Int,
        profilePreampGainDb: Double,
        state: PlayerDspState,
    ) {
        val requestedNormalizationDb = if (normalizationEnabled) {
            state.replayGainInfo?.preferredTrackGainDb() ?: 0.0
        } else {
            0.0
        }
        state.appliedNormalizationGainDb = requestedNormalizationDb

        val attenuationDb = profilePreampGainDb + min(requestedNormalizationDb, 0.0)
        val baseGain = dbToLinear(attenuationDb)
        player.volume = (baseGain * state.transitionGain).coerceIn(0f, 1f)

        val positiveGainDb = max(requestedNormalizationDb, 0.0)
        if (!normalizationEnabled) {
            releaseLoudnessEnhancer(state)
            state.normalizationMessage = "Loudness normalization is off."
            return
        }
        if (state.replayGainInfo == null) {
            releaseLoudnessEnhancer(state)
            state.normalizationMessage = "No ReplayGain tag found; normalization leaves this track unchanged."
            return
        }
        if (positiveGainDb <= 0.0) {
            releaseLoudnessEnhancer(state)
            state.normalizationMessage = "ReplayGain ${formatDb(requestedNormalizationDb)} applied as safe attenuation."
            return
        }
        if (audioSessionId <= 0) {
            releaseLoudnessEnhancer(state)
            state.normalizationMessage = "ReplayGain is waiting for the Media3 audio session."
            return
        }

        try {
            val enhancer = if (state.loudnessEnhancer != null && state.loudnessAudioSessionId == audioSessionId) {
                state.loudnessEnhancer!!
            } else {
                releaseLoudnessEnhancer(state)
                LoudnessEnhancer(audioSessionId).also {
                    state.loudnessEnhancer = it
                    state.loudnessAudioSessionId = audioSessionId
                }
            }
            enhancer.enabled = false
            enhancer.setTargetGain((positiveGainDb * 100.0).roundToInt())
            enhancer.enabled = true
            state.normalizationMessage = "ReplayGain ${formatDb(requestedNormalizationDb)} applied with native loudness gain."
        } catch (_: RuntimeException) {
            releaseLoudnessEnhancer(state)
            state.appliedNormalizationGainDb = 0.0
            state.normalizationMessage = "ReplayGain boost unavailable on this output; normalization leaves the level unchanged."
        }
    }

    private fun effectiveProfilePreampDb(): Double {
        val state = primaryPlayer?.let(playerStates::get) ?: return 0.0
        return effectiveProfilePreampDb(state)
    }

    private fun effectiveProfilePreampDb(state: PlayerDspState): Double {
        return if (state.equalizer?.enabled == true && !activeProfile.isOff) {
            activeProfile.preampGainDb
        } else {
            0.0
        }
    }

    private fun normalizationStatusMap(state: PlayerDspState? = primaryPlayer?.let(playerStates::get)): Map<String, Any?> = mapOf(
        "loudnessNormalizationEnabled" to normalizationEnabled,
        "replayGainTrackDb" to state?.replayGainInfo?.trackGainDb,
        "replayGainAlbumDb" to state?.replayGainInfo?.albumGainDb,
        "replayGainTrackPeak" to state?.replayGainInfo?.trackPeak,
        "appliedNormalizationGainDb" to (state?.appliedNormalizationGainDb ?: 0.0),
        "loudnessEnhancerActive" to (state?.loudnessEnhancer?.enabled == true),
        "loudnessNormalizationMessage" to (state?.normalizationMessage ?: if (normalizationEnabled) "No active playback session." else "Loudness normalization is off."),
    )

    private fun transitionStatusMap(player: ExoPlayer, state: PlayerDspState): Map<String, Any?> = mapOf(
        "transitionGain" to state.transitionGain,
        "audioSessionId" to player.audioSessionId,
        "profileId" to activeProfile.id,
        "dspPlayerCount" to playerStates.size,
    )

    // Kept as a primary-state helper for the existing sound-engine contract and
    // for callers that need to explicitly tear down current session effects.
    private fun releaseEqualizer() {
        primaryPlayer?.let(playerStates::get)?.let(::releaseEqualizer)
    }

    private fun releaseEqualizer(state: PlayerDspState) {
        try {
            state.equalizer?.enabled = false
        } catch (_: RuntimeException) {
        }
        try {
            state.equalizer?.release()
        } catch (_: RuntimeException) {
        }
        state.equalizer = null
        state.equalizerAudioSessionId = null
    }

    private fun releaseLoudnessEnhancer(state: PlayerDspState) {
        try {
            state.loudnessEnhancer?.enabled = false
        } catch (_: RuntimeException) {
        }
        try {
            state.loudnessEnhancer?.release()
        } catch (_: RuntimeException) {
        }
        state.loudnessEnhancer = null
        state.loudnessAudioSessionId = null
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
