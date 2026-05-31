# FMA Local Demo Library

WaveZero #87 adds a safe repo-side foundation for building a large local demo catalog from Free Music Archive (FMA) metadata while keeping all audio and generated local content outside Git.

## What the importer does

`tools/fma/build_fma_green_small_local_library.py` is a local-only helper that:

- Reads a FMA Green candidates CSV, such as `wavezero_fma_green_candidates_all_v2.csv` or an equivalent export.
- Filters rows to strict Green candidates in the FMA `small` subset.
- Finds the matching MP3s inside `fma_small.zip`.
- Extracts those MP3s into a caller-provided local audio directory using the FMA folder layout from the ZIP.
- Writes a WaveZero-compatible catalog JSON with top-level `artists`, `tracks`, and `assets` arrays.
- Embeds each track's primary MP3 asset in the track-level `assets` list expected by the Rust API and Flutter catalog client.
- Writes an import report CSV with imported and missing rows.
- Prints a summary with Green small input, imported audio, missing audio, artist count, audio folder, catalog JSON, and report CSV.

The script uses only the Python standard library and does not require pandas.

## What the importer does not do

The importer intentionally does **not**:

- Commit or vendor MP3 files.
- Commit `fma_small.zip`.
- Commit generated local catalog JSON files that may contain LAN IPs or machine-specific paths.
- Add copyrighted/commercial music to the repository.
- Download from, rip from, or integrate YouTube, SoundCloud, Spotify, Anghami, or other commercial streaming services.
- Upload audio to hosted storage.
- Change Android native playback.
- Change Rust API behavior.
- Change Flutter UI.
- Change Cloud Vault.
- Add auth, accounts, cloud sync, artist uploads, dashboards, subscriptions, payments, DRM, or a backend database.

## Required external files

Keep these files outside the repository, for example under `C:\Users\<you>\Desktop\wavezero-fma-work\fma\data`:

- `fma_small.zip`
- FMA metadata CSVs, usually in a `fma_metadata` directory
- `wavezero_fma_green_candidates_all_v2.csv` or an equivalent CSV that includes strict Green candidate rows and enough FMA track metadata to build the catalog

## Example Windows PowerShell workflow

Set local paths. Replace `<LAN-IP>` with the development machine IP address reachable from the Android device.

```powershell
$WorkRoot = "C:\Users\dell\Desktop\wavezero-fma-work\fma\data"
$MetadataDir = "$WorkRoot\fma_metadata"
$AudioDir = "$WorkRoot\wavezero_fma_green_small_audio"
$CatalogJson = "$MetadataDir\wavezero_fma_green_small_catalog.json"
$ReportCsv = "$MetadataDir\wavezero_fma_green_small_import_report.csv"
$AudioBaseUrl = "http://<LAN-IP>:8091"

python tools\fma\build_fma_green_small_local_library.py `
  --metadata-dir $MetadataDir `
  --fma-small-zip "$WorkRoot\fma_small.zip" `
  --input-csv "$MetadataDir\wavezero_fma_green_candidates_all_v2.csv" `
  --output-audio-dir $AudioDir `
  --output-catalog-json $CatalogJson `
  --output-report-csv $ReportCsv `
  --audio-base-url $AudioBaseUrl
```

Expected successful summary for the current FMA Green Small Demo Library shape:

```text
Green small input: 1374
Imported audio: 1374
Missing: 0
Artists: 284
Audio folder: C:\Users\dell\Desktop\wavezero-fma-work\fma\data\wavezero_fma_green_small_audio
Catalog JSON: C:\Users\dell\Desktop\wavezero-fma-work\fma\data\fma_metadata\wavezero_fma_green_small_catalog.json
Report CSV: C:\Users\dell\Desktop\wavezero-fma-work\fma\data\fma_metadata\wavezero_fma_green_small_import_report.csv
```

If `Missing` is not `0`, inspect the generated import report and document the missing track IDs before using the catalog for demo testing.

## Start the local audio server

In a dedicated terminal:

```powershell
cd <output-audio-dir>
python -m http.server 8091 --bind 0.0.0.0
```

Confirm the Android device can reach `http://<LAN-IP>:8091/` on the same trusted LAN or hotspot.

## Start the Rust API with the generated catalog

In another terminal, from the repository root, set demo catalog environment variables before starting the API:

```powershell
$env:WAVEZERO_CONTENT_MODE = "demo"
$env:WAVEZERO_CATALOG_PATH = "<generated catalog json>"
$env:WAVEZERO_AUDIO_BASE_URL = "http://<LAN-IP>:8091"
$env:WAVEZERO_CONTENT_MODE_LABEL = "FMA Green Demo Library"
```

Then start the Rust API using the normal local API command for your development loop.

Useful manual checks after the API is running:

- Open `http://<API-IP>:<API-PORT>/api/content/status` and confirm the catalog is loaded.
- Open `http://<API-IP>:<API-PORT>/catalog` and confirm the large local demo catalog returns more than 1000 tracks.

## Run the Flutter app against the Rust API

Start the Flutter app with the API base URL pointing to the Rust API on the development machine. Use the same LAN IP that the Android device can reach.

```powershell
cd apps\flutter\wavezero_app
flutter run --dart-define=WAVEZERO_API_BASE_URL=http://<API-IP>:<API-PORT>
```

After launch, confirm:

- Library and Search show the large demo catalog.
- Multiple tracks from different genres play.
- Multiple FMA tracks can be queued.

## Keeping local content out of Git

The repository ignore rules include safety patterns for local FMA ZIPs, extracted audio folders, generated local library JSON, generated FMA catalog/report files, and MP3 files. Still review staged files before every commit and make sure the following never enter Git:

- `fma_small.zip`
- `wavezero_fma_green_small_audio/`
- `wavezero_demo_audio_*/`
- `wavezero_fma_green_small_catalog.json`
- `wavezero_fma_green_small_import_report.csv`
- Any generated `*_local_library.json`
- Any MP3 files from the local FMA library

## Legal and attribution boundaries

`productionSafe` in the generated catalog means **local demo candidate only**. It does not mean final legal approval.

The importer maps licenses conservatively:

- CC0/Public Domain metadata becomes `licenseStatus: public_domain`.
- Attribution and ShareAlike-style Creative Commons metadata becomes `licenseStatus: attribution_required`.
- Unknown or unrecognized metadata becomes `licenseStatus: license_pending`.

Every generated track includes usage notes stating that the original FMA track page, license URL, attribution requirements, and production rights must be verified before any production release. Preserve attribution text and verify license details against the original source before any public or production distribution.

## Curated Featured Demo vs. Big Local Demo Library

| Catalog | Purpose | Content location | Expected size | Production implication |
| --- | --- | --- | --- | --- |
| Curated Featured Demo | Small stable demo set for routine development and presentation flows. | Repo fixtures or approved dev content paths. | Small. | Still requires rights clarity before production use. |
| Big Local Demo Library | Large local FMA Green Small catalog for stress-testing Library, Search, queue, and playback variety. | Outside Git on a developer machine. | More than 1000 tracks. | Local demo candidate only; original pages/licenses must be verified before production release. |

## Manual checklist

1. Confirm `fma_small.zip` exists outside the repo.
2. Confirm the FMA metadata CSV exists outside the repo.
3. Run the importer with `--audio-base-url http://<LAN-IP>:8091`.
4. Confirm `Imported audio` equals the expected Green small input.
5. Confirm `Missing` is `0` or document missing rows from the report.
6. Start the local audio server on port `8091`.
7. Start the Rust API with the generated catalog path.
8. Open `/api/content/status`.
9. Open `/catalog` and confirm more than 1000 tracks.
10. Launch the Flutter app with the API base URL.
11. Confirm Library/Search show the large demo catalog.
12. Play multiple tracks from different genres.
13. Queue multiple FMA tracks.
14. Confirm no MP3/ZIP/generated local catalog files are staged for Git.
15. Confirm docs explain attribution and production verification boundaries.
