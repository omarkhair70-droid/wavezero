# WaveZero Architecture

WaveZero is an Android-first independent music streaming platform with a small,
strongly typed foundation for playback decisions.

## Phase 0 Components

- `apps/android/` — Android client placeholder for Kotlin, Jetpack Compose, and
  AndroidX Media3 ExoPlayer integration.
- `crates/wavezero-core/` — Rust shared playback brain. It owns queue movement,
  prefetch decisions, cache metadata shapes, manifest asset types, network
  scoring, and playback metrics.
- `services/api/` — Rust Axum service exposing health checks, track reads, and
  playback event ingestion.
- `services/edge-worker/` — Cloudflare Worker placeholder for signed manifest
  access in front of R2.
- `infra/database/schema.sql` — PostgreSQL schema for artists, tracks,
  streamable track assets, and playback events.
- `infra/encoding/` — HLS/CMAF encoding pipeline placeholder.

## Non-Goals

Phase 0 intentionally excludes authentication, subscriptions, social features,
comments, likes, AI recommendations, and artist dashboards.

## TODOs

- TODO: Android Media3 integration.
- TODO: iOS AVFoundation integration.
- TODO: Cloudflare R2 signed manifests.
- TODO: HLS/CMAF encoding pipeline.
- TODO: Offline cache policy.
