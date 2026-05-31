# WaveZero Beta Release Checklist

WaveZero #84 defines a repeatable beta/release-style build path without adding auth, cloud sync, payments, DRM, uploads, hosted deployment, or new content systems.

## 1. Pre-build local checks

- Confirm the working tree contains no secrets, keystores, signing passwords, commercial songs, or copyrighted catalog files.
- Confirm Android native playback, Media3 notification controls, Device Music import, CacheService storage, Queue Engine v2, Smart Downloads, Audio Quality, and Audio Effects behavior are unchanged from the last validated build.
- Confirm the Rust API/content server expected for the build is already running or reachable by testers.
- Confirm the app can launch even when the catalog server is unavailable.
- Confirm Developer Mode is off before consumer smoke testing.

## 2. Required dart-defines

Use explicit build-time configuration for every non-dev build:

```text
--dart-define=WAVEZERO_APP_ENV=beta
--dart-define=WAVEZERO_API_BASE_URL=<https-or-lan-api-base-url>
--dart-define=WAVEZERO_CONTENT_MODE_LABEL=<Demo catalog or Catalog ready>
```

Supported environments:

- `dev` — default. Keeps local API workflows and Developer Mode access available.
- `beta` — hides manual API setup from consumer mode while allowing Developer Mode inspection.
- `production` — hides developer entry points from normal Settings and does not default consumer copy to local laptop URLs.

## 3. API/content server requirements

- The API base URL must point to the catalog API root, not an endpoint path.
- The catalog should expose rights metadata for every catalog track.
- Demo/dev-only tracks must remain labeled as demo or dev-only and must not be represented as production-safe catalog content.
- If the catalog is down, consumer UI should show: “Catalog is unavailable right now.” and “Check your connection or try again later.”
- Device Music and Downloads should remain usable when the API/content server is unavailable.

## 4. Android device install checklist

- Use a trusted test device or emulator.
- Confirm the app is installed from the intended APK/build variant.
- Confirm media notification permissions and Android audio permissions are handled by existing app flows.
- Do not add signing secrets, keystores, Play Store credentials, or production distribution metadata for this beta foundation.

## 5. Smoke test checklist

1. Launch the app.
2. Open Home and confirm it does not block on server availability.
3. Open Library and confirm Catalog, Device Music, and Downloads sections render.
4. Kill or disconnect the API server and confirm Library shows friendly catalog unavailable copy.
5. Import Device Music and confirm WaveZero states that device music is not uploaded.
6. Play a catalog, device, or downloaded track that is available.
7. Confirm the premium player surface opens.
8. Confirm the mini player appears and controls playback.
9. Confirm Android notification controls continue to work.
10. Add tracks to Queue and exercise previous/next where available.
11. Download a track and confirm downloads stay on this device.
12. Open Storage Manager and confirm it does not expose raw file paths in consumer mode.
13. Create/open Collections and confirm local-only playlist copy.
14. Open Listening History and confirm history stays on this device.
15. Run Search and confirm search runs on this device across local state.
16. Open Settings and confirm app environment/build info appears.
17. Open Legal / Licenses and confirm rights messaging remains clear.

## 6. Consumer UI safety checklist

Consumer mode must not prominently show:

- API base URLs.
- local laptop IP addresses or `localhost` setup copy.
- manifest URLs or stream URLs.
- raw status JSON.
- stack traces.
- raw file paths.
- internal IDs as primary user-facing copy.
- SharedPreferences keys.
- Rust/service implementation details.

Developer Mode may show technical details only in Engine/developer surfaces.

## 7. Known non-production limitations

- No auth or login.
- No cloud sync.
- No artist uploads.
- No payments or subscriptions.
- No DRM.
- No licensed commercial catalog claim.
- No hosted production API deployment is included.
- Local/dev content and demo catalog tracks are limited to test and validation workflows.

## 8. Android build command examples

Documentation-only examples; fill in real values locally and do not commit secrets.

Dev debug build:

```bash
cd apps/flutter/wavezero_app
flutter build apk --debug \
  --dart-define=WAVEZERO_APP_ENV=dev \
  --dart-define=WAVEZERO_API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=WAVEZERO_CONTENT_MODE_LABEL="Local/dev catalog"
```

Beta debug build:

```bash
cd apps/flutter/wavezero_app
flutter build apk --debug \
  --dart-define=WAVEZERO_APP_ENV=beta \
  --dart-define=WAVEZERO_API_BASE_URL=<beta-api-base-url> \
  --dart-define=WAVEZERO_CONTENT_MODE_LABEL="Demo catalog"
```

Beta profile build:

```bash
cd apps/flutter/wavezero_app
flutter build apk --profile \
  --dart-define=WAVEZERO_APP_ENV=beta \
  --dart-define=WAVEZERO_API_BASE_URL=<beta-api-base-url> \
  --dart-define=WAVEZERO_CONTENT_MODE_LABEL="Demo catalog"
```

Beta release-style build placeholder:

```bash
cd apps/flutter/wavezero_app
flutter build apk --release \
  --dart-define=WAVEZERO_APP_ENV=beta \
  --dart-define=WAVEZERO_API_BASE_URL=<beta-api-base-url> \
  --dart-define=WAVEZERO_CONTENT_MODE_LABEL="Demo catalog"
```

## 9. Rollback notes

- Reinstall the last known good APK if beta smoke testing fails.
- Reset app data if a stale Developer Mode preference affects consumer checks.
- Revert only the Flutter release-config/docs changes if native playback, Device Music, cache format, queue, Smart Downloads, Audio Quality, Audio Effects, or legal catalog behavior appears affected.
- Keep tester communication clear: beta builds are local/device-first and do not include production account, sync, upload, or payment systems.
