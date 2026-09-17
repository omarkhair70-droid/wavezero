import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/wavezero_design_system.dart';

class WzHandsFreeControls extends StatefulWidget {
  const WzHandsFreeControls({super.key});

  @override
  State<WzHandsFreeControls> createState() => _WzHandsFreeControlsState();
}

class _WzHandsFreeControlsState extends State<WzHandsFreeControls>
    with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('wavezero/handsfree');

  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  bool _microphoneGranted = false;
  bool _recognitionAvailable = true;
  bool _onDeviceRecognitionAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('status');
      if (!mounted) return;
      setState(() {
        _enabled = result?['enabled'] == true;
        _microphoneGranted = result?['microphoneGranted'] == true;
        _recognitionAvailable = result?['recognitionAvailable'] != false;
        _onDeviceRecognitionAvailable = result?['onDeviceRecognitionAvailable'] == true;
        _loading = false;
        _error = null;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _recognitionAvailable = false;
        _error = 'Hands-free controls are only available in the Android app.';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message ?? error.code;
      });
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      if (!enabled) _enabled = false;
    });
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'setEnabled',
        <String, Object?>{'enabled': enabled},
      );
      if (!mounted) return;
      setState(() {
        _enabled = enabled && (result?['startRequested'] == true || result?['enabled'] == true);
        _microphoneGranted = result?['microphoneGranted'] == true;
        _recognitionAvailable = result?['recognitionAvailable'] != false;
        _onDeviceRecognitionAvailable = result?['onDeviceRecognitionAvailable'] == true;
      });
      if (enabled) {
        unawaited(Future<void>.delayed(const Duration(milliseconds: 450), _refresh));
        unawaited(Future<void>.delayed(const Duration(milliseconds: 1200), _refresh));
      } else {
        unawaited(Future<void>.delayed(const Duration(milliseconds: 250), _refresh));
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message ?? error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _statusText {
    if (_loading) return 'Checking Android voice service…';
    if (!_recognitionAvailable) return 'Speech recognition is not available on this device.';
    if (_enabled) {
      return _onDeviceRecognitionAvailable
          ? 'Listening locally for “Wave Zero”. On-device speech is available.'
          : 'Listening for “Wave Zero”. Android speech recognition fallback is active.';
    }
    if (!_microphoneGranted) {
      return 'Turn this on once to allow microphone access, then WaveZero can listen while the screen is off.';
    }
    return 'Off. Turn it on when you want WaveZero to behave like a hands-free music device.';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled && _recognitionAvailable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WzSculptedIcon(
                icon: Icons.graphic_eq_rounded,
                size: 42,
                iconSize: 18,
                color: enabled ? WzColors.accent : WzColors.textPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hands-free WaveZero',
                      style: WzText.sectionTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _statusText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: WzText.caption,
                    ),
                  ],
                ),
              ),
              if (_loading || _busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Switch.adaptive(
                  value: _enabled,
                  onChanged: _recognitionAvailable ? _setEnabled : null,
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: WzText.caption.copyWith(color: WzColors.danger),
            ),
          ],
          if (_enabled) ...[
            const SizedBox(height: 9),
            Text(
              'Try: “Wave Zero, وطي الصوت” · “ارجع عشر ثواني” · “احفظ الحتة دي باسم البداية”',
              style: WzText.caption,
            ),
          ],
        ],
      ),
    );
  }
}
