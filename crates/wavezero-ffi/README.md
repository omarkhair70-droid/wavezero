# wavezero-ffi

`wavezero-ffi` is the Phase 0C scaffold for exposing `wavezero-core` across app boundaries.

This crate does **not** replace `wavezero-core`. It wraps selected core concepts in DTOs that are easier to expose through future UniFFI-generated bindings for Flutter/native bridge work.

## Current scope

- Keep DTOs lightweight and dependency-free.
- Convert boundary DTOs into `wavezero-core` types before making decisions.
- Preserve deterministic playback decisions in `wavezero-core`.
- Avoid generating bindings until the bridge implementation PR chooses the final UniFFI layout.

## TODO

- Add UniFFI scaffolding and binding generation.
- Decide whether Flutter talks directly to generated Rust bindings, native platform code, or both for each command.
- Add Android/iOS packaging scripts once native bridge code is ready.
- Extend DTO coverage for cache snapshots, queue operations, and metrics ingestion as those APIs stabilize.
