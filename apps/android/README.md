# WaveZero Android App

Android is the first native playback target for WaveZero. The current app contains the Phase 0B Media3 playback proof and is also the native playback implementation used by the Phase 0D Flutter bridge. Phase 0E does not change playback behavior; it documents and scripts the development and tester distribution loop.

## Default daily loop: Android Studio Run

Use Android Studio Run for normal Android development and device testing:

1. Open `apps/android` in Android Studio.
2. Wait for Gradle sync.
3. Choose a physical device.
4. Press **Run** for the `app` configuration.

This is the default loop because Android Studio handles install, logs, debugger attachment, and device selection without needing to create or manually share APK files.

## Wireless Debugging

1. Enable **Developer options** on the Android device.
2. Enable **Wireless debugging**.
3. In Android Studio, use **Device Manager > Pair Devices Using Wi-Fi**.
4. Pair the device with the QR code or pairing code.
5. Select the paired wireless device and press **Run**.

Command-line check:

```powershell
adb devices
```

If `adb` is missing, install Android Studio or add the Android SDK `platform-tools` directory to `PATH`.

## Local Java setup on Windows

If local PowerShell builds cannot find Java, use Android Studio's bundled JBR:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

The Phase 0E helper scripts set this automatically when the JBR path exists and `JAVA_HOME` is not already set.

## Manual debug APK fallback

Manual APK generation is a fallback, not the default tester-sharing path.

From the repository root:

```powershell
.\scripts\dev\android-assemble-debug.ps1
```

The script changes to `apps/android`, uses `gradlew.bat` when present, falls back to `gradle`, runs `:app:assembleDebug`, and prints the APK path.

Generated APK:

```text
apps\android\app\build\outputs\apk\debug\app-debug.apk
```

Install on a connected device:

```powershell
.\scripts\dev\android-install-debug.ps1
```

## Firebase App Distribution tester sharing

Use Firebase App Distribution for internal tester builds instead of manually sending APK files.

Required environment variables:

```powershell
$env:FIREBASE_APP_ID = "1:YOUR_PROJECT_NUMBER:android:YOUR_APP_ID"
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\outside\repo\wavezero-firebase-app-distribution.json"
```

`FIREBASE_APP_ID` identifies the Firebase Android app. `GOOGLE_APPLICATION_CREDENTIALS` should point to a local service account JSON file outside the repository when the Firebase Gradle upload uses Application Default Credentials.

Do not commit:

- `apps/android/local.properties`
- `apps/android/app/google-services.json`
- service account JSON files
- Gradle wrapper JAR binaries

Upload from the repository root:

```powershell
.\scripts\dev\android-firebase-upload-debug.ps1
```

The Gradle `Debug` Firebase App Distribution configuration uploads an APK to the `internal-testers` group when `:app:appDistributionUploadDebug` is available.

## Gradle wrapper note

This repository intentionally does not require committing Gradle wrapper JAR binary files in Phase 0E. The helper scripts prefer `apps/android/gradlew.bat` if it exists locally and fall back to a system `gradle` command when it does not.

## Verify the Flutter bridge after Phase 0D

To verify that Flutter still commands Android Media3 correctly:

1. Install Flutter locally.
2. Run `scripts\dev\flutter-run-android.ps1` from the repository root.
3. Use the Flutter playback controls to load and play the test track.
4. Confirm audio plays through Android Media3.
5. Confirm metrics update for session ID, attempt ID, playback state, current position, timing fields, last event, track title, and track URL.

See `docs/DEVELOPMENT.md` and `docs/DISTRIBUTION.md` for the cross-project workflow.

## CI status

Phase 0E adds Rust CI only. Android and Flutter CI are deferred until the local build path is verified without secrets or committed Gradle wrapper binaries.
