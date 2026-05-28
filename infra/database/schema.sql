CREATE TABLE artists (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tracks (
    id UUID PRIMARY KEY,
    artist_id UUID NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    duration_ms INTEGER NOT NULL CHECK (duration_ms > 0),
    release_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX tracks_artist_id_idx ON tracks(artist_id);

CREATE TABLE track_assets (
    id UUID PRIMARY KEY,
    track_id UUID NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    codec TEXT NOT NULL CHECK (codec IN ('aac_lc', 'opus', 'flac')),
    bitrate_kbps INTEGER NOT NULL CHECK (bitrate_kbps > 0),
    manifest_key TEXT NOT NULL,
    segment_count INTEGER NOT NULL CHECK (segment_count >= 0),
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (track_id, manifest_key)
);

CREATE INDEX track_assets_track_id_idx ON track_assets(track_id);

CREATE TABLE playback_events (
    id UUID PRIMARY KEY,
    track_id UUID NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    user_id UUID,
    session_id TEXT NOT NULL,
    time_to_first_audio_ms INTEGER NOT NULL CHECK (time_to_first_audio_ms >= 0),
    buffer_count INTEGER NOT NULL CHECK (buffer_count >= 0),
    network_type TEXT NOT NULL,
    cache_hit BOOLEAN NOT NULL,
    manifest_fetch_ms INTEGER NOT NULL CHECK (manifest_fetch_ms >= 0),
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX playback_events_track_id_occurred_at_idx ON playback_events(track_id, occurred_at DESC);
CREATE INDEX playback_events_session_id_idx ON playback_events(session_id);
