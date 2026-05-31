use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::{
    collections::{HashMap, HashSet},
    env, fs,
    net::SocketAddr,
    path::{Path as FsPath, PathBuf},
    sync::Arc,
};
use tokio::net::TcpListener;
use wavezero_core::{
    AudioCodec, LicenseMetadata as CoreLicenseMetadata, LicenseStatus as CoreLicenseStatus,
    NetworkType, PlaybackMetric, Track, TrackAsset,
};

const DEV_CATALOG_JSON: &str = include_str!("../fixtures/dev_catalog.json");
const SERVER_VERSION: &str = env!("CARGO_PKG_VERSION");
const DEFAULT_DEV_AUDIO_BASE_URL: &str = "http://192.168.1.7:8090";

#[derive(Clone)]
struct AppState {
    catalog: Arc<CatalogStore>,
}

#[derive(Debug, Clone)]
struct CatalogStore {
    config: ApiConfig,
    artists: Vec<Artist>,
    tracks: Vec<CatalogTrack>,
    catalog_loaded: bool,
    catalog_error: Option<ApiErrorBody>,
}

#[derive(Debug, Clone)]
struct ApiConfig {
    content_mode: ContentMode,
    catalog_path: Option<PathBuf>,
    content_base_url: Option<String>,
    audio_base_url: Option<String>,
    artwork_base_url: Option<String>,
    local_audio_dir: Option<PathBuf>,
    local_folder_catalog_enabled: bool,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum ContentMode {
    Dev,
    Demo,
    Production,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct CatalogFixture {
    #[serde(default)]
    artists: Vec<Artist>,
    #[serde(default)]
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
    #[serde(default)]
    artist_name: Option<String>,
    title: String,
    #[serde(default)]
    album_name: Option<String>,
    duration_ms: u32,
    #[serde(default)]
    artwork_url: Option<String>,
    #[serde(default, alias = "artworkPath", alias = "artwork_path")]
    artwork_path: Option<String>,
    #[serde(default)]
    assets: Vec<CatalogTrackAsset>,
    #[serde(rename = "sourceType", alias = "source_type", default)]
    source_type: Option<String>,
    #[serde(rename = "productionSafe", alias = "production_safe", default)]
    production_safe: Option<bool>,
    #[serde(flatten)]
    license: LicenseMetadata,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct LicenseMetadata {
    #[serde(rename = "licenseStatus", alias = "license_status", default = "default_license_status")]
    license_status: LicenseStatus,
    #[serde(rename = "licenseName", alias = "license_name", default)]
    license_name: Option<String>,
    #[serde(rename = "licenseUrl", alias = "license_url", default)]
    license_url: Option<String>,
    #[serde(rename = "sourceName", alias = "source_name", default)]
    source_name: Option<String>,
    #[serde(rename = "sourceUrl", alias = "source_url", default)]
    source_url: Option<String>,
    #[serde(rename = "artistUrl", alias = "artist_url", default)]
    artist_url: Option<String>,
    #[serde(rename = "attributionText", alias = "attribution_text", default)]
    attribution_text: Option<String>,
    #[serde(rename = "attributionRequired", alias = "attribution_required", default)]
    attribution_required: bool,
    #[serde(rename = "commercialUseAllowed", alias = "commercial_use_allowed", default)]
    commercial_use_allowed: bool,
    #[serde(rename = "redistributionAllowed", alias = "redistribution_allowed", default)]
    redistribution_allowed: bool,
    #[serde(rename = "derivativesAllowed", alias = "derivatives_allowed", default)]
    derivatives_allowed: bool,
    #[serde(rename = "usageNotes", alias = "usage_notes", default)]
    usage_notes: Option<String>,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum LicenseStatus {
    Verified,
    AttributionRequired,
    PublicDomain,
    DevOnly,
    UserDevice,
    LicensePending,
    Unknown,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
struct CatalogTrackAsset {
    id: String,
    track_id: String,
    #[serde(default)]
    manifest_url: String,
    #[serde(default, alias = "streamUrl", alias = "stream_url")]
    stream_url: Option<String>,
    #[serde(default, alias = "assetUrl", alias = "asset_url")]
    asset_url: Option<String>,
    #[serde(default, alias = "assetPath", alias = "asset_path")]
    asset_path: Option<String>,
    codec: CatalogAudioCodec,
    bitrate_kbps: u32,
    #[serde(default)]
    quality_label: Option<CatalogAudioQuality>,
    #[serde(default)]
    sample_rate_hz: Option<u32>,
    #[serde(default)]
    bit_depth: Option<u16>,
    #[serde(default)]
    file_size_bytes: Option<u64>,
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
    Wav,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum CatalogAudioQuality {
    Standard,
    High,
    Original,
}

#[derive(Debug, Clone, Serialize)]
struct CatalogResponse {
    artists: Vec<ArtistResponse>,
    tracks: Vec<TrackResponse>,
    #[serde(rename = "contentMode")]
    content_mode: ContentMode,
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
    album_name: Option<String>,
    duration_ms: u32,
    artwork_url: Option<String>,
    source: String,
    source_type: Option<String>,
    production_safe: bool,
    primary_asset: Option<TrackAssetResponse>,
    assets: Vec<TrackAssetResponse>,
    #[serde(flatten)]
    license: LicenseMetadata,
}

#[derive(Debug, Clone, Serialize)]
struct TrackAssetResponse {
    id: String,
    track_id: String,
    manifest_url: String,
    quality_label: String,
    codec: String,
    bitrate_kbps: u32,
    sample_rate_hz: Option<u32>,
    bit_depth: Option<u16>,
    file_size_bytes: Option<u64>,
    segment_count: u32,
    is_primary: bool,
}

#[derive(Debug, Clone, Serialize)]
struct TrackManifestResponse {
    track: TrackResponse,
    asset: TrackAssetResponse,
    stream_url: String,
    #[serde(flatten)]
    license: LicenseMetadata,
}

#[derive(Debug, Clone, Serialize)]
struct ContentStatusResponse {
    ok: bool,
    #[serde(rename = "contentMode")]
    content_mode: ContentMode,
    #[serde(rename = "catalogLoaded")]
    catalog_loaded: bool,
    #[serde(rename = "trackCount")]
    track_count: usize,
    #[serde(rename = "assetCount")]
    asset_count: usize,
    #[serde(rename = "localFolderCatalogEnabled")]
    local_folder_catalog_enabled: bool,
    #[serde(rename = "productionSafeTrackCount")]
    production_safe_track_count: usize,
    #[serde(rename = "serverVersion")]
    server_version: &'static str,
    #[serde(rename = "catalogConfigured")]
    catalog_configured: bool,
    #[serde(rename = "audioBaseUrlConfigured")]
    audio_base_url_configured: bool,
    #[serde(rename = "artworkBaseUrlConfigured")]
    artwork_base_url_configured: bool,
    #[serde(rename = "contentBaseUrlConfigured")]
    content_base_url_configured: bool,
    #[serde(rename = "localAudioDirConfigured", skip_serializing_if = "Option::is_none")]
    local_audio_dir_configured: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<ApiErrorBody>,
}

#[derive(Debug, Clone, Serialize)]
struct ApiErrorBody {
    error: String,
    message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    code: Option<String>,
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
        catalog: Arc::new(CatalogStore::from_env()),
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
        .route("/api/content/status", get(content_status))
        .route("/catalog", get(get_catalog))
        .route("/artists", get(list_artists))
        .route("/artists/:id", get(get_artist))
        .route("/tracks", get(list_tracks))
        .route("/tracks/:id", get(get_track))
        .route("/tracks/:id/manifest", get(get_track_manifest))
        .route("/playback-events", post(record_playback_event))
        .with_state(state)
}

async fn health(State(state): State<AppState>) -> Json<ContentStatusResponse> {
    Json(state.catalog.status_response())
}

async fn content_status(State(state): State<AppState>) -> Json<ContentStatusResponse> {
    Json(state.catalog.status_response())
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
        None => json_error(StatusCode::NOT_FOUND, "artist_not_found", "Artist was not found"),
    }
}

async fn list_tracks(State(state): State<AppState>) -> Json<Vec<TrackResponse>> {
    Json(state.catalog.track_responses())
}

async fn get_track(Path(id): Path<String>, State(state): State<AppState>) -> impl IntoResponse {
    match state.catalog.find_track(&id) {
        Some(track) => (StatusCode::OK, Json(state.catalog.track_response(track))).into_response(),
        None => json_error(StatusCode::NOT_FOUND, "track_not_found", "Track was not found"),
    }
}

async fn get_track_manifest(Path(id): Path<String>, State(state): State<AppState>) -> impl IntoResponse {
    let Some(track) = state.catalog.find_track(&id) else {
        return json_error(StatusCode::NOT_FOUND, "track_not_found", "Track was not found");
    };

    let Some(asset) = track.primary_asset() else {
        return json_error(
            StatusCode::NOT_FOUND,
            "asset_not_available",
            "Track does not have an available primary asset",
        );
    };

    if asset.manifest_url.trim().is_empty() {
        return json_error(
            StatusCode::NOT_FOUND,
            "asset_not_available",
            "Track asset is missing a stream URL",
        );
    }

    (
        StatusCode::OK,
        Json(TrackManifestResponse {
            track: state.catalog.track_response(track),
            asset: TrackAssetResponse::from(asset),
            stream_url: asset.manifest_url.clone(),
            license: track.license.clone(),
        }),
    )
        .into_response()
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

fn json_error(status: StatusCode, code: &str, message: &str) -> axum::response::Response {
    (
        status,
        Json(ApiErrorBody {
            error: code.to_string(),
            message: message.to_string(),
            code: Some(code.to_string()),
        }),
    )
        .into_response()
}

impl ApiConfig {
    fn from_env() -> Result<Self, ApiErrorBody> {
        let content_mode = ContentMode::from_env()?;
        let content_base_url = normalized_env_url("WAVEZERO_CONTENT_BASE_URL")
            .or_else(|| content_mode.is_dev().then(|| DEFAULT_DEV_AUDIO_BASE_URL.to_string()));
        let audio_base_url = normalized_env_url("WAVEZERO_AUDIO_BASE_URL")
            .or_else(|| content_mode.is_dev().then(|| DEFAULT_DEV_AUDIO_BASE_URL.to_string()));
        let artwork_base_url = normalized_env_url("WAVEZERO_ARTWORK_BASE_URL").or_else(|| content_base_url.clone());
        let catalog_path = env::var("WAVEZERO_CATALOG_PATH")
            .ok()
            .filter(|value| !value.trim().is_empty())
            .map(PathBuf::from);
        let local_audio_dir = env::var("WAVEZERO_LOCAL_AUDIO_DIR")
            .or_else(|_| env::var("WAVEZERO_AUDIO_DIR"))
            .ok()
            .filter(|value| !value.trim().is_empty())
            .map(PathBuf::from)
            .or_else(|| content_mode.is_dev().then(default_dev_audio_directory).flatten());
        let local_folder_catalog_enabled = content_mode.is_dev()
            && env_bool("WAVEZERO_ENABLE_LOCAL_FOLDER_CATALOG").unwrap_or(true);

        Ok(Self {
            content_mode,
            catalog_path,
            content_base_url,
            audio_base_url,
            artwork_base_url,
            local_audio_dir,
            local_folder_catalog_enabled,
        })
    }

    fn catalog_configured(&self) -> bool {
        self.catalog_path.is_some() || self.content_mode.is_dev()
    }
}

impl ContentMode {
    fn from_env() -> Result<Self, ApiErrorBody> {
        match env::var("WAVEZERO_CONTENT_MODE")
            .unwrap_or_else(|_| "dev".to_string())
            .trim()
            .to_lowercase()
            .as_str()
        {
            "dev" => Ok(Self::Dev),
            "demo" => Ok(Self::Demo),
            "production" | "prod" => Ok(Self::Production),
            value => Err(ApiErrorBody {
                error: "invalid_content_mode".to_string(),
                message: format!("Unsupported WAVEZERO_CONTENT_MODE '{value}'. Use dev, demo, or production."),
                code: Some("invalid_content_mode".to_string()),
            }),
        }
    }

    fn is_dev(self) -> bool {
        matches!(self, Self::Dev)
    }
}

impl CatalogStore {
    fn from_env() -> Self {
        let config = match ApiConfig::from_env() {
            Ok(config) => config,
            Err(error) => {
                return Self::empty_with_error(ApiConfig::dev_fallback(), error);
            }
        };

        Self::from_config(config)
    }

    fn from_config(config: ApiConfig) -> Self {
        let fixture_result = match (&config.content_mode, &config.catalog_path) {
            (ContentMode::Dev, Some(path)) => load_catalog_file(path),
            (ContentMode::Dev, None) => serde_json::from_str(DEV_CATALOG_JSON).map_err(|error| ApiErrorBody {
                error: "catalog_parse_failed".to_string(),
                message: format!("Could not parse bundled dev catalog: {error}"),
                code: Some("catalog_parse_failed".to_string()),
            }),
            (ContentMode::Demo | ContentMode::Production, Some(path)) => load_catalog_file(path),
            (ContentMode::Demo | ContentMode::Production, None) => {
                return Self::empty_with_error(
                    config,
                    ApiErrorBody {
                        error: "catalog_not_configured".to_string(),
                        message: "WAVEZERO_CATALOG_PATH is required for demo and production content modes.".to_string(),
                        code: Some("catalog_not_configured".to_string()),
                    },
                );
            }
        };

        let mut fixture = match fixture_result {
            Ok(fixture) => fixture,
            Err(error) => return Self::empty_with_error(config, error),
        };

        normalize_catalog_urls(&config, &mut fixture);
        filter_catalog_for_mode(&config, &mut fixture);

        let mut tracks = fixture.tracks;
        if config.content_mode.is_dev() && config.local_folder_catalog_enabled {
            let local_tracks = scan_local_audio_tracks(config.local_audio_dir.clone(), config.audio_base_url.clone(), &tracks);
            tracks.extend(local_tracks);
        }

        Self {
            config,
            artists: fixture.artists,
            tracks,
            catalog_loaded: true,
            catalog_error: None,
        }
    }

    fn empty_with_error(config: ApiConfig, error: ApiErrorBody) -> Self {
        Self {
            config,
            artists: Vec::new(),
            tracks: Vec::new(),
            catalog_loaded: false,
            catalog_error: Some(error),
        }
    }

    fn response(&self) -> CatalogResponse {
        CatalogResponse {
            artists: self.artists.iter().map(ArtistResponse::from).collect(),
            tracks: self.track_responses(),
            content_mode: self.config.content_mode,
        }
    }

    fn status_response(&self) -> ContentStatusResponse {
        ContentStatusResponse {
            ok: self.catalog_loaded && self.catalog_error.is_none(),
            content_mode: self.config.content_mode,
            catalog_loaded: self.catalog_loaded,
            track_count: self.tracks.len(),
            asset_count: self.tracks.iter().map(|track| track.assets.len()).sum(),
            local_folder_catalog_enabled: self.config.local_folder_catalog_enabled,
            production_safe_track_count: self.tracks.iter().filter(|track| track.is_production_safe()).count(),
            server_version: SERVER_VERSION,
            catalog_configured: self.config.catalog_configured(),
            audio_base_url_configured: self.config.audio_base_url.is_some(),
            artwork_base_url_configured: self.config.artwork_base_url.is_some(),
            content_base_url_configured: self.config.content_base_url.is_some(),
            local_audio_dir_configured: self.config.content_mode.is_dev().then_some(self.config.local_audio_dir.is_some()),
            error: self.catalog_error.clone(),
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
            artist_name: track.artist_name.clone().or_else(|| {
                artist_names
                    .get(track.artist_id.as_str())
                    .map(|name| (*name).to_string())
            }),
            title: track.title.clone(),
            album_name: track.album_name.clone(),
            duration_ms: track.duration_ms,
            artwork_url: track.artwork_url.clone(),
            source: track.source_label(),
            source_type: track.source_type.clone(),
            production_safe: track.is_production_safe(),
            primary_asset: track.primary_asset().map(TrackAssetResponse::from),
            assets: track.assets.iter().map(TrackAssetResponse::from).collect(),
            license: track.license.clone(),
        }
    }
}

impl ApiConfig {
    fn dev_fallback() -> Self {
        Self {
            content_mode: ContentMode::Dev,
            catalog_path: None,
            content_base_url: Some(DEFAULT_DEV_AUDIO_BASE_URL.to_string()),
            audio_base_url: Some(DEFAULT_DEV_AUDIO_BASE_URL.to_string()),
            artwork_base_url: Some(DEFAULT_DEV_AUDIO_BASE_URL.to_string()),
            local_audio_dir: default_dev_audio_directory(),
            local_folder_catalog_enabled: true,
        }
    }
}

fn load_catalog_file(path: &FsPath) -> Result<CatalogFixture, ApiErrorBody> {
    let body = fs::read_to_string(path).map_err(|error| ApiErrorBody {
        error: "catalog_load_failed".to_string(),
        message: format!("Could not read configured catalog file: {error}"),
        code: Some("catalog_load_failed".to_string()),
    })?;

    serde_json::from_str(&body).map_err(|error| ApiErrorBody {
        error: "catalog_parse_failed".to_string(),
        message: format!("Could not parse configured catalog JSON: {error}"),
        code: Some("catalog_parse_failed".to_string()),
    })
}

fn normalize_catalog_urls(config: &ApiConfig, catalog: &mut CatalogFixture) {
    for artist in &mut catalog.artists {
        artist.image_url = artist.image_url.take().and_then(|url| build_content_url(config.artwork_base_url.as_deref(), config.content_base_url.as_deref(), &url));
    }

    for track in &mut catalog.tracks {
        if track.artwork_url.is_none() {
            track.artwork_url = track.artwork_path.take();
        }
        track.artwork_url = track.artwork_url.take().and_then(|url| build_content_url(config.artwork_base_url.as_deref(), config.content_base_url.as_deref(), &url));

        for asset in &mut track.assets {
            let raw_url = first_non_empty([
                Some(asset.manifest_url.as_str()),
                asset.stream_url.as_deref(),
                asset.asset_url.as_deref(),
                asset.asset_path.as_deref(),
            ]);
            asset.manifest_url = raw_url
                .and_then(|url| build_content_url(config.audio_base_url.as_deref(), config.content_base_url.as_deref(), url))
                .unwrap_or_default();
        }
    }
}

fn filter_catalog_for_mode(config: &ApiConfig, catalog: &mut CatalogFixture) {
    match config.content_mode {
        ContentMode::Dev => {}
        ContentMode::Demo => {
            catalog.tracks.retain(|track| track.is_demo_safe());
        }
        ContentMode::Production => {
            catalog.tracks.retain(|track| track.is_production_safe());
        }
    }

    let artist_ids: HashSet<&str> = catalog.tracks.iter().map(|track| track.artist_id.as_str()).collect();
    catalog.artists.retain(|artist| artist_ids.contains(artist.id.as_str()));
}

fn build_content_url(primary_base_url: Option<&str>, fallback_base_url: Option<&str>, value: &str) -> Option<String> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return None;
    }
    if trimmed.starts_with("http://") || trimmed.starts_with("https://") || trimmed.starts_with("file://") || trimmed.starts_with("content://") {
        return Some(trimmed.to_string());
    }
    let base = primary_base_url.or(fallback_base_url)?.trim_end_matches('/');
    if base.is_empty() {
        return None;
    }
    let path = trimmed.trim_start_matches('/');
    Some(format!("{base}/{path}"))
}

fn first_non_empty<'a>(values: impl IntoIterator<Item = Option<&'a str>>) -> Option<&'a str> {
    values
        .into_iter()
        .flatten()
        .map(str::trim)
        .find(|value| !value.is_empty())
}

fn normalized_env_url(name: &str) -> Option<String> {
    env::var(name)
        .ok()
        .map(|value| value.trim().trim_end_matches('/').to_string())
        .filter(|value| !value.is_empty())
}

fn env_bool(name: &str) -> Option<bool> {
    let value = env::var(name).ok()?.trim().to_lowercase();
    match value.as_str() {
        "1" | "true" | "yes" | "on" => Some(true),
        "0" | "false" | "no" | "off" => Some(false),
        _ => None,
    }
}

fn default_license_status() -> LicenseStatus {
    LicenseStatus::Unknown
}

impl Default for LicenseMetadata {
    fn default() -> Self {
        Self {
            license_status: LicenseStatus::Unknown,
            license_name: None,
            license_url: None,
            source_name: None,
            source_url: None,
            artist_url: None,
            attribution_text: None,
            attribution_required: false,
            commercial_use_allowed: false,
            redistribution_allowed: false,
            derivatives_allowed: false,
            usage_notes: None,
        }
    }
}

impl LicenseMetadata {
    fn local_folder() -> Self {
        Self {
            license_status: LicenseStatus::DevOnly,
            license_name: Some("Local development audio - rights not verified".to_string()),
            source_name: Some("Local Folder / Local Dev Audio".to_string()),
            commercial_use_allowed: false,
            redistribution_allowed: false,
            usage_notes: Some("Imported from local dev folder. Rights are not verified and this must not ship in production.".to_string()),
            ..Self::default()
        }
    }

    fn is_production_license(&self) -> bool {
        matches!(
            self.license_status,
            LicenseStatus::Verified | LicenseStatus::AttributionRequired | LicenseStatus::PublicDomain
        )
    }

    fn is_dev_or_pending(&self) -> bool {
        matches!(
            self.license_status,
            LicenseStatus::DevOnly | LicenseStatus::LicensePending | LicenseStatus::Unknown | LicenseStatus::UserDevice
        )
    }
}

impl CatalogTrack {
    fn primary_asset(&self) -> Option<&CatalogTrackAsset> {
        self.assets
            .iter()
            .find(|asset| asset.is_primary && !asset.manifest_url.trim().is_empty())
            .or_else(|| self.assets.iter().find(|asset| !asset.manifest_url.trim().is_empty()))
    }

    fn source_label(&self) -> String {
        self.license
            .source_name
            .clone()
            .or_else(|| self.source_type.clone())
            .unwrap_or_else(|| "WaveZero Catalog".to_string())
    }

    fn is_production_safe(&self) -> bool {
        self.production_safe.unwrap_or(false) && self.license.is_production_license()
    }

    fn is_demo_safe(&self) -> bool {
        !self.license.is_dev_or_pending()
            && self.license.is_production_license()
            && self.production_safe.unwrap_or(false)
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
        .with_license_metadata(self.license.clone().into())
    }
}

impl CatalogTrackAsset {
    fn inferred_quality_label(&self) -> CatalogAudioQuality {
        self.quality_label
            .unwrap_or_else(|| infer_quality_label(self.codec, self.bitrate_kbps, &self.manifest_url))
    }

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

fn default_dev_audio_directory() -> Option<PathBuf> {
    let default_path = PathBuf::from(r"C:\Users\dell\Desktop\wavezero-test-audio");
    if default_path.is_dir() {
        Some(default_path)
    } else {
        None
    }
}

fn scan_local_audio_tracks(
    audio_dir: Option<PathBuf>,
    audio_base_url: Option<String>,
    existing_tracks: &[CatalogTrack],
) -> Vec<CatalogTrack> {
    let audio_dir = match audio_dir.and_then(|dir| fs::canonicalize(dir).ok()) {
        Some(dir) if dir.is_dir() => dir,
        _ => return Vec::new(),
    };

    let audio_base_url = match audio_base_url {
        Some(url) if !url.trim().is_empty() => url.trim_end_matches('/').to_string(),
        _ => return Vec::new(),
    };

    let existing_manifest_files: HashSet<String> = existing_tracks
        .iter()
        .flat_map(|track| track.assets.iter())
        .filter_map(|asset| asset.manifest_url.rsplit('/').next().map(|name| name.to_lowercase()))
        .collect();

    let mut reserved_ids: HashSet<String> = existing_tracks
        .iter()
        .map(|track| track.id.clone())
        .collect();

    let mut tracks: Vec<CatalogTrack> = Vec::new();

    for entry in audio_dir.read_dir().into_iter().flatten() {
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => continue,
        };

        let path = match fs::canonicalize(entry.path()) {
            Ok(path) if path.is_file() && path.starts_with(&audio_dir) => path,
            _ => continue,
        };

        let extension = path
            .extension()
            .and_then(|ext| ext.to_str())
            .map(|ext| ext.to_lowercase());
        let extension = match extension.as_deref() {
            Some("mp3") | Some("m4a") | Some("wav") | Some("aac") | Some("flac") => extension.unwrap(),
            _ => continue,
        };

        let file_name = match path.file_name().and_then(|name| name.to_str()) {
            Some(name) if !name.contains('/') && !name.contains('\\') && !name.contains("..") => name.to_string(),
            _ => continue,
        };

        if existing_manifest_files.contains(&file_name.to_lowercase()) {
            continue;
        }

        let stem = match path.file_stem().and_then(|stem| stem.to_str()) {
            Some(stem) => stem,
            None => continue,
        };

        let mut track_id = format!("track-local-{}", normalize_track_id(stem));
        let base_track_id = track_id.clone();
        let mut suffix = 1;
        while reserved_ids.contains(&track_id) {
            track_id = format!("{base_track_id}-{suffix}");
            suffix += 1;
        }
        reserved_ids.insert(track_id.clone());

        let title = readable_title(stem);
        let codec = audio_codec_from_extension(&extension);
        let bitrate_kbps = infer_bitrate_kbps(&extension, &file_name);
        let quality_label = infer_quality_label(codec, bitrate_kbps, &file_name);
        let file_size_bytes = fs::metadata(&path).ok().map(|metadata| metadata.len());
        let manifest_url = format!("{}/{}", audio_base_url, file_name);
        let asset_id = format!("asset-{}-{}", track_id, extension);

        tracks.push(CatalogTrack {
            id: track_id.clone(),
            artist_id: "artist-local-lab".to_string(),
            artist_name: Some("Local Lab".to_string()),
            title,
            album_name: Some("Local Dev Audio".to_string()),
            duration_ms: 180_000,
            artwork_url: None,
            artwork_path: None,
            assets: vec![CatalogTrackAsset {
                id: asset_id,
                track_id,
                manifest_url,
                stream_url: None,
                asset_url: None,
                asset_path: None,
                codec,
                bitrate_kbps,
                quality_label: Some(quality_label),
                sample_rate_hz: None,
                bit_depth: None,
                file_size_bytes,
                segment_count: 1,
                is_primary: true,
            }],
            source_type: Some("local_folder".to_string()),
            production_safe: Some(false),
            license: LicenseMetadata::local_folder(),
        });
    }

    tracks
}

fn normalize_track_id(stem: &str) -> String {
    let mut sanitized = String::new();
    let mut last_was_dash = false;

    for ch in stem.chars() {
        if ch.is_ascii_alphanumeric() {
            sanitized.push(ch.to_ascii_lowercase());
            last_was_dash = false;
        } else if !last_was_dash {
            sanitized.push('-');
            last_was_dash = true;
        }
    }

    sanitized.trim_matches('-').to_string()
}

fn readable_title(stem: &str) -> String {
    let mut normalized = String::new();
    let mut last_is_whitespace = false;
    let mut last_is_digit = false;
    let mut last_is_letter = false;

    for ch in stem.chars() {
        if ch.is_ascii_alphanumeric() {
            if ch.is_ascii_digit() && last_is_letter && !last_is_whitespace {
                normalized.push(' ');
            }
            if ch.is_ascii_alphabetic() && last_is_digit && !last_is_whitespace {
                normalized.push(' ');
            }
            normalized.push(ch);
            last_is_whitespace = false;
            last_is_digit = ch.is_ascii_digit();
            last_is_letter = ch.is_ascii_alphabetic();
        } else if !last_is_whitespace {
            normalized.push(' ');
            last_is_whitespace = true;
            last_is_digit = false;
            last_is_letter = false;
        }
    }

    normalized
        .split_whitespace()
        .map(|word| {
            let mut chars = word.chars();
            match chars.next() {
                Some(first) => first.to_ascii_uppercase().to_string() + chars.as_str().to_ascii_lowercase().as_str(),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn infer_bitrate_kbps(extension: &str, file_name: &str) -> u32 {
    let lower = file_name.to_lowercase();
    for bitrate in [1411_u32, 1024, 768, 512, 320, 256, 192, 160, 128, 96] {
        if lower.contains(&format!("{bitrate}kbps")) || lower.contains(&format!("{bitrate}k")) {
            return bitrate;
        }
    }

    match extension {
        "flac" | "wav" => 1411,
        "m4a" | "aac" => 256,
        "mp3" => 128,
        _ => 128,
    }
}

fn infer_quality_label(codec: CatalogAudioCodec, bitrate_kbps: u32, source: &str) -> CatalogAudioQuality {
    let source = source.to_lowercase();
    if source.contains("original") || source.contains("lossless") || source.contains("flac") || source.contains("wav") {
        return CatalogAudioQuality::Original;
    }

    match codec {
        CatalogAudioCodec::Flac | CatalogAudioCodec::Wav => CatalogAudioQuality::Original,
        CatalogAudioCodec::Mp3 | CatalogAudioCodec::AacLc if bitrate_kbps >= 256 => CatalogAudioQuality::High,
        _ => CatalogAudioQuality::Standard,
    }
}

fn audio_codec_from_extension(extension: &str) -> CatalogAudioCodec {
    match extension {
        "mp3" => CatalogAudioCodec::Mp3,
        "m4a" | "aac" => CatalogAudioCodec::AacLc,
        "wav" => CatalogAudioCodec::Wav,
        "flac" => CatalogAudioCodec::Flac,
        _ => CatalogAudioCodec::AacLc,
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
            quality_label: match asset.inferred_quality_label() {
                CatalogAudioQuality::Standard => "standard",
                CatalogAudioQuality::High => "high",
                CatalogAudioQuality::Original => "original",
            }
            .to_string(),
            codec: match asset.codec {
                CatalogAudioCodec::AacLc => "aac_lc",
                CatalogAudioCodec::Opus => "opus",
                CatalogAudioCodec::Flac => "flac",
                CatalogAudioCodec::Mp3 => "mp3",
                CatalogAudioCodec::Wav => "wav",
            }
            .to_string(),
            bitrate_kbps: asset.bitrate_kbps,
            sample_rate_hz: asset.sample_rate_hz,
            bit_depth: asset.bit_depth,
            file_size_bytes: asset.file_size_bytes,
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

impl From<LicenseMetadata> for CoreLicenseMetadata {
    fn from(license: LicenseMetadata) -> Self {
        Self {
            license_status: license.license_status.into(),
            license_name: license.license_name,
            license_url: license.license_url,
            source_name: license.source_name,
            source_url: license.source_url,
            artist_url: license.artist_url,
            attribution_text: license.attribution_text,
            attribution_required: license.attribution_required,
            commercial_use_allowed: license.commercial_use_allowed,
            redistribution_allowed: license.redistribution_allowed,
            derivatives_allowed: license.derivatives_allowed,
            usage_notes: license.usage_notes,
        }
    }
}

impl From<LicenseStatus> for CoreLicenseStatus {
    fn from(status: LicenseStatus) -> Self {
        match status {
            LicenseStatus::Verified => CoreLicenseStatus::Verified,
            LicenseStatus::AttributionRequired => CoreLicenseStatus::AttributionRequired,
            LicenseStatus::PublicDomain => CoreLicenseStatus::PublicDomain,
            LicenseStatus::DevOnly => CoreLicenseStatus::DevOnly,
            LicenseStatus::UserDevice => CoreLicenseStatus::UserDevice,
            LicenseStatus::LicensePending => CoreLicenseStatus::LicensePending,
            LicenseStatus::Unknown => CoreLicenseStatus::Unknown,
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
            CatalogAudioCodec::Wav => AudioCodec::Wav,
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
    use axum::body::to_bytes;
    use serde_json::Value;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn test_config(content_mode: ContentMode) -> ApiConfig {
        ApiConfig {
            content_mode,
            catalog_path: None,
            content_base_url: None,
            audio_base_url: Some(DEFAULT_DEV_AUDIO_BASE_URL.to_string()),
            artwork_base_url: None,
            local_audio_dir: None,
            local_folder_catalog_enabled: false,
        }
    }

    fn temp_path(name: &str) -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system clock after unix epoch")
            .as_nanos();
        env::temp_dir().join(format!("wavezero_{name}_{nonce}"))
    }

    fn artist() -> Artist {
        Artist {
            id: "artist-test".to_string(),
            name: "Test Artist".to_string(),
            image_url: None,
        }
    }

    fn asset(track_id: &str, manifest_url: &str) -> CatalogTrackAsset {
        CatalogTrackAsset {
            id: format!("asset-{track_id}"),
            track_id: track_id.to_string(),
            manifest_url: manifest_url.to_string(),
            stream_url: None,
            asset_url: None,
            asset_path: None,
            codec: CatalogAudioCodec::Mp3,
            bitrate_kbps: 128,
            quality_label: Some(CatalogAudioQuality::Standard),
            sample_rate_hz: Some(44_100),
            bit_depth: None,
            file_size_bytes: None,
            segment_count: 1,
            is_primary: true,
        }
    }

    fn track(
        id: &str,
        license_status: LicenseStatus,
        production_safe: bool,
        manifest_url: &str,
    ) -> CatalogTrack {
        CatalogTrack {
            id: id.to_string(),
            artist_id: "artist-test".to_string(),
            artist_name: Some("Test Artist".to_string()),
            title: id.to_string(),
            album_name: Some("Test Album".to_string()),
            duration_ms: 180_000,
            artwork_url: None,
            artwork_path: None,
            assets: vec![asset(id, manifest_url)],
            source_type: Some("test".to_string()),
            production_safe: Some(production_safe),
            license: LicenseMetadata {
                license_status,
                license_name: Some("Test license".to_string()),
                source_name: Some("Test Catalog".to_string()),
                commercial_use_allowed: false,
                redistribution_allowed: false,
                ..LicenseMetadata::default()
            },
        }
    }

    fn catalog_file(fixture: &CatalogFixture) -> PathBuf {
        let path = temp_path("catalog").with_extension("json");
        fs::write(
            &path,
            serde_json::to_string(fixture).expect("serialize test catalog"),
        )
        .expect("write test catalog");
        path
    }

    async fn response_json(response: axum::response::Response) -> Value {
        let body = to_bytes(response.into_body(), usize::MAX)
            .await
            .expect("read response body");
        serde_json::from_slice(&body).expect("response body is json")
    }

    #[tokio::test]
    async fn routes_are_registered() {
        let router = app(AppState {
            catalog: Arc::new(CatalogStore::from_config(test_config(ContentMode::Dev))),
        });

        let _ = router;
    }

    #[test]
    fn dev_catalog_loads_bundled_fixture() {
        let catalog = CatalogStore::from_config(test_config(ContentMode::Dev));

        assert!(catalog.catalog_loaded);
        assert!(catalog.catalog_error.is_none());
        assert_eq!(catalog.config.content_mode, ContentMode::Dev);
        assert_eq!(catalog.artists.len(), 1);
        assert_eq!(catalog.tracks.len(), 4);
    }

    #[test]
    fn dev_catalog_keeps_local_playback_chain_playable() {
        let catalog = CatalogStore::from_config(test_config(ContentMode::Dev));
        let expected_tracks = [
            ("track-local-real-song", "Local Real Song", "http://192.168.1.7:8090/song.mp3"),
            ("track-local-song-3", "Song 3", "http://192.168.1.7:8090/song3.mp3"),
            ("track-local-song-4", "Song 4", "http://192.168.1.7:8090/song4.mp3"),
            ("track-local-song-5", "Song 5", "http://192.168.1.7:8090/song5.mp3"),
        ];

        for (track_id, title, manifest_url) in expected_tracks {
            let track = catalog
                .find_track(track_id)
                .unwrap_or_else(|| panic!("{track_id} exists in dev catalog"));
            let asset = track
                .primary_asset()
                .unwrap_or_else(|| panic!("{track_id} has primary asset"));

            assert_eq!(track.title, title);
            assert_eq!(asset.manifest_url, manifest_url);
            assert!(matches!(asset.codec, CatalogAudioCodec::Mp3));
            assert!(asset.is_primary);
            assert!(track.to_core_track().primary_asset().is_some());
        }
    }

    #[test]
    fn config_audio_base_url_normalizes_relative_asset_urls() {
        let fixture = CatalogFixture {
            artists: vec![artist()],
            tracks: vec![track(
                "track-relative",
                LicenseStatus::PublicDomain,
                true,
                "audio/relative.mp3",
            )],
        };
        let path = catalog_file(&fixture);
        let mut config = test_config(ContentMode::Dev);
        config.catalog_path = Some(path.clone());
        config.audio_base_url = Some("https://cdn.example.test/audio/".to_string());

        let catalog = CatalogStore::from_config(config);
        fs::remove_file(path).expect("cleanup test catalog");
        let asset = catalog
            .find_track("track-relative")
            .and_then(CatalogTrack::primary_asset)
            .expect("relative track has primary asset");

        assert_eq!(asset.manifest_url, "https://cdn.example.test/audio/audio/relative.mp3");
    }

    #[test]
    fn local_folder_discovery_works_only_in_dev_mode() {
        let dir = temp_path("local_audio_dev_only");
        fs::create_dir_all(&dir).expect("create temp audio dir");
        fs::write(dir.join("dev-only.mp3"), b"audio").expect("create mp3 file");

        let fixture = CatalogFixture {
            artists: vec![artist()],
            tracks: vec![track("track-safe", LicenseStatus::PublicDomain, true, "safe.mp3")],
        };
        let path = catalog_file(&fixture);

        let mut dev_config = test_config(ContentMode::Dev);
        dev_config.catalog_path = Some(path.clone());
        dev_config.local_audio_dir = Some(dir.clone());
        dev_config.audio_base_url = Some("http://127.0.0.1:8090".to_string());
        dev_config.local_folder_catalog_enabled = true;
        let dev_catalog = CatalogStore::from_config(dev_config);
        assert!(dev_catalog.find_track("track-local-dev-only").is_some());

        let mut demo_config = test_config(ContentMode::Demo);
        demo_config.catalog_path = Some(path.clone());
        demo_config.local_audio_dir = Some(dir.clone());
        demo_config.audio_base_url = Some("http://127.0.0.1:8090".to_string());
        demo_config.local_folder_catalog_enabled = true;
        let demo_catalog = CatalogStore::from_config(demo_config);
        assert!(demo_catalog.find_track("track-local-dev-only").is_none());

        let mut production_config = test_config(ContentMode::Production);
        production_config.catalog_path = Some(path.clone());
        production_config.local_audio_dir = Some(dir.clone());
        production_config.audio_base_url = Some("http://127.0.0.1:8090".to_string());
        production_config.local_folder_catalog_enabled = true;
        let production_catalog = CatalogStore::from_config(production_config);
        assert!(production_catalog.find_track("track-local-dev-only").is_none());

        fs::remove_file(path).expect("cleanup test catalog");
        fs::remove_dir_all(dir).expect("cleanup temp audio dir");
    }

    #[test]
    fn local_folder_discovery_includes_mp3_and_flac_as_dev_only_not_production_safe() {
        let dir = temp_path("local_audio_formats");
        fs::create_dir_all(&dir).expect("create temp audio dir");
        fs::write(dir.join("song6.mp3"), b"audio").expect("create mp3 file");
        fs::write(dir.join("lossless-original.flac"), b"audio").expect("create flac file");

        let mut config = test_config(ContentMode::Dev);
        config.local_audio_dir = Some(dir.clone());
        config.audio_base_url = Some("http://127.0.0.1:8090".to_string());
        config.local_folder_catalog_enabled = true;

        let catalog = CatalogStore::from_config(config);
        let mp3_track = catalog
            .find_track("track-local-song6")
            .expect("song6 discovered");
        let mp3_asset = mp3_track.primary_asset().expect("mp3 primary asset");
        assert!(matches!(mp3_track.license.license_status, LicenseStatus::DevOnly));
        assert!(!mp3_track.is_production_safe());
        assert!(matches!(mp3_asset.codec, CatalogAudioCodec::Mp3));
        assert_eq!(mp3_asset.manifest_url, "http://127.0.0.1:8090/song6.mp3");

        let flac_track = catalog
            .find_track("track-local-lossless-original")
            .expect("flac discovered");
        let flac_asset = flac_track.primary_asset().expect("flac primary asset");
        assert!(matches!(flac_track.license.license_status, LicenseStatus::DevOnly));
        assert!(!flac_track.is_production_safe());
        assert!(matches!(flac_asset.codec, CatalogAudioCodec::Flac));
        assert_eq!(flac_asset.inferred_quality_label(), CatalogAudioQuality::Original);

        fs::remove_dir_all(dir).expect("cleanup temp audio dir");
    }

    #[test]
    fn local_folder_discovery_does_not_duplicate_existing_fixture_files() {
        let dir = temp_path("local_audio_dup");
        fs::create_dir_all(&dir).expect("create temp audio dir");
        fs::write(dir.join("song3.mp3"), b"audio").expect("create mp3 file");

        let mut config = test_config(ContentMode::Dev);
        config.local_audio_dir = Some(dir.clone());
        config.audio_base_url = Some("http://127.0.0.1:8090".to_string());
        config.local_folder_catalog_enabled = true;

        let catalog = CatalogStore::from_config(config);
        let count = catalog
            .tracks
            .iter()
            .filter(|track| track.id == "track-local-song-3")
            .count();
        assert_eq!(count, 1);

        fs::remove_dir_all(dir).expect("cleanup temp audio dir");
    }

    #[test]
    fn demo_mode_without_catalog_path_returns_safe_empty_status() {
        let catalog = CatalogStore::from_config(test_config(ContentMode::Demo));
        let status = catalog.status_response();

        assert!(!status.ok);
        assert!(!status.catalog_loaded);
        assert_eq!(status.track_count, 0);
        assert_eq!(status.asset_count, 0);
        assert_eq!(status.error.as_ref().map(|error| error.error.as_str()), Some("catalog_not_configured"));
    }

    #[test]
    fn production_mode_without_catalog_path_returns_safe_empty_status() {
        let catalog = CatalogStore::from_config(test_config(ContentMode::Production));
        let status = catalog.status_response();

        assert!(!status.ok);
        assert!(!status.catalog_loaded);
        assert_eq!(status.track_count, 0);
        assert_eq!(status.asset_count, 0);
        assert_eq!(status.error.as_ref().map(|error| error.error.as_str()), Some("catalog_not_configured"));
    }

    #[test]
    fn production_mode_filters_out_dev_only_and_not_production_safe_tracks() {
        let fixture = CatalogFixture {
            artists: vec![artist()],
            tracks: vec![
                track("track-safe", LicenseStatus::PublicDomain, true, "safe.mp3"),
                track("track-dev-only", LicenseStatus::DevOnly, true, "dev.mp3"),
                track("track-not-safe", LicenseStatus::Verified, false, "unsafe.mp3"),
            ],
        };
        let path = catalog_file(&fixture);
        let mut config = test_config(ContentMode::Production);
        config.catalog_path = Some(path.clone());
        config.audio_base_url = Some("https://cdn.example.test".to_string());

        let catalog = CatalogStore::from_config(config);
        fs::remove_file(path).expect("cleanup test catalog");

        assert!(catalog.find_track("track-safe").is_some());
        assert!(catalog.find_track("track-dev-only").is_none());
        assert!(catalog.find_track("track-not-safe").is_none());
        assert_eq!(catalog.tracks.len(), 1);
    }

    #[tokio::test]
    async fn manifest_response_exposes_track_asset_and_stream_url() {
        let state = AppState {
            catalog: Arc::new(CatalogStore::from_config(test_config(ContentMode::Dev))),
        };

        let response = get_track_manifest(
            Path("track-local-song-3".to_string()),
            State(state),
        )
        .await
        .into_response();
        assert_eq!(response.status(), StatusCode::OK);
        let json = response_json(response).await;

        assert_eq!(json["track"]["id"], "track-local-song-3");
        assert_eq!(json["asset"]["id"], "asset-local-song-3-mp3");
        assert_eq!(json["stream_url"], "http://192.168.1.7:8090/song3.mp3");
    }

    #[tokio::test]
    async fn missing_track_returns_json_track_not_found() {
        let state = AppState {
            catalog: Arc::new(CatalogStore::from_config(test_config(ContentMode::Dev))),
        };

        let response = get_track_manifest(Path("missing-track".to_string()), State(state))
            .await
            .into_response();
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
        let json = response_json(response).await;

        assert_eq!(json["error"], "track_not_found");
    }

    #[tokio::test]
    async fn url_less_asset_returns_json_asset_not_available() {
        let fixture = CatalogFixture {
            artists: vec![artist()],
            tracks: vec![track(
                "track-url-less",
                LicenseStatus::PublicDomain,
                true,
                "",
            )],
        };
        let path = catalog_file(&fixture);
        let mut config = test_config(ContentMode::Dev);
        config.catalog_path = Some(path.clone());
        let state = AppState {
            catalog: Arc::new(CatalogStore::from_config(config)),
        };

        let response = get_track_manifest(Path("track-url-less".to_string()), State(state))
            .await
            .into_response();
        fs::remove_file(path).expect("cleanup test catalog");
        assert_eq!(response.status(), StatusCode::NOT_FOUND);
        let json = response_json(response).await;

        assert_eq!(json["error"], "asset_not_available");
    }
}
