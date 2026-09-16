import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WzCustomEqBand {
  const WzCustomEqBand({
    required this.frequencyHz,
    required this.gainDb,
  });

  final int frequencyHz;
  final double gainDb;

  WzCustomEqBand copyWith({double? gainDb}) => WzCustomEqBand(
        frequencyHz: frequencyHz,
        gainDb: gainDb ?? this.gainDb,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'frequencyHz': frequencyHz,
        'gainDb': gainDb,
      };
}

class WzCustomEqualizerPage extends StatefulWidget {
  const WzCustomEqualizerPage({
    required this.onActivated,
    super.key,
  });

  final VoidCallback onActivated;

  @override
  State<WzCustomEqualizerPage> createState() => _WzCustomEqualizerPageState();
}

class _WzCustomEqualizerPageState extends State<WzCustomEqualizerPage> {
  static const MethodChannel _channel = MethodChannel('wavezero/playback');
  static const List<int> _frequencies = <int>[
    31,
    62,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  List<WzCustomEqBand> _bands = _flatBands();
  bool _loading = true;
  bool _applying = false;
  String _status = 'Loading your custom curve…';

  static List<WzCustomEqBand> _flatBands() => _frequencies
      .map((frequencyHz) => WzCustomEqBand(frequencyHz: frequencyHz, gainDb: 0))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'customEqualizerSettings',
      );
      final rawBands = result?['bands'];
      if (rawBands is List) {
        final byFrequency = <int, double>{};
        for (final raw in rawBands) {
          if (raw is! Map) continue;
          final frequency = raw['frequencyHz'];
          final gain = raw['gainDb'];
          if (frequency is num && gain is num) {
            byFrequency[frequency.toInt()] = gain.toDouble().clamp(-6.0, 6.0);
          }
        }
        _bands = _frequencies
            .map(
              (frequencyHz) => WzCustomEqBand(
                frequencyHz: frequencyHz,
                gainDb: byFrequency[frequencyHz] ?? 0,
              ),
            )
            .toList(growable: false);
      }
      _status = 'Custom EQ is ready. Changes apply only when you tap Apply.';
    } on MissingPluginException {
      _status = 'Native custom EQ is unavailable on this build.';
    } on PlatformException catch (error) {
      _status = error.message ?? 'Could not load the custom EQ.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _preampGainDb {
    final maxBoost = _bands.fold<double>(
      0,
      (value, band) => math.max(value, band.gainDb),
    );
    return -maxBoost;
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() {
      _applying = true;
      _status = 'Applying custom EQ…';
    });
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'setCustomEqualizer',
        <String, Object?>{
          'bands': _bands.map((band) => band.toJson()).toList(growable: false),
          'preampGainDb': _preampGainDb,
        },
      );
      final message = result?['message'];
      if (!mounted) return;
      widget.onActivated();
      setState(() {
        _status = message is String && message.trim().isNotEmpty
            ? message
            : 'Custom EQ applied.';
      });
    } on MissingPluginException {
      if (mounted) setState(() => _status = 'Native custom EQ is unavailable on this build.');
    } on PlatformException catch (error) {
      if (mounted) setState(() => _status = error.message ?? 'Custom EQ could not be applied.');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _reset() {
    setState(() {
      _bands = _flatBands();
      _status = 'Curve reset to flat. Tap Apply to send it to the sound engine.';
    });
  }

  String _frequencyLabel(int frequencyHz) {
    if (frequencyHz >= 1000) {
      final value = frequencyHz / 1000;
      return value == value.roundToDouble() ? '${value.toInt()}k' : '${value.toStringAsFixed(1)}k';
    }
    return '$frequencyHz';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom EQ'),
        actions: [
          TextButton(
            onPressed: _loading || _applying ? null : _reset,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Shape WaveZero’s native Android EQ',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Ten control points are mapped onto the EQ bands exposed by this device. WaveZero automatically adds ${_preampGainDb.toStringAsFixed(1)} dB of headroom for the strongest boost.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else
              ...List<Widget>.generate(_bands.length, (index) {
                final band = _bands[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          _frequencyLabel(band.frequencyHz),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          min: -6,
                          max: 6,
                          divisions: 24,
                          value: band.gainDb,
                          label: '${band.gainDb >= 0 ? '+' : ''}${band.gainDb.toStringAsFixed(1)} dB',
                          onChanged: _applying
                              ? null
                              : (value) {
                                  setState(() {
                                    final next = List<WzCustomEqBand>.of(_bands);
                                    next[index] = band.copyWith(gainDb: value);
                                    _bands = next;
                                  });
                                },
                        ),
                      ),
                      SizedBox(
                        width: 58,
                        child: Text(
                          '${band.gainDb >= 0 ? '+' : ''}${band.gainDb.toStringAsFixed(1)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading || _applying ? null : _apply,
              icon: _applying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.graphic_eq),
              label: Text(_applying ? 'Applying…' : 'Apply custom EQ'),
            ),
            const SizedBox(height: 12),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Text(
              'Flat (all 0 dB) keeps the EQ curve neutral. Off / Original in Playback settings still disables the native equalizer completely.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
