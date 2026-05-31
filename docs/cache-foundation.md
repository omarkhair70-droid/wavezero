Cache Foundation (WaveZero #59)

Overview
- Adds a simple Flutter-side cache foundation for offline listening.
- Does not modify native playback internals, prepared handoff, Rust APIs, or Smart Queue.

Behavior
- A `CacheService` downloads a track's audio URL and stores the file in app-local storage.
- Cache status is tracked per catalog track: `notCached`, `caching`, `cached`, `failed`.
- Cached tracks now persist metadata locally so the app can show and select cached tracks even when the catalog API is unavailable.
- Persisted cache metadata includes: `trackId`, `title`, `artistName`, `durationMs`, `artworkUrl`, `localFilePath`, `originalRemoteUrl`, and `cachedAt`.
- When loading/selecting a track, the app prefers a local `file://` URL for playback if a cached file exists.
- The Flutter playback bridge API usage is unchanged: callers still pass a URL to the native player.

UI
- Library catalog rows include a download/cache button and a cached indicator.
- Engine page shows cache diagnostics: `cachedTrackCount`, `cacheBytes`, `lastCacheResult`, and a "Clear cache" button.

Limitations / Scope
- No native (Android/iOS) player code changes were made.
- No DRM, encryption, cloud sync, or auth was added.
- This is a foundation only — behavior is intentionally minimal and synchronous UI updates are simple.

Developer Manual Checklist
1. Verify the Flutter app builds locally (ensure dependencies are fetched):

   flutter pub get

2. Run the app on Android device/emulator and navigate to Library.
3. In the Library catalog, tap the download icon for a track that has a primary asset URL.
4. Observe a snackbar confirming cache status (cached / failed).
5. Load the same track — the app should pass a `file://` URL to the playback bridge and native player will play the local file.
6. Open the Engine tab: verify `Cached tracks`, `Cache bytes`, and `Last` values update.
7. Click `Clear cache` and verify the cached files are removed and diagnostics reset.

Offline library manual checklist
- Start the audio server, API server, and app.
- Cache one or more tracks from the Library.
- Stop the audio server and confirm cached audio still plays from local storage.
- Stop the Rust API server.
- Refresh the app or reload the Library.
- Confirm cached tracks still appear in Library and are marked as cached.
- Select a cached track and confirm it plays from the local file URL.
- Confirm normal cached playback does not emit a playback error.
- Clear the cache and confirm the offline library becomes empty.

Notes for reviewers
- The cache index is stored in `SharedPreferences` under key `wz_cache_index`.
- Cached files are stored in the app documents directory with the prefix `wz_cache_<trackId>`.

Predictive Smart Downloads (WaveZero #63)

- Overview: Predictive Smart Downloads automatically caches the currently playing track and the up-next queued track in the background so users can play them offline without manually tapping download.

- Behavior:
   - When a track is loaded/played from the catalog or offline metadata, the app will attempt to auto-cache the current track if it is not already cached.
   - After the current track is ready, the app checks the queue and will attempt to auto-cache the up-next track (if available and not already cached/caching).
   - Auto-cache operations run in the background and do not block playback.
   - A simple internal limit prevents auto-caching more than 10 cached tracks: if the offline cached library already has >= 10 tracks, auto-cache is skipped.
   - Auto-cache will skip tracks that are already cached, currently caching, or already in-flight via the auto-cache engine.

- Engine UI:
   - The Engine tab contains a new "Smart Downloads" diagnostics card showing on/off, last smart download, counters (started/completed/failed/skipped), in-flight count, and last reason/result.
   - A toggle allows enabling/disabling Smart Downloads during runtime.

Manual test checklist
1. Clear cache.
2. Start audio/API/app.
3. Play a track without pressing manual download.
4. Confirm Engine shows smart download started/completed.
5. Confirm cache count increases.
6. Add multiple tracks to queue.
7. Play first track.
8. Confirm up-next track gets cached automatically.
9. Stop audio server.
10. Confirm auto-cached current/next tracks can still play from cache.
11. Toggle Smart Downloads off and confirm no new auto-cache starts.
