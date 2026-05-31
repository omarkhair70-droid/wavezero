# WaveZero Cloud Vault

WaveZero Cloud Vault is the safe foundation for personal cloud music sources. It is a private, user-owned source organization feature for music a listener already controls; it is not a catalog, upload service, public sharing feature, or piracy/sharing workflow.

## Purpose

Cloud Vault introduces the product language, local data model, and Flutter UX needed to later connect private providers such as Google Drive, Dropbox, OneDrive, and Nextcloud. The first foundation keeps provider integrations in a coming-soon state and stores only lightweight metadata locally.

## Safety model

- User cloud files belong to the user.
- WaveZero does not upload cloud files to WaveZero servers.
- Only files the user chooses should appear in Cloud Vault.
- WaveZero does not support public redistribution of copyrighted files.
- Cloud Vault is a private playback/source organization feature, not a piracy or sharing feature.
- Future provider work must not add full-drive scans, public links, friend-to-friend transfer, or copyrighted catalog ingestion.

## Provider roadmap

Current provider cards are intentionally non-auth placeholders:

- Google Drive — Coming soon
- Dropbox — Later
- OneDrive — Later
- Nextcloud / self-hosted — Later
- Manual private URL — Developer preview only when Developer Mode is enabled

Future provider PRs should add provider-specific authentication and playback only after a separate privacy/security review. This foundation does not include OAuth credentials, token refresh, provider SDK setup, backend uploads, cloud sync accounts, or provider API keys.

## Locally stored metadata

Cloud Vault persists a JSON list in `SharedPreferences` under `wavezero.cloud_vault.tracks.v1`. Each entry can contain:

- `cloudTrackId`
- `title`
- `artistName`
- `albumName`
- `durationMs`
- `artworkUrl`
- `provider`
- `providerFileId`
- `sourceUri`
- `playableUri`
- `mimeType`
- `fileSizeBytes`
- `importedAtMs`
- `lastPlayedAtMs`
- `isAvailable`
- local-only/privacy flags

If the stored JSON is corrupt, WaveZero backs up the raw string to `wavezero.cloud_vault.tracks.v1.corrupt_backup`, clears the active Cloud Vault key, and returns an empty list so the consumer UI fails safe.

## What is not stored

Cloud Vault does not store:

- OAuth tokens
- refresh tokens
- provider API credentials
- Google Cloud project configuration
- hosted backend database records
- uploaded music files
- public sharing links for redistribution
- friend-to-friend transfer payloads
- DRM or payment/subscription state

## Playback boundaries

Playable developer-preview entries use the existing Flutter-to-native playback bridge with a URL/path placeholder. Cloud Vault does not invent signed URLs, bypass native playback, refresh provider tokens, or scan cloud drives. Unavailable entries show friendly copy: “Cloud playback is not connected yet.”

## Manual checklist

1. Start app.
2. Open Settings.
3. Open Cloud Vault.
4. Confirm consumer copy is privacy-safe.
5. Confirm provider cards show coming-soon states.
6. Confirm no OAuth/token/API credential UI appears in consumer mode.
7. Enable Developer Mode.
8. Confirm developer preview/manual seed controls appear only in Developer Mode.
9. Add a manual test cloud track if supported.
10. Confirm it appears in Cloud Vault list.
11. Confirm unavailable cloud tracks show friendly unavailable copy.
12. Confirm playable developer-preview track uses existing playback path.
13. Confirm Add to Queue works only when track is resolvable.
14. Confirm remove-one and clear-all work.
15. Restart app and confirm Cloud Vault entries persist.
16. Corrupt/clear storage behavior should fail safe.
17. Confirm Library/Search integration does not clutter consumer UI.
18. Confirm no raw provider IDs/tokens/URLs appear in consumer surfaces unless Developer Mode is active.
19. Confirm Device Music, Downloads, Library, Search, Queue, Now, Settings still work.
20. Confirm no bottom-nav item was added.
