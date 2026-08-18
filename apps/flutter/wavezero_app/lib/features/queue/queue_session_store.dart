import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QueueSessionSnapshot {
  const QueueSessionSnapshot({
    required this.queueTrackIds,
    this.currentTrackId,
    this.selectedTrackId,
    this.autoAdvanceEnabled = true,
  });

  final List<String> queueTrackIds;
  final String? currentTrackId;
  final String? selectedTrackId;
  final bool autoAdvanceEnabled;

  String encode() {
    return jsonEncode(<String, Object?>{
      'queueTrackIds': queueTrackIds,
      'currentTrackId': currentTrackId,
      'selectedTrackId': selectedTrackId,
      'autoAdvanceEnabled': autoAdvanceEnabled,
    });
  }

  static QueueSessionSnapshot? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final ids = decoded['queueTrackIds'];
      return QueueSessionSnapshot(
        queueTrackIds: ids is List ? ids.whereType<String>().toList(growable: false) : const [],
        currentTrackId: decoded['currentTrackId'] is String ? decoded['currentTrackId'] as String : null,
        selectedTrackId: decoded['selectedTrackId'] is String ? decoded['selectedTrackId'] as String : null,
        autoAdvanceEnabled: decoded['autoAdvanceEnabled'] is bool ? decoded['autoAdvanceEnabled'] as bool : true,
      );
    } catch (_) {
      return null;
    }
  }
}

class QueueSessionStore {
  QueueSessionStore({SharedPreferences? preferences}) : _preferences = preferences;

  static const sessionKey = 'wavezero_queue_session_v1';

  SharedPreferences? _preferences;
  Future<void> _writeTail = Future<void>.value();

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<QueueSessionSnapshot?> load() async {
    await _writeTail;
    final raw = (await _prefs).getString(sessionKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return QueueSessionSnapshot.decode(raw);
  }

  Future<void> save(QueueSessionSnapshot snapshot) {
    final encoded = snapshot.encode();
    return _enqueueWrite(() async {
      await (await _prefs).setString(sessionKey, encoded);
    });
  }

  Future<void> clear() {
    return _enqueueWrite(() async {
      await (await _prefs).remove(sessionKey);
    });
  }

  Future<void> _enqueueWrite(Future<void> Function() write) {
    final result = _writeTail.then((_) => write());
    _writeTail = result.catchError((Object _) {});
    return result;
  }
}
