from pathlib import Path

root = Path('.')
manager_path = root / 'apps/android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt'
activity_path = root / 'apps/flutter/wavezero_app/android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt'
manifest_path = root / 'apps/flutter/wavezero_app/android/app/src/main/AndroidManifest.xml'
bridge_path = root / 'apps/flutter/wavezero_app/lib/playback/playback_bridge.dart'
app_path = root / 'apps/flutter/wavezero_app/lib/app/wavezero_app.dart'

manager = manager_path.read_text()

property_anchor = '    private var nativePrebufferStartedAtMs: Long? = null\n'
if 'private val nativeDspController = NativeDspController()' not in manager:
    if property_anchor not in manager:
        raise SystemExit('native prebuffer property anchor not found')
    manager = manager.replace(
        property_anchor,
        property_anchor + '    private val nativeDspController = NativeDspController()\n',
        1,
    )

analytics_anchor = '''    private val analyticsListener = object : AnalyticsListener {
        override fun onLoadCompleted(
'''
if 'override fun onAudioSessionIdChanged(' not in manager:
    if analytics_anchor not in manager:
        raise SystemExit('analytics listener anchor not found')
    replacement = '''    private val analyticsListener = object : AnalyticsListener {
        override fun onAudioSessionIdChanged(
            eventTime: AnalyticsListener.EventTime,
            audioSessionId: Int,
        ) {
            nativeDspController.onAudioSessionChanged(audioSessionId, player)
        }

        override fun onLoadCompleted(
'''
    manager = manager.replace(analytics_anchor, replacement, 1)

reset_anchor = '''    fun resetMetrics() {
        publish(metricsTracker.resetTransientMetrics())
        if (player.isPlaying) {
            publish(metricsTracker.markPlaying(player.currentPosition))
        } else {
            publish(metricsTracker.markNotPlaying(player.currentPosition))
        }
    }

'''
if 'fun setAudioEffectProfile(profile: NativeEqProfile)' not in manager:
    if reset_anchor not in manager:
        raise SystemExit('reset metrics anchor not found')
    sound_methods = reset_anchor + '''    fun setAudioEffectProfile(profile: NativeEqProfile): Map<String, Any?> {
        return nativeDspController.setProfile(profile, player).toMap() + mapOf(
            "profileId" to profile.id,
        )
    }

    fun audioEffectStatusMap(): Map<String, Any?> = nativeDspController.statusMap()

'''
    manager = manager.replace(reset_anchor, sound_methods, 1)

metrics_anchor = '''    fun metricsSnapshotMap(): Map<String, Any?> {
        val durationMs = currentTrack.durationMs ?: player.duration.takeIf { it != C.TIME_UNSET && it > 0 }
        return metricsTracker.snapshot().toMap() + mapOf(
'''
if 'val dspStatus = nativeDspController.statusMap()' not in manager:
    if metrics_anchor not in manager:
        raise SystemExit('metrics map anchor not found')
    manager = manager.replace(
        metrics_anchor,
        '''    fun metricsSnapshotMap(): Map<String, Any?> {
        val durationMs = currentTrack.durationMs ?: player.duration.takeIf { it != C.TIME_UNSET && it > 0 }
        val dspStatus = nativeDspController.statusMap()
        return metricsTracker.snapshot().toMap() + mapOf(
''',
        1,
    )

metrics_tail = '''            "mediaNotificationShown" to mediaNotificationShown,
            "currentTrackLoaded" to currentTrackLoaded,
        )
'''
if '"nativeAudioEffectStatus" to dspStatus["status"]' not in manager:
    if metrics_tail not in manager:
        raise SystemExit('metrics tail anchor not found')
    manager = manager.replace(
        metrics_tail,
        '''            "mediaNotificationShown" to mediaNotificationShown,
            "currentTrackLoaded" to currentTrackLoaded,
            "nativeAudioEffectStatus" to dspStatus["status"],
            "nativeAudioEffectProfileId" to dspStatus["profileId"],
            "nativeAudioEffectMessage" to dspStatus["message"],
            "nativeAudioEffectSessionId" to dspStatus["audioSessionId"],
        )
''',
        1,
    )

release_anchor = '''    fun release() {
        positionJob?.cancel()
        player.removeListener(playerListener)
'''
if 'nativeDspController.release()' not in manager:
    if release_anchor not in manager:
        raise SystemExit('release anchor not found')
    manager = manager.replace(
        release_anchor,
        '''    fun release() {
        positionJob?.cancel()
        nativeDspController.release()
        player.removeListener(playerListener)
''',
        1,
    )

primary_anchor = '''        exoPlayer.setHandleAudioBecomingNoisy(true)
        exoPlayer.volume = 1f
    }
'''
if 'nativeDspController.onPrimaryPlayerChanged(exoPlayer)' not in manager:
    if primary_anchor not in manager:
        raise SystemExit('primary config anchor not found')
    manager = manager.replace(
        primary_anchor,
        '''        exoPlayer.setHandleAudioBecomingNoisy(true)
        exoPlayer.volume = 1f
        nativeDspController.onPrimaryPlayerChanged(exoPlayer)
    }
''',
        1,
    )

manager_path.write_text(manager)

activity = activity_path.read_text()
if 'import com.wavezero.player.playback.NativeEqProfile\n' not in activity:
    activity = activity.replace(
        'import com.wavezero.player.playback.NotificationTrackSnapshot\n',
        'import com.wavezero.player.playback.NotificationTrackSnapshot\nimport com.wavezero.player.playback.NativeEqProfile\n',
        1,
    )

old_handler = '''                "setAudioEffectProfile" -> {
                    val profileId = call.argument<String>("id").orEmpty()
                    if (profileId == "off") {
                        result.success(
                            mapOf(
                                "status" to "off",
                                "message" to "Audio effects are off; native playback remains original/no-effect.",
                            ),
                        )
                        return
                    }

                    result.success(
                        mapOf(
                            "status" to "unsupported",
                            "message" to "Native Android DSP is not enabled in this safe foundation build; profile ${profileId.ifBlank { "unknown" }} is stored for diagnostics only.",
                        ),
                    )
                }

'''
if 'NativeEqProfile(' not in activity:
    if old_handler not in activity:
        raise SystemExit('old audio effect handler not found')
    new_handler = '''                "setAudioEffectProfile" -> {
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
    activity = activity.replace(old_handler, new_handler, 1)
activity_path.write_text(activity)

manifest = manifest_path.read_text()
permission = '    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />\n'
if permission not in manifest:
    manifest = manifest.replace(
        '    <uses-permission android:name="android.permission.INTERNET" />\n',
        '    <uses-permission android:name="android.permission.INTERNET" />\n' + permission,
        1,
    )
manifest_path.write_text(manifest)

bridge = bridge_path.read_text()
abstract_anchor = '''  Future<AudioEffectApplyResult> setAudioEffectProfile(AudioEffectProfile profile);

  Future<PlaybackMetrics> metricsSnapshot();
'''
if 'Future<AudioEffectApplyResult> audioEffectStatus();' not in bridge:
    if abstract_anchor not in bridge:
        raise SystemExit('playback bridge abstract anchor not found')
    bridge = bridge.replace(
        abstract_anchor,
        '''  Future<AudioEffectApplyResult> setAudioEffectProfile(AudioEffectProfile profile);

  Future<AudioEffectApplyResult> audioEffectStatus();

  Future<PlaybackMetrics> metricsSnapshot();
''',
        1,
    )

platform_anchor = '''  @override
  Future<PlaybackMetrics> metricsSnapshot() async {
'''
if "'audioEffectStatus'" not in bridge:
    if platform_anchor not in bridge:
        raise SystemExit('platform metrics anchor not found')
    status_method = '''  @override
  Future<AudioEffectApplyResult> audioEffectStatus() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('audioEffectStatus');
      _lastBridgeError = null;
      return AudioEffectApplyResult.fromJson(result ?? const <Object?, Object?>{});
    } on MissingPluginException catch (error) {
      final message = 'Android audio effects bridge is not available: $error';
      _lastBridgeError = message;
      return AudioEffectApplyResult.unsupported(message);
    } on PlatformException catch (error) {
      final message = 'Android audio effects status error: ${error.message ?? error.code}';
      _lastBridgeError = message;
      return AudioEffectApplyResult.failed(message);
    }
  }

'''
    bridge = bridge.replace(platform_anchor, status_method + platform_anchor, 1)

mock_anchor = '''  @override
  Future<AudioEffectApplyResult> setAudioEffectProfile(AudioEffectProfile profile) async {
    if (profile == AudioEffectProfile.off) {
      return AudioEffectApplyResult.off('Mock bridge accepted Off / Original; no native DSP is active.');
    }
    return AudioEffectApplyResult.unsupported(
      'Mock bridge accepted ${profile.label}; no native DSP is active in mock playback.',
    );
  }
'''
if bridge.count('Future<AudioEffectApplyResult> audioEffectStatus()') < 2:
    if mock_anchor not in bridge:
        raise SystemExit('mock audio effect anchor not found')
    bridge = bridge.replace(
        mock_anchor,
        mock_anchor + '''

  @override
  Future<AudioEffectApplyResult> audioEffectStatus() async {
    return AudioEffectApplyResult.off('Mock playback has no native DSP session.');
  }
''',
        1,
    )
bridge_path.write_text(bridge)

app = app_path.read_text()
refresh_anchor = '''      setState(() {
        _metrics = next;
        _capturePlaybackBaselineMetrics(next);
        _alignQueueWithNativeNotificationAction(next);
      });
      if (allowAutoAdvance) await _maybeAutoAdvance(next);
'''
if 'await widget.playbackBridge.audioEffectStatus()' not in app:
    if refresh_anchor not in app:
        raise SystemExit('refresh metrics anchor not found')
    app = app.replace(
        refresh_anchor,
        '''      setState(() {
        _metrics = next;
        _capturePlaybackBaselineMetrics(next);
        _alignQueueWithNativeNotificationAction(next);
      });
      if (_selectedAudioEffectProfile != AudioEffectProfile.off &&
          _nativeAudioEffectStatus == NativeAudioEffectStatus.pending) {
        final effectStatus = await widget.playbackBridge.audioEffectStatus();
        if (mounted && effectStatus.status != NativeAudioEffectStatus.pending) {
          setState(() {
            _nativeAudioEffectStatus = effectStatus.status;
            _lastAudioEffectApplyResult = effectStatus.message;
          });
        }
      }
      if (allowAutoAdvance) await _maybeAutoAdvance(next);
''',
        1,
    )
app_path.write_text(app)
