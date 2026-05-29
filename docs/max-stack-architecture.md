# WaveZero Max Stack Architecture

Phase 0C establishes the **Max Stack** foundation: Flutter owns the product experience, Rust owns deterministic engine decisions, and each platform keeps native responsibility for decoded playback and operating-system integration.

## Stack responsibilities

| Layer | Responsibility | Phase 0C status |
| --- | --- | --- |
| Flutter app | Main UI, playback controls, metrics display, user flows, and command dispatch through a playback bridge. | Lightweight shell in `apps/flutter/wavezero_app`. |
| Rust core engine | Queue ordering, prefetch decisions, cache policy, network interpretation, playback metrics normalization, and future DSP/intelligence decisions. | Existing `wavezero-core` remains the shared deterministic core. |
| Rust FFI boundary | Stable DTOs and binding surface that translate Flutter/native-friendly values into `wavezero-core` types. | Scaffolded in `crates/wavezero-ffi`; UniFFI generation is intentionally TODO. |
| Android native adapter | Media3 ExoPlayer playback, OS lifecycle, foreground/background playback, audio focus, Bluetooth, lock screen/notification integration, and metrics from actual playback. | Existing Android proof remains intact. |
| Future iOS native adapter | AVFoundation playback, iOS lifecycle, background audio, Control Center/lock screen, route changes, interruptions, and metrics from actual playback. | Documented future adapter; not implemented in Phase 0C. |

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
    -> Platform channel / generated binding boundary
      -> Android Media3 adapter now
      -> iOS AVFoundation adapter later
      -> Rust FFI for deterministic core decisions
        -> wavezero-core
```

The bridge contract is intentionally small in Phase 0C: load a track, play, pause, stop, retry, reset metrics, and fetch a metrics snapshot. This leaves room to wire Android MethodChannel handling in the next PR without disturbing the current Android playback proof.

## What Phase 0C does not do

Phase 0C does not add auth, subscriptions, social features, iOS implementation, AI recommendations, or backend catalog expansion. It also does not replace Media3 with Flutter audio and does not remove `wavezero-core`.
