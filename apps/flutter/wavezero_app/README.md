# WaveZero Flutter Shell

This Flutter app is the Phase 0D command UI for WaveZero playback. On Android it uses the `PlatformChannelPlaybackBridge` by default and sends commands to the native MethodChannel `wavezero/playback`.

## Playback ownership

Flutter owns the UI, user commands, and metrics rendering. Android Media3 remains the real playback adapter. The Flutter Android host in `android/` reuses the existing `AudioPlayerManager` playback implementation from `apps/android`; it does not add Flutter audio playback.

## MethodChannel methods

- `loadTrack(title, url)`
- `play()`
- `pause()`
- `stop()`
- `retry()`
- `resetMetrics()`
- `metricsSnapshot()`

`metricsSnapshot()` returns Android playback metrics including `appScreenReadyMs`, `tapToFirstAudioMs`, `manifestLoadMs`, `bufferCount`, `isPlaying`, `currentPositionMs`, `playbackError`, `sessionId`, `attemptId`, `tapToReadyMs`, `tapToIsPlayingMs`, `tapToPositionAdvanceMs`, `lastEvent`, `trackTitle`, and `trackUrl`.

If the Android channel is missing, the UI keeps running and displays a readable `playbackError` in the metrics panel.

## Run locally

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d <device-id>
```

On Windows:

```powershell
cd C:\path\to\wavezero
git checkout main
git pull --ff-only
cd apps\flutter\wavezero_app
flutter pub get
flutter run -d <device-id>
```

Use Android Studio Run with USB or Wireless Debugging for the normal development loop. Manual APK sharing is not the default; Firebase App Distribution should be used for tester builds, and future CI should automate APK uploads.

## Keep the native Android proof available

The standalone Media3 proof remains in `apps/android`. To run it on Windows:

1. Open Android Studio.
2. Open `apps/android`.
3. Select the `app` configuration.
4. Run on a USB or Wireless Debugging device.
