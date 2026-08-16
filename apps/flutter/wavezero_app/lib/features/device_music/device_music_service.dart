import 'package:flutter/services.dart';

import 'device_music_track.dart';

class DeviceMusicPermissionStatus {
  const DeviceMusicPermissionStatus({
    required this.status,
    this.permission,
    this.permanentlyDenied = false,
    this.platformSupported = true,
    this.message,
  });

  final String status;
  final String? permission;
  final bool permanentlyDenied;
  final bool platformSupported;
  final String? message;

  bool get isGranted => status == 'granted';

  factory DeviceMusicPermissionStatus.fromJson(Map<Object?, Object?> json) {
    return DeviceMusicPermissionStatus(
      status: _readString(json['status']) ?? 'unknown',
      permission: _readString(json['permission']),
      permanentlyDenied: json['permanentlyDenied'] == true,
      platformSupported: json['platformSupported'] != false,
      message: _readString(json['message']),
    );
  }
}

class DeviceMusicScanResult {
  const DeviceMusicScanResult({
    required this.status,
    required this.tracks,
    this.count = 0,
    this.limit,
    this.error,
    this.scannedAtMs,
    this.platformSupported = true,
  });

  final String status;
  final List<DeviceMusicTrack> tracks;
  final int count;
  final int? limit;
  final String? error;
  final int? scannedAtMs;
  final bool platformSupported;

  factory DeviceMusicScanResult.fromJson(Map<Object?, Object?> json) {
    final rawTracks = json['tracks'];
    final tracks = rawTracks is List
        ? rawTracks
            .whereType<Map>()
            .map((track) => DeviceMusicTrack.fromJson(track.cast<Object?, Object?>()))
            .toList(growable: false)
        : const <DeviceMusicTrack>[];
    return DeviceMusicScanResult(
      status: _readString(json['status']) ?? 'unknown',
      tracks: tracks,
      count: _readInt(json['count']) ?? tracks.length,
      limit: _readInt(json['limit']),
      error: _readString(json['error']),
      scannedAtMs: _readInt(json['scannedAtMs']),
      platformSupported: json['platformSupported'] != false,
    );
  }
}

class DeviceMusicService {
  DeviceMusicService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('wavezero/playback');

  final MethodChannel _channel;

  Future<DeviceMusicPermissionStatus> getPermissionStatus() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('getDeviceMusicPermissionStatus');
      return DeviceMusicPermissionStatus.fromJson(result ?? const <Object?, Object?>{});
    } on MissingPluginException catch (error) {
      return DeviceMusicPermissionStatus(
        status: 'unsupported',
        platformSupported: false,
        message: 'Device music bridge is not available: $error',
      );
    } on PlatformException catch (error) {
      return DeviceMusicPermissionStatus(
        status: 'error',
        message: error.message ?? error.code,
      );
    }
  }

  Future<DeviceMusicPermissionStatus> requestPermission() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('requestDeviceMusicPermission');
      return DeviceMusicPermissionStatus.fromJson(result ?? const <Object?, Object?>{});
    } on MissingPluginException catch (error) {
      return DeviceMusicPermissionStatus(
        status: 'unsupported',
        platformSupported: false,
        message: 'Device music bridge is not available: $error',
      );
    } on PlatformException catch (error) {
      return DeviceMusicPermissionStatus(
        status: 'error',
        message: error.message ?? error.code,
      );
    }
  }

  Future<DeviceMusicScanResult> scanDeviceAudioLibrary() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>('scanDeviceAudioLibrary');
      return DeviceMusicScanResult.fromJson(result ?? const <Object?, Object?>{});
    } on MissingPluginException catch (error) {
      return DeviceMusicScanResult(
        status: 'unsupported',
        tracks: const [],
        error: 'Device music bridge is not available: $error',
        platformSupported: false,
      );
    } on PlatformException catch (error) {
      return DeviceMusicScanResult(
        status: 'error',
        tracks: const [],
        error: error.message ?? error.code,
      );
    }
  }
}

String? _readString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
