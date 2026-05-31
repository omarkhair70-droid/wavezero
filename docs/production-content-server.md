# WaveZero #83 — Production Content Server Foundation

WaveZero now separates development catalog behavior from demo and production content serving. This is a content-server foundation only: it does not add auth, cloud sync, uploads, a database, payments, DRM, CDN support, signed URLs, or real copyrighted/commercial music.

## Content modes

The Rust API reads `WAVEZERO_CONTENT_MODE` and supports three modes:

- `dev` (default): keeps the bundled fixture catalog and safe local developer folder behavior available.
- `demo`: expects an explicit curated catalog file and does not scan local folders.
- `production`: expects an explicit catalog file and never auto-exposes local developer audio.

If `WAVEZERO_CONTENT_MODE` is missing, the API uses `dev` so the existing local workflow remains available.

## Environment variables

| Variable | Purpose | Notes |
| --- | --- | --- |
| `WAVEZERO_CONTENT_MODE` | `dev`, `demo`, or `production` | Defaults to `dev`. Invalid values surface `invalid_content_mode` in status. |
| `WAVEZERO_CATALOG_PATH` | JSON catalog file path | Optional in `dev`; required for meaningful `demo`/`production` catalogs. |
| `WAVEZERO_CONTENT_BASE_URL` | Generic base URL for relative content paths | Used as fallback for artwork/audio path conversion. |
| `WAVEZERO_AUDIO_BASE_URL` | Base URL for relative audio assets | Dev defaults to the existing local audio server URL if not set. |
| `WAVEZERO_ARTWORK_BASE_URL` | Base URL for relative artwork assets | Falls back to `WAVEZERO_CONTENT_BASE_URL`. |
| `WAVEZERO_LOCAL_AUDIO_DIR` | Local developer audio directory | Dev-only replacement for the older `WAVEZERO_AUDIO_DIR` alias. |
| `WAVEZERO_ENABLE_LOCAL_FOLDER_CATALOG` | Enables local folder auto catalog in dev | Defaults to enabled in dev; ignored outside dev. |

Production and demo modes do not use safe dev defaults for local folder discovery and do not silently expose local laptop files.

## Catalog JSON shape

The server remains backward-compatible with `services/api/fixtures/dev_catalog.json`, while accepting a more production-oriented track shape:

```json
{
  "artists": [
    { "id": "artist-demo", "name": "Demo Artist", "image_url": "art/artwork.png" }
  ],
  "tracks": [
    {
      "id": "track-demo-safe",
      "artist_id": "artist-demo",
      "artist_name": "Demo Artist",
      "title": "Demo Track",
      "album_name": "Demo Album",
      "duration_ms": 180000,
      "artwork_url": "art/demo.png",
      "sourceType": "curated_demo",
      "productionSafe": true,
      "assets": [
        {
          "id": "asset-demo-safe-standard",
          "track_id": "track-demo-safe",
          "asset_path": "audio/demo.mp3",
          "codec": "mp3",
          "bitrate_kbps": 128,
          "quality_label": "standard",
          "sample_rate_hz": 44100,
          "bit_depth": null,
          "file_size_bytes": 1234567,
          "segment_count": 1,
          "is_primary": true
        }
      ],
      "licenseStatus": "public_domain",
      "licenseName": "Explicit safe license name",
      "licenseUrl": "https://example.invalid/license",
      "sourceName": "Curated Demo Catalog",
      "attributionRequired": false,
      "commercialUseAllowed": false,
      "redistributionAllowed": true,
      "derivativesAllowed": false,
      "usageNotes": "Only mark productionSafe true when rights metadata is explicit."
    }
  ]
}
```

Supported asset URL fields are `manifest_url`, `stream_url`, `asset_url`, and `asset_path`. Relative values are resolved against `WAVEZERO_AUDIO_BASE_URL` first and `WAVEZERO_CONTENT_BASE_URL` second. Relative artwork paths are resolved against `WAVEZERO_ARTWORK_BASE_URL` first and `WAVEZERO_CONTENT_BASE_URL` second.

## Manifest behavior

The existing manifest route remains available:

- `GET /tracks/:id/manifest`

The response still includes `track`, `asset`, and `stream_url` for Flutter compatibility. It now also carries the track license metadata at the top level. Missing tracks return JSON with `track_not_found`; missing or URL-less assets return `asset_not_available`.

## Health and content status

The API exposes both:

- `GET /health`
- `GET /api/content/status`

The status body includes:

- `ok`
- `contentMode`
- `catalogLoaded`
- `trackCount`
- `assetCount`
- `localFolderCatalogEnabled`
- `productionSafeTrackCount`
- `serverVersion`
- config-presence booleans such as `catalogConfigured`

Production mode does not expose raw local filesystem paths.

## Local folder dev behavior

Local folder auto catalog is dev-only. It accepts only:

- `.mp3`
- `.m4a`
- `.aac`
- `.wav`
- `.flac`

The server canonicalizes local paths, skips traversal-looking filenames, preserves codec/quality inference, and marks generated tracks as:

- `licenseStatus: dev_only`
- `sourceName: Local Folder / Local Dev Audio`
- `commercialUseAllowed: false`
- `redistributionAllowed: false`
- `productionSafe: false`

## Legal safety rules

- No real copyrighted/commercial music is added by this foundation.
- Nothing is treated as verified unless catalog metadata explicitly says so.
- `dev_only`, `license_pending`, `unknown`, and `user_device` server entries are not production-safe.
- Production mode filters out tracks unless `productionSafe` is true and the license status is one of `verified`, `attribution_required`, or `public_domain`.
- Device Music remains a user-owned, user-device context and is not part of the server catalog.

## Flutter integration

The Flutter catalog client can read `/api/content/status`. Consumer surfaces show friendly catalog labels such as `Catalog ready`, `Catalog unavailable`, and `Demo catalog`. API base URL and content status details stay in developer/Engine diagnostics instead of consumer library surfaces.

In dev, Flutter can continue using `WAVEZERO_API_BASE_URL` or the default Android emulator URL. In production, point Flutter at the deployed content server API while the server catalog resolves relative audio/artwork paths through configured base URLs.

## Intentionally not changed

This foundation does not change Android native playback, Device Music MediaStore behavior, cache file format, Queue Engine v2, Smart Downloads, Audio Quality selection, Audio Effects, auth, cloud sync, uploads, databases, payments, DRM, CDN/object storage, signed URLs, or production deployment.

## Future work

- Hosted production API deployment
- CDN/object storage
- Signed URLs
- Artist uploads
- Auth
- Moderation/review workflow
- Database-backed catalog
- Admin catalog dashboard
- Payments/subscriptions
- Analytics
- DRM/licensing integrations
