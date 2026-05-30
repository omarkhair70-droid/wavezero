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

### Phase 0B — Android Native Playback Proof

Status: Completed

Outcome:

- Android Media3/ExoPlayer proof runs on a real Android phone.
- HLS demo playback works.
- The native proof can build a debug APK locally.
- Core playback metrics are visible on device.

### Phase 0C — Max Stack Foundation

Status: Completed

Outcome:

- Flutter shell added as the future UI/experience layer.
- Rust FFI scaffold added without replacing `wavezero-core`.
- Max Stack architecture docs added.
- Flutter/Rust/native ownership boundaries documented.

### Phase 0D — Flutter to Android Media3 Bridge

Status: Completed

Outcome:

- Flutter Android host added under `apps/flutter/wavezero_app/android`.
- Flutter `wavezero/playback` MethodChannel wired to Android `AudioPlayerManager`.
- Android Media3 remains the real playback adapter.
- Flutter can command load/play/pause/stop/retry/reset/metrics through the bridge.
- Metrics model now includes richer bridge fields including session, attempt, timing, event, track title, and URL.

### Phase 0E — Developer Distribution Automation

Status: Completed

Outcome:

- Android and Flutter local development scripts were added.
- Flutter Android host can build and install locally.
- Firebase App Distribution documentation exists without committing credentials.
- Stable Rust CI checks run on GitHub Actions.

### Phase 0E.1 — Flutter Android Toolchain Upgrade

Status: Completed

Outcome:

- Flutter Android host Android Gradle Plugin was upgraded to a Flutter-supported version.
- Flutter Android host Kotlin plugin was upgraded to a Flutter-supported version.
- Flutter Android repository resolution and build output path remain stable.

### Phase 0F — Background Playback and Media Session

Status: Completed

Outcome:

- A Media3 `MediaSession` wraps the shared ExoPlayer instance.
- Music audio attributes and Android audio-focus handling are configured.
- Noisy-device handling is enabled through ExoPlayer's built-in becoming-noisy handling.
- Flutter and native manifests are prepared for media playback foreground-service permissions.
- Screen-off playback was verified manually on Android.

### Phase 0F.1 — Foreground Media Playback Service

Status: Completed

Outcome:

- A shared playback session owner connects Flutter, the native proof, and the Android service to the same playback manager.
- A Media3 `MediaSessionService` is registered in the native and Flutter Android manifests.
- Android can discover the active WaveZero media session.
- Android 13+ notification permission is declared.

### Phase 0F.2 — Runtime Notification Permission and Reliable Media Controls

Status: Completed

Outcome:

- Android 13+ notification permission is requested at runtime from the Flutter host.
- MediaSessionService starts before play/retry bridge commands.
- Flutter remains the product command surface.

### Phase 0F.3 — Explicit Foreground Playback Notification

Status: Completed

Outcome:

- WaveZero creates an explicit foreground playback notification.
- Notification channel `wavezero_playback` exists.
- Notification Play/Pause and Stop actions control the shared player.
- Notification playback controls were verified manually on Android.

### Phase 0G — Accurate Metrics System

Status: Completed

Outcome:

- Playback metrics are attempt-based and live-refreshing in Flutter.
- `tapToReadyMs`, `tapToIsPlayingMs`, and `tapToPositionAdvanceMs` are visible on device.
- Startup buffer and rebuffer metrics are separated.
- Duplicate Play taps during startup no longer create fake attempts.
- Wi-Fi and 4G baseline testing has started.

### Phase 0H — Startup Speed Optimization

Status: Completed

Outcome:

- Media3 prepare starts during Load Track.
- Play becomes a fast `playWhenReady` command when the player is already ready.
- Wi-Fi and 4G tap-to-audio results improved to around half a second in manual testing.
- Notification, background playback, and duplicate Play guard behavior were preserved.

### Phase 0H.1 — Preload Metrics

Status: Completed

Outcome:

- Preload work is now visible through `preparedBeforePlay`, `loadToManifestMs`, `loadToReadyMs`, `prebufferCount`, and `prebufferMs`.
- Flutter displays the preload metrics.
- Android and Flutter tests cover the preload metrics contract.

### Phase 0I — Real Player UX

Status: Completed

Outcome:

- The Flutter proof screen became a real player shell.
- The UI includes a now-playing card, artwork placeholder, progress slider, main playback controls, diagnostics panel, and mini-player strip.
- Native seek support is available through the Flutter/Android bridge.
- Metrics remain visible and copyable from the player UI.

### Phase 0I.1 — Player UX Polish and Seek Reliability

Status: Completed

Outcome:

- Seek attempts are tracked with `seekCount` and `lastSeekToMs`.
- Seek-induced buffering is tracked separately through `seekBufferMs`.
- Buffering caused immediately by seek no longer inflates `rebufferCount`.
- Native seek targets are clamped to known media duration when available.

### Phase 1A — Real Catalog API Foundation

Status: Completed

Outcome:

- A development catalog fixture now contains artists, tracks, artwork URLs, durations, and stream assets.
- API routes exist for `/catalog`, `/artists`, `/artists/:id`, `/tracks`, `/tracks/:id`, and `/tracks/:id/manifest`.
- API responses include artist names, artwork URLs, primary assets, and stream URLs.
- The API was verified locally through `/health`, `/catalog`, and `/tracks/track-apple-bipbop-hls/manifest`.

### Phase 1B — Flutter Catalog Client Integration

Status: Completed

Outcome:

- Flutter can fetch `/tracks/:id/manifest` from a configurable dev API base URL.
- The player loads title, stream URL, duration, artist, and artwork from the API manifest.
- Local demo fallback remains available when the API is unavailable.
- The dev runner can pass `WAVEZERO_API_BASE_URL` into Flutter with `--dart-define`.
- Manual testing verified the Android app loading the catalog manifest from the local Rust API.

### Phase 1C — Catalog List UI

Status: Completed

Outcome:

- Flutter fetches `/catalog` from the API.
- The app renders catalog tracks with title, artist, artwork, duration, and selected state.
- Tapping a catalog track loads that track manifest into the existing player shell.
- Manual testing verified selecting and playing the second catalog track from Android.

### Phase 1D — Search and Catalog Polish

Status: Completed

Outcome:

- Local catalog search/filtering works in Flutter.
- Selected-track refresh and reload behavior is stable.
- Catalog rows show asset metadata such as codec and bitrate.
- Seeded development tracks are easier to distinguish during manual testing.

## Next Phases

### Phase 1D.1 — Local Real Track Catalog Entry

Status: In progress

Goal:

Make a locally hosted real MP3 track appear as a first-class catalog item so real-audio testing can happen through catalog search and selection, not only manual URL entry.

Scope:

- Add a `Local Lab` development artist.
- Add a `Local Real Song` catalog entry pointing at `http://192.168.1.7:8090/song.mp3`.
- Support `mp3` as a catalog/core asset codec.
- Keep the actual MP3 file out of git; it stays local in `Desktop/wavezero-test-audio/song.mp3`.
- Keep playback, search, metrics, background playback, and notification controls unchanged.

Non-goals:

- No committed copyrighted audio files.
- No upload UI yet.
- No production storage or signed URLs yet.

### Phase 1E — Queue Foundation

Goal:

Introduce the first queue model after catalog selection is stable.

Scope:

- Add a simple in-memory Flutter queue state.
- Add next/previous controls in the Flutter player shell.
- Keep the native playback bridge as the playback execution layer.
- Keep catalog and metrics intact.
