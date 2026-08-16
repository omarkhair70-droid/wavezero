# WaveZero Flutter App

This directory contains the active WaveZero consumer application.

Flutter owns the product UI and app-level orchestration. On Android, decoded playback remains native: `PlatformChannelPlaybackBridge` sends playback commands through the `wavezero/playback` MethodChannel to the shared Kotlin/Media3 playback implementation.

## Active product surface

The current app includes:

- Home
- Library
- Now Playing / player sheet
- Queue
- Downloads / Storage Manager
- Search
- Collections
- Listening History
- Device Music
- Settings / themes / playback preferences
- Developer/Engine diagnostics when enabled

The app also contains local queue/session recovery, shuffle/repeat/sleep timer controls, smart preload/download foundations, catalog/device/offline source handling, and curated demo presentation.

## Playback ownership

```text
Flutter UI
  -> PlaybackBridge
  -> MethodChannel `wavezero/playback`
  -> shared Kotlin AudioPlayerManager
  -> Media3 / ExoPlayer
  -> MediaSession / notification controls
```

Flutter does not decode Android audio itself.

The native playback session is process-scoped because both the Flutter activity bridge and `WaveZeroMediaSessionService` use the same manager. Stopping/recreating the media service must not release the engine underneath a live Flutter activity.

## Run on Android

From the repository root on Windows:

```powershell
.\scripts\dev\flutter-run-android.ps1
```

Manual equivalent:

```powershell
cd apps\flutter\wavezero_app
flutter pub get
flutter run
```

Useful local checks:

```powershell
flutter doctor
adb devices
```

## Build configuration

The app reads release/environment values from dart-defines including:

```text
WAVEZERO_APP_ENV=dev|beta|production
WAVEZERO_API_BASE_URL=<api-root>
WAVEZERO_CONTENT_MODE_LABEL=<friendly label>
```

Dev mode can use local/LAN content-server workflows. Beta/production builds should use explicit release-appropriate configuration and must not expose raw local URLs or internal diagnostics on consumer surfaces.

See:

- `docs/DEVELOPMENT.md`
- `docs/beta-release-checklist.md`
- `docs/CONSOLIDATION_PLAN.md`
- `docs/ROADMAP.md`

## Current architecture cleanup

The active V3 product surface has accumulated substantial UI and orchestration in one large file. The consolidation plan intentionally decomposes it feature-by-feature without rewriting working behavior, then retires obsolete V1/V2/proof paths after parity is established.
