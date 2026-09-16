import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/wavezero_design_system.dart';

class WzCrossfadeControls extends StatefulWidget {
  const WzCrossfadeControls({super.key});

  @override
  State<WzCrossfadeControls> createState() => _WzCrossfadeControlsState();
}

class _WzCrossfadeControlsState extends State<WzCrossfadeControls> {
  static const MethodChannel _channel = MethodChannel('wavezero/playback');
  static const List<int> _durationsMs = <int>[0, 2000, 4000, 6000];

  int _durationMs = 0;
  bool _busy = true;
  String _status = 'Reading transition settings…';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('crossfadeStatus');
      if (!mounted) return;
      setState(() {
        _durationMs = _readDuration(result);
        _status = _statusText(result);
        _busy = false;
      });
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _durationMs = 0;
          _busy = false;
          _status = 'Native crossfade is unavailable on this build.';
        });
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = error.message ?? 'Could not read crossfade settings.';
        });
      }
    }
  }

  Future<void> _setDuration(int durationMs) async {
    if (_busy || !_durationsMs.contains(durationMs)) return;
    final previous = _durationMs;
    setState(() {
      _busy = true;
      _durationMs = durationMs;
      _status = durationMs == 0 ? 'Turning crossfade off…' : 'Saving ${durationMs ~/ 1000}s crossfade…';
    });
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'setCrossfadeDuration',
        <String, Object?>{'durationMs': durationMs},
      );
      if (!mounted) return;
      setState(() {
        _durationMs = _readDuration(result);
        _status = _statusText(result);
      });
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _durationMs = previous;
          _status = 'Native crossfade is unavailable on this build.';
        });
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _durationMs = previous;
          _status = error.message ?? 'Could not change crossfade duration.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _readDuration(Map<Object?, Object?>? result) {
    final raw = result?['durationMs'];
    final duration = raw is num ? raw.toInt() : 0;
    return _durationsMs.contains(duration) ? duration : 0;
  }

  String _statusText(Map<Object?, Object?>? result) {
    final duration = _readDuration(result);
    if (duration == 0) {
      return 'Off. Natural track changes use the prepared minimal-gap handoff.';
    }
    return '${duration ~/ 1000}s on natural auto-advance. Manual Next / Previous stay immediate.';
  }

  String _label(int durationMs) => durationMs == 0 ? 'Off' : '${durationMs ~/ 1000}s';

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Crossfade', style: WzText.sectionTitle),
          const SizedBox(height: WzSpacing.xs),
          const Text(
            'Overlaps the already-prepared next track near the natural end. EQ, ReplayGain, balance, and mono stay in the same sound-engine path.',
            style: WzText.caption,
          ),
          const SizedBox(height: WzSpacing.sm),
          Wrap(
            spacing: WzSpacing.xs,
            runSpacing: WzSpacing.xs,
            children: _durationsMs
                .map(
                  (duration) => ChoiceChip(
                    label: Text(_label(duration)),
                    selected: _durationMs == duration,
                    onSelected: _busy ? null : (_) => unawaited(_setDuration(duration)),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: WzSpacing.xs),
          Text(_status, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
        ],
      );
}
