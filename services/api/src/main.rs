use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::{net::SocketAddr, sync::Arc};
use tokio::net::TcpListener;
use wavezero_core::{AudioCodec, NetworkType, PlaybackMetric, Track, TrackAsset};

#[derive(Clone)]
struct AppState {
    tracks: Arc<Vec<Track>>,
}

#[derive(Debug, Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
}

#[derive(Debug, Clone, Serialize)]
struct TrackResponse {
    id: String,
    artist_id: String,
    title: String,
    duration_ms: u32,
    assets: Vec<TrackAssetResponse>,
}

#[derive(Debug, Clone, Serialize)]
struct TrackAssetResponse {
    id: String,
    track_id: String,
    manifest_url: String,
    codec: String,
    bitrate_kbps: u32,
    segment_count: u32,
    is_primary: bool,
}

#[derive(Debug, Deserialize)]
struct PlaybackEventRequest {
    user_id: Option<String>,
    session_id: String,
    metric: PlaybackMetricRequest,
}

#[derive(Debug, Deserialize)]
struct PlaybackMetricRequest {
    track_id: String,
    time_to_first_audio_ms: u32,
    buffer_count: u32,
    network_type: NetworkTypeRequest,
    cache_hit: bool,
    manifest_fetch_ms: u32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
enum NetworkTypeRequest {
    Offline,
    Unknown,
    Wifi,
    Ethernet,
    Cellular4g,
    Cellular5g,
}

#[derive(Debug, Serialize)]
struct PlaybackEventResponse {
    accepted: bool,
}

#[tokio::main]
async fn main() {
    let state = AppState {
        tracks: Arc::new(seed_tracks()),
    };

    let app = app(state);
    let addr = SocketAddr::from(([0, 0, 0, 0], 8080));
    let listener = TcpListener::bind(addr)
        .await
        .expect("bind WaveZero API listener");

    axum::serve(listener, app)
        .await
        .expect("run WaveZero API server");
}

fn app(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/tracks", get(list_tracks))
        .route("/tracks/:id", get(get_track))
        .route("/playback-events", post(record_playback_event))
        .with_state(state)
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok",
        service: "wavezero-api",
    })
}

async fn list_tracks(State(state): State<AppState>) -> Json<Vec<TrackResponse>> {
    Json(state.tracks.iter().map(TrackResponse::from).collect())
}

async fn get_track(Path(id): Path<String>, State(state): State<AppState>) -> impl IntoResponse {
    match state.tracks.iter().find(|track| track.id == id) {
        Some(track) => (StatusCode::OK, Json(TrackResponse::from(track))).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

async fn record_playback_event(Json(event): Json<PlaybackEventRequest>) -> impl IntoResponse {
    let _metric = PlaybackMetric::new(
        event.metric.track_id,
        event.metric.time_to_first_audio_ms,
        event.metric.buffer_count,
        event.metric.network_type.into(),
        event.metric.cache_hit,
        event.metric.manifest_fetch_ms,
    );
    let _ = (event.user_id, event.session_id);

    (
        StatusCode::ACCEPTED,
        Json(PlaybackEventResponse { accepted: true }),
    )
}

impl From<&Track> for TrackResponse {
    fn from(track: &Track) -> Self {
        Self {
            id: track.id.clone(),
            artist_id: track.artist_id.clone(),
            title: track.title.clone(),
            duration_ms: track.duration_ms,
            assets: track.assets.iter().map(TrackAssetResponse::from).collect(),
        }
    }
}

impl From<&TrackAsset> for TrackAssetResponse {
    fn from(asset: &TrackAsset) -> Self {
        Self {
            id: asset.id.clone(),
            track_id: asset.track_id.clone(),
            manifest_url: asset.manifest_url.clone(),
            codec: match asset.codec {
                AudioCodec::AacLc => "aac_lc",
                AudioCodec::Opus => "opus",
                AudioCodec::Flac => "flac",
            }
            .to_string(),
            bitrate_kbps: asset.bitrate_kbps,
            segment_count: asset.segment_count,
            is_primary: asset.is_primary,
        }
    }
}

impl From<NetworkTypeRequest> for NetworkType {
    fn from(network_type: NetworkTypeRequest) -> Self {
        match network_type {
            NetworkTypeRequest::Offline => NetworkType::Offline,
            NetworkTypeRequest::Unknown => NetworkType::Unknown,
            NetworkTypeRequest::Wifi => NetworkType::Wifi,
            NetworkTypeRequest::Ethernet => NetworkType::Ethernet,
            NetworkTypeRequest::Cellular4g => NetworkType::Cellular4g,
            NetworkTypeRequest::Cellular5g => NetworkType::Cellular5g,
        }
    }
}

fn seed_tracks() -> Vec<Track> {
    vec![
        Track::new(
            "track-001",
            "artist-001",
            "Phase Zero Signal",
            184_000,
            vec![TrackAsset::new(
                "asset-001-aac",
                "track-001",
                "https://r2.wavezero.example/manifests/track-001/master.m3u8",
                AudioCodec::AacLc,
                256,
                46,
                true,
            )],
        ),
        Track::new(
            "track-002",
            "artist-002",
            "Independent Frequency",
            212_000,
            vec![TrackAsset::new(
                "asset-002-aac",
                "track-002",
                "https://r2.wavezero.example/manifests/track-002/master.m3u8",
                AudioCodec::AacLc,
                256,
                53,
                true,
            )],
        ),
    ]
}

#[allow(dead_code)]
fn example_metric() -> PlaybackMetric {
    PlaybackMetric::new("track-001", 420, 0, NetworkType::Wifi, false, 95)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn routes_are_registered() {
        let router = app(AppState {
            tracks: Arc::new(seed_tracks()),
        });

        let _ = router;
    }
}
