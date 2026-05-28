use std::collections::{HashMap, HashSet};

/// Cache metadata for a track asset. Segment indexes are zero-based.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CachedTrackAsset {
    pub manifest_cached: bool,
    cached_segments: HashSet<u32>,
}

impl CachedTrackAsset {
    pub fn new(manifest_cached: bool, cached_segments: impl IntoIterator<Item = u32>) -> Self {
        Self {
            manifest_cached,
            cached_segments: cached_segments.into_iter().collect(),
        }
    }

    pub fn has_segment(&self, segment_index: u32) -> bool {
        self.cached_segments.contains(&segment_index)
    }

    pub fn cached_segments(&self) -> &HashSet<u32> {
        &self.cached_segments
    }
}

/// Platform-provided snapshot of cache state used by deterministic decisions.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct CacheState {
    assets: HashMap<String, CachedTrackAsset>,
}

impl CacheState {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_asset(mut self, asset_id: impl Into<String>, asset: CachedTrackAsset) -> Self {
        self.assets.insert(asset_id.into(), asset);
        self
    }

    pub fn asset(&self, asset_id: &str) -> Option<&CachedTrackAsset> {
        self.assets.get(asset_id)
    }

    pub fn is_manifest_cached(&self, asset_id: &str) -> bool {
        self.asset(asset_id)
            .map(|asset| asset.manifest_cached)
            .unwrap_or(false)
    }

    pub fn is_segment_cached(&self, asset_id: &str, segment_index: u32) -> bool {
        self.asset(asset_id)
            .map(|asset| asset.has_segment(segment_index))
            .unwrap_or(false)
    }
}
