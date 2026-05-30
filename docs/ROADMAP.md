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

### Phase 1G — Player State Machine and UX Cleanup

Status: Completed

Outcome:

- A Flutter operation-state model separates player, catalog, queue, seek, manual-track, and metrics operations.
- The player shows clearer state/status copy.
- Catalog search stays usable while audio is playing.
- Metrics refresh no longer blocks normal controls.
- Native playback bridge ownership remains unchanged.

### Phase 1I — Persistent Queue and Session Recovery

Status: Completed

Outcome:

- The queue, selected/current track, and auto-advance preference persist on-device.
- The player restores queued tracks after catalog load by matching stored track IDs against the current API catalog.
- Lightweight session recovery status is visible in the Flutter shell.
- Persistence remains client-side; accounts, backend storage, and databases are still outside the product scope.

## Next Phases

### Phase 2A — Predictive Preload + Instant Next Foundation

Status: In progress

Goal:

Use the current queue position to predict the next track and prefetch its catalog manifest so Next can avoid redundant API work before handing playback to the existing native bridge.

Scope:

- Add a Smart Preload toggle in the Flutter player shell, enabled by default.
- Detect the next queued track whenever the current track, queue, or auto-advance setting changes.
- Prefetch the predicted next track manifest on the Flutter side.
- Track prefetch hit/miss counts and show manifest-prefetch status separately from true audio preparation.
- Preserve the existing Media3/ExoPlayer playback bridge and normal fallback path.

Non-goals:

- No native dual-player audio prebuffering in Phase 2A.
- No Hi-Res Lossless.
- No Rust decoder rewrite.
- No P2P/IPFS.
- No auth.
- No cloud sync.
- No database.

### Phase 2B — Native Dual-Player Prebuffer / True Audio Preloading

Status: Planned

Goal:

Add a safe native playback-layer implementation for true audio preloading, likely with a second prepared player or Media3-supported prebuffer path, while keeping the Flutter Phase 2A manifest prefetch metrics honest.

Scope:

- Investigate a native dual-player or Media3 preloading strategy.
- Explicitly report audioPreparedBeforeNext only when native audio was actually prepared before the transition.
- Preserve background playback, notification controls, lock-screen controls, queue recovery, and accurate playback metrics.

Non-goals:

- No Hi-Res Lossless.
- No Rust decoder rewrite.
- No P2P/IPFS.
- No auth.
- No cloud sync.
- No database.

### Phase 1H — Local Library and Add Track UX

Status: Planned

Goal:

Replace manual URL editing with a cleaner local-library workflow.

Scope:

- Add a clearer local-track entry workflow.
- Reduce manual setup visibility for normal use.
- Keep production storage and upload outside this phase.
