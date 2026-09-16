from pathlib import Path

root = Path('.')
manager_path = root / 'apps/android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt'
activity_path = root / 'apps/flutter/wavezero_app/android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt'
settings_path = root / 'apps/flutter/wavezero_app/lib/features/settings/settings_page.dart'

# ---- AudioPlayerManager ----
text = manager_path.read_text()
old = '''    private val soundEnginePreferences = appContext.getSharedPreferences(SOUND_ENGINE_PREFS, Context.MODE_PRIVATE)
    private var loudnessNormalizationEnabled = soundEnginePreferences.getBoolean(LOUDNESS_NORMALIZATION_KEY, false)

    private var player: ExoPlayer = buildPrimaryPlayer()
'''
new = '''    private val soundEnginePreferences = appContext.getSharedPreferences(SOUND_ENGINE_PREFS, Context.MODE_PRIVATE)
    private var loudnessNormalizationEnabled = soundEnginePreferences.getBoolean(LOUDNESS_NORMALIZATION_KEY, false)
    private val channelAudioState = WaveZeroChannelAudioState(
        initialBalance = soundEnginePreferences.getFloat(CHANNEL_BALANCE_KEY, 0f).toDouble(),
        initialMono = soundEnginePreferences.getBoolean(MONO_OUTPUT_KEY, false),
    )

    private var player: ExoPlayer = buildPrimaryPlayer()
'''
if old not in text:
    raise SystemExit('manager preferences block not found')
text = text.replace(old, new, 1)

old = '''    fun loudnessNormalizationStatusMap(): Map<String, Any?> = nativeDspController.statusMap()

    fun metricsSnapshotMap(): Map<String, Any?> {
        val durationMs = currentTrack.durationMs ?: player.duration.takeIf { it != C.TIME_UNSET && it > 0 }
        val dspStatus = nativeDspController.statusMap()
'''
new = '''    fun loudnessNormalizationStatusMap(): Map<String, Any?> = nativeDspController.statusMap()

    fun setChannelBalance(balance: Double): Map<String, Any?> {
        val safeBalance = balance.coerceIn(-1.0, 1.0)
        channelAudioState.setBalance(safeBalance)
        soundEnginePreferences.edit().putFloat(CHANNEL_BALANCE_KEY, safeBalance.toFloat()).apply()
        return channelAudioState.statusMap()
    }

    fun setMonoOutput(enabled: Boolean): Map<String, Any?> {
        channelAudioState.setMono(enabled)
        soundEnginePreferences.edit().putBoolean(MONO_OUTPUT_KEY, enabled).apply()
        return channelAudioState.statusMap()
    }

    fun channelAudioStatusMap(): Map<String, Any?> = channelAudioState.statusMap()

    fun metricsSnapshotMap(): Map<String, Any?> {
        val durationMs = currentTrack.durationMs ?: player.duration.takeIf { it != C.TIME_UNSET && it > 0 }
        val dspStatus = nativeDspController.statusMap()
        val channelStatus = channelAudioState.statusMap()
'''
if old not in text:
    raise SystemExit('manager sound controls block not found')
text = text.replace(old, new, 1)

old = '''            "loudnessEnhancerActive" to dspStatus["loudnessEnhancerActive"],
            "loudnessNormalizationMessage" to dspStatus["loudnessNormalizationMessage"],
        )
'''
new = '''            "loudnessEnhancerActive" to dspStatus["loudnessEnhancerActive"],
            "loudnessNormalizationMessage" to dspStatus["loudnessNormalizationMessage"],
            "channelBalance" to channelStatus["balance"],
            "monoOutputEnabled" to channelStatus["mono"],
            "channelPcmStereoConfigured" to channelStatus["pcmStereoConfigured"],
            "channelProcessorFormat" to channelStatus["channelProcessorFormat"],
        )
'''
if old not in text:
    raise SystemExit('manager metrics block not found')
text = text.replace(old, new, 1)

old = '''    private fun buildPrimaryPlayer(): ExoPlayer = ExoPlayer.Builder(appContext).build().also(::configurePrimaryPlayer)

    private fun buildPrebufferPlayer(): ExoPlayer = ExoPlayer.Builder(appContext).build().also(::configurePrebufferPlayer)
'''
new = '''    private fun buildPrimaryPlayer(): ExoPlayer = ExoPlayer.Builder(
        appContext,
        WaveZeroAudioRenderersFactory(appContext, channelAudioState),
    ).build().also(::configurePrimaryPlayer)

    private fun buildPrebufferPlayer(): ExoPlayer = ExoPlayer.Builder(
        appContext,
        WaveZeroAudioRenderersFactory(appContext, channelAudioState),
    ).build().also(::configurePrebufferPlayer)
'''
if old not in text:
    raise SystemExit('manager player builders not found')
text = text.replace(old, new, 1)

old = '''        const val SOUND_ENGINE_PREFS = "wavezero_sound_engine"
        const val LOUDNESS_NORMALIZATION_KEY = "loudness_normalization_enabled"
'''
new = '''        const val SOUND_ENGINE_PREFS = "wavezero_sound_engine"
        const val LOUDNESS_NORMALIZATION_KEY = "loudness_normalization_enabled"
        const val CHANNEL_BALANCE_KEY = "channel_balance"
        const val MONO_OUTPUT_KEY = "mono_output_enabled"
'''
if old not in text:
    raise SystemExit('manager companion keys not found')
text = text.replace(old, new, 1)
manager_path.write_text(text)

# ---- MainActivity MethodChannel ----
text = activity_path.read_text()
old = '''                "loudnessNormalizationStatus" -> result.success(audioPlayerManager.loudnessNormalizationStatusMap())

                "metricsSnapshot" -> result.success(audioPlayerManager.metricsSnapshotMap())
'''
new = '''                "loudnessNormalizationStatus" -> result.success(audioPlayerManager.loudnessNormalizationStatusMap())

                "setChannelBalance" -> {
                    val balance = call.argument<Number>("balance")?.toDouble() ?: 0.0
                    result.success(audioPlayerManager.setChannelBalance(balance))
                }

                "setMonoOutput" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(audioPlayerManager.setMonoOutput(enabled))
                }

                "channelAudioStatus" -> result.success(audioPlayerManager.channelAudioStatusMap())

                "metricsSnapshot" -> result.success(audioPlayerManager.metricsSnapshotMap())
'''
if old not in text:
    raise SystemExit('activity channel insertion point not found')
text = text.replace(old, new, 1)
activity_path.write_text(text)

# ---- Flutter Settings ----
text = settings_path.read_text()
old = '''                const SizedBox(height: WzSpacing.md),
                const _WzLoudnessNormalizationTile(),
              ],
'''
new = '''                const SizedBox(height: WzSpacing.md),
                const _WzLoudnessNormalizationTile(),
                const SizedBox(height: WzSpacing.md),
                const _WzChannelAudioControls(),
              ],
'''
if old not in text:
    raise SystemExit('settings playback insertion point not found')
text = text.replace(old, new, 1)

text += '''

class _WzChannelAudioControls extends StatefulWidget {
  const _WzChannelAudioControls();

  @override
  State<_WzChannelAudioControls> createState() => _WzChannelAudioControlsState();
}

class _WzChannelAudioControlsState extends State<_WzChannelAudioControls> {
  static const MethodChannel _channel = MethodChannel('wavezero/playback');
  double _balance = 0;
  bool _mono = false;
  bool _loading = true;
  bool _monoBusy = false;
  Timer? _balanceDebounce;
  String _status = 'Reading channel controls…';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _balanceDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('channelAudioStatus');
      if (!mounted) return;
      final rawBalance = result?['balance'];
      setState(() {
        _balance = rawBalance is num ? rawBalance.toDouble().clamp(-1.0, 1.0).toDouble() : 0;
        _mono = result?['mono'] == true;
        _status = _processorStatus(result);
        _loading = false;
      });
    } on MissingPluginException {
      if (mounted) setState(() {
        _loading = false;
        _status = 'Native channel controls are unavailable on this build.';
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() {
        _loading = false;
        _status = error.message ?? 'Could not read channel controls.';
      });
    }
  }

  void _onBalanceChanged(double value) {
    setState(() => _balance = value);
    _balanceDebounce?.cancel();
    _balanceDebounce = Timer(const Duration(milliseconds: 80), () {
      unawaited(_persistBalance(value));
    });
  }

  Future<void> _persistBalance(double value) async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'setChannelBalance',
        <String, Object?>{'balance': value},
      );
      if (!mounted) return;
      final rawBalance = result?['balance'];
      setState(() {
        if (rawBalance is num) _balance = rawBalance.toDouble().clamp(-1.0, 1.0).toDouble();
        _status = _processorStatus(result);
      });
    } on MissingPluginException {
      if (mounted) setState(() => _status = 'Native channel controls are unavailable on this build.');
    } on PlatformException catch (error) {
      if (mounted) setState(() => _status = error.message ?? 'Could not change balance.');
    }
  }

  Future<void> _setMono(bool enabled) async {
    if (_monoBusy) return;
    setState(() {
      _mono = enabled;
      _monoBusy = true;
    });
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'setMonoOutput',
        <String, Object?>{'enabled': enabled},
      );
      if (!mounted) return;
      setState(() {
        _mono = result?['mono'] == true;
        _status = _processorStatus(result);
      });
    } on MissingPluginException {
      if (mounted) setState(() {
        _mono = !enabled;
        _status = 'Native channel controls are unavailable on this build.';
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() {
        _mono = !enabled;
        _status = error.message ?? 'Could not change mono output.';
      });
    } finally {
      if (mounted) setState(() => _monoBusy = false);
    }
  }

  String _processorStatus(Map<Object?, Object?>? result) {
    if (result?['pcmStereoConfigured'] == true) {
      return 'Stereo PCM channel processing is active for the current playback path.';
    }
    return 'Saved. It will apply when playback uses a supported stereo PCM path.';
  }

  String get _balanceLabel {
    if (_balance.abs() < 0.025) return 'Center';
    final percent = (_balance.abs() * 100).round();
    return _balance < 0 ? 'Left $percent%' : 'Right $percent%';
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Channel output', style: WzText.sectionTitle),
          const SizedBox(height: WzSpacing.xs),
          Row(
            children: [
              const Icon(Icons.surround_sound, size: 20),
              const SizedBox(width: WzSpacing.xs),
              Expanded(child: Text('Balance · $_balanceLabel', style: WzText.body)),
            ],
          ),
          Slider(
            min: -1,
            max: 1,
            divisions: 40,
            value: _balance,
            label: _balanceLabel,
            onChanged: _loading ? null : _onBalanceChanged,
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('L', style: WzText.caption),
              Text('Center', style: WzText.caption),
              Text('R', style: WzText.caption),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mono output'),
            subtitle: const Text('Mixes left and right together, then sends the same signal to both stereo channels.'),
            value: _mono,
            onChanged: _loading || _monoBusy ? null : (value) => unawaited(_setMono(value)),
          ),
          Text(_status, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
        ],
      );
}
'''
settings_path.write_text(text)
