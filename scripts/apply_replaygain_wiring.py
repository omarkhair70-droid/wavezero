from pathlib import Path

root = Path('.')
manager_path = root / 'apps/android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt'
activity_path = root / 'apps/flutter/wavezero_app/android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt'
settings_path = root / 'apps/flutter/wavezero_app/lib/features/settings/settings_page.dart'

# ---- AudioPlayerManager ----
text = manager_path.read_text()
text = text.replace(
    'import androidx.media3.common.MediaMetadata\n',
    'import androidx.media3.common.MediaMetadata\nimport androidx.media3.common.Metadata\nimport androidx.media3.common.Tracks\n',
)
text = text.replace(
    '    private val appContext = context.applicationContext\n\n    private var player: ExoPlayer = buildPrimaryPlayer()\n',
    '    private val appContext = context.applicationContext\n    private val soundEnginePreferences = appContext.getSharedPreferences(SOUND_ENGINE_PREFS, Context.MODE_PRIVATE)\n    private var loudnessNormalizationEnabled = soundEnginePreferences.getBoolean(LOUDNESS_NORMALIZATION_KEY, false)\n\n    private var player: ExoPlayer = buildPrimaryPlayer()\n',
)
listener_marker = '''        override fun onPlayerError(error: PlaybackException) {
'''
listener_insert = '''        override fun onTracksChanged(tracks: Tracks) {
            applyReplayGainFromTracks(tracks)
        }

        override fun onMetadata(metadata: Metadata) {
            ReplayGainMetadata.parse(metadata)?.let { info ->
                nativeDspController.setReplayGain(info, player)
            }
        }

'''
if listener_marker not in text:
    raise SystemExit('player listener marker missing')
text = text.replace(listener_marker, listener_insert + listener_marker, 1)
text = text.replace(
    '''        player.addAnalyticsListener(analyticsListener)
        prebufferPlayer.addListener(prebufferListener)
    }
''',
    '''        player.addAnalyticsListener(analyticsListener)
        prebufferPlayer.addListener(prebufferListener)
        nativeDspController.setLoudnessNormalizationEnabled(loudnessNormalizationEnabled, player)
    }
''',
    1,
)
text = text.replace(
    '''    fun loadTrack(track: NotificationTrackSnapshot) {
        clearNativePrebuffer(NativePrebufferClearReason.TrackLoaded)
        applyCurrentTrack(track)
''',
    '''    fun loadTrack(track: NotificationTrackSnapshot) {
        clearNativePrebuffer(NativePrebufferClearReason.TrackLoaded)
        nativeDspController.clearReplayGain(player)
        applyCurrentTrack(track)
''',
    1,
)
text = text.replace(
    '''    fun retry() {
        softStopped = false
        clearNativePrebuffer(NativePrebufferClearReason.Retry)
        player.stop()
''',
    '''    fun retry() {
        softStopped = false
        clearNativePrebuffer(NativePrebufferClearReason.Retry)
        nativeDspController.clearReplayGain(player)
        player.stop()
''',
    1,
)
text = text.replace(
    '''    fun audioEffectStatusMap(): Map<String, Any?> = nativeDspController.statusMap()

    fun metricsSnapshotMap(): Map<String, Any?> {
''',
    '''    fun audioEffectStatusMap(): Map<String, Any?> = nativeDspController.statusMap()

    fun setLoudnessNormalizationEnabled(enabled: Boolean): Map<String, Any?> {
        loudnessNormalizationEnabled = enabled
        soundEnginePreferences.edit().putBoolean(LOUDNESS_NORMALIZATION_KEY, enabled).apply()
        return nativeDspController.setLoudnessNormalizationEnabled(enabled, player)
    }

    fun loudnessNormalizationStatusMap(): Map<String, Any?> = nativeDspController.statusMap()

    fun metricsSnapshotMap(): Map<String, Any?> {
''',
    1,
)
text = text.replace(
    '''            "nativeAudioEffectSessionId" to dspStatus["audioSessionId"],
        )
''',
    '''            "nativeAudioEffectSessionId" to dspStatus["audioSessionId"],
            "loudnessNormalizationEnabled" to dspStatus["loudnessNormalizationEnabled"],
            "replayGainTrackDb" to dspStatus["replayGainTrackDb"],
            "replayGainAlbumDb" to dspStatus["replayGainAlbumDb"],
            "appliedNormalizationGainDb" to dspStatus["appliedNormalizationGainDb"],
            "loudnessEnhancerActive" to dspStatus["loudnessEnhancerActive"],
            "loudnessNormalizationMessage" to dspStatus["loudnessNormalizationMessage"],
        )
''',
    1,
)
text = text.replace(
    '''        preparedPlayer.removeListener(prebufferListener)
        configurePrimaryPlayer(preparedPlayer)
''',
    '''        nativeDspController.clearReplayGain(previousPrimaryPlayer)
        preparedPlayer.removeListener(prebufferListener)
        configurePrimaryPlayer(preparedPlayer)
''',
    1,
)
text = text.replace(
    '''        mediaSession?.setPlayer(player)

        publish(metricsTracker.loadTrack(currentTrackTitle, currentHlsUrl))
''',
    '''        mediaSession?.setPlayer(player)
        applyReplayGainFromTracks(player.currentTracks)

        publish(metricsTracker.loadTrack(currentTrackTitle, currentHlsUrl))
''',
    1,
)
helper_marker = '''    private fun ensureCurrentMediaItemLoaded() {
'''
helpers = '''    private fun applyReplayGainFromTracks(tracks: Tracks) {
        for (group in tracks.groups) {
            if (group.type != C.TRACK_TYPE_AUDIO || !group.isSelected) continue
            for (index in 0 until group.length) {
                if (!group.isTrackSelected(index)) continue
                val info = ReplayGainMetadata.parse(group.getTrackFormat(index).metadata) ?: continue
                nativeDspController.setReplayGain(info, player)
                return
            }
        }
    }

'''
if helper_marker not in text:
    raise SystemExit('helper marker missing')
text = text.replace(helper_marker, helpers + helper_marker, 1)
text = text.replace(
    '''    private companion object {
        const val POSITION_UPDATE_MS = 250L
        const val MEDIA_SESSION_ID = "wavezero-playback"
    }
''',
    '''    private companion object {
        const val POSITION_UPDATE_MS = 250L
        const val MEDIA_SESSION_ID = "wavezero-playback"
        const val SOUND_ENGINE_PREFS = "wavezero_sound_engine"
        const val LOUDNESS_NORMALIZATION_KEY = "loudness_normalization_enabled"
    }
''',
    1,
)
manager_path.write_text(text)

# ---- MainActivity channel ----
text = activity_path.read_text()
text = text.replace(
    '''                "audioEffectStatus" -> result.success(audioPlayerManager.audioEffectStatusMap())

                "metricsSnapshot" -> result.success(audioPlayerManager.metricsSnapshotMap())
''',
    '''                "audioEffectStatus" -> result.success(audioPlayerManager.audioEffectStatusMap())

                "setLoudnessNormalizationEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(audioPlayerManager.setLoudnessNormalizationEnabled(enabled))
                }

                "loudnessNormalizationStatus" -> result.success(audioPlayerManager.loudnessNormalizationStatusMap())

                "metricsSnapshot" -> result.success(audioPlayerManager.metricsSnapshotMap())
''',
    1,
)
activity_path.write_text(text)

# ---- Settings UI ----
text = settings_path.read_text()
text = text.replace(
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n",
    1,
)
text = text.replace(
    '''                Text('Off / Original disables native EQ completely. $lastAudioEffectApplyResult', maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.caption),
              ],
''',
    '''                Text('Off / Original disables native EQ completely. $lastAudioEffectApplyResult', maxLines: 3, overflow: TextOverflow.ellipsis, style: WzText.caption),
                const SizedBox(height: WzSpacing.md),
                const _WzLoudnessNormalizationTile(),
              ],
''',
    1,
)
text += '''

class _WzLoudnessNormalizationTile extends StatefulWidget {
  const _WzLoudnessNormalizationTile();

  @override
  State<_WzLoudnessNormalizationTile> createState() => _WzLoudnessNormalizationTileState();
}

class _WzLoudnessNormalizationTileState extends State<_WzLoudnessNormalizationTile> {
  static const MethodChannel _channel = MethodChannel('wavezero/playback');
  bool _enabled = false;
  bool _busy = true;
  String _message = 'Reading ReplayGain normalization status…';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('loudnessNormalizationStatus');
      if (!mounted) return;
      setState(() {
        _enabled = result?['loudnessNormalizationEnabled'] == true;
        _message = (result?['loudnessNormalizationMessage'] as String?) ??
            'ReplayGain normalization is ready.';
        _busy = false;
      });
    } on MissingPluginException {
      if (mounted) setState(() {
        _busy = false;
        _message = 'Native loudness normalization is unavailable on this build.';
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() {
        _busy = false;
        _message = error.message ?? 'Could not read loudness normalization status.';
      });
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _enabled = enabled;
      _message = enabled ? 'Enabling ReplayGain normalization…' : 'Turning normalization off…';
    });
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'setLoudnessNormalizationEnabled',
        <String, Object?>{'enabled': enabled},
      );
      if (!mounted) return;
      setState(() {
        _enabled = result?['loudnessNormalizationEnabled'] == true;
        _message = (result?['loudnessNormalizationMessage'] as String?) ??
            (_enabled ? 'ReplayGain normalization is on.' : 'Loudness normalization is off.');
      });
    } on MissingPluginException {
      if (mounted) setState(() {
        _enabled = false;
        _message = 'Native loudness normalization is unavailable on this build.';
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() {
        _enabled = !enabled;
        _message = error.message ?? 'Could not change loudness normalization.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Loudness normalization'),
            subtitle: const Text('Uses ReplayGain tags when tracks provide them. Untagged music stays at its original level.'),
            value: _enabled,
            onChanged: _busy ? null : (value) => unawaited(_setEnabled(value)),
          ),
          Text(_message, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
        ],
      );
}
'''
settings_path.write_text(text)
