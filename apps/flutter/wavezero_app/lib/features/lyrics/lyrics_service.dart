import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'lyrics_models.dart';

const String waveZeroLyricsPreferenceKey = 'wavezero.lyrics.v1';

class WzLyricsService {
  WzLyricsService({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;
  Future<void> _mutationTail = Future<void>.value();

  Future<SharedPreferences> get _prefs async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  Future<Map<String, WzLyricsDocument>> loadAll() async {
    await _mutationTail;
    return _loadNow();
  }

  Future<Map<String, WzLyricsDocument>> save({
    required String trackId,
    required String rawText,
  }) {
    final normalizedTrackId = trackId.trim();
    final normalizedText = rawText.trim();
    return _enqueueMutation(() async {
      final current = await _loadNow();
      if (normalizedTrackId.isEmpty) return current;
      final next = Map<String, WzLyricsDocument>.of(current);
      if (normalizedText.isEmpty) {
        next.remove(normalizedTrackId);
      } else {
        next[normalizedTrackId] = WzLyricsDocument(
          trackId: normalizedTrackId,
          rawText: normalizedText,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
      }
      await _saveNow(next);
      return next;
    });
  }

  Future<Map<String, WzLyricsDocument>> remove(String trackId) {
    final normalizedTrackId = trackId.trim();
    return _enqueueMutation(() async {
      final current = await _loadNow();
      if (normalizedTrackId.isEmpty || !current.containsKey(normalizedTrackId)) {
        return current;
      }
      final next = Map<String, WzLyricsDocument>.of(current)
        ..remove(normalizedTrackId);
      await _saveNow(next);
      return next;
    });
  }

  Future<Map<String, WzLyricsDocument>> _loadNow() async {
    final prefs = await _prefs;
    final raw = prefs.getString(waveZeroLyricsPreferenceKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <String, WzLyricsDocument>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, WzLyricsDocument>{};
      final entries = decoded['entries'];
      if (entries is! List) return const <String, WzLyricsDocument>{};
      final next = <String, WzLyricsDocument>{};
      for (final value in entries) {
        if (value is! Map) continue;
        try {
          final document = WzLyricsDocument.fromJson(
            value.cast<String, Object?>(),
          );
          next[document.trackId] = document;
        } catch (_) {
          // Ignore malformed local entries instead of breaking the player.
        }
      }
      return Map<String, WzLyricsDocument>.unmodifiable(next);
    } catch (_) {
      return const <String, WzLyricsDocument>{};
    }
  }

  Future<void> _saveNow(Map<String, WzLyricsDocument> documents) async {
    final prefs = await _prefs;
    final entries = documents.values.toList(growable: false)
      ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    await prefs.setString(
      waveZeroLyricsPreferenceKey,
      jsonEncode(<String, Object?>{
        'version': 1,
        'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
      }),
    );
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
