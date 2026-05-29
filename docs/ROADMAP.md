# WaveZero Roadmap

This roadmap is the working execution plan for WaveZero after the Phase 0D Max Stack bridge work.

## Architecture Direction

WaveZero is a native audio platform with a Flutter experience layer and a Rust deterministic core.

- Flutter owns the main product UI and experience layer.
- Android Media3 owns Android decoded playback and operating-system integration.
- Future iOS AVFoundation owns iOS decoded playback and operating-system integration.
- Rust owns deterministic shared logic: queue decisions, prefetch decisions, cache policy, network scoring, normalized metrics, and future DSP/intelligence primitives.
- Cloud/edge infrastructure will own catalog APIs, signed manifests, storage, encoding, and delivery.

## Completed Phases

### Phase 0B — Android Native Playback Proof

Status: Completed

Outcome:

- Android Media3/ExoPlayer proof runs on a real Android phone.
- HLS demo playback works.
- The native proof can build a debug APK locally.
- Core playback metrics are visible on device.

### Phase 0C — Max Stack Foundation

Status: Completed

Outcome:

- Flutter shell added as the future UI/experience layer.
- Rust FFI scaffold added without replacing `wavezero-core`.
- Max Stack architecture docs added.
- Flutter/Rust/native ownership boundaries documented.

### Phase 0D — Flutter to Android Media3 Bridge

Status: Completed

Outcome:

- Flutter Android host added under `apps/flutter/wavezero_app/android`.
- Flutter `wavezero/playback` MethodChannel wired to Android `AudioPlayerManager`.
- Android Media3 remains the real playback adapter.
- Flutter can command load/play/pause/stop/retry/reset/metrics through the bridge.
- Metrics model now includes richer bridge fields including session, attempt, timing, event, track title, and URL.

### Phase 0E — Developer Distribution Automation

Status: Completed

Outcome:

- Android and Flutter local development scripts were added.
- Flutter Android host can build and install locally.
- Firebase App Distribution documentation exists without committing credentials.
- Stable Rust CI checks run on GitHub Actions.

### Phase 0E.1 — Flutter Android Toolchain Upgrade

Status: Completed

Outcome:

- Flutter Android host Android Gradle Plugin was upgraded to a Flutter-supported version.
- Flutter Android host Kotlin plugin was upgraded to a Flutter-supported version.
- Flutter Android repository resolution and build output path remain stable.

### Phase 0F — Background Playback and Media Session

Status: Completed

Outcome:

- A Media3 `MediaSession` wraps the shared ExoPlayer instance.
- Music audio attributes and Android audio-focus handling are configured.
- Noisy-device handling is enabled through ExoPlayer's built-in becoming-noisy handling.
- Flutter and native manifests are prepared for media playback foreground-service permissions.
- Screen-off playback was verified manually on Android.

### Phase 0F.1 — Foreground Media Playback Service

Status: Completed

Outcome:

- A shared playback session owner connects Flutter, the native proof, and the Android service to the same playback manager.
- A Media3 `MediaSessionService` is registered in the native and Flutter Android manifests.
- Android can discover the active WaveZero media session.
- Android 13+ notification permission is declared.

### Phase 0F.2 — Runtime Notification Permission and Reliable Media Controls

Status: Completed

Outcome:

- Android 13+ notification permission is requested at runtime from the Flutter host.
- MediaSessionService starts before play/retry bridge commands.
- Flutter remains the product command surface.

### Phase 0F.3 — Explicit Foreground Playback Notification

Status: Completed

Outcome:

- WaveZero creates an explicit foreground playback notification.
- Notification channel `wavezero_playback` exists.
- Notification Play/Pause and Stop actions control the shared player.
- Notification playback controls were verified manually on Android.

### Phase 0G — Accurate Metrics System

Status: Completed

Outcome:

- Playback metrics are attempt-based and live-refreshing in Flutter.
- `tapToReadyMs`, `tapToIsPlayingMs`, and `tapToPositionAdvanceMs` are visible on device.
- Startup buffer and rebuffer metrics are separated.
- Duplicate Play taps during startup no longer create fake attempts.
- Wi-Fi and 4G baseline testing has started.

## Next Phases

### Phase 0H — Startup Speed Optimization

Status: In progress

Goal:

Reduce first-play startup latency by preparing the Media3 player during Load Track instead of waiting until Play.

Scope:

- Call Media3 `prepare()` during `loadTrack`.
- Keep Play as a fast `playWhenReady` command when the player is already ready.
- Preserve notification, background playback, and duplicate Play guard behavior.
- Compare before/after Wi-Fi and 4G metrics using `tapToFirstAudioMs`, `tapToReadyMs`, and `startupBufferMs`.

Non-goals:

- No backend catalog work.
- No CDN optimization yet.
- No production audio pipeline yet.

### Phase 1 — Real Catalog API

Goal:

Replace hardcoded demo HLS tracks with real backend-driven tracks/assets.

Scope:

- Expand Rust API service for tracks, artists, and assets.
- Read real track manifests from the backend.
- Keep playback adapter isolated from catalog implementation.
- Add basic local/dev seed data.
