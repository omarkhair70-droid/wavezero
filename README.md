# WaveZero

WaveZero is an Android-first music experience built with Flutter for the consumer UI and Kotlin/AndroidX Media3 for native playback.

The project has grown well beyond its original Phase 0 playback proof. The active Flutter app includes a consumer shell for Home, Library, Now Playing, Queue, Downloads, Search, Collections, Listening History, Settings, Device Music, storage/offline management, and developer diagnostics.

## What is real today

- Native Android playback through Media3/ExoPlayer.
- Flutter-to-native MethodChannel playback bridge.
- MediaSession and notification/lock-screen controls.
- Secondary ExoPlayer prebuffer with prepared explicit-Next and auto-advance handoff.
- Android MediaStore Device Music import and playback.
- Queue/session persistence, shuffle, repeat, and sleep timer controls.
- Local downloads/cache and offline playback.
- Local search, history, collections, themes, and settings persistence.
- Large-catalog safeguards plus curated demo shelves and generated artwork fallbacks.
- Rust deterministic playback/core models and an Axum content API foundation.

## Runtime ownership

The shipping Android playback path is currently:

```text
Flutter UI
  -> PlaybackBridge / MethodChannel
  -> Kotlin playback adapter
  -> AndroidX Media3 / ExoPlayer
```

`wavezero-core` contains deterministic queue/prefetch/cache/network logic, while `wavezero-ffi` is still a boundary scaffold. Generated Rust FFI is not currently the runtime playback path.

## Foundations that are not production-complete yet

- Native audio DSP/effects support.
- Cloud Vault provider OAuth/API integrations.
- Database-backed production catalog/analytics persistence.
- Cloudflare R2 signed media delivery and production encoding pipeline.
- Auth/accounts, artist uploads, subscriptions/payments, DRM, and iOS playback.

These areas should remain clearly labeled as foundations/placeholders until they are actually connected.

## Main directories

- `apps/flutter/wavezero_app/` — active Flutter consumer product and Android host.
- `apps/android/` — shared native Android/Media3 playback implementation plus the historical standalone playback proof app.
- `crates/wavezero-core/` — deterministic Rust playback decision models.
- `crates/wavezero-ffi/` — future FFI boundary scaffold.
- `services/api/` — Rust Axum catalog/content service.
- `services/edge-worker/` — edge delivery placeholder/foundation.
- `infra/` — database and encoding foundations.
- `docs/` — product, architecture, development, release, and consolidation documentation.

## Consolidation

The current cleanup/hardening roadmap lives in [`docs/CONSOLIDATION_PLAN.md`](docs/CONSOLIDATION_PLAN.md).

The consolidation strategy is intentionally incremental: preserve working playback/product behavior, establish clear ownership, decompose the large Flutter V3 state/UI surface, harden native lifecycle boundaries, align documentation with reality, and improve CI/release engineering before adding another large feature wave.
