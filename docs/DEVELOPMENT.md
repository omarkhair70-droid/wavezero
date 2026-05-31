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
