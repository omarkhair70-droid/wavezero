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

### Phase 1G — Player State Machine and UX Cleanup

Status: Completed

Outcome:

- A Flutter operation-state model separates player, catalog, queue, seek, manual-track, and metrics operations.
- The player shows clearer state/status copy.
- Catalog search stays usable while audio is playing.
- Metrics refresh no longer blocks normal controls.
- Native playback bridge ownership remains unchanged.

## Next Phases

### Phase 1I — Persistent Queue and Session Recovery

Status: In progress

Goal:

Make the queue and selected/current track survive app restarts on-device.

Scope:

- Add local queue/session storage through SharedPreferences.
- Persist queued track IDs, selected track ID, current track ID, and auto-advance preference.
- Restore the queue after catalog load by matching stored track IDs against the current catalog.
- Show lightweight session recovery status in the player UI.
- Keep persistence client-side until production accounts/backend storage exist.

Non-goals:

- No auth.
- No cloud sync.
- No database.
- No upload UI.

### Phase 1H — Local Library and Add Track UX

Goal:

Replace manual URL editing with a cleaner local-library workflow.

Scope:

- Add a clearer local-track entry workflow.
- Reduce manual setup visibility for normal use.
- Keep production storage and upload outside this phase.
