# WaveZero Max Stack Architecture

Phase 0D extends the **Max Stack** foundation: Flutter owns the product experience, Rust owns deterministic engine decisions, and each platform keeps native responsibility for decoded playback and operating-system integration.

## Stack responsibilities

| Layer | Responsibility | Phase 0D status |
| --- | --- | --- |
| Flutter app | Main UI, playback controls, metrics display, user flows, and command dispatch through a playback bridge. | `apps/flutter/wavezero_app` defaults to the real Android MethodChannel bridge on Android and keeps a mock bridge for tests/fallback. |
| Rust core engine | Queue ordering, prefetch decisions, cache policy, network interpretation, playback metrics normalization, and future DSP/intelligence decisions. | Existing `wavezero-core` remains the shared deterministic core. |
| Rust FFI boundary | Stable DTOs and binding surface that translate Flutter/native-friendly values into `wavezero-core` types. | Scaffolded in `crates/wavezero-ffi`; UniFFI generation is intentionally TODO. |
| Android native adapter | Media3 ExoPlayer playback, OS lifecycle, foreground/background playback, audio focus, Bluetooth, lock screen/notification integration, and metrics from actual playback. | Existing Android proof remains intact; the Flutter Android host wires `wavezero/playback` to `AudioPlayerManager`. |
| Future iOS native adapter | AVFoundation playback, iOS lifecycle, background audio, Control Center/lock screen, route changes, interruptions, and metrics from actual playback. | Documented future adapter; not implemented in Phase 0D. |

## Core principle

Flutter should **command playback through a bridge**. It should not own low-level audio output, decode audio, manage media sessions, or replace native platform playback engines.

Rust should own deterministic decisions that must behave consistently across platforms:

- queue state and navigation rules;
- prefetch eligibility and first-segment strategy;
- cache-policy decisions;
- network-state interpretation;
- normalized playback metrics and future analytics inputs;
- future DSP, ranking, and intelligence decisions once those features are explicitly scheduled.

Native playback adapters should own platform behavior that cannot be modeled correctly in a cross-platform UI layer:

- decoded playback and media pipeline integration;
- app/background lifecycle and service/session ownership;
- lock-screen and notification controls;
- Bluetooth and route changes;
- audio focus, interruptions, noisy-device handling, and platform permissions;
- real playback telemetry from Media3 or AVFoundation.

## Command flow

```text
Flutter UI
  -> PlaybackBridge command API
    -> Android MethodChannel wavezero/playback
      -> AudioPlayerManager
        -> Media3 ExoPlayer
      -> serializable PlaybackMetrics map
        -> Flutter metrics panel
    -> iOS AVFoundation adapter later
    -> Rust FFI for deterministic core decisions later
      -> wavezero-core
```

The Phase 0D bridge contract is intentionally small: load a track, play, pause, stop, retry, reset metrics, and fetch a metrics snapshot. This lets the Flutter command UI control the existing Android Media3 proof without disturbing native playback ownership.

## Android and Flutter app layout

- `apps/android` remains the existing native Android Media3 proof and can still be opened/run directly in Android Studio.
- `apps/flutter/wavezero_app` remains the Flutter shell. Its generated Android host is intentionally minimal and reuses the shared `AudioPlayerManager` playback sources from `apps/android`.
- Both Android entry points use Media3 for actual playback. Flutter does not use a Flutter audio package.

## Development loop

Manual APK sharing is not the default development loop. For day-to-day Android work:

1. Use Android Studio Run with a USB device or Wireless Debugging.
2. Use the existing native Android proof when validating Media3 behavior in isolation.
3. Use the Flutter Android host when validating Flutter command UI -> Android Media3 bridge behavior.
4. Use Firebase App Distribution for tester builds.
5. Let future CI automate APK builds/uploads instead of manually building and sharing APKs for every change.

## What Phase 0D does not do

Phase 0D does not add auth, subscriptions, social features, iOS implementation, AI recommendations, backend catalog expansion, Google Play work, Android Gradle Plugin upgrades, or compile SDK upgrades. It also does not replace Media3 with Flutter audio and does not remove `wavezero-core`.
