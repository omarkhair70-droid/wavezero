# Streaming Pipeline

WaveZero will store streamable audio in Cloudflare R2 as HLS/CMAF manifests and
segments.

## Target Flow

1. Source audio is validated and normalized.
2. Encoders produce HLS/CMAF audio variants.
3. Manifests and media segments are uploaded to Cloudflare R2.
4. `track_assets` rows store manifest keys, codecs, bitrates, and segment counts.
5. Android fetches signed manifests through the edge worker.
6. Media3 streams segments while the Rust core guides prefetch and cache policy.

## Edge Access

TODO: Cloudflare R2 signed manifests will be implemented in
`services/edge-worker` with signature validation, expiry checks, and object
streaming from R2.

## Encoding

TODO: HLS/CMAF encoding pipeline scripts will live in `infra/encoding` once the
source media format, variant ladder, and loudness normalization policy are set.
