# WaveZero V2 — Daily Driver Quality Pass

Date: 2026-09-15
Branch: `feat/v2-daily-driver-quality-20260915`

## Goal

Make WaveZero comfortable enough for real daily use before adding more product surface area. The pass is driven by actual device use: long Device Music libraries, repeated home content, large decorative surfaces, nested scroll traps, and slow/manual library refresh habits.

## Acceptance criteria

- Library and Search use one vertical scroll surface; long lists do not trap upward gestures.
- Entering Device Music can refresh the device library without a separate manual rescan ritual once permission is already granted.
- The Device Music surface clearly communicates that it refreshes on entry and keeps a manual scan action as fallback.
- Home does not repeat the Continue Listening track again at the top of Recently Played.
- Recently Played is deduplicated by track id.
- The decorative Home hero is materially smaller so music appears above the fold sooner.
- Bottom navigation is less vertically heavy while retaining the existing Porcelain identity and touch targets.
- Existing offline/local-first behavior, queue, playback, collections, cache/downloads, and Android MediaStore contracts stay intact.
- No new runtime dependency is introduced in this pass.

## Follow-up lane

A native in-app Web/Downloads surface is intentionally a separate lane because it changes Android browser/download handling and should ship with focused device QA rather than be mixed into the interaction cleanup.
