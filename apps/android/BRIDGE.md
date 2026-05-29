# Android Playback Bridge Plan

The existing Android playback proof remains the native Media3 adapter for WaveZero. Phase 0C does not wire Flutter into Android yet; it documents the bridge contract that a future PR can expose safely.

## Native owner

`AudioPlayerManager` should remain responsible for Media3 ExoPlayer ownership and Android playback concerns:

- actual decoded playback through Media3;
- app lifecycle and future background playback service integration;
- audio focus, Bluetooth, and route changes;
- lock-screen, notification, and MediaSession integration;
- playback errors, buffering state, manifest loading, and position metrics.

Flutter should call Android through a platform bridge. Flutter should not replace Media3 or perform low-level audio output.

## Reserved MethodChannel

The Flutter shell reserves this channel name:

```text
wavezero/playback
```

The Android bridge should eventually handle these method names:

| Method | Expected Android behavior |
| --- | --- |
| `loadTrack` | Accept a title and HLS URL, update the current MediaItem, reset relevant state, and prepare for playback when requested. |
| `play` | Delegate to `AudioPlayerManager.play()`. |
| `pause` | Delegate to `AudioPlayerManager.pause()`. |
| `stop` | Delegate to `AudioPlayerManager.stop()`. |
| `retry` | Re-load the current MediaItem and attempt playback after an error or stalled load. |
| `resetMetrics` | Reset playback metrics while preserving the currently loaded track. |
| `metricsSnapshot` | Return a serializable metrics map matching the Dart `PlaybackMetrics` model. |

## Next implementation step

A future bridge PR can add a small MethodChannel adapter around `AudioPlayerManager`, then let Flutter use `PlatformChannelPlaybackBridge`. That PR should preserve the current Android proof and keep all native playback responsibilities on Android.
