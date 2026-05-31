# WaveZero Development Guide

Phase 0E keeps the app feature set unchanged and focuses on the daily developer loop. The default path is to run the app directly from Android Studio or Flutter tooling, then use Firebase App Distribution only when a build needs to be shared with testers.

## Recommended daily Android loop

Use **Android Studio Run** for normal Android development:

1. Open Android Studio.
2. Choose **File > Open** and select `apps/android`.
3. Let Gradle sync finish.
4. Select a connected physical Android device.
5. Press **Run** for the `app` configuration.

This is preferred over manually building and sending APKs because it keeps install, logcat, and debugger workflows in one place.

## Wireless Debugging setup

Wireless Debugging is useful when the device and development machine are on the same trusted network.

1. On the Android device, enable **Developer options**.
2. Enable **Wireless debugging**.
3. In Android Studio, open **Device Manager > Pair Devices Using Wi-Fi**.
4. Pair using the QR code or pairing code shown by the device.
5. After pairing, choose the wireless device in Android Studio and press **Run**.

PowerShell verification commands:

```powershell
adb devices
adb connect <device-ip-and-port>
adb devices
```

If `adb` is not found, install Android Studio or add the Android SDK `platform-tools` directory to `PATH`.

## Java environment on Windows

Android Studio includes a Java runtime that works for the local Gradle build. If a PowerShell build cannot find Java, set `JAVA_HOME` to Android Studio's bundled JBR:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

The helper scripts set this automatically when that path exists and `JAVA_HOME` is not already set.

## Manual debug APK fallback

Manual APK generation is only a fallback for debugging or temporary local install. Prefer Android Studio Run for development and Firebase App Distribution for tester sharing.

From the repository root:

```powershell
.\scripts\dev\android-assemble-debug.ps1
```

The generated native Android APK appears at:

```text
apps\android\app\build\outputs\apk\debug\app-debug.apk
```

Install the fallback APK on a connected device:

```powershell
.\scripts\dev\android-install-debug.ps1
```

## Flutter Android loop after Flutter SDK install

After installing Flutter and Android Studio support, run the Flutter host from PowerShell:

```powershell
.\scripts\dev\flutter-run-android.ps1
```

The script runs `flutter pub get` in `apps/flutter/wavezero_app` and then runs `flutter run`. You can also run the commands manually:

```powershell
cd apps\flutter\wavezero_app
flutter pub get
flutter run
```

## Verify the Phase 0D Flutter bridge

The Phase 0D bridge is healthy when the Flutter app can command Android Media3 through the `wavezero/playback` MethodChannel.

1. Start the Flutter app on an Android device with `flutter run` or Android Studio.
2. Use the playback controls to load and play the test track.
3. Confirm audio plays through the native Android Media3 adapter.
4. Confirm the metrics panel updates fields such as session ID, attempt ID, playback state, current position, `tapToReadyMs`, `tapToIsPlayingMs`, `tapToPositionAdvanceMs`, last event, track title, and track URL.
5. If the Android channel is missing, the Flutter UI should remain open and show a readable playback error instead of crashing.

## Local environment check

Run this before sharing a build or debugging a local setup:

```powershell
.\scripts\dev\check-local-env.ps1
```

It prints the current Git branch and checks Java, `adb`, Flutter, `FIREBASE_APP_ID`, and expected project directories.

## Auto local development workflow

Use the new local startup scripts to avoid editing IP addresses when your hotspot or Wi-Fi address changes.

Terminal 1:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\wavezero-run-audio.ps1
```

Terminal 2:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\wavezero-run-api.ps1
```

Terminal 3:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\wavezero-run-flutter.ps1
```

These scripts auto-detect your active local IPv4 address and update `WAVEZERO_AUDIO_BASE_URL` for the Rust API at startup. That means `services/api/fixtures/dev_catalog.json` can keep its existing hardcoded local URLs without manual editing.
The Rust API also now auto-discovers supported local audio files from `WAVEZERO_AUDIO_DIR` or the default Windows path `C:\Users\dell\Desktop\wavezero-test-audio`.

Supported formats:

- `.mp3`
- `.m4a`
- `.wav`
- `.aac`

If a supported file is present in the local audio folder, the API will add a catalog track such as `track-local-song6` with a generated title like `Song 6` and a manifest URL under `http://<ip>:8090/<filename>`. This is a dev-only local catalog discovery feature, not a production upload path.
If auto-detection fails, run `.\scripts\wavezero-local-ip.ps1` to verify your local address or use a fixed `WAVEZERO_AUDIO_BASE_URL` during API startup as a fallback.

## CI status

Phase 0E adds stable Rust CI only. Android and Flutter CI are intentionally documented as future work until the local Android and Flutter build paths are verified without committing Gradle wrapper binaries or secrets.

## Local multi-track catalog audio

The development API serves a controlled local catalog for validating queued playback, native prebuffering, and prepared handoff behavior across more than one transition. The catalog keeps the existing local tracks and adds two more local MP3 placeholders; catalog loading does not check whether these files exist, so missing files should only surface when a developer tries to play that specific track.

Expected local audio files on the Windows development machine:

```text
C:\Users\dell\Desktop\wavezero-test-audio\song.mp3
C:\Users\dell\Desktop\wavezero-test-audio\song3.mp3
C:\Users\dell\Desktop\wavezero-test-audio\song4.mp3
C:\Users\dell\Desktop\wavezero-test-audio\song5.mp3
```

Serve that directory on port `8090` so the API catalog URLs resolve from the Android device:

```text
http://192.168.1.7:8090/song.mp3
http://192.168.1.7:8090/song3.mp3
http://192.168.1.7:8090/song4.mp3
http://192.168.1.7:8090/song5.mp3
```

Manual Android verification checklist for the expanded local chain:

1. Add `song4.mp3` and `song5.mp3` to `C:\Users\dell\Desktop\wavezero-test-audio`.
2. Start the local audio server on port `8090`.
3. Start the Rust API.
4. Run the Flutter app.
5. Confirm catalog shows at least 4 tracks.
6. Add all tracks to queue.
7. Play Local Real Song.
8. Wait for `nativePrebufferReady` on the up-next track.
9. Tap Next repeatedly and confirm each next track plays.
10. Let one track auto-advance and confirm prepared auto-advance still works.
11. Confirm `playbackError = none`.
12. Confirm prebuffer/handoff metrics still update.

## Phase 2A.2 Android smoke checklist

Use this checklist when validating Smart Preload with Phase 2A.1 Soft Stop recovery on a physical Android device or emulator:

1. Start the Flutter host and confirm the Smart Preload card is enabled by default.
2. Load the catalog and wait for `manifestPrefetched: true` for the up-next track.
3. Tap Stop while the current track is loaded or playing; the current track should reset to `0:00`, notification controls should remain available, and the Smart Preload card should keep the valid prefetched manifest for the unchanged up-next track.
4. Tap Play after Stop; playback should resume from the current track without incrementing `prefetchHitCount` or `prefetchMissCount`.
5. Tap Stop again, then tap Next; the queue should advance to the up-next track and the prefetch hit/miss counters should update only for that Next action.
6. Continue with Play/Pause from the app and notification controls while backgrounding the app; metrics should stay consistent and no playback error should appear.
7. Confirm Phase 2A metric honesty: `manifestPrefetched` may be `true`, while `audioPreparedBeforeNext` and `nextPreparedBeforePlay` remain `false` until a native audio prebuffer implementation exists.

## Phase 2A.3 Performance baseline checklist

Use this developer-facing baseline before Phase 2B native audio prebuffering changes:

1. Open the Flutter player shell and load the catalog.
2. Play Local Real Song and record `tapToAudioMs` from the Performance Baseline panel. This is surfaced from the existing native `tapToFirstAudioMs` metric.
3. Wait for Smart Preload to show a manifest-prefetched up-next track, then tap Next while playback is active.
4. Confirm `nextTapToAudioMs` appears after playback is observed for the next track; leave it unavailable if the session has not observed a Next-to-audio flow yet.
5. Record `prefetchHitCount` and `prefetchMissCount` only from explicit Next actions; Stop then Play must not change either counter.
6. Tap Stop, then Play, and record `stopToPlayRecoveryMs` if it appears. Leave it unavailable if the flow has not been observed yet.
7. Record `sessionRecoveryMs` when available from startup session-store recovery.
8. Confirm honesty before Phase 2B: `audioPreparedBeforeNext` and `nextPreparedBeforePlay` must remain `false` unless native audio preparation actually exists.

## Phase 2B native prebuffer clear-state smoke checklist

Use this checklist when validating the Phase 2B secondary ExoPlayer prebuffer foundation on Android:

1. Enable Smart Preload and wait for `manifestPrefetched: true`, then `nativePrebufferReady: true` for the up-next track.
2. Disable Smart Preload and confirm `nativePrebufferReady` clears.
3. Clear the queue and confirm native prebuffer metrics clear instead of retaining the previous up-next track.
4. Change the up-next track and confirm `nativePrebufferTrackId` updates to the new candidate.
5. Tap Next and confirm playback still uses the safe fallback path.
6. Confirm `nextPreparedBeforePlay` remains `false` until a future prepared-player handoff is implemented.

## WaveZero design system foundation metrics layout

The Flutter player shell now uses a calmer dark design-system foundation for the current single-screen music engine experience. The default screen keeps playback controls, queue, Smart Preload, and metrics copy/reset behavior intact, but presents engine telemetry with clearer hierarchy instead of a raw debug-dashboard layout.

Smart Preload telemetry is grouped into three visible sections:

1. **Manifest Prefetch** — user-facing predictive manifest state and last prefetch result.
2. **Native Prebuffer** — the key native prebuffer readiness, prepare latency, and hit/miss counters.
3. **Prepared Handoff** — explicit Next / auto-advance prepared handoff timing and readiness signals.

Only the most important playback engine numbers are emphasized by default. The complete unchanged metrics payload remains available from the collapsed **Show raw metrics** control for developer inspection, copying, and reset workflows.

## Premium product shell (Phase 57)

Phase 57 introduces a UI-only reorganization that converts the single long "lab" screen into a premium product shell with five product sections while preserving all existing engine and playback behavior. This is a visual/layout change only — no native playback, ExoPlayer/Media3, queue policy, Smart Queue Policy, catalog API, or metrics names were changed.

Sections and responsibilities

- Home: WaveZero identity, current track summary, quick playback health. Reuses existing `_TopBar`, `_NowPlayingCard`, `_StatusStrip`, `_SessionStrip`, and `_HealthStrip` widgets for a focused first impression.
- Now: Focused now-playing controls and timeline. Reuses existing `_NowPlayingCard`, `_MetricsToggle`, and `_MetricsPanel` for developer toggles when needed.
- Queue: Queue list and Smart Queue reason/controls. Reuses existing `_QueueCard` and `_SmartPreloadCard` to show the predictive candidate and reason.
- Library: Catalog list, search, and manual track setup. Reuses existing `_CatalogListCard` and `_TrackSetupCard` and keeps the same `CatalogClient` API usage (including demo fallback behavior).
- Engine: Smart Preload, Performance Baseline, and Show raw metrics. Reuses `_SmartPreloadCard`, `_PerformanceBaselinePanel`, `_MetricsToggle`, and `_MetricsPanel` to surface developer telemetry; the raw metrics remain available under "Show raw metrics".

Design and constraints

- Visual direction: premium dark — calm, minimal, strong hierarchy; reuses `_WzTokens` color and typography tokens. No gradients or neon; no Spotify-like visuals.
- Hard rules preserved:
	- Native playback implementation is unchanged.
	- ExoPlayer/Media3 logic and prepared / prebuffer handoff logic are unchanged.
	- Queue behavior and Smart Queue Policy logic are unchanged.
	- Catalog API usage is unchanged; manifest prefetch and manifest fetch flows are preserved.
	- All metrics names, counters, and developer tools (copy/reset) are unchanged and still accessible.

Developer notes

 - This change is intentionally UI-only and keeps all existing widgets and behaviors to avoid any runtime or engine regressions.

**Manual visual/playback checklist**

- App opens on Home.
- Bottom navigation switches Home / Now / Queue / Library / Engine.
- Play/Pause/Stop/Next still work from Now.
- Queue actions still work from Queue.
- Catalog search and track selection still work from Library.
- Smart Preload and raw metrics remain available from Engine.
- `playbackError` remains `none` during normal local playback.

## WaveZero #66 — Audio Effects Foundation

WaveZero #66 adds the first safe foundation for user-selectable audio effect profiles without changing the Rust API, Queue Engine v2, Downloads Manager, Local Folder Auto Catalog, or preferred audio quality selection behavior.

### Profiles

The Flutter app models these profiles in `AudioEffectProfile`:

- **Off / Original** — no intentional effect; preserves the original playback path.
- **Bass Boost** — subtle low-end lift with negative preamp metadata to avoid aggressive boost.
- **Vocal Clarity** — slight mid/high presence metadata for clearer vocals.
- **Warm** — gentle low-mid warmth metadata with mild treble softening.
- **Bright** — light treble lift metadata.
- **Night / Soft** — low-intensity listening profile foundation. This does not claim compression or normalization unless a native bridge reports that real DSP is applied.

The EQ-style bass/mid/treble/preamp values are intentionally subtle and are shown as diagnostics/profile intent. They must not be interpreted as active DSP unless the native status is `applied`.

### Off / Original mode and quality safety

Off / Original is the default and returns the app to no-effect mode. When preferred audio quality is **Original**, WaveZero does not automatically enable any effect. Effects may alter original audio, so any non-off profile must come from explicit user selection and diagnostics call this out.

### Native status meanings

The Engine → Audio Effects panel reports the native effect status returned by the playback bridge:

- `off` — effects are disabled and original/no-effect playback is intended.
- `pending` — Flutter has selected/restored a profile and is waiting for the native bridge result.
- `applied` — native playback reports that the requested effect is actually active.
- `unsupported` — the profile is represented in app state/diagnostics, but native DSP is not available or not enabled.
- `failed` — the bridge call failed; playback should continue without crashing.

For the current safe foundation, Android accepts the method channel call and returns `off` for Off / Original or `unsupported` for non-off profiles. This deliberately avoids claiming Equalizer, BassBoost, compressor, normalizer, or mastering DSP is active before a stable native audio-session implementation is added.

### Manual checklist

1. Start app.
2. Play a cached or catalog track.
3. Open Engine → Audio Effects.
4. Switch between Off / Bass Boost / Vocal Clarity / Warm / Bright / Night.
5. Confirm playback does not stop/crash.
6. Confirm diagnostics update.
7. Confirm Off returns to original/no-effect mode.
8. Restart app and confirm selected profile persists.
9. Play an original/high-quality track and confirm effects are only applied by explicit user selection.

## WaveZero #68 — Now Playing Experience v1

WaveZero #68 upgrades Now Playing into the core premium playback screen while preserving engine behavior. The screen now emphasizes large artwork or a generated gradient placeholder, real track identity, live playback state, quality/effects/cache badges, an up-next preview, a larger progress area, and a centered player control row.

The implementation uses existing real engine state only. Quality reflects the selected manifest/cache/preferred quality state, effects reflect the selected profile and native effect status, cache/offline reflects current cached playback and offline-library availability, and Queue context reflects the existing Queue Engine v2 position and up-next track.

This work does not change native Android playback, the native playback bridge, queue/cache/download behavior, Smart Downloads, Audio Quality selection logic, or the Audio Effects bridge behavior. It also intentionally does not add lyrics, a visualizer, theme customization, AI recommendations, login/cloud features, upload, database, DRM, payments, or fake data. Engine diagnostics remain available.

Manual checklist:
1. Start app.
2. Open Now page before loading a track and confirm empty/placeholder state looks good.
3. Play a track from Library.
4. Confirm Now shows title, artwork/placeholder, playback state, quality, effects, cache/offline state.
5. Confirm play/pause works.
6. Confirm seek works.
7. Confirm previous/next still work.
8. Add multiple tracks to queue and confirm up-next preview updates.
9. Cache a track and confirm source/cache badge updates.
10. Open Downloads and play a cached track; confirm Now reflects cached/offline context.
11. Confirm Engine diagnostics still exist and behavior did not change.

## WaveZero #67 — Real Design System v1 + Product Shell Upgrade

WaveZero #67 starts moving the Flutter player from a developer-dashboard feel toward a real premium music app shell while preserving the playback engine. This is a UI/product-architecture pass only: Android native playback, Rust API behavior, cache/download behavior, queue behavior, audio quality selection logic, audio effects bridge behavior, local catalog behavior, and session persistence remain unchanged.

### Design System v1 purpose

The shared Flutter design system lives at `apps/flutter/wavezero_app/lib/design/wavezero_design_system.dart`. It provides the first reusable product tokens and lightweight components for upcoming Home, Now Playing, Library, Settings, and future theme work:

- `WzColors` for premium dark surfaces, product accents, gradients, semantic status colors, and text colors.
- `WzSpacing` and `WzRadius` for reusable spacing and shape scale.
- `WzText` for product display, page, section, body, caption, and eyebrow typography.
- `WzSurface` for shared panel decoration and shadows.
- `WzPageScaffold`, `WzPageHeader`, `WzSectionHeader`, `WzPanel` / `WzGlassCard`, `WzStatusPill`, `WzPrimaryAction`, and `WzMiniMetric` for simple premium shell building blocks.

The existing private `_WzTokens` remain in place for compatibility and now mirror the shared design-system colors. Future UI work can migrate gradually instead of performing a risky split/refactor.

### Product shell direction

The app shell now has a branded WaveZero top area with concise product-level engine status, keeps the mini player, and keeps the bottom navigation across Home / Now / Queue / Library / Downloads / Engine. Main pages use product headers and cards so the default app experience feels like a music product while Engine continues to hold advanced diagnostics.

### Home v1 sections

Home v1 is no longer an empty or purely technical landing page. It uses only real existing state and includes:

1. **Hero** — “WaveZero” and “A smart music experience engine.” with a concise native playback / engine summary.
2. **Current listening** — current track title when present, play state, quality label when available, and cache/offline hints only when real state indicates them.
3. **Smart engine cards** — Smart Downloads, Instant Next / Preload, Offline Ready, and Audio Quality summaries.
4. **Quick actions** — Go to Library, Go to Queue, Go to Downloads, and Go to Engine.
5. **Status/session context** — concise operation and session state without turning Home into raw debug telemetry.

### Engine remains advanced diagnostics

Engine is still the advanced/developer diagnostics area. It is visually organized into:

- Playback Engine
- Smart Preload
- Smart Downloads
- Audio Quality
- Audio Effects
- Cache / Offline
- Raw Metrics

Raw metric names and important diagnostics remain available for developer validation. Product pages avoid raw-only language where possible, but Engine keeps the detailed counters and labels needed for troubleshooting.

### Not final full UI/UX yet

This is the first real design-system and product-shell foundation, not the final WaveZero interface. Full Home content, expanded Now Playing, complete Library UX, Settings, and Theme Customization are intentionally later work. Theme Customization specifically comes after this design-system foundation is stable.

### Manual checklist

1. Start app.
2. Confirm bottom navigation still works.
3. Confirm Home shows real current state and quick actions.
4. Confirm Now playback controls still work.
5. Confirm Library load/select/cache actions still work.
6. Confirm Queue move/play-next/remove still work.
7. Confirm Downloads play/delete/clear still work.
8. Confirm Engine diagnostics are still visible.
9. Confirm Audio Quality and Audio Effects panels still work.
10. Confirm no playback behavior changed.

## WaveZero #69 — Device Local Music Import Foundation

WaveZero #69 adds the first Android device-local music import foundation so the Flutter app can discover and play audio that already lives on the phone, separately from the Rust API catalog, Local Folder Auto Catalog, and Downloads cache.

### Android MediaStore behavior

- Uses Android `MediaStore.Audio.Media` to scan audio/music entries from the device media library.
- Requests the minimal audio-only runtime permission:
  - Android 13+ (`API 33+`): `android.permission.READ_MEDIA_AUDIO`
  - Older Android versions: `android.permission.READ_EXTERNAL_STORAGE` with `maxSdkVersion="32"`
- Does **not** request `MANAGE_EXTERNAL_STORAGE`.
- Does **not** request image/video media permissions.
- Does **not** scan arbitrary raw file paths.
- The initial scan is intentionally bounded to 500 tracks and ignores clips shorter than 30 seconds to avoid notification/ringtone-like audio in this foundation PR.
- Metadata is read safely from MediaStore only: title, artist, album, duration, size, MIME type, display name, date fields, content URI, and best-effort codec/quality labels.
- No heavy metadata parsing, background worker, cloud sync, database migration, upload, DRM, or AI recommendation logic is included.

### Playback and cache behavior

- Device tracks play directly from their `content://` MediaStore URI through the existing native Media3/ExoPlayer playback bridge.
- WaveZero does **not** copy device music into app cache or Downloads storage.
- Device Music is a separate local source from:
  - API Catalog tracks
  - Local Folder Auto Catalog served by the Rust API
  - Downloads Manager remote/API cached tracks
  - Smart Downloads cached tracks
- Smart Downloads must skip device `content://` tracks because they are already local.
- Downloads Manager behavior for remote/API cached tracks is unchanged.

### Flutter app behavior

- Library now has a source filter for **API Catalog**, **Device Music**, and **All**.
- Device Music import is user-initiated through the Library screen.
- Device tracks can be searched by title, artist, album, and display name.
- Device tracks can be selected for playback and added to Queue Engine v2.
- Now Playing shows device playback as a device/local source and avoids presenting it as a remote track that is merely “not cached.”
- Engine diagnostics report device permission status, import count, scan status, last error, last import time, and platform support.

### Manual checklist

1. Install/run app on an Android device.
2. Open Library.
3. Tap **Import Device Music**.
4. Grant audio permission.
5. Confirm device music count appears.
6. Confirm device tracks show title/artist/duration/source.
7. Search for a device song.
8. Play a device song.
9. Confirm Now Playing shows the device track and a Device source.
10. Add device tracks to Queue.
11. Confirm Queue play-next/move/remove still work.
12. Confirm Smart Downloads does not try to cache `content://` device tracks.
13. Deny permission on a fresh install/device and confirm app does not crash.
14. Confirm API Catalog still works.

This is a focused foundation PR, not the final full Library v2 experience.
