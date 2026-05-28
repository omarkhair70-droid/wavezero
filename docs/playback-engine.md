# Playback Engine

The playback engine is split between platform playback libraries and the shared
Rust core.

## Rust Core Responsibilities

`crates/wavezero-core` is pure decision logic. It does not perform network IO,
read disks, or control decoders directly. This keeps playback behavior easy to
unit test and portable across Android and future clients.

Core modules:

- `queue.rs` — `PlaybackQueue` with `set_queue`, `current_track`, `next_track`,
  `previous_track`, and `move_to_track`.
- `prefetch.rs` — deterministic `PrefetchDecision` calculation from current
  track, next track, network score, and cache state.
- `cache.rs` — cache metadata snapshots supplied by clients.
- `manifest.rs` — `Track` and `TrackAsset` stream metadata.
- `network.rs` — platform-normalized `NetworkScore` and `NetworkType`.
- `metrics.rs` — `PlaybackMetric` startup, buffering, network, and cache fields.

## Android Playback Path

Phase 0B adds a real Android playback proof with Kotlin, Jetpack Compose, and
AndroidX Media3 ExoPlayer. ExoPlayer owns HLS loading, decoding, buffering, and
audio output. The Android `AudioPlayerManager` exposes state and metrics to
Compose while keeping the demo track source isolated for later API replacement.

The Rust core remains the playback brain for deterministic queue and prefetch
decisions. Android will pass track, queue, cache, and network snapshots through a
future UniFFI/JNI boundary, then translate `PrefetchDecision` outputs into Media3
preload/cache behavior. See `docs/android-playback-proof.md` for the Phase 0B
boundary and metrics details.

## Future iOS Playback Path

TODO: iOS AVFoundation integration will consume the same core decisions through a
future FFI boundary.

## Offline Cache

TODO: Offline cache policy will define which manifests and segments may persist,
when to evict, and how to respect metered networks and user settings.
