use crate::{CacheState, NetworkScore, Track};

const FIRST_AUDIO_SEGMENTS_TO_PREFETCH: u32 = 2;

/// Deterministic output that clients can translate into Media3 cache/download work.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PrefetchDecision {
    pub should_prefetch_manifest: bool,
    pub should_prefetch_first_segments: bool,
    pub first_segment_count: u32,
    pub asset_id: Option<String>,
    pub reason: PrefetchReason,
}

impl PrefetchDecision {
    pub fn skip(reason: PrefetchReason) -> Self {
        Self {
            should_prefetch_manifest: false,
            should_prefetch_first_segments: false,
            first_segment_count: 0,
            asset_id: None,
            reason,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrefetchReason {
    Ready,
    NoCurrentTrack,
    NoNextTrack,
    MissingNextAsset,
    NetworkUnavailable,
    NetworkTooConstrainedForAudio,
    AlreadyCached,
}

/// Decide whether to prefetch the next track's manifest and first audio segments.
pub fn decide_prefetch(
    current_track: Option<&Track>,
    next_track: Option<&Track>,
    network: &NetworkScore,
    cache: &CacheState,
) -> PrefetchDecision {
    if current_track.is_none() {
        return PrefetchDecision::skip(PrefetchReason::NoCurrentTrack);
    }

    let Some(next_track) = next_track else {
        return PrefetchDecision::skip(PrefetchReason::NoNextTrack);
    };

    if !network.supports_manifest_prefetch() {
        return PrefetchDecision::skip(PrefetchReason::NetworkUnavailable);
    }

    let Some(asset) = next_track.primary_asset() else {
        return PrefetchDecision::skip(PrefetchReason::MissingNextAsset);
    };

    let wanted_segments = asset.segment_count.min(FIRST_AUDIO_SEGMENTS_TO_PREFETCH);
    let manifest_cached = cache.is_manifest_cached(&asset.id);
    let first_segments_cached =
        (0..wanted_segments).all(|segment_index| cache.is_segment_cached(&asset.id, segment_index));

    if manifest_cached && first_segments_cached {
        return PrefetchDecision {
            should_prefetch_manifest: false,
            should_prefetch_first_segments: false,
            first_segment_count: 0,
            asset_id: Some(asset.id.clone()),
            reason: PrefetchReason::AlreadyCached,
        };
    }

    let should_prefetch_first_segments = !first_segments_cached
        && wanted_segments > 0
        && network.supports_audio_prefetch(asset.bitrate_kbps);

    let reason = if should_prefetch_first_segments || !manifest_cached {
        PrefetchReason::Ready
    } else {
        PrefetchReason::NetworkTooConstrainedForAudio
    };

    PrefetchDecision {
        should_prefetch_manifest: !manifest_cached,
        should_prefetch_first_segments,
        first_segment_count: if should_prefetch_first_segments {
            wanted_segments
        } else {
            0
        },
        asset_id: Some(asset.id.clone()),
        reason,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{AudioCodec, CachedTrackAsset, NetworkType, TrackAsset};

    fn track(id: &str, bitrate_kbps: u32) -> Track {
        Track::new(
            id,
            "artist-1",
            format!("Track {id}"),
            180_000,
            vec![TrackAsset::new(
                format!("asset-{id}"),
                id,
                format!("https://cdn.wavezero.test/{id}/master.m3u8"),
                AudioCodec::AacLc,
                bitrate_kbps,
                10,
                true,
            )],
        )
    }

    #[test]
    fn prefetches_manifest_and_first_segments_on_strong_unmetered_network() {
        let current = track("current", 256);
        let next = track("next", 256);
        let network = NetworkScore::new(NetworkType::Wifi, 10_000, 40, false);
        let decision = decide_prefetch(Some(&current), Some(&next), &network, &CacheState::new());

        assert!(decision.should_prefetch_manifest);
        assert!(decision.should_prefetch_first_segments);
        assert_eq!(decision.first_segment_count, 2);
        assert_eq!(decision.asset_id.as_deref(), Some("asset-next"));
        assert_eq!(decision.reason, PrefetchReason::Ready);
    }

    #[test]
    fn skips_audio_segments_on_metered_network_but_allows_manifest() {
        let current = track("current", 256);
        let next = track("next", 256);
        let network = NetworkScore::new(NetworkType::Cellular5g, 10_000, 40, true);
        let decision = decide_prefetch(Some(&current), Some(&next), &network, &CacheState::new());

        assert!(decision.should_prefetch_manifest);
        assert!(!decision.should_prefetch_first_segments);
        assert_eq!(decision.reason, PrefetchReason::Ready);
    }

    #[test]
    fn does_not_prefetch_when_next_asset_is_already_cached() {
        let current = track("current", 256);
        let next = track("next", 256);
        let network = NetworkScore::new(NetworkType::Wifi, 10_000, 40, false);
        let cache = CacheState::new().with_asset("asset-next", CachedTrackAsset::new(true, [0, 1]));

        let decision = decide_prefetch(Some(&current), Some(&next), &network, &cache);

        assert!(!decision.should_prefetch_manifest);
        assert!(!decision.should_prefetch_first_segments);
        assert_eq!(decision.reason, PrefetchReason::AlreadyCached);
    }

    #[test]
    fn skips_when_there_is_no_next_track() {
        let current = track("current", 256);
        let network = NetworkScore::new(NetworkType::Wifi, 10_000, 40, false);
        let decision = decide_prefetch(Some(&current), None, &network, &CacheState::new());

        assert_eq!(decision.reason, PrefetchReason::NoNextTrack);
        assert!(!decision.should_prefetch_manifest);
    }
}
