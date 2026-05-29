# Flutter, Rust, and Native Playback Boundary

This document defines the Phase 0D boundary between WaveZero's Flutter experience layer, Rust shared engine, and native playback adapters.

## Flutter boundary

Flutter owns the main app surface and experience orchestration:

- premium playback UI;
- visible track metadata and editable test HLS URL fields;
- user commands such as Play/Pause, Stop, Retry, Reset Metrics, and Copy Metrics;
- rendering metrics returned by the bridge;
- app-level navigation and future product flows.

Flutter must not own decoded audio output. It sends commands through `PlaybackBridge` and renders state returned by the bridge. On Android, `WaveZeroApp` now chooses `PlatformChannelPlaybackBridge` by default so the Flutter UI commands real Media3 playback through a Flutter Android host. `MockPlaybackBridge` remains available for tests, unsupported platforms, and local UI fallback.

## Dart playback bridge contract

The Flutter contract is represented by `PlaybackBridge` and the Android MethodChannel `wavezero/playback`:

| Method | Arguments | Native behavior |
| --- | --- | --- |
| `loadTrack` | `title`, `url` | Update the current track and Media3 `MediaItem`, reset transient metrics, and wait for play. |
| `play` | none | Start Media3 playback. |
| `pause` | none | Pause Media3 playback. |
| `stop` | none | Stop playback and reset the player to the loaded MediaItem. |
| `retry` | none | Stop/reset/reload the current track and play again. |
| `resetMetrics` | none | Reset transient metrics without losing the loaded track. |
| `metricsSnapshot` | none | Return a serializable map matching Dart `PlaybackMetrics`. |

If the MethodChannel is unavailable, Flutter records a readable `playbackError` in the metrics snapshot instead of crashing the UI.

## Metrics returned by Android

The Android metrics map includes the Phase 0B/0C fields used by the Flutter UI:

- `appScreenReadyMs`
- `tapToFirstAudioMs`
- `manifestLoadMs`
- `bufferCount`
- `isPlaying`
- `currentPositionMs`
- `playbackError`

Phase 0D also returns richer bridge fields when available:

- `sessionId`
- `attemptId`
- `tapToReadyMs`
- `tapToIsPlayingMs`
- `tapToPositionAdvanceMs`
- `lastEvent`
- `trackTitle`
- `trackUrl`

## Rust boundary

Rust owns deterministic shared engine behavior:

- playback queue decisions;
- prefetch and cache policy;
- network scoring;
- metrics normalization;
- future DSP and intelligence primitives when scheduled.

`wavezero-core` remains the source crate for this logic. `crates/wavezero-ffi` is a boundary scaffold that wraps core types into future FFI-safe DTOs. It must not duplicate or replace the core engine.

## Android native boundary

Android remains the Media3 playback adapter. It owns:

- ExoPlayer / Media3 decoded playback;
- Activity/service lifecycle and future background playback;
- MediaSession, notification, lock-screen controls, and Bluetooth integration;
- audio focus and noisy-device handling;
- platform-level buffering, manifest-load, error, and position metrics.

The Flutter Android host reuses the existing `AudioPlayerManager` playback implementation from `apps/android`; it does not introduce Flutter audio playback.

## iOS native boundary

The future iOS adapter should use AVFoundation and own:

- AVPlayer decoded playback;
- background audio mode integration;
- Control Center and lock-screen controls;
- route changes, interruptions, and Bluetooth devices;
- AVFoundation-derived playback metrics.

No iOS implementation is added in Phase 0D.
