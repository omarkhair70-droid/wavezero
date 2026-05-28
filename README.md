# WaveZero

WaveZero is an Android-first independent music streaming platform foundation.

Phase 0 is a playback engine proof focused on:

- Rust shared playback core in `crates/wavezero-core`.
- Rust Axum API service in `services/api`.
- Cloudflare Worker placeholder in `services/edge-worker`.
- PostgreSQL schema in `infra/database/schema.sql`.
- Documentation for architecture, playback, and streaming pipeline.

The project intentionally does not include auth, subscriptions, comments, likes,
social features, AI recommendations, or artist dashboards in Phase 0.
