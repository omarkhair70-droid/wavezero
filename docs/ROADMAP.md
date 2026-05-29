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

## Next Phases

### Phase 0E — Developer Distribution Automation

Goal:

Make development and testing faster without manually creating and sharing APK files every time.

Scope:

- Document Android Studio Run and Wireless Debugging workflow.
- Stabilize Firebase App Distribution debug upload workflow.
- Add CI checks for Rust, Android, and Flutter where tooling is available.
- Add future CI path for automatically building and distributing debug tester builds.

Non-goals:

- No Google Play release automation yet.
- No production signing setup yet.
- No feature expansion.

### Phase 0F — Background Playback and Media Session

Goal:

Turn Android playback from foreground proof into a real music-app playback service.

Scope:

- Add Media3 `MediaSessionService` or equivalent service structure.
- Add notification controls.
- Add lock-screen controls.
- Handle audio focus.
- Handle Bluetooth/headset route changes.
- Handle noisy-device events.
- Preserve Flutter as the command UI.

Non-goals:

- No iOS yet.
- No catalog backend dependency.

### Phase 0G — Accurate Metrics System

Goal:

Make playback metrics trustworthy enough to compare Wi-Fi, 4G, cold start, retry, and buffering behavior.

Scope:

- Finalize `tapToReadyMs`, `tapToIsPlayingMs`, and `tapToPositionAdvanceMs` semantics.
- Add clear attempt/session lifecycle.
- Add metrics copy/export flow.
- Add Wi-Fi vs 4G manual test guide.
- Add local logging for playback attempts.

Non-goals:

- No analytics vendor integration.
- No user tracking.

### Phase 1 — Real Catalog API

Goal:

Replace hardcoded demo HLS tracks with real backend-driven tracks/assets.

Scope:

- Expand Rust API service for tracks, artists, and assets.
- Read real track manifests from the backend.
- Keep playback adapter isolated from catalog implementation.
- Add basic local/dev seed data.

### Phase 2 — Rust Core Integration

Goal:

Move deterministic playback decisions into Rust core and use them from app flows.

Scope:

- Connect queue decisions to app UI.
- Connect prefetch decisions to Android playback preparation.
- Connect network scoring and cache policy to playback flow.
- Advance `wavezero-ffi` toward generated bindings when appropriate.

### Phase 3 — Streaming Pipeline

Goal:

Build the real audio delivery foundation.

Scope:

- Encoding pipeline decisions.
- HLS/CMAF manifest strategy.
- Cloudflare R2 or equivalent storage.
- Edge signed manifests.
- CDN delivery.
- Track asset variants and quality strategy.

### Phase 4 — iOS Native Adapter

Goal:

Add iOS playback using the same architecture.

Scope:

- Swift/AVFoundation playback adapter.
- Flutter command UI on iOS.
- Control Center and lock-screen controls.
- iOS route/interruption handling.
- Metrics parity with Android where possible.

### Phase 5 — Premium Product UX

Goal:

Move from proof to product.

Scope:

- Home.
- Search.
- Library.
- Player screen.
- Artist and album screens.
- Offline/download strategy.
- Account and settings flows.

## Development Loop

Default development should not require manual APK sharing.

Preferred loops:

1. Android Studio Run or Wireless Debugging for daily device testing.
2. `flutter run` for Flutter host testing once Flutter is installed locally.
3. Firebase App Distribution for sharing tester builds.
4. GitHub Actions for automated checks and, later, automated tester build uploads.

Manual APK generation should be used only when needed for debugging or temporary sharing.
