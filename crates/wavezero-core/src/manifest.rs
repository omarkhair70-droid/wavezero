/// A playable music track.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Track {
    pub id: String,
    pub artist_id: String,
    pub title: String,
    pub duration_ms: u32,
    pub assets: Vec<TrackAsset>,
}

impl Track {
    pub fn new(
        id: impl Into<String>,
        artist_id: impl Into<String>,
        title: impl Into<String>,
        duration_ms: u32,
        assets: Vec<TrackAsset>,
    ) -> Self {
        Self {
            id: id.into(),
            artist_id: artist_id.into(),
            title: title.into(),
            duration_ms,
            assets,
        }
    }

    pub fn primary_asset(&self) -> Option<&TrackAsset> {
        self.assets
            .iter()
            .find(|asset| asset.is_primary)
            .or_else(|| self.assets.first())
    }
}

/// A concrete streamable asset for a track, such as an HLS/CMAF variant or direct audio file.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrackAsset {
    pub id: String,
    pub track_id: String,
    pub manifest_url: String,
    pub codec: AudioCodec,
    pub bitrate_kbps: u32,
    pub segment_count: u32,
    pub is_primary: bool,
}

impl TrackAsset {
    pub fn new(
        id: impl Into<String>,
        track_id: impl Into<String>,
        manifest_url: impl Into<String>,
        codec: AudioCodec,
        bitrate_kbps: u32,
        segment_count: u32,
        is_primary: bool,
    ) -> Self {
        Self {
            id: id.into(),
            track_id: track_id.into(),
            manifest_url: manifest_url.into(),
            codec,
            bitrate_kbps,
            segment_count,
            is_primary,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AudioCodec {
    AacLc,
    Opus,
    Flac,
    Mp3,
}
