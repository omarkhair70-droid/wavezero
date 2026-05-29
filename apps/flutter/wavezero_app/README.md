# WaveZero Flutter Shell

This Flutter app is the Phase 0D command UI for WaveZero playback. On Android it uses `PlatformChannelPlaybackBridge` by default and sends commands to the native MethodChannel `wavezero/playback`.

## Playback ownership

Flutter owns the UI, user commands, and metrics rendering. Android Media3 remains the real playback adapter. The Flutter Android host in `android/` reuses the existing Android playback implementation; it does not add Flutter audio playback.

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

## Install Flutter SDK

Install Flutter before using the Flutter host. After installation, make sure `flutter` is available on `PATH` and Android Studio has the Android SDK/device tooling configured.

Check locally:

```powershell
flutter doctor
adb devices
```

## Run on Android

From the repository root on Windows:

```powershell
.\scripts\dev\flutter-run-android.ps1
```

The script checks that Flutter exists, changes to `apps/flutter/wavezero_app`, runs `flutter pub get`, and then runs `flutter run`.

Manual equivalent:

```powershell
cd apps\flutter\wavezero_app
flutter pub get
flutter run
```

Use Android Studio Run or Wireless Debugging for normal Android device testing. Manual APK sharing is not the default; Firebase App Distribution is the tester-sharing path for debug Android builds.

## Verify the Phase 0D Android bridge

1. Start the Flutter app on an Android device.
2. Tap the app controls to load and play the test track.
3. Confirm that audio playback starts through Android Media3.
4. Confirm the metrics panel updates playback state, position, session ID, attempt ID, timing fields, last event, track title, and URL.
5. If the channel is unavailable, confirm the app shows a readable `playbackError` instead of crashing.

## Generated build outputs

Flutter-generated Android artifacts are under:

```text
apps\flutter\wavezero_app\build\
```

The standalone native Android debug APK fallback is generated separately at:

```text
apps\android\app\build\outputs\apk\debug\app-debug.apk
```

## Environment variables used by Phase 0E tooling

- `JAVA_HOME`: needed for local PowerShell Gradle builds when Java is not already found. Android Studio's bundled JBR is usually `C:\Program Files\Android\Android Studio\jbr`.
- `FIREBASE_APP_ID`: required only for Firebase App Distribution upload of native Android debug builds.
- `GOOGLE_APPLICATION_CREDENTIALS`: required when Firebase CLI/Gradle upload uses Application Default Credentials. Point it to a local service account JSON outside the repository.
