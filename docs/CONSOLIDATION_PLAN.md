# WaveZero Consolidation Plan

Baseline: `main` at `c270a3087cc5a965810e4804451b312c87774818` (PR #91).

This document is the source of truth for cleanup and hardening after the rapid feature-building phase. The goal is not a rewrite. The goal is to preserve the working product while making ownership, testing, release behavior, and documentation match the code that exists today.

The current Android build is known to run on a physical device. Refactors must preserve behavior first and improve structure in small reviewable changes.

## Product truth today

Real, working foundations that must be protected:

- Flutter consumer shell with Home, Library, Now, Queue, Downloads, Settings, Search, Collections, History, Storage, Device Music, and developer/Engine surfaces.
- Android Media3/ExoPlayer decoded playback through the Flutter MethodChannel bridge.
- Shared process playback session and MediaSession/notification controls.
- Secondary ExoPlayer native prebuffer plus prepared explicit-Next and auto-advance handoff.
- Device Music import through Android MediaStore.
- Queue/session persistence, shuffle, repeat, and sleep timer behavior.
- Local downloads/cache and offline playback.
- Local search, listening history, and collections.
- Large-catalog performance safeguards and curated demo shelves.
- Rust deterministic queue/prefetch/cache/network models and API content-mode foundations.

Foundations that must not be represented as complete production features yet:

- Native audio DSP/effects: UI/profile model exists; Android DSP is not enabled.
- Cloud Vault providers: metadata/product foundation exists; provider OAuth/API integrations are not implemented.
- Rust FFI: scaffold exists; generated runtime bindings are not integrated into the shipping Flutter playback path.
- Database-backed production catalog/analytics: schema exists, but production persistence is not wired through the current API.
- Edge/R2 signed delivery and encoding pipeline: placeholders/foundations only.
- Production auth, payments, uploads, DRM, hosted catalog operations, and iOS playback are not implemented.

## Protected behavior

Every cleanup PR must preserve these unless the PR explicitly targets one of them:

1. Catalog/device/downloaded track playback.
2. Play, pause, stop, seek, retry, previous, next, shuffle, repeat, sleep timer.
3. Mini-player and Now surface continuity.
4. Android notification/lock-screen playback controls.
5. Queue persistence and current/up-next semantics.
6. Native prebuffer metrics and prepared-player handoff.
7. Device Music permissions, scan, metadata, and playback.
8. Download/cache/offline playback and storage management.
9. Search, history, collections, themes, and settings persistence.
10. Large-catalog bounded rendering/debounced search behavior.
11. Rights metadata and dev/demo/production content-mode safety.
12. Developer diagnostics remain separate from normal consumer surfaces.

## Phase 0 — Stability and source-of-truth cleanup

Status: In progress.

### 0.1 Playback-session lifetime

Problem:

`WaveZeroMediaSessionService.onDestroy()` previously released the singleton `WaveZeroPlaybackSession` even though the Flutter activity MethodChannel could still hold the same `AudioPlayerManager`. A service stop/dismiss could therefore invalidate ExoPlayers underneath a live activity.

Decision:

- `WaveZeroPlaybackSession` is process-scoped.
- Service teardown must not release it.
- Explicit release remains reserved for a boundary where no client can retain the manager.

### 0.2 Consumer status truth

Audit the top shell/status chips so healthy catalog/device states are not shown beside a stale generic `Error` state. Consumer status should explain the actionable problem, not leak old playback/API diagnostics.

### 0.3 Documentation truth

Update README/roadmap/architecture docs to match the real product:

- Flutter V3 is the active consumer app.
- Prepared native handoff is already implemented.
- Current runtime path is Flutter -> MethodChannel -> Kotlin/Media3.
- Rust FFI remains a future/runtime-boundary decision unless it is deliberately integrated.

## Phase 1 — Flutter architecture consolidation

Do not rewrite the UI. Extract behavior from `wavezero_live_metrics_app_v3.dart` in small parity-preserving PRs.

Target ownership:

```text
lib/
  app/
    app_shell/
    navigation/
    theme/
  features/
    playback/
    library/
    search/
    queue/
    downloads/
    device_music/
    collections/
    history/
    cloud_vault/
    settings/
    developer/
  shared/
    design/
    models/
    widgets/
```

Recommended sequence:

1. Extract app shell/navigation/theme ownership.
2. Extract playback UI state/orchestration.
3. Extract Library + Search.
4. Extract Queue + preload orchestration.
5. Extract Downloads + cache/storage UI orchestration.
6. Extract Device Music.
7. Extract Collections + History.
8. Extract Settings + Developer + Cloud Vault foundations.
9. Switch the active app directly to the new modules.
10. Delete obsolete V1/V2/proof-shell files only after parity is established.

## Phase 2 — Android/native hardening

- Keep playback engine lifetime ownership explicit and process-safe.
- Review exported MediaSessionService/custom intent action boundary before production release.
- Keep MediaSession attached to the current primary player after prepared-player swaps.
- Add focused tests around metrics/prebuffer/handoff state where JVM-testable.
- Decide whether audio-effect profiles remain hidden/diagnostic until real DSP exists or implement a real supported native effect path.

## Phase 3 — Rust boundary decision

Choose one explicit direction:

A. Integrate Rust as a real runtime decision layer through a stable FFI/native boundary; or
B. Keep Rust as a deterministic shared/reference engine and document that the shipping Flutter playback path does not depend on it.

Before runtime integration:

- Align FFI DTO codec/model coverage with `wavezero-core`.
- Remove duplicated decision logic or define one canonical owner for each decision.
- Add binding/package automation only after the ownership choice is final.

## Phase 4 — Backend modularization

Split `services/api/src/main.rs` by responsibility while preserving routes:

- config/content modes
- catalog loading/normalization
- HTTP routes/DTOs
- licensing/production safety
- local-dev catalog scanning
- playback-event ingestion

Then decide whether to wire PostgreSQL persistence for playback/catalog operations. Placeholder schema or edge infrastructure must remain clearly labeled until it is actually connected.

## Phase 5 — CI and release hardening

Required before calling WaveZero production-ready:

- Flutter analyze/test/build checks.
- Android compile/unit-test/build checks for the Flutter host/native playback source.
- Rust workspace/API checks remain green.
- Real package name/app label/icon/versioning.
- Production network configuration; remove development cleartext assumptions from release builds.
- Release signing/distribution path.
- Crash/diagnostic strategy with consumer privacy boundaries.
- Physical-device smoke matrix for playback, notification controls, Device Music, downloads, queue, and app restart.

## Phase 6 — Nova integration

Keep integration local-first and narrow. WaveZero should expose a track/clip selection contract rather than making Nova depend on WaveZero's unfinished cloud/backend infrastructure.

Candidate handoff payload:

```text
track/source id
content or playable URI
track title
artist
artwork URI when available
clip start/end offsets
```

Nova remains responsible for its own social-post/message semantics and media policy.

## PR policy

- One ownership boundary or bug class per PR.
- No broad rewrite PRs.
- Preserve the current physical-device behavior unless a bug is explicitly being fixed.
- Inspect the complete diff before merge.
- Do not claim a foundation/placeholder is production-complete.
- Prefer removing stale/duplicate paths after parity rather than keeping multiple generations indefinitely.
