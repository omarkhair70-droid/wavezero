# WaveZero Product Evolution — 2026-09-15

This document records the next product lanes after the daily-driver quality pass and in-app Web/download work. The goal is not to add random features. Each lane should ship as a coherent daily-use improvement, reach Alpha, be used on a real device, and be hardened before the next lane.

## Product thesis

WaveZero should become the place where music on the phone naturally ends up: Device Music, files shared from other apps, direct downloadable audio links, user-approved web downloads, collections, queue/history and offline playback — all without forcing the user through a file manager.

## Lane 1 — Universal Import + Music Inbox

Priority: NOW.

- Android Share target: `Share -> WaveZero` for audio files and text/URLs.
- Copy/import shared audio into a WaveZero-owned public media location using Android MediaStore rather than holding temporary content URIs.
- Direct audio URLs can reuse the existing DownloadManager pipeline.
- Generic webpage links are saved as link inbox items and can open in WaveZero Web.
- Music Inbox shows new imports with Play, Play next, Queue, Like, Add to collection, Rename/Fix info and Delete actions.
- Fresh on your device shelf is driven from real import/MediaStore timestamps.
- Avoid automatic destructive duplicate removal.

### Lane 1.5 — Local media to audio

After the Inbox flow is stable, allow the user to share/select a local video file and extract its audio on-device into WaveZero. This is a local file utility, not a website ripper.

- `Share local video -> WaveZero -> Extract audio`.
- MP4/MOV/MKV/WebM and other practical input formats where the Android/native conversion stack supports them.
- Save the result as M4A/MP3 or another explicit user-selected audio format.
- No upload to a WaveZero server is required.
- Keep this path separate from social-site URL handling: a local file supplied by the user can be converted; a restricted third-party streaming URL is not silently ripped.

## Lane 2 — Library Intelligence

- Folder browsing.
- Possible duplicate detection with explicit keep/remove choice.
- Local metadata overrides for ugly/missing title/artist/artwork.
- Recently Added / Fresh on device.
- Smart shelves from local history: On Repeat, Back to This, Still Unfinished, time-of-day candidates.
- Optional Smart Playlist rules later, after automatic shelves prove useful.

## Lane 3 — Lyrics

- Embedded lyrics.
- Sidecar `.lrc` files.
- Synced scrolling when timestamps exist.
- Online lookup only as a later, separately reviewed provider integration.

## Lane 4 — Real Sound Engine

The current effect presets are product/state foundations and must not be presented as real DSP until native playback actually applies them.

- Native EQ / effect chain.
- ReplayGain or loudness normalization.
- Gapless playback hardening.
- Crossfade / smart fade.
- Preserve Off / Original as a true no-effect path.

## Later lanes

- Android home-screen widget.
- Android Auto / automotive browsing and playback.
- User-authored smart playlist editor.
- Cloud provider sources.
- Better library metadata tooling and full tag editing.

## Distribution / policy boundary

Google Play currently allows many generic browser/media downloader and local media-converter apps. The product boundary is therefore not “no downloading” or “no audio extraction”. WaveZero may support ordinary user-directed downloads, imports and local file conversion where the content is downloadable and the user has the right to save or transform it.

Do not ship platform-specific circumvention or extraction whose purpose is to defeat a service's restrictions. In particular, the Play build must not present or implement YouTube-to-MP3 / YouTube offline extraction. YouTube's current terms and developer policies prohibit downloading content except when the service expressly permits it, and explicitly prohibit separating audio/video components in API clients.

For other sites, prefer standards-based direct media downloads or creator/platform-provided download affordances over scraping private endpoints or bypassing restrictions. Keep the user-facing copy neutral: WaveZero imports files/links the user chooses; it does not claim rights to third-party media.

## Release discipline

For every lane:

1. Build on a dedicated branch.
2. Add focused tests for the new contract.
3. Run Flutter analyze/tests and release AAB CI.
4. Publish to Alpha only after CI is green.
5. Use on a physical device and collect real friction.
6. Fix the friction before beginning the next large lane.
7. Production promotion stays a separate explicit action.
