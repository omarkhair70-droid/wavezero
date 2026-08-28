# WaveZero

**A calm, Android-first local/offline music player built with Flutter and native Kotlin/Media3 playback.**

[Portfolio case study](https://omar-khair-portfolio.vercel.app/work/wavezero) · [Privacy policy](https://omar-khair-portfolio.vercel.app/privacy/wavezero)

> **V1 repository status:** code frozen and release-candidate preparation complete. Final Android identity, launcher/Play artwork, release AAB pipeline, privacy policy, and Play handoff are prepared. Signing/upload remains a manual publishing operation unless a later release record proves distribution.

<p align="center">
  <img src="https://raw.githubusercontent.com/omarkhair70-droid/omar-khair-portfolio/main/public/work/wavezero/01-brand-home.webp" alt="WaveZero brand home" width="23%" />
  <img src="https://raw.githubusercontent.com/omarkhair70-droid/omar-khair-portfolio/main/public/work/wavezero/04-device-music.webp" alt="WaveZero Device Music" width="23%" />
  <img src="https://raw.githubusercontent.com/omarkhair70-droid/omar-khair-portfolio/main/public/work/wavezero/06-now-playing.webp" alt="WaveZero Now Playing" width="23%" />
  <img src="https://raw.githubusercontent.com/omarkhair70-droid/omar-khair-portfolio/main/public/work/wavezero/07-settings-downloads.webp" alt="WaveZero settings and downloads" width="23%" />
</p>

## Product

WaveZero V1 is deliberately narrower than the full long-term music-platform vision. The shipping Android target is **local/offline-first**: music already on the device, native background playback, queue/session behavior, search, collections, history, downloads/cache, and storage controls without requiring accounts, ads, subscriptions, or cloud sync.

## Strongest systems

1. **Native playback** — Flutter UI connected through a MethodChannel bridge to Kotlin and AndroidX Media3 / ExoPlayer.
2. **Android media integration** — MediaSession, notification and lock-screen controls, background playback, MediaStore Device Music import.
3. **Queue lifecycle** — queue/session persistence, explicit next, auto-advance handoff, shuffle, repeat and sleep timer.
4. **Offline/local behavior** — downloads/cache, local playback, storage controls and device-owned music.
5. **Personal library state** — local search, collections/likes, listening history, saved positions, settings and themes.
6. **Release engineering** — frozen Android identity, reproducible Flutter dependency resolution, CI-built release AAB, Play assets and release handoff.

## Product screens

<p align="center">
  <img src="https://raw.githubusercontent.com/omarkhair70-droid/omar-khair-portfolio/main/public/work/wavezero/02-listening-home.webp" alt="WaveZero listening home" width="23%" />
  <img src="https://raw.githubusercontent.com/omarkhair70-droid/omar-khair-portfolio/main/public/work/wavezero/03-library.webp" alt="WaveZero library" width="23%" />
  <img src="https://raw.githubusercontent.com/omarkhair70-droid/omar-khair-portfolio/main/public/work/wavezero/05-search.webp" alt="WaveZero search" width="23%" />
  <img src="https://raw.githubusercontent.com/omarkhair70-droid/omar-khair-portfolio/main/public/work/wavezero/06-now-playing.webp" alt="WaveZero Now Playing" width="23%" />
</p>

## Runtime ownership

```text
Flutter consumer UI
        │
        ▼
PlaybackBridge / MethodChannel
        │
        ▼
Kotlin playback adapter
        │
        ▼
AndroidX Media3 / ExoPlayer
```

The Rust core and Axum API remain useful foundations, but generated Rust FFI is not the V1 runtime playback owner.

## V1 release identity

- Application ID: `com.omarkhair.wavezero`
- Version: `1.0.0` / code `1`
- Target SDK: 36
- Category: Music & Audio
- Final launcher/adaptive icon: integrated
- Google Play 512×512 artwork: committed under `docs/play-assets/`
- Public privacy policy: https://omar-khair-portfolio.vercel.app/privacy/wavezero
- Repository-side release state: **READY FOR SIGNED PLAY UPLOAD**

---

## Detailed engineering notes

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

## V1 Android release

The first Google Play release is intentionally Android-first and local/offline-first. Release closure, signing, AAB, Samsung smoke testing, and Play listing gates live in [docs/V1_RELEASE_CHECKLIST.md](docs/V1_RELEASE_CHECKLIST.md).

