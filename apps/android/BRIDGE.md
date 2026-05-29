# Android Playback Bridge

The existing Android playback proof remains the native Media3 adapter for WaveZero. Phase 0D adds a Flutter Android host that exposes the small `wavezero/playback` MethodChannel while preserving the standalone `apps/android` proof.

## Native owner

`AudioPlayerManager` remains responsible for Media3 ExoPlayer ownership and Android playback concerns:

- actual decoded playback through Media3;
- app lifecycle and future background playback service integration;
- audio focus, Bluetooth, and route changes;
- lock-screen, notification, and MediaSession integration;
- playback errors, buffering state, manifest loading, and position metrics.

Flutter calls Android through a platform bridge. Flutter must not replace Media3 or perform low-level audio output.

## MethodChannel

The Flutter shell and Android host use this channel name:

```text
wavezero/playback
```

| Method | Android behavior |
| --- | --- |
| `loadTrack` | Accept `title` and `url`, update the loaded track, reset transient metrics, and set the Media3 `MediaItem`. |
| `play` | Delegate to `AudioPlayerManager.play()`. |
| `pause` | Delegate to `AudioPlayerManager.pause()`. |
| `stop` | Delegate to `AudioPlayerManager.stop()`. |
| `retry` | Stop/reset/reload the current MediaItem and attempt playback again. |
| `resetMetrics` | Reset transient playback metrics while preserving the currently loaded track. |
| `metricsSnapshot` | Return a serializable metrics map matching the Dart `PlaybackMetrics` model. |

The Flutter host implementation lives under `apps/flutter/wavezero_app/android` and reuses the playback manager sources from `apps/android/app/src/main/java/com/wavezero/player/playback`.

## Metrics map

`metricsSnapshot` returns at least:

- `appScreenReadyMs`
- `tapToFirstAudioMs`
- `manifestLoadMs`
- `bufferCount`
- `isPlaying`
- `currentPositionMs`
- `playbackError`

It also returns richer Phase 0D fields:

- `sessionId`
- `attemptId`
- `tapToReadyMs`
- `tapToIsPlayingMs`
- `tapToPositionAdvanceMs`
- `lastEvent`
- `trackTitle`
- `trackUrl`

## Running locally on Windows

```powershell
cd C:\path\to\wavezero
git checkout main
git pull --ff-only
```

### Run the existing native Android proof

1. Open Android Studio.
2. Choose **File > Open** and select `apps/android`.
3. Select the `app` run configuration.
4. Connect a phone with USB debugging or pair it with Wireless Debugging.
5. Click **Run**.

### Run the Flutter Android bridge app

Only use this path if Flutter is installed and `flutter doctor` is healthy:

```powershell
cd C:\path\to\wavezero\apps\flutter\wavezero_app
flutter pub get
flutter run -d <device-id>
```

You can also open `apps/flutter/wavezero_app/android` in Android Studio after Flutter has generated `local.properties` with `flutter.sdk`.

## Build and distribution guidance

Manual APK builds are not the default development loop. Prefer Android Studio Run and Wireless Debugging for development. Use Firebase App Distribution for tester builds. Future CI should automate APK uploads so developers do not manually share APKs for every iteration.
