import 'package:flutter/material.dart';

import 'lyrics_models.dart';
import 'lyrics_panel.dart';
import 'lyrics_service.dart';

class WzLocalLyricsPanel extends StatefulWidget {
  const WzLocalLyricsPanel({
    super.key,
    required this.trackId,
    required this.trackTitle,
    required this.positionMs,
    required this.hasTrack,
    this.service,
  });

  final String? trackId;
  final String trackTitle;
  final int positionMs;
  final bool hasTrack;
  final WzLyricsService? service;

  @override
  State<WzLocalLyricsPanel> createState() => _WzLocalLyricsPanelState();
}

class _WzLocalLyricsPanelState extends State<WzLocalLyricsPanel> {
  late final WzLyricsService _service;
  WzLyricsDocument? _document;
  int _loadGeneration = 0;

  String? get _stableTrackId {
    final value = widget.trackId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? WzLyricsService();
    _loadForTrack();
  }

  @override
  void didUpdateWidget(covariant WzLocalLyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId) _loadForTrack();
  }

  Future<void> _loadForTrack() async {
    final generation = ++_loadGeneration;
    final trackId = _stableTrackId;
    if (trackId == null) {
      if (mounted) setState(() => _document = null);
      return;
    }
    final documents = await _service.loadAll();
    if (!mounted || generation != _loadGeneration) return;
    setState(() => _document = documents[trackId]);
  }

  Future<void> _save(String text) async {
    final trackId = _stableTrackId;
    if (trackId == null) return;
    final next = await _service.save(trackId: trackId, rawText: text);
    if (!mounted || _stableTrackId != trackId) return;
    setState(() => _document = next[trackId]);
  }

  Future<void> _remove() async {
    final trackId = _stableTrackId;
    if (trackId == null) return;
    await _service.remove(trackId);
    if (!mounted || _stableTrackId != trackId) return;
    setState(() => _document = null);
  }

  void _openEditor() {
    final trackId = _stableTrackId;
    if (trackId == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => WzLyricsEditorSheet(
        trackTitle: widget.trackTitle,
        initialText: _document?.rawText ?? '',
        onSave: _save,
        onDelete: _remove,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WzLyricsPanel(
        document: _document,
        positionMs: widget.positionMs,
        hasTrack: widget.hasTrack && _stableTrackId != null,
        onEdit: _stableTrackId == null ? null : _openEditor,
        onClear: _document == null ? null : _remove,
      );
}
