# WaveZero Legal Demo Catalog Ledger

## Purpose

WaveZero keeps catalog audio legally safe by separating playable files from rights claims. This ledger records the current catalog source types, license status meanings, and rules for adding demo or production catalog tracks. It does not grant rights to any audio file.

## Allowed catalog source types

- **Device Music**: audio discovered from the user's device. WaveZero does not claim catalog, redistribution, or commercial rights for these files.
- **Local dev audio**: local files used only for development, QA, playback proof, and cache/offline testing.
- **Legal demo catalog tracks**: future demo entries with explicit metadata included in the repository.
- **Artist uploads**: future creator-provided tracks with a rights declaration and review workflow.
- **Licensed catalog**: future production tracks backed by signed or otherwise auditable rights records.

## License status definitions

| Status | Meaning |
| --- | --- |
| `verified` | Rights metadata exists in the repo or production rights record and has been reviewed for the intended use. |
| `attribution_required` | Use is allowed only with the required attribution text and source/license links. |
| `public_domain` | Explicit public-domain metadata is present and manually verified before use. |
| `dev_only` | Development-only audio. Not production-safe. |
| `user_device` | User-owned/user-provided device music. WaveZero does not claim catalog rights. |
| `license_pending` | Metadata or review is incomplete. Not production-safe. |
| `unknown` | No usable rights metadata. Not production-safe. |

## Rules for adding demo tracks

1. Do not add copyrighted or commercial third-party music files.
2. Do not download, scrape, or embed external music in the repository.
3. Do not mark a track as `verified`, `public_domain`, or commercially usable unless explicit metadata is committed with the track entry.
4. Include source, artist, license, attribution, and usage notes whenever any non-dev demo track is added.
5. Treat missing metadata as `unknown` or `license_pending` until reviewed.

## Attribution requirements

When `attributionRequired` is true, `attributionText` must be shown in the app Credits / Licenses page. Source, artist, and license links should be included when available. If attribution requirements are unclear, the track must remain `license_pending`.

## Prohibited actions

- Adding real commercial music files.
- Claiming royalty-free, Creative Commons, public-domain, redistribution, derivative, or commercial-use permission without explicit metadata.
- Using code to scrape or verify external licenses automatically.
- Shipping local dev audio as a production catalog.

## Future production catalog process

Production catalog tracks should require manual rights review, signed or auditable rights records, moderation approval, source/license attribution checks, and a release checklist before being exposed as production-safe.

## Current dev/demo catalog entries

| Track id | Title | Artist | Source | License status | Attribution required | Production safe? | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `track-local-real-song` | Local Real Song | Local Lab | Local Dev Audio | `dev_only` | No | No | Local development audio only. Do not ship as production catalog unless rights are verified. |
| `track-local-song-3` | Song 3 | Local Lab | Local Dev Audio | `dev_only` | No | No | Local development audio only. Do not ship as production catalog unless rights are verified. |
| `track-local-song-4` | Song 4 | Local Lab | Local Dev Audio | `dev_only` | No | No | Local development audio only. Do not ship as production catalog unless rights are verified. |
| `track-local-song-5` | Song 5 | Local Lab | Local Dev Audio | `dev_only` | No | No | Local development audio only. Do not ship as production catalog unless rights are verified. |
| `track-local-*` | Auto-discovered local folder files | Local Lab | Local Folder | `dev_only` | No | No | Imported from local dev folder. Rights are not verified. |
