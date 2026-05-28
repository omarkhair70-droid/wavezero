use crate::NetworkType;
/// Playback startup and buffering metric emitted by clients.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlaybackMetric {
    pub track_id: String,
    pub time_to_first_audio_ms: u32,
    pub buffer_count: u32,
    pub network_type: NetworkType,
    pub cache_hit: bool,
    pub manifest_fetch_ms: u32,
}

impl PlaybackMetric {
    pub fn new(
        track_id: impl Into<String>,
        time_to_first_audio_ms: u32,
        buffer_count: u32,
        network_type: NetworkType,
        cache_hit: bool,
        manifest_fetch_ms: u32,
    ) -> Self {
        Self {
            track_id: track_id.into(),
            time_to_first_audio_ms,
            buffer_count,
            network_type,
            cache_hit,
            manifest_fetch_ms,
        }
    }
}
