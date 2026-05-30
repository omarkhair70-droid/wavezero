use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, net::SocketAddr, sync::Arc};
use tokio::net::TcpListener;
use wavezero_core::{AudioCodec, NetworkType, PlaybackMetric, Track, TrackAsset};

const DEV_CATALOG_JSON: &str = include_str!("../fixtures/dev_catalog.json");

#[derive(Clone)]
struct AppState {
    catalog: Arc<CatalogStore>,
}

#[derive(Debug, Clone)]
struct CatalogStore {
    artists: Vec<Artist>,
    tracks: Vec<CatalogTrack>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct CatalogFixture {
    artists: Vec<Artist>,
    tracks: Vec<CatalogTrack>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct Artist {
    id: String,
    name: String,
    image_url: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct CatalogTrack {
    id: String,
    artist_id: String,
    title: String,
    duration_ms: u32,
    artwork_url: Option<String>,
    assets: Vec<CatalogTrackAsset>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct CatalogTrackAsset {
    id: String,
    track_id: String,
    manifest_url: String,
    codec: CatalogAudioCodec,
    bitrate_kbps: u32,
    segment_count: u32,
    is_primary: bool,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
enum CatalogAudioCodec {
    AacLc,
    Opus,
    Flac,
    Mp3,
}

#[derive(Debug, Serialize)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
}

#[derive(Debug, Clone, Serialize)]
struct CatalogResponse {
    artists: Vec<ArtistResponse>,
    tracks: Vec<TrackResponse>,
}

#[derive(Debug, Clone, Serialize)]
struct ArtistResponse {
    id: String,
    name: String,
    image_url: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
struct TrackResponse {
    id: String,
    artist_id: String,
    artist_name: Option<String>,
    title: String,
    duration_ms: u32,
    artwork_url: Option<String>,
    primary_asset: Option<TrackAssetResponse>,
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
        catalog: Arc::new(CatalogStore::from_dev_fixture()),
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
        .route("/catalog", get(get_catalog))
        .route("/artists", get(list_artists))
        .route("/artists/:id", get(get_artist))
        .route("/tracks", get(list_tracks))
        .route("/tracks/:id", get(get_track))
        .route("/tracks/:id/manifest", get(get_track_manifest))
        .route("/playback-events", post(record_playback_event))
        .with_state(state)
}

async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok",
        service: "wavezero-api",
    })
}

async fn get_catalog(State(state): State<AppState>) -> Json<CatalogResponse> {
    Json(state.catalog.response())
}

async fn list_artists(State(state): State<AppState>) -> Json<Vec<ArtistResponse>> {
    Json(state.catalog.artists.iter().map(ArtistResponse::from).collect())
}

async fn get_artist(Path(id): Path<String>, State(state): State<AppState>) -> impl IntoResponse {
    match state.catalog.artists.iter().find(|artist| artist.id == id) {
        Some(artist) => (StatusCode::OK, Json(ArtistResponse::from(artist))).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

async fn list_tracks(State(state): State<AppState>) -> Json<Vec<TrackResponse>> {
    Json(state.catalog.track_responses())
}

async fn get_track(Path(id): Path<String>, State(state): State<AppState>) -> impl IntoResponse {
    match state.catalog.find_track(&id) {
        Some(track) => (StatusCode::OK, Json(state.catalog.track_response(track))).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

async fn get_track_manifest(Path(id): Path<String>, State(state): State<AppState>) -> impl IntoResponse {
    let Some(track) = state.catalog.find_track(&id) else {
        return StatusCode::NOT_FOUND.into_response();
    };

    let Some(asset) = track.primary_asset() else {
        return StatusCode::NOT_FOUND.into_response();
    };

    (
        StatusCode::OK,
        Json(TrackManifestResponse {
            track: state.catalog.track_response(track),
            asset: TrackAssetResponse::from(asset),
            stream_url: asset.manifest_url.clone(),
        }),
    )
        .into_response()
}

#[derive(Debug, Clone, Serialize)]
struct TrackManifestResponse {
    track: TrackResponse,
    asset: TrackAssetResponse,
    stream_url: String,
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

impl CatalogStore {
    fn from_dev_fixture() -> Self {
        let fixture: CatalogFixture = serde_json::from_str(DEV_CATALOG_JSON)
            .expect("parse services/api/fixtures/dev_catalog.json");
        Self {
            artists: fixture.artists,
            tracks: fixture.tracks,
        }
    }

    fn response(&self) -> CatalogResponse {
        CatalogResponse {
            artists: self.artists.iter().map(ArtistResponse::from).collect(),
            tracks: self.track_responses(),
        }
    }

    fn track_responses(&self) -> Vec<TrackResponse> {
        self.tracks
            .iter()
            .map(|track| self.track_response(track))
            .collect()
    }

    fn find_track(&self, id: &str) -> Option<&CatalogTrack> {
        self.tracks.iter().find(|track| track.id == id)
    }

    fn artist_names_by_id(&self) -> HashMap<&str, &str> {
        self.artists
            .iter()
            .map(|artist| (artist.id.as_str(), artist.name.as_str()))
            .collect()
    }

    fn track_response(&self, track: &CatalogTrack) -> TrackResponse {
        let artist_names = self.artist_names_by_id();
        TrackResponse {
            id: track.id.clone(),
            artist_id: track.artist_id.clone(),
            artist_name: artist_names
                .get(track.artist_id.as_str())
                .map(|name| (*name).to_string()),
            title: track.title.clone(),
            duration_ms: track.duration_ms,
            artwork_url: track.artwork_url.clone(),
            primary_asset: track.primary_asset().map(TrackAssetResponse::from),
            assets: track.assets.iter().map(TrackAssetResponse::from).collect(),
        }
    }
}

impl CatalogTrack {
    fn primary_asset(&self) -> Option<&CatalogTrackAsset> {
        self.assets
            .iter()
            .find(|asset| asset.is_primary)
            .or_else(|| self.assets.first())
    }

    fn to_core_track(&self) -> Track {
        Track::new(
            self.id.clone(),
            self.artist_id.clone(),
            self.title.clone(),
            self.duration_ms,
            self.assets
                .iter()
                .map(CatalogTrackAsset::to_core_asset)
                .collect(),
        )
    }
}

impl CatalogTrackAsset {
    fn to_core_asset(&self) -> TrackAsset {
        TrackAsset::new(
            self.id.clone(),
            self.track_id.clone(),
            self.manifest_url.clone(),
            self.codec.into(),
            self.bitrate_kbps,
            self.segment_count,
            self.is_primary,
        )
    }
}

impl From<&Artist> for ArtistResponse {
    fn from(artist: &Artist) -> Self {
        Self {
            id: artist.id.clone(),
            name: artist.name.clone(),
            image_url: artist.image_url.clone(),
        }
    }
}

impl From<&CatalogTrackAsset> for TrackAssetResponse {
    fn from(asset: &CatalogTrackAsset) -> Self {
        Self {
            id: asset.id.clone(),
            track_id: asset.track_id.clone(),
            manifest_url: asset.manifest_url.clone(),
            codec: match asset.codec {
                CatalogAudioCodec::AacLc => "aac_lc",
                CatalogAudioCodec::Opus => "opus",
                CatalogAudioCodec::Flac => "flac",
                CatalogAudioCodec::Mp3 => "mp3",
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

impl From<CatalogAudioCodec> for AudioCodec {
    fn from(codec: CatalogAudioCodec) -> Self {
        match codec {
            CatalogAudioCodec::AacLc => AudioCodec::AacLc,
            CatalogAudioCodec::Opus => AudioCodec::Opus,
            CatalogAudioCodec::Flac => AudioCodec::Flac,
            CatalogAudioCodec::Mp3 => AudioCodec::Mp3,
        }
    }
}

#[allow(dead_code)]
fn example_metric() -> PlaybackMetric {
    PlaybackMetric::new("track-apple-bipbop-hls", 420, 0, NetworkType::Wifi, false, 95)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn routes_are_registered() {
        let router = app(AppState {
            catalog: Arc::new(CatalogStore::from_dev_fixture()),
        });

        let _ = router;
    }

    #[test]
    fn dev_catalog_fixture_loads_real_playable_track() {
        let catalog = CatalogStore::from_dev_fixture();
        assert_eq!(catalog.artists.len(), 1);
        assert_eq!(catalog.tracks.len(), 2);

        let track = catalog
            .find_track("track-local-song-3")
            .expect("song 3 track exists");
        let asset = track.primary_asset().expect("song 3 has primary asset");

        assert_eq!(track.title, "Song 3");
        assert_eq!(asset.manifest_url, "http://192.168.1.7:8090/song3.mp3");
        assert_eq!(
            track.to_core_track().primary_asset().unwrap().manifest_url,
            asset.manifest_url
        );
    }

    #[test]
    fn dev_catalog_fixture_loads_local_real_mp3_track() {
        let catalog = CatalogStore::from_dev_fixture();
        let track = catalog
            .find_track("track-local-real-song")
            .expect("local real track exists");
        let asset = track.primary_asset().expect("local real track has primary asset");
        let core_track = track.to_core_track();
        let core_asset = core_track.primary_asset().expect("core local asset exists");

        assert_eq!(track.title, "Local Real Song");
        assert_eq!(asset.manifest_url, "http://192.168.1.7:8090/song.mp3");
        assert_eq!(core_asset.codec, AudioCodec::Mp3);
    }

    #[test]
    fn catalog_response_includes_artist_name_and_primary_asset() {
        let catalog = CatalogStore::from_dev_fixture();
        let response = catalog.response();
        let track = response
            .tracks
            .iter()
            .find(|track| track.id == "track-local-song-3")
            .expect("song 3 track response exists");

        assert_eq!(track.artist_name.as_deref(), Some("Local Lab"));
        assert_eq!(track.primary_asset.as_ref().unwrap().codec, "mp3");
    }

    #[test]
    fn catalog_response_includes_local_real_song_mp3_asset() {
        let catalog = CatalogStore::from_dev_fixture();
        let response = catalog.response();
        let track = response
            .tracks
            .iter()
            .find(|track| track.id == "track-local-real-song")
            .expect("local real track response exists");

        assert_eq!(track.artist_name.as_deref(), Some("Local Lab"));
        assert_eq!(track.primary_asset.as_ref().unwrap().codec, "mp3");
        assert_eq!(track.primary_asset.as_ref().unwrap().bitrate_kbps, 128);
    }
}
