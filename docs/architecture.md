# WaveZero Architecture

WaveZero is an Android-first independent music streaming platform with a small,
strongly typed foundation for playback decisions.

## Phase 0 Components

- `apps/android/` — Android client proof using Kotlin, Jetpack Compose, and
  AndroidX Media3 ExoPlayer to play a real HLS stream and display playback
  metrics.
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

## Phase 0B Android Playback Proof

The Android app now contains a minimal dark playback UI backed by a clean Media3
player layer. The proof plays one isolated HLS test stream, displays current
state, and records startup, first-audio, manifest-load, buffering, position, and
error metrics. This validates real Android audio output before expanding the API,
auth, subscription, social, or artist workflows.

Rust integration remains intentionally decision-oriented: Android will call the
Rust core for queue and prefetch decisions in the next step, while Media3 remains
responsible for platform playback and lifecycle.

## TODOs

- TODO: Connect Android to `wavezero-core` through a thin UniFFI/JNI decision boundary.
- TODO: iOS AVFoundation integration.
- TODO: Cloudflare R2 signed manifests.
- TODO: HLS/CMAF encoding pipeline.
- TODO: Offline cache policy.
