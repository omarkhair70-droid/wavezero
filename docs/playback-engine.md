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

## Smart Queue Policy

The Flutter shell now has a small deterministic Smart Queue Policy layer before
manifest prefetch/native prebuffer. This layer does not recommend music and does
not change Android playback, ExoPlayer handoff, MediaSession, notification, or
catalog API behavior. It only decides which already-queued catalog track should
be prepared next and exposes a developer-visible reason string.

Policy rules:

- If Smart Preload is off, no candidate is selected and `smartQueueReason` is
  `smart_preload_off`.
- If the queue is empty, no candidate is selected and `smartQueueReason` is
  `queue_empty`.
- If the current track is unknown, the policy falls back to the selected/current
  queue position safely before looking for an up-next track.
- If a valid up-next track exists, that track is selected with
  `smartQueueReason` set to `up_next`.
- The policy never selects the current track, a removed track, or a track that is
  not present in both the queue and the current catalog snapshot.
- If the candidate changes because the user selects another track or the queue
  changes, the old candidate is invalidated and `smartQueueReason` becomes
  `candidate_changed`.
- If the same candidate is already manifest-prefetched and native-prebuffered,
  the policy reports `already_prepared` and avoids re-preparing it.
- If there is no up-next track after applying these checks, no candidate is
  selected and `smartQueueReason` is `no_up_next`.

The Smart Preload panel and Queue card display the current candidate and
`smartQueueReason` so local verification can confirm queue-policy decisions
without relying on raw native playback metrics.
