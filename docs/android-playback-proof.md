# Android Playback Proof

Phase 0B proves that the Android shell can play a real network HLS stream with
AndroidX Media3 ExoPlayer while keeping WaveZero's Rust core as the future owner
of queue, prefetch, and cache decisions.

## Scope

Included:

- Android-only playback proof.
- Kotlin + Jetpack Compose UI.
- Media3 ExoPlayer HLS playback.
- Local playback state and startup/buffering metrics.

Excluded:

- Authentication, subscriptions, social features, artist dashboards, AI
  recommendations, and iOS.
- Full Rust FFI wiring. That boundary is documented below and will be connected
  after the playback proof is stable.

## Demo Track

The app currently isolates a single hardcoded test track in `DemoTrack`:

- title: `Apple BipBop HLS Demo`
- artist: `WaveZero Phase 0B`
- URL:
  `https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear0/prog_index.m3u8`

This is intentionally centralized so the next API-backed step can replace the
constant with a track response without rewriting the player manager or UI.

## Android Player Layer

The playback proof uses three small Kotlin files under
`apps/android/app/src/main/java/com/wavezero/player/playback/`:

- `PlaybackState.kt` defines display state, status values, and the isolated demo
  track source.
- `PlaybackMetrics.kt` defines readable metrics plus pure `PlaybackMetricsTracker`
  logic that is unit tested without Android runtime dependencies.
- `AudioPlayerManager.kt` owns ExoPlayer, maps Media3 listener/analytics events
  into WaveZero state, and exposes `StateFlow` values for Compose.

`MainActivity.kt` only composes the proof UI and delegates playback operations to
`AudioPlayerManager`.

## Metrics

The UI displays:

- `app_screen_ready_ms`
- `tap_to_first_audio_ms`
- `manifest_load_ms`
- `buffer_count`
- `is_playing`
- `current_position_ms`
- `playback_error`

`tap_to_first_audio_ms` is measured from the play tap to the first Media3
`isPlaying=true` callback. `manifest_load_ms` is captured from Media3 analytics
when the completed load is classified as `DATA_TYPE_MANIFEST`. Buffer count is
incremented once per buffering span, not for repeated buffering callbacks in the
same span.

## Rust Integration Boundary

Phase 0B deliberately does not force UniFFI/JNI into the Android app. The next
step should add a thin boundary where Android asks Rust for decisions and then
applies them to Media3:

```text
Android UI tap / track selection
  -> Kotlin playback adapter captures current track, queue, cache, and network snapshots
  -> Rust wavezero-core computes PlaybackQueue and PrefetchDecision values
  -> Kotlin adapter converts decisions into Media3 media item, preload, and cache operations
  -> Media3 performs network IO, decoding, and audio output
  -> Kotlin sends observed PlaybackMetric values back to Rust/API event ingestion
```

The FFI surface should stay decision-oriented. Rust should not own Android
`Context`, ExoPlayer instances, coroutines, or platform lifecycle. Kotlin should
not duplicate queue and prefetch algorithms once the FFI boundary is connected.
