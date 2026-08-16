# WaveZero Product Cleanup Plan

## Goal

Turn the current development-oriented surface into a focused consumer music product before the next visual-design pass.

This phase changes product hierarchy and visibility, not playback behavior.

## Primary navigation

Target consumer shell:

1. Home
2. Search
3. Library

Now Playing opens from the mini player / current track surface.
Queue belongs to Now Playing.
Downloads and Storage belong to Library.

Developer Engine is never part of the normal consumer shell.

## KEEP

- Home
- Search
- Library
- Now Playing
- Mini player
- Device Music capability
- Queue capability
- Downloads/offline capability
- Collections
- Listening History
- Sleep timer
- Audio quality preference
- Legal / licenses / privacy information

## MERGE / RELOCATE

- Queue -> Now Playing
- Downloads -> Library
- Storage Manager -> Library > Downloads / Storage
- Collections -> Library
- Listening History -> Library or a secondary activity surface
- Device Music import / permission -> Library onboarding and source management
- Sleep timer / shuffle / repeat -> Now Playing controls, not Settings
- Search history clearing -> Search context or Privacy, not a top-level Settings section

## HIDE FROM CONSUMER PRODUCT

Hide behind debug/developer builds or an internal developer entry:

- Engine diagnostics
- App mode controls
- Catalog/content mode diagnostics
- Runtime notification status
- Native playback bridge diagnostics
- Device scan status details
- Cache/manual/smart diagnostic metrics
- Source implementation labels that are useful only to development

Hide until the feature is genuinely product-ready:

- Cloud Vault provider UI / provider promises
- Audio-effect profiles while native DSP is foundation-level
- Demo-catalog-specific controls and messaging

## DELETE FROM CONSUMER COPY

Remove prototype / implementation language such as:

- "Queue Engine v2"
- "Library ready"
- "Catalog unavailable" as a permanent product-facing state
- "demo catalog" implementation copy
- "foundation-level" feature copy
- status badges whose only purpose is proving internal subsystems are alive

Replace these only where the user genuinely needs an actionable state.

## SETTINGS TARGET

Settings should become small and consumer-facing.

Likely groups:

- Audio
  - Preferred quality
- Downloads & storage
  - Storage usage / clear downloads where useful
- Privacy
  - Clear listening history
- About
  - Version
  - Legal / licenses

Remove from normal Settings:

- Theme presets
- Accent presets
- Shuffle / repeat
- Sleep timer
- Search launcher
- Device scan diagnostics
- Cloud Vault placeholders
- Developer / Engine controls
- App/content/catalog diagnostics
- Native DSP status text

## Visual redesign workflow

Do not redesign the entire app through global style changes.

For each surface:

1. Design one static reference image first.
2. Review and approve the reference.
3. Implement only that surface.
4. Run it on the physical Samsung device.
5. Compare a real screenshot against the reference.
6. Tune until the implementation matches.
7. Move to the next surface.

First surface: Now Playing.

Recommended order after Now Playing:

1. Mini player
2. Home
3. Library
4. Search
5. Collections / History secondary surfaces
6. Lean Settings

## Performance track

Product cleanup and performance are separate workstreams.

The current physical-device logs show large skipped-frame bursts during startup / re-entry. Do not assume visual cleanup fixes them.

Performance work should separately profile:

- startup before first frame
- app resume / activity recreation
- catalog and library initialization
- queue/history/session restore
- device-music work
- cache/download initialization
- playback codec churn only where traces show user-visible stalls

Do not accept a redesign as finished while startup / resume remains visibly janky.
