from pathlib import Path

root = Path('.')
activity = root / 'apps/flutter/wavezero_app/android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt'
settings = root / 'apps/flutter/wavezero_app/lib/features/settings/settings_page.dart'

text = activity.read_text()
text = text.replace(
    'import com.wavezero.player.playback.NativeEqProfile\n',
    'import com.wavezero.player.playback.NativeEqBand\nimport com.wavezero.player.playback.NativeEqProfile\n',
)
old = '''                "setAudioEffectProfile" -> {
                    val profile = NativeEqProfile(
                        id = call.argument<String>("id").orEmpty().ifBlank { "off" },
                        label = call.argument<String>("label").orEmpty().ifBlank { "Audio effect" },
                        bassGainDb = call.argument<Number>("bassGainDb")?.toDouble() ?: 0.0,
                        midGainDb = call.argument<Number>("midGainDb")?.toDouble() ?: 0.0,
                        trebleGainDb = call.argument<Number>("trebleGainDb")?.toDouble() ?: 0.0,
                        preampGainDb = call.argument<Number>("preampGainDb")?.toDouble() ?: 0.0,
                    )
                    result.success(audioPlayerManager.setAudioEffectProfile(profile))
                }

                "audioEffectStatus" -> result.success(audioPlayerManager.audioEffectStatusMap())
'''
new = '''                "setAudioEffectProfile" -> {
                    val profileId = call.argument<String>("id").orEmpty().ifBlank { "off" }
                    val profile = if (profileId == "custom") {
                        loadCustomEqProfile()
                    } else {
                        NativeEqProfile(
                            id = profileId,
                            label = call.argument<String>("label").orEmpty().ifBlank { "Audio effect" },
                            bassGainDb = call.argument<Number>("bassGainDb")?.toDouble() ?: 0.0,
                            midGainDb = call.argument<Number>("midGainDb")?.toDouble() ?: 0.0,
                            trebleGainDb = call.argument<Number>("trebleGainDb")?.toDouble() ?: 0.0,
                            preampGainDb = call.argument<Number>("preampGainDb")?.toDouble() ?: 0.0,
                        )
                    }
                    result.success(audioPlayerManager.setAudioEffectProfile(profile))
                }

                "setCustomEqualizer" -> {
                    val profile = customEqProfileFromCall(call)
                    saveCustomEqProfile(profile)
                    result.success(audioPlayerManager.setAudioEffectProfile(profile))
                }

                "customEqualizerSettings" -> result.success(customEqSettingsMap(loadCustomEqProfile()))

                "audioEffectStatus" -> result.success(audioPlayerManager.audioEffectStatusMap())
'''
if old not in text:
    raise SystemExit('setAudioEffectProfile block not found')
text = text.replace(old, new)
marker = '''    private fun notificationTrackFromCall(call: MethodCall): NotificationTrackSnapshot {
'''
helpers = '''    private fun customEqProfileFromCall(call: MethodCall): NativeEqProfile {
        val rawBands = call.argument<List<Map<String, Any?>>>("bands").orEmpty()
        val bands = rawBands.mapNotNull { raw ->
            val frequencyHz = (raw["frequencyHz"] as? Number)?.toInt() ?: return@mapNotNull null
            val gainDb = (raw["gainDb"] as? Number)?.toDouble() ?: return@mapNotNull null
            if (frequencyHz !in 20..24000) return@mapNotNull null
            NativeEqBand(
                frequencyHz = frequencyHz,
                gainDb = gainDb.coerceIn(-6.0, 6.0),
            )
        }.distinctBy { it.frequencyHz }.sortedBy { it.frequencyHz }
        if (bands.size < 3) throw IllegalArgumentException("Custom EQ requires at least three valid bands")
        val maxBoost = bands.maxOfOrNull { it.gainDb }?.coerceAtLeast(0.0) ?: 0.0
        val requestedPreamp = call.argument<Number>("preampGainDb")?.toDouble() ?: -maxBoost
        return NativeEqProfile(
            id = "custom",
            label = "Custom EQ",
            bassGainDb = 0.0,
            midGainDb = 0.0,
            trebleGainDb = 0.0,
            preampGainDb = requestedPreamp.coerceIn(-12.0, 0.0),
            customBands = bands,
        )
    }

    private fun saveCustomEqProfile(profile: NativeEqProfile) {
        val encoded = profile.customBands.joinToString("|") { "${it.frequencyHz}:${it.gainDb}" }
        context.getSharedPreferences(CUSTOM_EQ_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(CUSTOM_EQ_BANDS_KEY, encoded)
            .putFloat(CUSTOM_EQ_PREAMP_KEY, profile.preampGainDb.toFloat())
            .apply()
    }

    private fun loadCustomEqProfile(): NativeEqProfile {
        val prefs = context.getSharedPreferences(CUSTOM_EQ_PREFS, Context.MODE_PRIVATE)
        val encoded = prefs.getString(CUSTOM_EQ_BANDS_KEY, null)
        val bands = encoded
            ?.split('|')
            ?.mapNotNull { item ->
                val pieces = item.split(':', limit = 2)
                if (pieces.size != 2) return@mapNotNull null
                val frequencyHz = pieces[0].toIntOrNull() ?: return@mapNotNull null
                val gainDb = pieces[1].toDoubleOrNull() ?: return@mapNotNull null
                NativeEqBand(frequencyHz, gainDb.coerceIn(-6.0, 6.0))
            }
            ?.takeIf { it.size >= 3 }
            ?: DEFAULT_CUSTOM_EQ_FREQUENCIES.map { NativeEqBand(it, 0.0) }
        val maxBoost = bands.maxOfOrNull { it.gainDb }?.coerceAtLeast(0.0) ?: 0.0
        val preampGainDb = if (prefs.contains(CUSTOM_EQ_PREAMP_KEY)) {
            prefs.getFloat(CUSTOM_EQ_PREAMP_KEY, (-maxBoost).toFloat()).toDouble()
        } else {
            -maxBoost
        }
        return NativeEqProfile(
            id = "custom",
            label = "Custom EQ",
            bassGainDb = 0.0,
            midGainDb = 0.0,
            trebleGainDb = 0.0,
            preampGainDb = preampGainDb.coerceIn(-12.0, 0.0),
            customBands = bands,
        )
    }

    private fun customEqSettingsMap(profile: NativeEqProfile): Map<String, Any?> = mapOf(
        "bands" to profile.customBands.map { band ->
            mapOf(
                "frequencyHz" to band.frequencyHz,
                "gainDb" to band.gainDb,
            )
        },
        "preampGainDb" to profile.preampGainDb,
    )

'''
if marker not in text:
    raise SystemExit('notification helper marker not found')
text = text.replace(marker, helpers + marker)
old_companion = '''    companion object {
        const val CHANNEL_NAME = "wavezero/playback"
        private const val DEVICE_AUDIO_SCAN_LIMIT = 500
        private const val MIN_DEVICE_AUDIO_DURATION_MS = 30_000L
    }
'''
new_companion = '''    companion object {
        const val CHANNEL_NAME = "wavezero/playback"
        private const val DEVICE_AUDIO_SCAN_LIMIT = 500
        private const val MIN_DEVICE_AUDIO_DURATION_MS = 30_000L
        private const val CUSTOM_EQ_PREFS = "wavezero_custom_equalizer"
        private const val CUSTOM_EQ_BANDS_KEY = "bands"
        private const val CUSTOM_EQ_PREAMP_KEY = "preamp_db"
        private val DEFAULT_CUSTOM_EQ_FREQUENCIES = listOf(31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)
    }
'''
if old_companion not in text:
    raise SystemExit('companion block not found')
text = text.replace(old_companion, new_companion)
activity.write_text(text)

text = settings.read_text()
text = text.replace(
    "import '../playback/playback_modes.dart';\n",
    "import '../playback/custom_equalizer_page.dart';\nimport '../playback/playback_modes.dart';\n",
)
old_settings = '''                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: AudioEffectProfile.values
                      .map((profile) => ChoiceChip(label: Text(profile.shortLabel), selected: selectedAudioEffectProfile == profile, onSelected: controlsDisabled ? null : (_) => onAudioEffectChanged(profile)))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.xs),
                Text('Off / Original is the safest default. ${nativeAudioEffectStatus == NativeAudioEffectStatus.unsupported ? 'Effect profile saved. Native DSP support is still foundation-level.' : lastAudioEffectApplyResult}', maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.caption),
'''
new_settings = '''                Wrap(
                  spacing: WzSpacing.xs,
                  runSpacing: WzSpacing.xs,
                  children: AudioEffectProfile.values
                      .map((profile) => ChoiceChip(label: Text(profile.shortLabel), selected: selectedAudioEffectProfile == profile, onSelected: controlsDisabled ? null : (_) => onAudioEffectChanged(profile)))
                      .toList(growable: false),
                ),
                const SizedBox(height: WzSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: controlsDisabled
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => WzCustomEqualizerPage(
                                  onActivated: () => onAudioEffectChanged(AudioEffectProfile.custom),
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.tune),
                    label: const Text('Tune Custom EQ'),
                  ),
                ),
                const SizedBox(height: WzSpacing.xs),
                Text('Off / Original disables native EQ completely. $lastAudioEffectApplyResult', maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.caption),
'''
if old_settings not in text:
    raise SystemExit('settings effect block not found')
text = text.replace(old_settings, new_settings)
settings.write_text(text)
