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
- `.flac`

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

## WaveZero #70 — Library v2 + Search Experience

WaveZero #70 upgrades Library from a source-specific technical list into a unified music-library surface while preserving the existing playback, queue, cache, and Android MediaStore foundations.

### Unified Library sources

Library v2 exposes four real sources from existing app state:

- **All** — a combined view of API Catalog tracks, Android Device Music tracks, and cached/downloaded remote tracks.
- **API Catalog** — tracks returned by the existing catalog API and manifest flow.
- **Device Music** — user-imported Android MediaStore audio tracks that remain separate from app cache storage.
- **Downloads / Cached** — remote/API tracks already available from the existing Downloads Manager cache metadata.

The existing Downloads tab remains in place. The Downloads / Cached Library source is only an additional Library filter over the same cached-library state.

### Source filters, counts, and source cards

The Library screen now shows compact source summary cards for All, API Catalog, Device Music, and Downloads. Counts and statuses come from live app state only:

- API track count and current catalog status.
- Device import count, permission status, and last scan status.
- Cached/downloaded track count and cache storage size.
- Combined Library count across all Library sources.
- Filtered result count for the selected source/search state.

### Search behavior

Search v2 remains deliberately lightweight and in-memory. It does not add a database, indexer, fuzzy-search package, AI search, or cloud service.

Search runs only across the currently selected Library source and matches available metadata including:

- Title
- Artist/subtitle
- Album
- Display name
- Codec
- Quality label
- Source
- Track id

Search states are explicit:

- Empty query shows all tracks in the selected source.
- Active query shows the result count for the selected source.
- Empty results show a useful empty state and keep the clear-search action available in the search field.

### Sort behavior

Library v2 adds a sort control with safe handling for missing metadata:

- Recently added / imported
- Title A-Z
- Artist A-Z
- Longest duration
- Shortest duration
- Quality

Recently added/imported uses cached-at timestamps for downloaded tracks, the last import timestamp for Device Music, and stable existing order for API Catalog tracks.

### Source-aware rows and actions

Library rows now surface source-specific context:

- Title, artist/album subtitle, and duration.
- Source badges for API, Device, and cached/downloaded tracks.
- Quality and codec labels when available.
- Cache state for remote/API tracks.
- Already-local/device indicators for Device Music.

Actions remain source-aware:

- API Catalog tracks can be selected/played, added to Queue Engine v2, and cached/downloaded when an asset URL is available.
- Device Music tracks can be selected/played and added to Queue Engine v2, but do not show a cache button because they are already local `content://` media.
- Cached/downloaded Library rows can be played, added to Queue when safe, and deleted from cache using the same cache-delete behavior as the Downloads tab.

### Downloads/Cached view inside Library

The Downloads / Cached source shows cached remote/API tracks from the existing cached-library state. It displays quality, codec, download source, and cached/local status when available. It intentionally does not add new storage-manager logic.

Deleting a cached row from the Library Downloads view uses the existing cache deletion path so the Downloads tab reflects the same state after refresh.

### Device Music remains separate from Downloads cache

Device Music continues to play directly from Android MediaStore `content://` URIs. WaveZero does not copy device files into Downloads, and cached remote/API files remain separate from MediaStore imports.

### Intentionally not included

WaveZero #70 is not:

- Playlists.
- Cloud library sync.
- Login, upload, DRM, payments, or database-backed library storage.
- AI recommendations or AI search.
- Theme customization.
- A change to Android native playback, Media3/ExoPlayer, Rust API behavior, MediaStore permission behavior, Queue Engine v2 semantics, Smart Downloads behavior, CacheService behavior, Audio Quality selection, or Audio Effects bridge behavior.

### Manual checklist

1. Start app.
2. Open Library.
3. Confirm source cards/counts show real state.
4. Search API Catalog.
5. Import Device Music and search device songs.
6. Switch between All / API / Device / Downloads.
7. Sort by title and duration.
8. Play API track.
9. Play Device track.
10. Add API and Device tracks to Queue.
11. Cache API track and confirm it appears in Downloads/Cached library view.
12. Delete cached track from Library Downloads view and confirm Downloads tab updates.
13. Confirm Now Playing still works.
14. Confirm Engine diagnostics still exist.

## WaveZero #71B — Consumer Shell + Remove Dev UI from User App

WaveZero now separates the Flutter shell into two persisted app modes:

- **Consumer mode** is the default app mode for fresh installs and normal use. It presents WaveZero as a music app rather than a developer dashboard.
- **Developer mode** keeps the internal playback, library, cache, quality, effects, and metrics tools available for diagnostics without deleting them.

The mode is stored in SharedPreferences so a local developer device can stay in developer mode across launches. For now, developer mode is enabled or disabled through the internal long-press gesture on the WaveZero logo in the top shell header. Developer mode also includes an internal switch on the Engine diagnostics page to return to consumer mode.

Consumer bottom navigation is limited to:

1. Home
2. Library
3. Now
4. Queue
5. Downloads

The **Engine** tab is developer-only. In developer mode, navigation shows:

1. Home
2. Library
3. Now
4. Queue
5. Downloads
6. Engine

Manual/API setup is developer-only. API base URL fields, manual title/audio URL fields, raw metrics, raw performance baselines, engine diagnostics, device/library diagnostics, and developer metric names such as `tapToAudioMs`, `nativePrebufferReady`, `manifestPrefetched`, and `smartQueueReason` should not appear in consumer pages.

Consumer pages should prefer product copy and friendly failures. Raw catalog/API/network details remain available in developer mode, while consumer surfaces use simple messages such as:

- “Couldn’t load music right now.”
- “Check your connection and try again.”
- “Device music permission is needed to import local songs.”

Release builds should eventually be locked to consumer-only by default unless an explicit internal build flag enables developer mode. Future production API URLs should come from configuration or the build environment, not a user-editable text field in the consumer app.

Manual checklist:

1. Start app fresh.
2. Confirm default mode is consumer.
3. Confirm bottom nav does not show Engine.
4. Confirm Home has no raw metrics.
5. Confirm Library has no raw API setup panel.
6. Confirm Now has no raw metrics panel unless developer mode is enabled.
7. Enable developer mode with the internal WaveZero logo long-press gesture.
8. Confirm Engine tab appears.
9. Confirm Manual/API setup and raw metrics are still available in developer mode.
10. Disable developer mode from the Engine diagnostics internal switch or by long-pressing the WaveZero logo again.
11. Confirm app returns to the consumer shell.
12. Confirm playback, Library, Device Music, Queue, Downloads still work.
## WaveZero #71 — Rich Media Notification + Lock Screen Controls

WaveZero #71 upgrades the Android foreground media notification from the earlier basic Play/Pause + Stop foundation into a richer, source-aware media notification and lock-screen metadata foundation.

### Implemented notification and lock-screen behavior

- The native Android playback layer now tracks a notification media snapshot with track id, title, artist, album, URL, artwork URI, duration, source, quality label, and codec when Flutter has real metadata available.
- Flutter sends notification metadata over the existing `wavezero/playback` MethodChannel when catalog/API tracks, Android Device Music tracks, and cached/downloaded tracks are loaded.
- Flutter also sends a safe queue snapshot whenever Queue Engine v2 state changes through add, reorder, Play Next, remove, clear, and current-track changes. Queue-only edits update the native snapshot but do not force-start a foreground notification from a cold/no-track state.
- The foreground notification now exposes Previous, Play/Pause, Next, and Stop actions. Compact media-style actions prioritize Previous / Play-Pause / Next.
- Previous and Next are queue-aware on the native side. They use only the Flutter-provided snapshot and safely no-op when there is no previous/next playable item or the snapshot is missing/stale.
- Native notification actions accept existing playable URLs, including Android MediaStore `content://` tracks, cached/downloaded `file://` tracks, and remote `http://`/`https://` tracks. Notification actions do not download or cache anything.
- Media3 `MediaItem` metadata is updated with title, artist, album, and artwork URI where available so Android lock-screen/media surfaces can display the current metadata through the MediaSession foundation.

### Artwork behavior

Artwork is intentionally conservative in this foundation:

- Flutter sends real artwork URLs/URIs only when they already exist in catalog, device, or cache metadata.
- Native Android sets the Media3 metadata artwork URI when it can parse the URI.
- The notification does not perform blocking network artwork downloads on the main thread.
- Broken or missing artwork is reported through diagnostics as `none`, `uri_set`, or `failed` rather than crashing playback.

### Diagnostics

Engine metrics now include notification/media-session diagnostics:

- Notification metadata title and source.
- Native queue snapshot count.
- Previous/Next availability.
- Last notification action, result, and action track id.
- Native current track id, URL, title, artist, album, and source for small Flutter-side reconciliation.
- Artwork status.
- Media session status.

Flutter uses the native current track/action metrics during normal metrics refresh to align selected/current queue ids when the track exists in current library or queue state. This is deliberately small and does not rebuild manifests or rewrite Queue Engine v2 semantics.

### What is supported now

- Richer Android media notification metadata for API Catalog, Device Music, and cached/downloaded playback.
- Previous / Play-Pause / Next / Stop actions in the notification.
- Queue-aware native Previous/Next from the Flutter-provided queue snapshot.
- Lock-screen/media-session metadata foundation for title, artist, album, artwork URI, controls, and playback state.
- Device `content://`, cached `file://`, and remote URL playback through notification controls when those URLs are already known.

### Foundation / future work

This is not final certification or a full platform media integration suite:

- Android Auto is not final or certified.
- Bluetooth/media-button behavior is only the platform MediaSession foundation where Android supports it automatically; it is not claimed as final Bluetooth certification.
- No lyrics.
- No custom notification artwork generation.
- No like/download buttons in the notification yet.
- No cloud sync.

### Behavior intentionally not changed

WaveZero #71 does not change the Rust API, CacheService behavior, Android MediaStore scan/permission behavior, Downloads Manager semantics, Queue Engine v2 semantics beyond sending a safe notification queue snapshot, Smart Downloads behavior, Audio Quality selection logic, or the Audio Effects bridge. It also does not add playlists, login/cloud/upload/database/DRM/payments, AI recommendations, or theme customization.

### Manual checklist

1. Start app on Android.
2. Play an API Catalog track.
3. Pull down notification shade.
4. Confirm title and artist/subtitle are correct.
5. Confirm Play/Pause works from notification.
6. Add multiple tracks to Queue.
7. Confirm Next works from notification.
8. Confirm Previous works from notification.
9. Confirm app Now Playing/Queue state stays reasonable after notification Next/Previous.
10. Play a Device Music `content://` track and confirm notification works.
11. Play a cached/downloaded `file://` track and confirm notification works.
12. Lock phone and confirm lock-screen media controls appear with current metadata.
13. Press Stop/Dismiss and confirm playback stops and notification disappears.
14. Reopen app and confirm it does not crash and Engine diagnostics still show notification state.

## WaveZero #74 — Settings v1 + Theme Customization

WaveZero now includes a user-facing Settings screen that is available from the product shell header gear and from the Home quick actions panel. Settings is intentionally **not** a sixth consumer bottom-navigation item, so the consumer shell remains Home, Library, Now, Queue, and Downloads. Developer mode continues to add Engine diagnostics to the bottom navigation.

### Consumer and developer behavior

- Settings is available in both consumer and developer modes.
- Consumer mode keeps Engine diagnostics and raw metrics out of the Settings page.
- The Developer section in Settings shows the current app mode and provides the official Developer Mode switch.
- When Developer Mode is on, Settings explains that Engine diagnostics are available in the Engine tab and provides a shortcut to that tab.
- The existing long-press logo developer toggle remains available for now.

### Appearance and theme customization

Settings → Appearance provides persisted theme customization foundation:

- Theme presets:
  - Midnight — default/current dark look.
  - OLED Dark — deeper black surfaces for OLED-style contrast.
  - Wave Purple — a purple-tinted dark shell.
- Accent presets:
  - Wave Purple — default WaveZero purple.
  - Cyan.
  - Green.
  - Amber / Sunset.

Theme and accent choices are real app preferences. They update the Material theme color scheme, standard controls such as Switch, ChoiceChip, and FilledButton, the selected bottom-navigation color, the product shell gradient, and the Settings preview card.

Persistence keys:

- `wavezero.theme_preset`
- `wavezero.accent_preset`

### Playback settings

Settings → Playback mirrors the existing audio quality and audio effects controls without changing their underlying behavior.

- Preferred audio quality uses the existing quality selection state and user-friendly labels: Standard, High, and Original.
- If a selected track does not include the preferred asset, WaveZero keeps using the existing fallback behavior and explains it in friendly language.
- Audio effect profiles use the existing Audio Effects bridge and persistence behavior.
- Off / Original is described as the safest default.
- If native effect support is unsupported, Settings uses friendly copy: “Effect profile saved. Native DSP support is still foundation-level.”

### Downloads & Storage settings

Settings → Downloads & Storage summarizes the existing cache state without changing `CacheService` behavior:

- Smart Downloads enabled state.
- Cached tracks count.
- Total cache size.
- Manual downloads count.
- Smart downloads count.
- Clear all cache action, wired to the existing clear-cache handler.

This does not add storage manager v2, auto-clean policy, or any new download semantics.

### Device Music settings

Settings → Device Music uses the existing Android MediaStore import/permission flow and does not change native permissions or scanning behavior.

It shows:

- Permission status.
- Platform support status.
- Imported device tracks count.
- Last scan status.
- Friendly last message/error text.

Actions:

- Import Device Music.
- Rescan Device Music.

This does not add all-files access and does not use `MANAGE_EXTERNAL_STORAGE`.

### Notifications & Lock Screen settings

Settings → Notifications & Lock Screen gives consumer-friendly state only:

- Whether the media notification is active/inactive.
- Whether lock-screen controls are ready based on the active playback session.
- A short explanation that lock-screen controls use the current playback session and current track metadata.

This does not change native notification behavior and does not expose raw notification metrics in consumer mode.

### About

Settings → About identifies WaveZero as a smart music experience engine and keeps a small version/build placeholder. Legal/licenses and catalog credits remain future work.

### Future work intentionally left out

- Full storage manager v2.
- Legal catalog credits.
- Account/profile.
- Cloud sync.
- Subscriptions.
- Advanced EQ/native DSP.
- Production config management.
- Login, uploads, databases, DRM, payments, playlists, or legal catalog tracks.

### Manual checklist

1. Start app fresh.
2. Open Settings from Home/header.
3. Confirm Settings page has no overflow.
4. Change accent color and confirm visible UI changes.
5. Change theme preset and confirm visible UI changes.
6. Restart app and confirm theme/accent persist.
7. Change preferred audio quality from Settings.
8. Change audio effect profile from Settings.
9. Toggle Smart Downloads from Settings.
10. Clear cache from Settings and confirm Downloads updates.
11. Import/rescan Device Music from Settings.
12. Confirm consumer mode does not show raw metrics.
13. Toggle Developer Mode from Settings.
14. Confirm Engine appears in developer mode.
15. Toggle Developer Mode off and confirm Engine disappears.
16. Confirm playback, Library, Queue, Downloads, notification controls still work.

## WaveZero #75 — Real Storage Manager v1

WaveZero #75 adds a user-facing Storage Manager v1 for downloaded and cached-for-offline tracks while preserving the existing cache, download, Smart Downloads, offline playback, queue, and native playback semantics.

### Entry points

- Settings → Downloads & Storage keeps the existing summary metrics and now includes a **Manage storage** action.
- Downloads remains the user’s offline music list and includes a **Manage Storage** action for deeper management.
- Storage Manager is not a new bottom-navigation item; it is reached from Settings and Downloads.

### Storage summary

Storage Manager shows friendly summary cards for:

- Total tracks cached for offline playback.
- Total device storage used by downloaded/cached tracks.
- Manual downloads.
- Smart downloads.
- Offline-ready tracks.

The page also shows a friendly status:

- **Ready for offline playback** when tracks are available.
- **No downloads yet** / **Storage is clear** when the downloaded cache is empty.

### Categories

Storage Manager groups existing cached metadata into simple categories without adding a database or changing file storage:

- All cached.
- Manual downloads.
- Smart downloads.
- Current / recently cached, using the existing Smart Downloads current-track source when available.
- Unknown source fallback.

### Per-track actions and metadata

Each downloaded/cached track row can show:

- Title.
- Artist/subtitle.
- Source label: Manual, Smart Current, Smart Up Next, or Unknown.
- Quality label when available.
- Codec and bitrate when available.
- Local file size when available.
- Play action using the existing cached playback path.
- Remove from device action using the existing single-track cache delete handler.

### Smart Downloads toggle

Storage Manager exposes the existing Smart Downloads toggle with this consumer explanation:

> WaveZero can cache the current and up-next tracks for faster offline-ready playback.

This is only an entry-point/settings exposure. WaveZero #75 does not change Smart Downloads behavior.

### Clear all downloads

Storage Manager and Settings both keep a clear-all action wired to the existing clear-cache handler. Consumer copy uses **Clear all downloads** / **Storage is clear** language instead of raw diagnostic wording.

### Consumer and developer behavior

Consumer-facing storage UI avoids raw implementation details such as cache service names, file paths, internal asset IDs, preference keys, and stack traces. Developer diagnostics remain in Engine and may continue to expose advanced cache/offline counters for development.

### Intentionally not changed

WaveZero #75 intentionally does not change:

- Android native playback.
- Rust API behavior.
- Device Music native MediaStore behavior.
- Queue Engine v2 semantics.
- Smart Downloads logic beyond exposing the existing toggle.
- Audio Quality logic.
- Audio Effects bridge behavior.
- CacheService file format or persistence model.
- Cached playback semantics.
- Login, cloud sync, uploads, databases, DRM, payments, playlists, legal demo catalog tracks, or account sync.

Device Music tracks remain separate from downloaded/cached remote/API tracks and are not treated as Storage Manager downloads.

### Future work

- Auto-clean policy.
- Storage quota.
- Pin downloads.
- Playlist downloads.
- Cloud sync.
- Account sync.

### Manual checklist

1. Start app.
2. Open Settings.
3. Open Manage Storage.
4. Confirm storage summary matches Downloads/cache state.
5. Cache/download multiple tracks.
6. Confirm tracks appear in Storage Manager.
7. Confirm Manual vs Smart labels appear when available.
8. Play a cached track from Storage Manager.
9. Delete one cached track.
10. Confirm it disappears from Storage Manager and Downloads.
11. Clear all cache.
12. Confirm Downloads and Storage Manager become empty.
13. Toggle Smart Downloads.
14. Confirm no raw debug text appears in consumer mode.
15. Confirm Device Music tracks are not treated as cached downloads.
16. Confirm Library, Downloads, Queue, Now, Settings, and notification controls still work.

## WaveZero #76 — Legal Demo Catalog + License Ledger

WaveZero now includes a legal-safe demo catalog foundation. The goal is to expose rights metadata without adding copyrighted/commercial songs and without implying a track is licensed unless explicit metadata says so.

### License statuses

- `verified`
- `attribution_required`
- `public_domain`
- `dev_only`
- `user_device`
- `license_pending`
- `unknown`

Missing metadata remains safe by default: API/local entries are not treated as legally verified, and unknown entries are not production-safe.

### API and model fields

Catalog track responses and Flutter catalog models can carry:

- `licenseStatus`
- `licenseName`
- `licenseUrl`
- `sourceName`
- `sourceUrl`
- `artistUrl`
- `attributionText`
- `attributionRequired`
- `commercialUseAllowed`
- `redistributionAllowed`
- `derivativesAllowed`
- `usageNotes`

The Rust API keeps old clients compatible because missing fields deserialize with safe defaults. Flutter parsing is nullable-safe and cached metadata preserves license fields when available.

### Local dev tracks

Fixture tracks such as `song.mp3`, `song3.mp3`, `song4.mp3`, and `song5.mp3` are classified as `dev_only` with source `Local Dev Audio`. Auto-discovered local folder files default to `dev_only`, source `Local Folder`, no attribution requirement, no commercial use, no redistribution, and usage notes stating that rights are not verified.

### Device Music

Device Music imported from Android MediaStore is classified as `user_device`. WaveZero labels it as device/user music and does not claim catalog, redistribution, commercial, or production rights for those files.

### App UI entry points

- Settings → About → **Open Legal / Licenses** opens the Credits / Licenses page.
- Library rows show lightweight source/license badges such as Device music, Dev only, License pending, or Unknown.
- No bottom-navigation item was added for legal pages.

### Credits / Licenses page behavior

The page explains that WaveZero separates user device music, local dev audio, demo catalog tracks, and future licensed/artist uploads. It lists loaded catalog/library tracks with license badges, attribution text when present, source/license labels when available, and a warning for dev-only, pending, or unknown entries: not for production distribution until rights are verified.

### Legal-safe rules

- Do not add real third-party music files.
- Do not add copyrighted/commercial songs.
- Do not claim royalty-free, public-domain, Creative Commons, commercial-use, redistribution, derivative, or verified status without explicit committed metadata.
- Do not scrape, fetch, or verify licenses online in app/API code.

### Intentionally not done

- No copyrighted/commercial track was added.
- No online license fetching, scraping, DRM, login, uploads, payments, playlists, or cloud/database catalog was added.
- Android native playback, MediaStore behavior, Queue Engine v2 semantics, Smart Downloads, Audio Quality, Audio Effects, and notification behavior were not changed.

### Future work

- Real public-domain/Creative-Commons import after manual verification.
- Artist upload rights declaration.
- Signed rights records.
- Production content pipeline.
- Moderation/review workflow.
- Distributor/licensing integrations.

### Manual checklist

1. Start API/app.
2. Confirm API catalog still loads.
3. Confirm old tracks without license metadata do not crash.
4. Confirm local folder tracks appear as dev-only/license-pending.
5. Confirm Device Music is labeled as user/device music.
6. Open Settings → About → Legal / Licenses.
7. Confirm Credits / Licenses page opens.
8. Confirm license badges appear.
9. Confirm dev-only/local tracks are not shown as production-safe.
10. Confirm attribution text appears when present.
11. Confirm Library rows show lightweight source/license badges without overflow.
12. Cache a track and confirm cached playback still works.
13. Confirm Downloads/Storage Manager still work.
14. Confirm notification/Now/Queue still work.
15. Confirm no copyrighted/commercial track was added.
16. Confirm no raw debug/legal internals appear in consumer mode.

## WaveZero #77 — Playlists / Collections Foundation

WaveZero now includes a local-first Collections v1 foundation so users can organize music without accounts, backend APIs, cloud sync, uploads, payments, DRM, or database complexity.

### Local-first collections

- Collections are stored only on the device with `SharedPreferences` JSON.
- Persistence key: `wavezero.collections.v1`.
- The store persists lightweight collection and track snapshot metadata only.
- It does not store raw debug data, large blobs, or copied audio files.

### Collection model/store behavior

- `WzCollection` stores an id, name, optional description, type, created/updated timestamps, and track snapshots.
- `WzCollectionTrackSnapshot` stores lightweight rendering/playback-resolution metadata: track id, title, subtitle, optional album/artwork, source, optional URL metadata, quality/codec, license metadata, and added time.
- `CollectionsService` restores saved JSON and always normalizes the default liked collection back into the list.
- Duplicate tracks inside one collection are prevented by replacing the existing snapshot for the same track id.

### Liked Tracks behavior

- `Liked Tracks` always exists.
- It cannot be deleted or renamed.
- It can be emptied by removing tracks or unliking them.
- Library rows and Now Playing expose heart actions where the current track can be mapped to a known library item.

### User collections behavior

- Users can create, rename, open, and delete local user collections.
- Deleting a user collection only removes the collection metadata; it does not delete audio files, downloads, or cache entries.
- Empty collection copy guides users to save tracks from Library or Now Playing.

### Source handling

- API catalog tracks save snapshots with source `api` and resolve by track id from the current catalog/library.
- Device Music tracks save snapshots with source `device`, preserve the user-device legal distinction, and resolve against the current MediaStore import list.
- Downloads/Cached tracks save snapshots with source `cached`, preserve original license metadata where available, and resolve against the current cached library or a matching API catalog track if present.
- If a saved snapshot cannot be resolved to a current playable track, the UI shows the friendly unavailable path: `Track is not available right now.`

### Add/remove behavior

- Library rows include like/unlike and add-to-collection actions alongside existing play/cache/queue controls.
- Now Playing includes like/unlike and add-to-collection actions when the current track maps to a known library item.
- The add-to-collection sheet includes Liked Tracks, existing user collections, and a quick `Create New Collection` action.
- Removing a track from a collection does not delete downloaded/cache files or device music.

### Queue integration

- Collection detail can play the first available track, add one resolved track to Queue, or add all resolved tracks to Queue.
- Unavailable tracks are skipped for bulk queue adds and counted in user-facing copy.
- Queue Engine v2 semantics, queue persistence, smart preload, and Smart Downloads behavior are not changed.

### Legal metadata preservation

- Collection snapshots include existing `LicenseMetadata` fields.
- Device Music remains labeled as user device music / your device, and WaveZero does not claim catalog rights for it.
- API and cached tracks preserve license badges such as Dev only, License pending, Verified, Public domain, or Unknown.
- Legal catalog rules and production-rights claims are not changed.

### Storage relationship

- Deleting a collection does not delete downloads/cache.
- Removing a track from a collection does not delete downloads/cache.
- Clearing downloads/cache does not delete collections; cached-only tracks may become unavailable until another playable source is available.

### Intentionally not changed

- No auth, account sync, cloud sync, backend APIs, database, uploads, payments/subscriptions, DRM, or real music files were added.
- Rust API, Android native playback, Android MediaStore behavior, CacheService file format, Queue Engine v2 semantics, Smart Downloads logic, Audio Quality logic, Audio Effects bridge, and legal catalog rules remain unchanged.
- No bottom navigation item was added for Collections; entry points live inside Home, Library, and Now Playing.
- Consumer mode does not expose raw JSON, SharedPreferences keys, stack traces, or Engine/raw metrics.

### Future work

- Cloud sync
- Account sync
- Playlist covers
- Drag/drop ordering
- Playlist downloads
- Collaborative playlists
- Public sharing
- Import/export
- Artist/album collection pages

### Manual checklist

1. Start app.
2. Open Collections from Home/Library.
3. Confirm Liked Tracks exists.
4. Create a collection.
5. Rename a collection.
6. Add API track to Liked Tracks.
7. Add API track to user collection.
8. Import Device Music and add a device track to collection.
9. Download/cache a track and add cached track to collection.
10. Open collection detail.
11. Play a collection track.
12. Add one collection track to Queue.
13. Add all available collection tracks to Queue.
14. Remove a track from collection.
15. Delete user collection.
16. Restart app and confirm collections persist.
17. Clear downloads and confirm collections remain but removed cached-only tracks show unavailable if needed.
18. Confirm no raw debug UI appears in consumer mode.
19. Confirm Library, Queue, Now, Downloads, Storage Manager, Settings, Legal/Licenses, and notifications still work.

## WaveZero #78 — Listening History + Recently Played + Continue Listening

WaveZero now includes a local-first Listening History v1 foundation for Recently Played, Continue Listening, play counts, last played position, and user-facing history controls. The feature is intentionally device-only and does not introduce accounts, cloud sync, backend APIs, analytics SDKs, SQLite, Supabase, uploads, DRM, payments, or any new Rust/native playback surface.

### Local-first history store

- Persistence is a SharedPreferences JSON document at `wavezero.listening_history.v1`.
- The store is managed by `ListeningHistoryService` and uses lightweight `WzListeningHistoryEntry` snapshots.
- Bad or corrupt JSON fails safely to an empty history list.
- Entries are sorted by `lastPlayedAtMs` descending and capped to 200 entries.
- New plays update an existing `trackId` entry instead of duplicating it.

### Stored metadata

History stores only lightweight playback metadata:

- track id, title, subtitle/artist, optional album and artwork URL
- source: API, Device Music, Downloads/Cached, or Unknown
- safely available playback pointer metadata such as manifest/content/local URL references already used by the app
- quality label, codec, duration, play count, first/last played time, last position, and completed count foundation
- existing legal/license metadata snapshot when available

History does not store raw debug data, large blobs, copied audio files, analytics events, private consumer-facing path dumps, accounts, tokens, uploads, or cloud identifiers.

### Recording behavior

- API/catalog playback records history after a manifest resolves and the native bridge successfully loads the playable URL.
- Cached/downloaded playback records the entry as `cached` when the resolved playable URL is local cache backed.
- Device Music playback records after the MediaStore-backed manifest is loaded into native playback.
- `playCount` increments once per meaningful load/play snapshot, not on every progress tick.
- `lastPositionMs` is saved opportunistically on pause, stop, track switch, and user seek rather than every polling tick.

### Source handling

- API tracks resolve back through the current catalog/library track list.
- Device Music tracks resolve through the current imported device music list and keep the “Device music / user device” license label.
- Downloads/Cached tracks resolve through the cached library and keep original license metadata when available.
- If an entry cannot be resolved from the current library/device/cache lists, consumer UI shows: “Track is not available right now.”
- History never invents playback URLs and does not bypass existing `_loadCatalogTrack`, device, cache, or queue flows.

### Home personalization

Home now has local history-powered sections:

- **Continue Listening** shows the most recent entry, source/license/quality badges, saved position copy, and Continue/Play action.
- **Recently Played** shows the latest local entries with source badge, friendly last-played time, play count, Play, Queue, Collection, and Remove controls.
- **Listening Snapshot** metrics summarize history count, most played title, and the local-only privacy note: listening history stays on this device.

### History page and entry points

An internal Listening History page is available without adding a bottom navigation item. Entry points include:

- Home → Recently Played → View all
- Settings → Listening History → View History

The page includes summary cards, a full history list, Play, Add to Queue, Add to Collection, Remove from history, and Clear all history actions.

### Settings integration

Settings includes a Listening History section with:

- recently played count
- most played track
- local-only privacy indicator
- View History
- Clear listening history

The clear-history copy is consumer-friendly: clearing history does not delete downloads, playlists, collections, or device music.

### Collections relationship

Listening History is separate from Collections:

- Clearing history does not delete collections.
- Deleting a collection does not delete history.
- Removing an item from history does not unlike it and does not remove it from playlists/collections.
- Add-to-Collection from history uses the existing collection sheet and collection snapshot flow.

### Storage and downloads relationship

History is metadata-only and is not storage-heavy download data:

- Clearing downloads/cache does not clear history.
- Clearing history does not delete downloads/cache.
- Cached-only history entries can become unavailable if their playable cached source is removed.
- History is not counted as downloaded audio storage.

### Legal metadata preservation

History snapshots preserve existing license metadata where available:

- API/dev catalog tracks keep their current license status such as Dev only, License pending, Verified, or Unknown.
- Device Music entries use Device music / Your device metadata and do not claim catalog rights.
- Cached entries keep the original cached metadata license snapshot when available.
- No production rights claims or legal catalog rules were changed.

### Intentionally not changed

WaveZero #78 does not add auth, cloud sync, cross-device state, backend APIs, analytics SDKs, database complexity, uploads, subscriptions/payments, DRM, real music files, Rust API changes, Android native playback changes, MediaStore behavior changes, CacheService file format changes, Queue Engine v2 semantic changes, Smart Downloads changes, Audio Quality changes, Audio Effects bridge changes, legal catalog rule changes, or consumer-mode raw engine metrics.

### Future work

- cloud sync
- account sync
- cross-device history
- listening analytics dashboard
- recommendations
- skip/complete intelligence
- replay year summary
- private mode
- per-playlist history

### Manual checklist

1. Start app.
2. Play an API track.
3. Confirm it appears in Recently Played.
4. Play a Device Music track.
5. Confirm it appears with Device source/user-device label.
6. Play a cached/downloaded track.
7. Confirm it appears in history.
8. Restart app and confirm history persists.
9. Open Home and confirm Continue Listening shows the latest track.
10. Play from Continue Listening.
11. Open History page.
12. Remove one history item.
13. Clear all history.
14. Confirm clearing history does not delete Collections.
15. Confirm clearing history does not delete Downloads/cache.
16. Confirm unavailable tracks show friendly unavailable copy.
17. Confirm add-to-Queue from history works for available tracks.
18. Confirm add-to-Collection from history works.
19. Confirm no raw debug UI appears in consumer mode.
20. Confirm Library, Collections, Queue, Now, Downloads, Storage Manager, Settings, Legal/Licenses, and notifications still work.

## WaveZero #79 — Search & Discovery v2

WaveZero #79 upgrades search from a Library-only filter into a local-first Search & Discovery surface across existing app state. It adds an internal Search page without adding a bottom-navigation item, backend search, cloud sync, auth, analytics, database storage, or production catalog complexity.

### Internal Search page

- The app shell now has an internal `_AppTab.search` route.
- Search is opened from in-app entry points rather than the bottom nav, so the consumer bottom navigation remains Home, Library, Now, Queue, and Downloads. Developer mode still adds Engine.
- The Search page uses the WaveZero design system and has a header copy of “Find tracks, downloads, collections, and recent plays on this device.”

### Entry points

- Home quick actions include **Search music**.
- Library v2 keeps its existing local source search and adds **Open full search** to jump into unified Search & Discovery.
- Settings includes a small **Search & Discovery** row with **View search** and a recent-search clear action when recent searches exist.

### Searchable sources

Search combines current in-memory UI state only:

- API catalog / Library tracks from the loaded catalog.
- Device Music tracks imported from Android MediaStore summaries.
- Downloads / cached tracks from the existing cache summaries.
- Collections, including Liked Tracks and user-created collections, plus saved collection track snapshots.
- Listening History / Recently Played entries.
- Existing legal/source metadata such as license status, source name, source labels, quality labels, and codec labels.

### Result model and result types

Search results are normalized into a lightweight UI model with id, title, subtitle, type, source, optional artwork URL, track id, collection id, history track id, quality label, codec, license metadata, availability, and a friendly secondary label.

Result types are:

- `track`
- `deviceTrack`
- `downloadedTrack`
- `collection`
- `historyEntry`
- `artistLike` reserved for future artist-like discovery
- `unknown` reserved for fallback UI

### Filters

The Search page exposes source/type filter chips using a mobile-safe `Wrap`:

- All
- Songs
- Device
- Downloads
- Collections
- History
- Legal / Demo

The active query, selected filter, and result count are shown above results. Filters are local UI filters only and do not change Library, Queue, cache, or playback semantics.

### Matching and ranking behavior

Matching is local and deterministic. Search text is normalized by trimming, lowercasing, collapsing repeated spaces, removing simple Arabic diacritics, and normalizing common Arabic alef/ya/ta marbuta forms without adding packages or breaking Arabic titles.

Search matches useful existing metadata where available:

- Track title.
- Artist/subtitle.
- Album name.
- Collection name and collection track snapshots.
- History title/subtitle.
- Source labels.
- License badge/source metadata.
- Quality and codec labels.

Ranking prefers:

1. Exact title match.
2. Title starts with the query.
3. Title contains the query.
4. Artist/subtitle contains the query.
5. Collection-name or collection-snapshot matches.
6. History, downloaded, and device matches.
7. License/source metadata matches.

Ties are sorted deterministically by normalized title and original result order.

### Results, empty states, and discovery

Search result cards show title, subtitle, source/type badges, quality/codec badges when available, license badges when available, availability state, and relevant actions.

When the query is empty, Search shows only real local discovery sections:

- Continue Listening from the latest history entry.
- Recently Played from the top local history entries.
- Downloaded / Offline Ready from cached tracks.
- Collections from Liked Tracks and user collections.
- Legal Demo / API Catalog from loaded catalog tracks.

When a query has no matches, Search shows “No results found on this device.” and suggests importing Device Music or loading the catalog.

### Actions and resolution

Search actions reuse existing app behavior:

- Track-like results play through the existing catalog-track load path.
- Queue actions call the existing add-to-queue behavior.
- Collection actions call the existing add-to-collection sheet.
- Collection results open existing collection detail.
- History results reuse existing history play, queue, and collection helpers.
- Unavailable results show the existing “Track is not available right now.” behavior.

Search does not invent playback URLs and does not bypass device, cache, native playback, queue, or collection resolution.

### Recent searches

Recent searches are persisted locally in SharedPreferences with `wavezero.recent_searches.v1`.

- Last 10 text queries are stored.
- Duplicates are removed using normalized query text.
- Tapping a recent query restores it into the Search input.
- Recent searches can be cleared from Search or Settings.
- Recent search persistence is local-only and is not synced or logged.

### Library relationship

Library v2 keeps its existing source-filtered search behavior. The Library search box still filters the selected Library source, and the new **Open full search** action opens Search & Discovery with the current Library query when present.

### Legal and privacy behavior

Search preserves existing source/legal distinctions:

- Device Music is labeled as user/device music.
- Downloaded tracks preserve their cached license metadata.
- API/dev/demo catalog tracks preserve existing license badges and source labels.
- History and Collections preserve saved license snapshots where available.

Search is local-only:

- No analytics SDK.
- No server query logging.
- No cloud sync.
- No backend search API.
- No database or persistent search index.

### Intentionally not changed

This work does not change:

- Rust API behavior.
- Android native playback.
- Android MediaStore import behavior.
- CacheService file format.
- Queue Engine v2 semantics.
- Smart Downloads logic.
- Audio Quality logic.
- Audio Effects bridge.
- Legal catalog rules.
- Bottom navigation structure.
- Production catalog rights assumptions.

### Future work

- Backend search.
- Indexed search.
- Fuzzy search.
- Typo tolerance.
- Semantic search.
- Recommendations.
- Artist/album pages.
- Genre/mood discovery.
- Online catalog search.
- Voice search.

### Manual checklist

1. Start app.
2. Open Search from Home.
3. Search for an API catalog track.
4. Search for a Device Music track.
5. Search for a downloaded/cached track.
6. Search for a collection name.
7. Search for a recently played track.
8. Switch filters: All, Songs, Device, Downloads, Collections, History.
9. Play a track from Search.
10. Add a track to Queue from Search.
11. Add a track to Collection from Search.
12. Open a collection result.
13. Confirm empty query shows real discovery sections.
14. Confirm no-results state is friendly.
15. Confirm Arabic/long titles do not overflow.
16. Confirm Device Music remains labeled as user/device music.
17. Confirm dev/legal catalog badges remain clear.
18. Confirm no raw debug text appears in consumer mode.
19. Confirm Library search still works and the full-search entry works.
20. Confirm Home, Library, Collections, History, Queue, Now, Downloads, Storage Manager, Settings, Legal/Licenses, and notifications still work.

## WaveZero #80 — Premium Player Surface v2 + Mini Player Sheet

WaveZero #80 upgrades the Flutter playback presentation into a premium music-app surface while keeping the playback engine, queue semantics, cache files, Device Music import, native notification bridge, Rust API, and legal catalog behavior unchanged.

### Mini player behavior

- A persistent premium mini player appears above the bottom navigation whenever a track is currently loaded or selected by live playback state.
- The mini player uses compact artwork or a gradient vinyl/equalizer placeholder, one-line title, one-line subtitle, a tiny progress bar, a source badge such as Cache, Device, or Remote, and an offline-ready indicator when available.
- Tapping the mini player opens the bottom player sheet.
- Tapping the mini player play/pause button only toggles playback through the existing Flutter callback and does not intentionally navigate away from the current tab.
- The mini player is constrained for narrow Android screens and is intended to keep the bottom nav usable without adding a new nav destination.

### Tap-to-open sheet and full player behavior

- The mini player opens a `showModalBottomSheet` with `isScrollControlled: true` and a `DraggableScrollableSheet` player container.
- The sheet starts around a medium-height player, can be dragged toward a near-full-screen player, and can be dragged down or closed with the top handle.
- Opening and closing the sheet does not stop playback and does not create a second playback controller.
- The sheet reuses the same premium player surface as the Now tab, including artwork, status badges, progress, primary controls, actions, and up-next preview.

### Now tab relationship

- The Now tab remains in the existing bottom navigation for navigation stability.
- Now now renders the same premium player surface used by the bottom sheet instead of maintaining a separate older player-card layout.
- A later PR can decide whether Now should stay as a tab or become sheet-only.

### Home cleanup direction

- Home is now discovery- and personalization-oriented instead of repeating a full player surface when a track is active.
- If playback state has a current track, Home shows a compact Continue Listening summary and lets the mini player own live playback controls.
- If no track is active, Home can still show the existing Current Listening starter card.
- History, Continue Listening, Recently Played, smart engine cards, quick actions, Search, Library, Collections, Downloads, Storage, and Settings flows remain intact.

### Controls and actions

- The premium player surface uses existing callbacks only: play/pause, previous, next, stop, retry, seek, like, add to collection, add to queue, and queue navigation.
- The central play/pause control is visually dominant; retry and stop remain secondary actions.
- Like and Add to Collection are enabled only when the current track can be resolved through existing library/manifest/selected-track state.
- Add Up Next uses the existing queue add path and does not alter Queue Engine v2 semantics.

### Up-next preview

- The player surface shows the next queued track when one exists.
- When no next track is available, the friendly copy is: “Add more tracks to Queue”.
- The preview is intentionally compact so the player does not become a diagnostics dashboard.

### Visual direction

- The player UI uses dark glass, gradients, compact badges, controlled spacing, tasteful artwork sizing, and one-line constrained metadata for long or Arabic titles.
- Missing artwork uses a premium gradient/equalizer placeholder instead of relying on a plain giant icon.
- Consumer mode avoids raw metrics, debug IDs, internal URLs, and diagnostics in the player surface.
- Developer mode keeps the existing Engine/raw metrics panels where they already live; #80 does not add new diagnostics.

### Notification and lock-screen boundary

- #80 does not build custom Android notification RemoteViews and does not redesign native notification rendering.
- Notification and lock-screen controls continue to use the existing Android MediaStyle/system-rendered metadata foundation.
- Flutter-side surfaces read the same title, artist/subtitle, artwork, source, cache, and queue state fields that already feed playback metadata.
- Native notification artwork polish and deeper lock-screen metadata are future native-focused work.

### Intentionally unchanged

- Android native playback behavior was not changed.
- Rust API behavior was not changed.
- Device Music MediaStore behavior was not changed.
- CacheService file format was not changed.
- Queue Engine v2 semantics were not changed.
- Smart Downloads logic was not changed.
- Audio Quality selection logic was not changed.
- Audio Effects bridge behavior was not changed.
- Legal Catalog rules were not changed.
- No auth, cloud sync, database, backend API, analytics SDK, uploads, payments, subscriptions, DRM, or real music files were added.
- The Now tab was not removed and no new bottom-nav item was added.

### Future work

- Custom artwork pipeline.
- Animated visualizer.
- Crossfade.
- Sleep timer.
- Shuffle/repeat.
- Native notification artwork polish.
- Lock-screen metadata deepening.
- Sheet-only Now navigation option.

### Manual checklist

1. Start app.
2. Play an API track.
3. Confirm mini player appears above bottom nav.
4. Tap mini player and confirm player sheet opens.
5. Drag sheet up/down.
6. Confirm play/pause works from mini player.
7. Confirm play/pause/next/previous/seek work from sheet/full player.
8. Confirm Now tab shows premium player surface.
9. Confirm Home is less crowded and does not duplicate player heavily.
10. Play Device Music and confirm mini player/sheet show correct title/source.
11. Play cached/downloaded track and confirm cache/offline badges.
12. Confirm Like/Add to Collection works when current track is resolvable.
13. Confirm Up Next preview reflects queue state.
14. Confirm Arabic/long titles do not overflow.
15. Confirm bottom nav remains usable.
16. Confirm notification controls still work.
17. Confirm Search, Library, Collections, History, Queue, Downloads, Storage, Settings still work.
18. Confirm no raw debug UI appears in consumer mode.

## WaveZero #81 — Product Hardening + UX Consolidation

WaveZero #81 consolidates the recent feature wave into a calmer consumer product without adding major systems or changing playback, queue, cache, smart downloads, audio quality, audio effects, device music, Android native playback, Rust APIs, or legal catalog rules.

### Navigation consolidation

- Bottom navigation remains Home, Library, Now, Queue, and Downloads in consumer mode.
- Engine remains developer-only and appears only when Developer Mode is enabled.
- Internal pages such as Search, Collections, Collection Detail, Listening History, Storage Manager, Settings, and Legal / Licenses are treated as intentional product pages with clearer headers and return affordances where safe.
- Internal pages do not add new bottom-navigation items, and the shell avoids making consumer users think debug routes are selected destinations.

### Home consolidation

- Home is the consumer dashboard rather than a developer dashboard.
- The live player is left to the mini player, Now tab, and player sheet, reducing repeated current-playing copy on Home.
- Home keeps useful real-state sections for Search music, Continue Listening / Recently Played, Collections, Downloads / Offline Ready, and smart listening summaries.
- Empty Home sections explain what is missing and how to start without fake data.

### Consumer wording rules

Consumer surfaces prefer product language such as Catalog, Device music, Downloaded, Offline Ready, Smart Downloads, Collection, Listening History, Legal / Licenses, Search on this device, and Track is not available right now.

Harsh or internal wording such as API Base URL, raw manifest, raw metric, internal IDs, SharedPreferences keys, stack traces, and debug/session copy should stay out of consumer mode. Developer-only terms may remain inside Engine diagnostics and Developer Mode surfaces.

### Empty and unavailable states

Empty states across Library, Search, Collections, Collection Detail, Listening History, Downloads, Storage Manager, Legal / Licenses, Queue, Now, and Mini Player should include:

1. What is empty.
2. Why it matters.
3. One useful action when safe.

Unavailable track states use friendly copy such as “Track is not available right now.” and should avoid exposing raw errors in consumer mode.

### Mini player and player sheet polish

- The mini player remains visually separated from bottom navigation.
- Mini player title, subtitle, source badges, and Offline Ready badges are constrained for narrow screens and long or Arabic titles.
- Play/pause remains a direct control and should not be treated as a sheet-open affordance.
- The player sheet keeps a clear drag handle and close affordance.
- Now and the sheet continue to use the same premium player surface.
- Sheet state remains intentionally stable; this PR does not introduce a risky new controller just to live-update an already-open sheet.

### Search, Library, Collections, and History relationship

- Search is the global local finder across current in-memory app state.
- Library keeps source filters and handoff to full Search.
- Collections remain local metadata for Liked Tracks and user collections; deleting a collection does not delete audio files, downloads, cache files, or device music.
- Listening History remains local and can be cleared without deleting downloads, collections, or device music.
- Search discovery avoids duplicating Home too heavily and keeps recent searches clearable.

### Settings consolidation

Settings remains a calm control center for Search & Discovery, Appearance, Playback, Downloads & Storage, Listening History, Device music, Notifications / Lock Screen, Developer, and About / Legal.

Developer Mode is explicit, Engine access remains developer-only, and Legal / Licenses, Manage Storage, View History, Clear History, View Search, and Clear Recent Searches remain accessible.

### Stale UI cleanup

Obvious stale UI should be removed only when no longer referenced. The legacy mini player widget was removed after the premium mini player became the active shell surface. Engine and Developer Mode diagnostics are intentionally preserved.

### Mobile safety

Changed surfaces should use flexible layout primitives such as Expanded, Flexible, Wrap, maxLines, and ellipsis to avoid narrow Android overflows. Source, legal, quality, and offline badges must not stretch screens, and modal sheets should remain SafeArea-aware.

### What intentionally did not change

This work intentionally does not change Android native playback, Rust APIs, Device Music MediaStore behavior, CacheService file format, Queue Engine v2 semantics, Smart Downloads logic, Audio Quality selection logic, Audio Effects bridge behavior, or Legal Catalog rules.

This work also intentionally does not add auth, cloud sync, a database, backend APIs, analytics SDKs, uploads, payments, subscriptions, DRM, real music files, shuffle, repeat, sleep timer, or a new bottom-navigation item. The Now tab remains.

### Future work

- Player Experience v2: shuffle, repeat, and sleep timer.
- Production Content Server.
- Account/Auth.
- Cloud Sync.
- Artist Upload Pipeline.
- Artist Dashboard.
- Subscriptions/plans.
- Recommendations.

### Manual checklist

1. Start app in consumer mode.
2. Confirm bottom nav remains Home / Library / Now / Queue / Downloads.
3. Confirm Engine appears only in developer mode.
4. Open Home and confirm it feels less crowded.
5. Play a track and confirm mini player remains usable.
6. Open player sheet and confirm controls still work.
7. Open Now and confirm it matches the premium player surface.
8. Open Search and confirm no debug wording.
9. Open Library and confirm search/full-search/filters still work.
10. Open Collections and Collection Detail.
11. Open Listening History.
12. Open Downloads and Storage Manager.
13. Open Settings and confirm sections are readable.
14. Open Legal / Licenses.
15. Confirm empty states are friendly.
16. Confirm unavailable track states are friendly.
17. Confirm Arabic/long titles do not overflow.
18. Confirm no raw metrics/debug IDs/internal URLs in consumer mode.
19. Confirm playback, queue, downloads, smart downloads, audio quality/effects, device music, notification controls still work.
20. Confirm no major feature behavior changed.

## WaveZero #82 — Player Experience v2: Shuffle / Repeat / Sleep Timer

WaveZero #82 adds app-level playback mode controls for the Flutter player surface without changing Android native playback internals, the Rust API, cache file formats, Smart Downloads candidate logic, Device Music MediaStore behavior, audio quality selection, audio effects, backend services, auth, cloud sync, or legal catalog rules.

### Shuffle behavior

- Shuffle is stored as a lightweight Flutter app preference and affects Next behavior only.
- The visible Queue Engine v2 order is not reshuffled, reordered, duplicated, or permanently mutated by shuffle.
- When shuffle is on and the queue has more than one playable item, manual Next chooses a random queued track that is not the current track when possible.
- When shuffle is off, manual Next keeps the existing sequential queue behavior.
- Auto-advance can also use shuffle before falling back to normal sequential advance.
- Smart Downloads and smart preload continue to use the existing current/up-next signals and are not rewritten for shuffle memory in this PR.

### Repeat modes

- Repeat off preserves the existing end-of-track and auto-advance behavior.
- Repeat one replays the current track on the auto-advance/end path by seeking to the beginning and playing again through the existing playback bridge. Manual Next still respects user intent and advances away from the current track.
- Repeat all loops to the first queued track when the queue reaches the end and no normal next track remains.
- Repeat modes do not duplicate queue entries and do not create a second queue engine.

### Sleep timer behavior

- Sleep Timer v1 is memory-only while the app is running.
- Options are Off, 15 minutes, 30 minutes, 45 minutes, and 60 minutes.
- The active countdown deadline is not restored after app restart; the app starts with the sleep timer off.
- When the timer ends, WaveZero pauses playback safely through the existing playback bridge and keeps the queue/session context intact.
- Sleep timer status is computed from the in-memory deadline and is not written to preferences every second.

### Persistence keys

- `wavezero.shuffle_enabled` persists shuffle on/off.
- `wavezero.repeat_mode` persists repeat off/one/all.
- `wavezero.sleep_timer_preset` persists the selected sleep timer preset only; active countdown deadlines are intentionally not persisted.

### Player surface controls

- Premium Player Surface v2 now includes a compact Playback modes card with Shuffle, Repeat, and Sleep timer controls.
- The Now tab and the mini player sheet share the same premium controls because they both render the same player surface.
- Consumer labels use music-app wording such as “Shuffle on”, “Shuffle off”, “Repeat off”, “Repeat one”, “Repeat all”, “Sleep timer”, and “Sleep in 15m”. Raw enum names are not shown.
- Controls use wrapping layouts so long localized titles and compact screens do not overflow the player surface.

### Settings integration

- Settings → Playback mirrors the basic playback mode controls without duplicating the full player.
- Settings includes a Shuffle switch, Repeat mode chips, and a Sleep timer status/shortcut.
- The section remains focused on calm playback preferences alongside audio quality and audio effects.

### Mini player boundary

- The mini player remains compact.
- It may show small badges for active Shuffle, Repeat, and Sleep timer state when they fit.
- Primary playback mode controls remain in the Now tab and player sheet.

### Notification/native boundary

- Native Android notification controls remain system-rendered and unchanged in this PR.
- No custom Android RemoteViews, MediaSession redesign, or native notification shuffle/repeat buttons were added.
- Existing notification Next/Previous behavior is only affected where it already routes through Flutter app-level queue actions.
- Repeat and shuffle controls in notification UI are future native work if needed.

### Auto-advance decision order

The Flutter auto-advance path now evaluates playback modes in this order:

1. Repeat one replays the current track.
2. Shuffle chooses another queued track when possible.
3. Normal sequential next uses the existing queue advance path.
4. Repeat all loops to the first queued track when the end is reached.
5. Existing end behavior remains when none of the above applies.

### Queue relationship

- Shuffle v1 does not permanently reorder the queue.
- Repeat all loops queue playback without adding duplicate entries.
- Repeat one does not duplicate the current track.
- Sleep timer pauses playback and does not clear the queue.
- Queue Engine v2 remains the source of current/up-next context.

### What intentionally did not change

- Android native playback internals.
- Rust API and Rust queue/core crates.
- Device Music MediaStore import behavior.
- CacheService file format and offline cache semantics.
- Smart Downloads candidate selection beyond preserving existing current/up-next update calls.
- Audio Quality selection logic.
- Audio Effects bridge behavior.
- Legal Catalog rules.
- Backend, auth, cloud sync, database, uploads, payments, DRM, analytics SDKs, or real music files.
- Bottom navigation structure and the Now tab.
- Native notification design.

### Future work

- Collection playback sessions.
- Shuffle history memory to reduce repeats across longer sessions.
- Shuffle/repeat controls in native notification and lock-screen surfaces.
- Sleep timer fade-out.
- Crossfade.
- Gapless playback.
- Visualizer.
- Advanced playback preferences.

### Manual checklist

1. Start app.
2. Play a track.
3. Open player sheet.
4. Toggle Shuffle on/off.
5. Confirm Next with shuffle on chooses another queued track when possible.
6. Cycle Repeat off / one / all.
7. Confirm Repeat one replays current track on end if possible.
8. Confirm Repeat all loops queue when end is reached.
9. Set Sleep Timer 15 min.
10. Confirm timer status appears in player surface.
11. Cancel Sleep Timer.
12. Confirm sleep timer off state.
13. Confirm mini player remains compact.
14. Confirm Now tab shows same controls.
15. Confirm Settings Playback section reflects shuffle/repeat/sleep status if implemented.
16. Confirm queue order is not destroyed by shuffle.
17. Confirm downloads/cache/device music playback still works.
18. Confirm notification controls still work as before.
19. Confirm no raw debug UI appears in consumer mode.
20. Confirm Search, Library, Collections, History, Downloads, Storage, Settings still work.

## WaveZero #84 — Release Config + Beta Hardening

WaveZero #84 adds a lightweight app environment model and beta hardening guidance so the app can be built and reviewed with clearer release expectations while preserving the current dev workflow.

### App environments

Flutter reads the app environment from:

```text
--dart-define=WAVEZERO_APP_ENV=dev|beta|production
```

The default is `dev`.

Environment behavior:

- `dev`: keeps local API workflows available, defaults the API base URL to the Android emulator development server, and keeps Developer Mode entry visible.
- `beta`: expects an explicit API base URL from dart-define, hides manual API setup from consumer mode, and keeps Developer Mode available for API/content inspection.
- `production`: expects explicit release configuration, avoids local laptop defaults in consumer-facing copy, and hides developer entry points from normal Settings unless the existing internal logo gesture is used.

### API/content dart-defines

Use explicit API and content labels for beta or production-style builds:

```text
--dart-define=WAVEZERO_API_BASE_URL=<api-base-url>
--dart-define=WAVEZERO_CONTENT_MODE_LABEL=<Demo catalog|Catalog ready|Catalog configured by build>
```

The API base URL should be the API root. Do not use endpoint paths, manifest URLs, stream URLs, or local laptop URLs for beta/production consumer builds.

### Consumer/developer boundary

Consumer mode should not prominently expose API base URLs, raw content config, raw JSON/status payloads, manifest URLs, stream URLs, stack traces, file paths, internal IDs, SharedPreferences keys, or Rust/service implementation details. Developer Mode keeps Engine diagnostics and manual API setup separated from consumer navigation.

### Startup/catalog failure behavior

The app should not block launch on server availability. If the catalog is unavailable, consumer copy should say the catalog is unavailable, suggest checking the connection or trying later, and remind testers that Device Music and Downloads may still work. Home, Settings, Device Music, Downloads, Search, Queue, Now Playing, and Storage surfaces should continue to render where local state is available.

### Build metadata/About behavior

Settings → About shows the WaveZero name, build placeholder, app environment, content mode label, friendly catalog status, local-only privacy note, and Legal / Licenses entry. This intentionally avoids adding a package/version plugin for #84.

### Android build notes

Android build command examples for dev and beta debug/profile/release-style builds live in [`docs/beta-release-checklist.md`](beta-release-checklist.md). The examples are documentation-only placeholders; do not commit signing secrets, keystores, Play Store metadata, or production credentials.

### Legal/release-safe messaging

WaveZero legal messaging remains metadata-based. Device Music belongs to the user/device context and is not uploaded by WaveZero. Catalog tracks require explicit rights metadata. Dev-only tracks are not production-safe, and beta builds do not claim licensed commercial catalog rights.

### What intentionally did not change

WaveZero #84 does not add auth, login, cloud sync, Supabase, a database, hosted deployment scripts, CI/CD, Play Store signing, keystores, crash reporting, analytics, payments, artist uploads, an admin dashboard, DRM, real music files, or copyrighted/commercial songs. It also does not change Android native playback, Rust API behavior, Device Music MediaStore behavior, CacheService file format, Queue Engine v2, Smart Downloads logic, Audio Quality selection, Audio Effects bridge, Legal Catalog rules, or bottom navigation structure.

### Future work

- CI build pipeline.
- Signing/release keystore setup.
- Play Store/internal testing track.
- Hosted production API deployment.
- Crash reporting.
- Analytics with privacy controls.
- Auth.
- Cloud sync.
- Content moderation.
- Artist upload beta.

## WaveZero #83 — Production Content Server Foundation

WaveZero now has explicit Rust API content modes so the local dev catalog can remain useful without being confused with a production catalog.

### Content modes

- `dev` is the default and preserves the bundled dev fixture catalog plus dev-only local folder discovery.
- `demo` expects `WAVEZERO_CATALOG_PATH` and does not auto-scan local audio folders.
- `production` expects `WAVEZERO_CATALOG_PATH`, filters unsafe tracks, and never silently exposes local dev files.

### API/content environment variables

- `WAVEZERO_CONTENT_MODE=dev|demo|production`
- `WAVEZERO_CATALOG_PATH=`
- `WAVEZERO_CONTENT_BASE_URL=`
- `WAVEZERO_AUDIO_BASE_URL=`
- `WAVEZERO_ARTWORK_BASE_URL=`
- `WAVEZERO_LOCAL_AUDIO_DIR=`
- `WAVEZERO_CATALOG_PATH=<catalog.json>`
- `WAVEZERO_CONTENT_BASE_URL=<base-url-for-relative-content>`
- `WAVEZERO_AUDIO_BASE_URL=<base-url-for-relative-audio>`
- `WAVEZERO_ARTWORK_BASE_URL=<base-url-for-relative-artwork>`
- `WAVEZERO_LOCAL_AUDIO_DIR=<dev-only-local-audio-dir>`
- `WAVEZERO_ENABLE_LOCAL_FOLDER_CATALOG=true|false`

Local dev does not require every variable. Demo and production should use an explicit catalog file and production-appropriate base URLs.

### Catalog format and URL behavior

The catalog remains compatible with `services/api/fixtures/dev_catalog.json` and now supports production-oriented fields such as `artist_name`, `album_name`, `artwork_path`, `sourceType`, `productionSafe`, and asset URL/path fields including `manifest_url`, `stream_url`, `asset_url`, and `asset_path`. Relative audio paths resolve through `WAVEZERO_AUDIO_BASE_URL` or `WAVEZERO_CONTENT_BASE_URL`; relative artwork paths resolve through `WAVEZERO_ARTWORK_BASE_URL` or `WAVEZERO_CONTENT_BASE_URL`.

### Manifest behavior

`GET /tracks/:id/manifest` still returns `track`, `asset`, and `stream_url` for existing Flutter compatibility. Missing tracks return a JSON `track_not_found` response. Missing assets or assets without a URL return `asset_not_available`.

### Health/status endpoints

- `GET /health`
- `GET /api/content/status`

The status response reports content mode, catalog load state, track count, asset count, local folder catalog enablement, production-safe count, server version, and safe config-presence booleans. Production mode does not expose raw local filesystem paths.

### Dev local folder behavior

Local folder auto catalog is dev-only and only includes `.mp3`, `.m4a`, `.aac`, `.wav`, and `.flac`. Generated tracks are marked `dev_only`, `Local Folder / Local Dev Audio`, `commercialUseAllowed: false`, `redistributionAllowed: false`, and `productionSafe: false`.

### Legal safety

No real copyrighted/commercial music is added. Nothing is treated as verified unless metadata explicitly says so. `dev_only`, `license_pending`, `unknown`, and `user_device` server catalog tracks are not production-safe. Device Music remains user-owned/user-device context and is separate from the server catalog.

### Flutter integration

The Flutter catalog client can read content status. Consumer library/search surfaces keep friendly statuses such as Catalog ready, Catalog unavailable, Demo catalog, Device music, and Downloaded. API base URL and content mode details stay in developer/Engine diagnostics.

See [`docs/production-content-server.md`](production-content-server.md) for the longer content-server checklist.

### Intentionally not changed

WaveZero #83 does not add auth, cloud sync, database storage, backend uploads, payments, DRM, CDN/object storage, signed URLs, real music files, Android native playback changes, Device Music MediaStore changes, CacheService file format changes, Queue Engine v2 rewrites, Smart Downloads logic changes, Audio Quality selection changes, Audio Effects bridge changes, or a new bottom-nav item.

### Future work

- Hosted production API deployment
- CDN/object storage
- Signed URLs
- Artist uploads
- Auth
- Moderation/review workflow
- Database-backed catalog
- Admin catalog dashboard
- Payments/subscriptions
- Analytics
- DRM/licensing integrations

### Manual checklist

1. Start API in default dev mode.
2. Confirm current dev catalog still loads.
3. Confirm local folder auto catalog still works in dev if enabled.
4. Confirm local folder tracks are `dev_only`/license pending-safe and never production-safe.
5. Start API with `WAVEZERO_CONTENT_MODE=demo`.
6. Confirm demo mode does not auto-expose local folder tracks.
7. Start API with `WAVEZERO_CONTENT_MODE=production` and no catalog path.
8. Confirm it returns a safe empty/status response.
9. Configure `WAVEZERO_CATALOG_PATH` and confirm catalog loads.
10. Confirm `/health` works.
11. Confirm `/api/content/status` works.
12. Confirm manifest endpoint still returns `track`/`asset`/`stream_url`.
13. Confirm Flutter Library still loads catalog in dev.
14. Confirm Search/Now/Queue/Downloads still work with catalog tracks.
15. Confirm consumer mode does not show raw server config.
16. Confirm developer mode can inspect content status.
17. Confirm no real copyrighted/commercial music was added.
18. Confirm dev-only tracks are not treated as production-safe.

## WaveZero #85 — Personal Cloud Music Vault Foundation

WaveZero #85 adds the first safe Flutter-side foundation for Cloud Vault, a private personal cloud music source concept for music the user owns. The goal is product/data-model/UX readiness for future Google Drive, Dropbox, OneDrive, Nextcloud, and manual private URL work without adding risky provider authentication or backend music storage.

### Cloud Vault safety model

- User cloud files belong to the user.
- WaveZero does not upload cloud files to WaveZero servers.
- Only files the user chooses should appear in Cloud Vault.
- Sharing copyrighted files with others is not supported.
- Cloud Vault is a private playback/source organization feature, not a piracy, public redistribution, or friend-to-friend transfer feature.
- The foundation does not scan an entire cloud drive and does not ingest YouTube, SoundCloud, Spotify, Anghami, or commercial catalog tracks.

### Provider roadmap

Provider cards are intentionally placeholders:

- Google Drive — Coming soon
- Dropbox — Later
- OneDrive — Later
- Nextcloud / self-hosted — Later
- Manual private URL — Developer preview only when Developer Mode is enabled

Future provider work must be reviewed separately before adding OAuth, token refresh, provider SDKs, signed URL resolution, or cloud account sync.

### What is stored locally

Cloud Vault stores a SharedPreferences JSON list containing lightweight metadata such as `cloudTrackId`, title, artist/album names, duration, artwork URL, provider enum, provider file placeholder, source/playable URI placeholders, MIME type, size, import/play timestamps, availability, and privacy/local-only flags.

Corrupt Cloud Vault JSON fails safe: the raw payload is moved to a corruption backup preference key and the active Cloud Vault list returns empty.

### What is not stored

WaveZero #85 does not store OAuth tokens, refresh tokens, provider credentials, Google API credentials, backend database rows, uploaded user music, public sharing links, provider sync account state, DRM state, or payment/subscription state.

### Privacy/legal boundaries

Cloud Vault is private source organization for music the user owns. WaveZero does not claim rights to user cloud files, does not upload those files to WaveZero servers, and does not support redistribution of copyrighted files. Future provider integrations must preserve the consumer-safe copy and keep developer-only controls separated from consumer mode.

### Manual checklist

1. Start app.
2. Open Settings.
3. Open Cloud Vault.
4. Confirm consumer copy is privacy-safe.
5. Confirm provider cards show coming-soon states.
6. Confirm no OAuth/token/API credential UI appears in consumer mode.
7. Enable Developer Mode.
8. Confirm developer preview/manual seed controls appear only in Developer Mode.
9. Add a manual test cloud track if supported.
10. Confirm it appears in Cloud Vault list.
11. Confirm unavailable cloud tracks show friendly unavailable copy.
12. Confirm playable developer-preview track uses existing playback path.
13. Confirm Add to Queue works only when track is resolvable.
14. Confirm remove-one and clear-all work.
15. Restart app and confirm Cloud Vault entries persist.
16. Corrupt/clear storage behavior should fail safe.
17. Confirm Library/Search integration does not clutter consumer UI.
18. Confirm no raw provider IDs/tokens/URLs appear in consumer surfaces unless Developer Mode is active.
19. Confirm Device Music, Downloads, Library, Search, Queue, Now, Settings still work.
20. Confirm no bottom-nav item was added.

See [Cloud Vault](cloud-vault.md) for the detailed safety model and roadmap.

## WaveZero #87: FMA Green Small Local Demo Library

WaveZero #87 adds local tooling and documentation for a large FMA Green Small Demo Library without committing audio or generated machine-specific catalog files to the repository. The workflow is intended for local development and demo stress testing only.

Use `tools/fma/build_fma_green_small_local_library.py` when you have these external files outside Git:

- `fma_small.zip`
- FMA metadata CSVs in a local `fma_metadata` directory
- `wavezero_fma_green_candidates_all_v2.csv` or an equivalent strict Green candidates CSV

Example PowerShell command from the repository root:

```powershell
$WorkRoot = "C:\Users\dell\Desktop\wavezero-fma-work\fma\data"
$MetadataDir = "$WorkRoot\fma_metadata"
$AudioDir = "$WorkRoot\wavezero_fma_green_small_audio"
$CatalogJson = "$MetadataDir\wavezero_fma_green_small_catalog.json"
$ReportCsv = "$MetadataDir\wavezero_fma_green_small_import_report.csv"
$AudioBaseUrl = "http://<LAN-IP>:8091"

python tools\fma\build_fma_green_small_local_library.py `
  --metadata-dir $MetadataDir `
  --fma-small-zip "$WorkRoot\fma_small.zip" `
  --input-csv "$MetadataDir\wavezero_fma_green_candidates_all_v2.csv" `
  --output-audio-dir $AudioDir `
  --output-catalog-json $CatalogJson `
  --output-report-csv $ReportCsv `
  --audio-base-url $AudioBaseUrl
```

Serve the extracted audio from a dedicated terminal:

```powershell
cd <output-audio-dir>
python -m http.server 8091 --bind 0.0.0.0
```

Start the Rust API in demo content mode with the generated local catalog:

```powershell
$env:WAVEZERO_CONTENT_MODE = "demo"
$env:WAVEZERO_CATALOG_PATH = "<generated catalog json>"
$env:WAVEZERO_AUDIO_BASE_URL = "http://<LAN-IP>:8091"
$env:WAVEZERO_CONTENT_MODE_LABEL = "FMA Green Demo Library"
```

Then run the Flutter app against the Rust API base URL:

```powershell
cd apps\flutter\wavezero_app
flutter run --dart-define=WAVEZERO_API_BASE_URL=http://<API-IP>:<API-PORT>
```

Manual checklist:

1. Confirm `fma_small.zip` exists outside the repo.
2. Confirm the metadata CSV exists outside the repo.
3. Run the importer with `--audio-base-url http://<LAN-IP>:8091`.
4. Confirm `Imported audio` equals the expected Green small input.
5. Confirm `Missing` is `0` or document missing rows from the report.
6. Start the local audio server on `8091`.
7. Start the Rust API with the generated catalog path.
8. Open `/api/content/status`.
9. Open `/catalog` and confirm more than 1000 tracks.
10. Launch the Flutter app with the API base URL.
11. Confirm Library/Search show the large demo catalog.
12. Play multiple tracks from different genres.
13. Queue multiple FMA tracks.
14. Confirm no MP3/ZIP/generated local catalog files are staged for Git.
15. Confirm docs explain attribution and production verification boundaries.

Safety and legal boundaries:

- `productionSafe` in this generated catalog means local demo candidate, not final legal approval.
- Original FMA track pages, license URLs, attribution requirements, and production rights must be verified before production release.
- Do not commit MP3s, `fma_small.zip`, generated local catalogs, generated import reports, or machine-specific LAN URLs.
- Do not add ripping/downloading from YouTube, SoundCloud, Spotify, Anghami, or other commercial streaming services.

See `docs/fma-local-demo-library.md` for the complete local workflow and the distinction between the small Curated Featured Demo and the Big Local Demo Library.

## Large local demo catalog performance boundary

The Flutter host is hardened for large local demo catalogs such as the FMA Green Small library with **1,374 tracks**. The app keeps the full catalog count available for status and diagnostics, but it does not eagerly render every row or seed the queue with every catalog entry on startup.

Large catalog behavior:

- Catalog loading keeps the mini player and playback controls responsive by loading the selected/startup track first and avoiding a full-catalog startup queue.
- Library defaults to a safe visible window of **200 tracks** and uses a **Load more** button in **100-track** increments.
- Large catalog mode is enabled once the combined library is larger than the safe catalog limit of **300 tracks**.
- Consumer copy says **“Large demo library loaded”** and **“Showing first X tracks”** rather than exposing raw debug state.
- Search input is debounced and search results are capped; the no-query discovery view only samples a few catalog entries.
- Smart Downloads only follows the current/up-next playback context and does not scan or cache the full catalog at startup.

Developer diagnostics in the Engine tab include:

- `catalogTrackCount`
- `visibleTrackCount`
- `filteredTrackCount`
- `catalogLimit`
- `largeCatalogMode` enabled/disabled

Manual large-catalog checklist:

1. Run with 200-track catalog.
2. Run with full 1374-track catalog.
3. Confirm app does not freeze on startup.
4. Confirm Library opens smoothly.
5. Confirm Search does not freeze while typing.
6. Confirm Queue works.
7. Confirm Play works.
8. Confirm Smart Downloads does not mass-cache.
9. Confirm mini player remains responsive.
10. Confirm Device Music / Downloads / Cloud Vault still work.
