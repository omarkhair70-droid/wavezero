# WaveZero Roadmap

This roadmap reflects the product after PR #91. For the detailed cleanup sequence and protected behavior map, see [`CONSOLIDATION_PLAN.md`](CONSOLIDATION_PLAN.md).

## Architecture direction

WaveZero is an Android-first music experience with:

- Flutter owning the consumer UI and app-level product orchestration.
- Android Media3/ExoPlayer owning decoded Android playback, MediaSession, notification controls, audio focus, and native playback lifecycle.
- Rust `wavezero-core` owning deterministic shared playback decision models where they are deliberately used.
- `wavezero-ffi` remaining a future runtime boundary scaffold until generated bindings are intentionally integrated.
- Rust API/content infrastructure owning catalog/content-mode foundations.
- Future cloud/edge infrastructure owning hosted catalog storage, signed media delivery, encoding, and production operations when those systems are actually implemented.

## Playback milestones already implemented

### Player state and UX cleanup

Status: Implemented.

- Operation-state model separates long-running product operations from normal playback controls.
- Catalog/search remain usable while audio is playing.
- Metrics refresh does not intentionally block normal controls.

### Persistent queue and session recovery

Status: Implemented.

- Queue, selected/current track, and auto-advance state persist locally.
- Restored catalog tracks are resolved against the current catalog when possible.

### Predictive manifest preload

Status: Implemented.

- Flutter predicts the up-next track from current queue state.
- The next catalog manifest can be prefetched before a transition.
- Manifest-preload metrics remain separate from true native audio preparation.

### Native dual-player prebuffer and prepared handoff

Status: Implemented; hardening continues.

- Android owns a secondary ExoPlayer for the predicted next track.
- Native readiness is reported only after the secondary player reaches a prepared/ready state.
- Explicit Next can hand off to the prepared player when the candidate still matches.
- Auto-advance can use the prepared-player path when ready.
- The prepared player becomes the primary player and MediaSession is reattached to the new primary player.
- Safe fallback remains available when the candidate is stale or not ready.

This replaces the old roadmap statement that prepared-player handoff was still deferred.

## Product milestones already implemented

The active Flutter app now includes foundations for:

- Home / Library / Now / Queue / Downloads consumer navigation.
- Device Music through Android MediaStore.
- Local downloads/cache and offline playback.
- Search, collections, listening history, themes, settings, and developer diagnostics.
- Shuffle, repeat, and sleep timer controls.
- Audio quality selection and Smart Downloads.
- Cloud Vault product/data-model foundation.
- Large-catalog performance safeguards.
- Curated demo shelves and deterministic generated artwork fallbacks.

## Current priority — consolidation and hardening

Do not add another large feature wave before the active product is easier to maintain and release.

Current order:

1. Stabilize native playback/session lifetime and other P0 behavior bugs.
2. Correct stale consumer status/documentation truth.
3. Decompose the large Flutter V3 screen/state owner into feature modules without rewriting behavior.
4. Harden native service/security boundaries and decide the Audio Effects product truth.
5. Decide whether Rust becomes a real shipping runtime decision layer or remains a documented deterministic/reference engine.
6. Modularize the Rust API and wire production persistence only when required.
7. Add Flutter/Android CI and release engineering.
8. Build the narrow local-first Nova music/clip selection integration.

## Deferred product work

These remain future work and should not be presented as complete today:

- Real native DSP/effects implementation.
- Google Drive/Dropbox/OneDrive/Nextcloud provider integrations.
- Hosted production catalog/database operations.
- R2 signed media delivery and production encoding pipeline.
- Auth/accounts and cloud sync.
- Artist upload/dashboard workflows.
- Payments/subscriptions and DRM/licensing integrations.
- iOS AVFoundation playback adapter.
