package com.wavezero.player.playback

import android.content.Context
import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.AudioProcessor.AudioFormat
import androidx.media3.common.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Shared live settings for WaveZero's per-player channel processors.
 *
 * Every ExoPlayer owns its own processor instance, while primary and prebuffer
 * players read this shared state. That keeps prepared handoffs on the latest
 * balance/mono choice without sharing a stateful AudioProcessor between sinks.
 */
class WaveZeroChannelAudioState(
    initialBalance: Double = 0.0,
    initialMono: Boolean = false,
) {
    private val configuredStereoProcessorCount = AtomicInteger(0)

    @Volatile
    var balance: Double = initialBalance.coerceIn(-1.0, 1.0)
        private set

    @Volatile
    var mono: Boolean = initialMono
        private set

    @Volatile
    var lastFormatLabel: String = "waiting_for_stereo_pcm"
        internal set

    val pcmStereoConfigured: Boolean
        get() = configuredStereoProcessorCount.get() > 0

    fun setBalance(value: Double) {
        balance = value.coerceIn(-1.0, 1.0)
    }

    fun setMono(enabled: Boolean) {
        mono = enabled
    }

    internal fun markStereoProcessorConfigured() {
        configuredStereoProcessorCount.incrementAndGet()
        lastFormatLabel = "stereo_pcm16"
    }

    internal fun markStereoProcessorReleased() {
        configuredStereoProcessorCount.updateAndGet { count -> (count - 1).coerceAtLeast(0) }
    }

    fun statusMap(): Map<String, Any?> = mapOf(
        "balance" to balance,
        "mono" to mono,
        "pcmStereoConfigured" to pcmStereoConfigured,
        "channelProcessorFormat" to lastFormatLabel,
    )
}

/**
 * Creates a fresh channel processor for each ExoPlayer audio sink. Stateful
 * AudioProcessors must never be shared between WaveZero's primary and prebuffer
 * players, but both processors intentionally read the same live settings.
 */
@UnstableApi
class WaveZeroAudioRenderersFactory(
    context: Context,
    private val channelState: WaveZeroChannelAudioState,
) : DefaultRenderersFactory(context) {
    override fun buildAudioSink(
        context: Context,
        enableFloatOutput: Boolean,
        enableAudioTrackPlaybackParams: Boolean,
    ): AudioSink {
        val processor = WaveZeroChannelAudioProcessor(channelState)
        return DefaultAudioSink.Builder(context)
            .setEnableFloatOutput(enableFloatOutput)
            .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
            .setAudioProcessors(arrayOf<AudioProcessor>(processor))
            .build()
    }
}

/**
 * Lightweight live PCM16 stereo processor for balance and dual-mono output.
 *
 * The processor stays active for stereo PCM16 even when controls are neutral so
 * balance/mono changes take effect on the next audio buffer without rebuilding
 * ExoPlayer. Non-stereo and non-PCM16 formats are left outside this processor.
 */
@UnstableApi
class WaveZeroChannelAudioProcessor(
    private val state: WaveZeroChannelAudioState,
) : BaseAudioProcessor() {
    private var countedAsStereo = false

    override fun onConfigure(inputAudioFormat: AudioFormat): AudioFormat {
        val supported = inputAudioFormat.encoding == C.ENCODING_PCM_16BIT &&
            inputAudioFormat.channelCount == 2
        updateConfiguredStereoState(supported)
        state.lastFormatLabel = if (supported) {
            "stereo_pcm16"
        } else {
            "bypass_${inputAudioFormat.channelCount}ch_${inputAudioFormat.encoding}"
        }
        return if (supported) inputAudioFormat else AudioFormat.NOT_SET
    }

    override fun queueInput(inputBuffer: ByteBuffer) {
        val inputBytes = inputBuffer.remaining()
        if (inputBytes == 0) return

        val output = replaceOutputBuffer(inputBytes)
        val mono = state.mono
        val balance = state.balance.coerceIn(-1.0, 1.0)

        // Neutral settings still keep this processor configured so later live
        // changes need no player rebuild. Copying is the cheapest neutral path.
        if (!mono && abs(balance) < BALANCE_EPSILON) {
            output.put(inputBuffer)
            output.flip()
            return
        }

        val leftGain = if (balance > 0.0) 1.0 - balance else 1.0
        val rightGain = if (balance < 0.0) 1.0 + balance else 1.0

        while (inputBuffer.remaining() >= BYTES_PER_STEREO_FRAME) {
            var left = inputBuffer.short.toInt()
            var right = inputBuffer.short.toInt()

            if (mono) {
                val mixed = ((left + right) / 2.0).roundToInt()
                left = mixed
                right = mixed
            }

            output.putShort(scalePcm16(left, leftGain))
            output.putShort(scalePcm16(right, rightGain))
        }

        // A valid PCM16 stereo buffer should be frame aligned. Preserve any
        // unexpected trailing bytes rather than dropping audio data.
        while (inputBuffer.hasRemaining()) {
            output.put(inputBuffer.get())
        }
        output.flip()
    }

    override fun onReset() {
        updateConfiguredStereoState(false)
    }

    private fun updateConfiguredStereoState(configured: Boolean) {
        if (configured == countedAsStereo) return
        countedAsStereo = configured
        if (configured) {
            state.markStereoProcessorConfigured()
        } else {
            state.markStereoProcessorReleased()
        }
    }

    private fun scalePcm16(sample: Int, gain: Double): Short {
        return (sample * gain)
            .roundToInt()
            .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
            .toShort()
    }

    private companion object {
        const val BYTES_PER_STEREO_FRAME = 4
        const val BALANCE_EPSILON = 0.0001
    }
}
