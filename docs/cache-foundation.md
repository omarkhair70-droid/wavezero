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

Queue Engine v2 + Downloads Manager Foundation (WaveZero #64)

Queue Engine v2 behavior
- Queue rows now expose per-track controls for play/select, move up, move down, remove, and Play Next while keeping the existing add-to-queue behavior.
- The current track and up-next track are called out directly in the Queue card summary and row labels.
- Reorders, Play Next, removals, and additions save the existing queue session snapshot so the persisted queue order can survive app restart using the current session store.
- Queue order changes also refresh the existing Smart Preload candidate and schedule Smart Downloads for the new up-next track. Smart Queue Policy internals and native prebuffer behavior are unchanged.

Downloads Manager foundation
- `CacheService` now supports per-track delete, cached count, cache bytes, cached library, and cached-track lookup actions while preserving clear-all cache behavior.
- Cached metadata includes a lightweight `downloadSource` value: `manual`, `smart_current`, `smart_up_next`, or `unknown` for older records.
- Manual downloads are tagged `manual`; Smart Downloads for the current track are tagged `smart_current`; Smart Downloads for the up-next track are tagged `smart_up_next`.
- The product shell includes a Downloads section showing cached track title, artist/subtitle, source, play, delete, and clear-all cache actions.
- Engine diagnostics include downloaded track count, total cache bytes, manual download count, smart download count, and the last cache delete result.

WaveZero #64 manual checklist
1. Start audio/API/app.
2. Clear cache.
3. Play track and confirm Smart Downloads caches it.
4. Add multiple tracks to queue.
5. Reorder queue.
6. Use Play Next.
7. Confirm up-next smart download follows new queue order.
8. Open Downloads section.
9. Confirm cached tracks appear.
10. Delete one cached track.
11. Confirm it is removed from Downloads and Library cached badge updates.
12. Stop audio/API and confirm remaining cached tracks still play.
13. Clear all cache and confirm Downloads becomes empty.

## Audio Quality Pipeline Foundation

WaveZero now treats a playable track as a set of quality-aware audio assets instead of a single opaque URL. The local development catalog and Flutter catalog models carry asset diagnostics including:

- `quality_label`: `standard`, `high`, or `original`
- `codec`
- `bitrate_kbps`
- optional `sample_rate_hz`, `bit_depth`, and `file_size_bytes`

Existing `dev_catalog.json` entries remain compatible. When explicit quality metadata is missing, the API infers a safe quality label from codec, bitrate, filename, and extension:

- MP3 assets at or below 192 kbps fall back to `standard`.
- MP3/AAC/M4A assets at or above 256 kbps are treated as `high`.
- WAV/FLAC or lossless/original-looking filenames are treated as `original`.

The local folder auto catalog supports direct development audio files with these extensions: `.mp3`, `.m4a`, `.aac`, `.wav`, and `.flac`. It intentionally avoids heavy audio probing dependencies; bitrate and quality are inferred from filename hints where possible, otherwise extension-based fallbacks are used.

### Preferred quality and fallback

The Flutter engine has an internal preferred audio quality control under the Engine tab. The default preference is `high`, with available values `standard`, `high`, and `original`.

Playback, manual caching, Smart Downloads for the current track, Smart Downloads for the up-next track, and download metadata now use the same asset selection helper. Selection never blocks playback just because a preferred tier is unavailable:

- `original` preference tries `original`, then `high`, then `standard`, then the primary/first playable asset.
- `high` preference tries `high`, then `standard`, then `original`, then the primary/first playable asset.
- `standard` preference tries `standard`, then `high`, then `original`, then the primary/first playable asset.

The Engine diagnostics panel shows the preferred quality, current selected quality, codec, bitrate, asset URL, fallback reason, and cached quality when playback resolves to an offline file. Cached metadata also remembers the selected quality, codec, bitrate, and original remote URL; older cached metadata loads as `unknown` quality.

### Manual checklist

1. Add MP3/M4A/WAV/FLAC files to the local audio folder.
2. Start the audio server, API server, and Flutter app.
3. Confirm the catalog exposes quality and codec info.
4. Set preferred quality to `high` in the Engine tab.
5. Play a track and confirm the selected asset quality in Audio Quality diagnostics.
6. Set preferred quality to `original`.
7. Confirm an original/lossless-like asset is preferred when available.
8. Confirm fallback works when the preferred quality is unavailable.
9. Cache a track and confirm Downloads shows the remembered quality.
10. Stop the audio/API servers and confirm a cached high/original track still plays offline.
