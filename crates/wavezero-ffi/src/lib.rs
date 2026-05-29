//! FFI boundary scaffold for WaveZero's shared Rust engine.
//!
//! This crate intentionally does not implement generated FFI yet. It defines
//! DTOs that can be made UniFFI-friendly in a follow-up bridge PR while keeping
//! all deterministic playback logic in `wavezero-core`.

use wavezero_core::{
    AudioCodec, CacheState, NetworkScore, NetworkType, PrefetchDecision, Track, TrackAsset,
};

/// Boundary representation of a playable asset.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrackAssetDto {
    pub id: String,
    pub track_id: String,
    pub manifest_url: String,
    pub codec: AudioCodecDto,
    pub bitrate_kbps: u32,
    pub segment_count: u32,
    pub is_primary: bool,
}

impl From<TrackAssetDto> for TrackAsset {
    fn from(value: TrackAssetDto) -> Self {
        Self::new(
            value.id,
            value.track_id,
            value.manifest_url,
            value.codec.into(),
            value.bitrate_kbps,
            value.segment_count,
            value.is_primary,
        )
    }
}

/// Boundary representation of a track that can be converted into core state.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrackDto {
    pub id: String,
    pub artist_id: String,
    pub title: String,
    pub duration_ms: u32,
    pub assets: Vec<TrackAssetDto>,
}

impl From<TrackDto> for Track {
    fn from(value: TrackDto) -> Self {
        Self::new(
            value.id,
            value.artist_id,
            value.title,
            value.duration_ms,
            value.assets.into_iter().map(TrackAsset::from).collect(),
        )
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AudioCodecDto {
    AacLc,
    Opus,
    Flac,
}

impl From<AudioCodecDto> for AudioCodec {
    fn from(value: AudioCodecDto) -> Self {
        match value {
            AudioCodecDto::AacLc => Self::AacLc,
            AudioCodecDto::Opus => Self::Opus,
            AudioCodecDto::Flac => Self::Flac,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NetworkTypeDto {
    Offline,
    Unknown,
    Wifi,
    Ethernet,
    Cellular4g,
    Cellular5g,
}

impl From<NetworkTypeDto> for NetworkType {
    fn from(value: NetworkTypeDto) -> Self {
        match value {
            NetworkTypeDto::Offline => Self::Offline,
            NetworkTypeDto::Unknown => Self::Unknown,
            NetworkTypeDto::Wifi => Self::Wifi,
            NetworkTypeDto::Ethernet => Self::Ethernet,
            NetworkTypeDto::Cellular4g => Self::Cellular4g,
            NetworkTypeDto::Cellular5g => Self::Cellular5g,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetworkScoreDto {
    pub network_type: NetworkTypeDto,
    pub bandwidth_kbps: u32,
    pub latency_ms: u32,
    pub metered: bool,
}

impl From<NetworkScoreDto> for NetworkScore {
    fn from(value: NetworkScoreDto) -> Self {
        Self::new(
            value.network_type.into(),
            value.bandwidth_kbps,
            value.latency_ms,
            value.metered,
        )
    }
}

/// DTO returned to app bridge layers after core makes a prefetch decision.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PrefetchDecisionDto {
    pub should_prefetch_manifest: bool,
    pub should_prefetch_first_segments: bool,
    pub first_segment_count: u32,
    pub asset_id: Option<String>,
    pub reason: String,
}

impl From<PrefetchDecision> for PrefetchDecisionDto {
    fn from(value: PrefetchDecision) -> Self {
        Self {
            should_prefetch_manifest: value.should_prefetch_manifest,
            should_prefetch_first_segments: value.should_prefetch_first_segments,
            first_segment_count: value.first_segment_count,
            asset_id: value.asset_id,
            reason: format!("{:?}", value.reason),
        }
    }
}

/// Example boundary function for future UniFFI export.
///
/// TODO: expose through UniFFI once the Flutter/native bridge chooses its
/// generated binding strategy.
pub fn decide_prefetch_for_bridge(
    current_track: Option<TrackDto>,
    next_track: Option<TrackDto>,
    network: NetworkScoreDto,
) -> PrefetchDecisionDto {
    let current_track = current_track.map(Track::from);
    let next_track = next_track.map(Track::from);
    let network = NetworkScore::from(network);
    let cache = CacheState::new();

    wavezero_core::prefetch::decide_prefetch(
        current_track.as_ref(),
        next_track.as_ref(),
        &network,
        &cache,
    )
    .into()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn track(id: &str) -> TrackDto {
        TrackDto {
            id: id.to_owned(),
            artist_id: "artist-1".to_owned(),
            title: format!("Track {id}"),
            duration_ms: 180_000,
            assets: vec![TrackAssetDto {
                id: format!("asset-{id}"),
                track_id: id.to_owned(),
                manifest_url: format!("https://cdn.wavezero.test/{id}/master.m3u8"),
                codec: AudioCodecDto::AacLc,
                bitrate_kbps: 256,
                segment_count: 8,
                is_primary: true,
            }],
        }
    }

    #[test]
    fn bridge_prefetch_decision_delegates_to_core() {
        let decision = decide_prefetch_for_bridge(
            Some(track("current")),
            Some(track("next")),
            NetworkScoreDto {
                network_type: NetworkTypeDto::Wifi,
                bandwidth_kbps: 10_000,
                latency_ms: 40,
                metered: false,
            },
        );

        assert!(decision.should_prefetch_manifest);
        assert!(decision.should_prefetch_first_segments);
        assert_eq!(decision.asset_id.as_deref(), Some("asset-next"));
    }
}
