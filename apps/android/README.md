# WaveZero Android App

Android is the first client target for WaveZero.

Phase 0 focuses on the shared Rust playback brain and API foundations. The app
module is intentionally a placeholder until the Media3 playback adapter and FFI
boundary are introduced.

TODO: Android Media3 integration:
- Create Kotlin + Jetpack Compose app shell.
- Bridge queue, prefetch, cache metadata, and metrics decisions from `wavezero-core`.
- Use AndroidX Media3 ExoPlayer for HLS/CMAF playback.
- Wire Media3 cache events into deterministic core cache state.
- Emit playback metrics to `services/api`.

TODO: Offline cache policy:
- Define eviction rules and persistence boundaries.
- Respect user settings and metered-network constraints.
