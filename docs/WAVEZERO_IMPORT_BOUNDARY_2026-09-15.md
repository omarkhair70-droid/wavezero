# WaveZero Import Boundary — 2026-09-15

This note records the current Google Play product boundary for imports and downloads.

## Supported direction

- Receive user-shared local audio files through Android sharing.
- Import user-selected audio into Device Music.
- Accept ordinary direct HTTP/HTTPS audio URLs and download them through Android DownloadManager.
- Provide an in-app browser and save standard downloadable media exposed by a website when the user initiates the action.
- Save webpage/social links into a WaveZero Inbox and reopen them later.
- Respect platform-provided download controls when a creator or service allows download.

## Play-build exclusions

- No YouTube-to-MP3 or YouTube media extraction.
- No offline copies of YouTube content outside YouTube's permitted experience.
- No platform-specific private-endpoint scraping.
- No product copy that encourages unauthorized copyrighted downloads.

## Platform notes

- YouTube: link/web playback only unless YouTube itself exposes a permitted download path.
- TikTok: prefer creator-enabled download availability and ordinary user flows; do not automate extraction from non-downloadable content.
- Facebook/Instagram: keep to user-directed browsing, sharing and standard downloadable media rather than automated private-endpoint collection.

## Google Play pattern

The Play Store currently contains generic media downloader apps with built-in browsers and direct-link downloads. Their listings commonly support services such as Facebook, Instagram, TikTok, X and other websites while explicitly excluding YouTube and warning users to download only content they have the right to save. WaveZero follows this same high-level boundary while staying focused on audio/import.
