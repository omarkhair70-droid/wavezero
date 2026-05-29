# WaveZero Distribution Guide

Phase 0E establishes a safer development distribution path without changing app behavior, signing, playback, or release tooling.

## Distribution policy

- **Daily development:** Android Studio Run or Flutter `flutter run`.
- **Tester sharing:** Firebase App Distribution debug builds.
- **Fallback only:** Manually generated debug APKs.
- **Not included in Phase 0E:** Google Play release automation, production signing, committed Firebase secrets, committed service account JSON files, or committed Gradle wrapper JAR binaries.

## Firebase App Distribution path

Firebase App Distribution is the intended internal tester-sharing flow for Android debug builds.

Required environment variables:

| Variable | Required for | Notes |
| --- | --- | --- |
| `FIREBASE_APP_ID` | Firebase upload | Firebase Android App ID, for example `1:PROJECT_NUMBER:android:APP_ID`. |
| `GOOGLE_APPLICATION_CREDENTIALS` | Firebase CLI or Gradle upload when using Application Default Credentials | Absolute path to a local service account JSON file stored outside the repository. |
| `JAVA_HOME` | Local PowerShell Gradle builds when Java is not otherwise found | Use `C:\Program Files\Android\Android Studio\jbr` when Android Studio is installed there. |

Never commit:

- `google-services.json`
- service account JSON files
- `local.properties`
- Gradle wrapper JAR binaries

## Upload a debug build from Windows

From the repository root:

```powershell
$env:FIREBASE_APP_ID = "1:YOUR_PROJECT_NUMBER:android:YOUR_APP_ID"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\outside\repo\wavezero-firebase-app-distribution.json"
.\scripts\dev\android-firebase-upload-debug.ps1
```

The helper script validates required environment variables, checks that credentials are available, builds the debug APK, and runs the Gradle Firebase App Distribution upload task when it is available.

The generated APK appears at:

```text
apps\android\app\build\outputs\apk\debug\app-debug.apk
```

## Manual APK sharing fallback

If Firebase upload is unavailable, generate a debug APK only as a temporary fallback:

```powershell
.\scripts\dev\android-assemble-debug.ps1
```

Then install locally with:

```powershell
.\scripts\dev\android-install-debug.ps1
```

Avoid sending APKs manually as the normal process. Firebase App Distribution provides a better audit trail, tester notifications, and install links.

## GitHub Actions plan

Phase 0E adds stable Rust CI:

- `cargo fmt --all --check`
- `cargo test --workspace`
- `cargo check --manifest-path services/api/Cargo.toml`

Android and Flutter CI will be enabled after the local Android and Flutter build paths are verified in a way that does not require committing Gradle wrapper binary files or secrets. A future manual Android debug build workflow may upload the APK as an artifact once the CI Gradle invocation is known to be reliable.

Firebase deploy workflows are intentionally not added yet. They require GitHub Actions secrets for `FIREBASE_APP_ID` and credentials and should be manual-only or protected when introduced.
