import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_vault_models.dart';

class CloudVaultService {
  const CloudVaultService();

  static const storageKey = 'wavezero.cloud_vault.tracks.v1';
  static const corruptionBackupKey = 'wavezero.cloud_vault.tracks.v1.corrupt_backup';

  Future<List<CloudVaultTrack>> listTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const <CloudVaultTrack>[];
    try {
      return decodeCloudVaultTracks(raw);
    } catch (_) {
      await prefs.setString(corruptionBackupKey, raw);
      await prefs.remove(storageKey);
      return const <CloudVaultTrack>[];
    }
  }

  Future<List<CloudVaultTrack>> addTrack(CloudVaultTrack track) async {
    final current = await listTracks();
    final next = <CloudVaultTrack>[
      track,
      ...current.where((item) => item.cloudTrackId != track.cloudTrackId),
    ];
    await _save(next);
    return next;
  }

  Future<List<CloudVaultTrack>> removeTrack(String cloudTrackId) async {
    final current = await listTracks();
    final next = current.where((track) => track.cloudTrackId != cloudTrackId).toList(growable: false);
    await _save(next);
    return next;
  }

  Future<List<CloudVaultTrack>> markPlayed(String cloudTrackId, int playedAtMs) async {
    final current = await listTracks();
    final next = current
        .map((track) => track.cloudTrackId == cloudTrackId ? track.copyWith(lastPlayedAtMs: playedAtMs) : track)
        .toList(growable: false);
    await _save(next);
    return next;
  }

  Future<void> clearTracks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  Future<void> _save(List<CloudVaultTrack> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, encodeCloudVaultTracks(tracks));
  }
}
