//! Shared playback brain for WaveZero clients and services.
//!
//! The core crate deliberately keeps playback decisions deterministic and free
//! of platform IO. Android Media3, future iOS AVFoundation, and backend systems
//! can provide observed state, then consume strongly typed decisions from here.

pub mod cache;
pub mod manifest;
pub mod metrics;
pub mod network;
pub mod prefetch;
pub mod queue;

pub use cache::{CacheState, CachedTrackAsset};
pub use manifest::{AudioCodec, Track, TrackAsset};
pub use metrics::PlaybackMetric;
pub use network::{NetworkScore, NetworkType};
pub use prefetch::{PrefetchDecision, PrefetchReason};
pub use queue::PlaybackQueue;
