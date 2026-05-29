# Flutter, Rust, and Native Playback Boundary

This document defines the Phase 0C boundary between WaveZero's Flutter experience layer, Rust shared engine, and native playback adapters.

## Flutter boundary

Flutter owns the main app surface and experience orchestration:

- premium playback UI;
- visible track metadata and editable test HLS URL fields;
- user commands such as Play/Pause, Stop, Retry, Reset Metrics, and Copy Metrics;
- rendering metrics returned by the bridge;
- app-level navigation and future product flows.

Flutter must not own decoded audio output. It sends commands through `PlaybackBridge` and renders state returned by the bridge. In Phase 0C the shell can use mock metrics when no platform channel handler is available, but the Dart API matches the native bridge shape.

## Dart playback bridge contract

The Flutter contract is represented by `PlaybackBridge`:

- `loadTrack(title, url)`
- `play()`
- `pause()`
- `stop()`
- `retry()`
- `resetMetrics()`
- `metricsSnapshot()`

The placeholder platform channel is named `wavezero/playback` and reserves these method names for the Android and future iOS adapters.

## Rust boundary

Rust owns deterministic shared engine behavior:

- playback queue decisions;
- prefetch and cache policy;
- network scoring;
- metrics normalization;
- future DSP and intelligence primitives when scheduled.

`wavezero-core` remains the source crate for this logic. `crates/wavezero-ffi` is a boundary scaffold that wraps core types into future FFI-safe DTOs. It must not duplicate or replace the core engine.

## Android native boundary

Android remains the Media3 playback adapter. It should continue to own:

- ExoPlayer / Media3 decoded playback;
- Activity/service lifecycle and future background playback;
- MediaSession, notification, lock-screen controls, and Bluetooth integration;
- audio focus and noisy-device handling;
- platform-level buffering, manifest-load, error, and position metrics.

In the next bridge PR, the existing `AudioPlayerManager` can expose the reserved MethodChannel commands without changing the architectural ownership model.

## iOS native boundary

The future iOS adapter should use AVFoundation and own:

- AVPlayer decoded playback;
- background audio mode integration;
- Control Center and lock-screen controls;
- route changes, interruptions, and Bluetooth devices;
- AVFoundation-derived playback metrics.

No iOS implementation is added in Phase 0C.
