# WaveZero Encoding Pipeline Placeholder

Phase 0 does not implement media ingestion or transcoding.

TODO: HLS/CMAF encoding pipeline:
- Normalize source audio into mezzanine assets.
- Encode Android-first adaptive audio variants.
- Package HLS/CMAF manifests and segments.
- Upload manifests and segments to Cloudflare R2.
- Emit `track_assets` rows with manifest keys, codecs, bitrates, and segment counts.
