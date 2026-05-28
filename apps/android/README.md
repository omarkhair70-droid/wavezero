# WaveZero Android App

Android is the first client target for WaveZero. The current app contains the
Phase 0B Media3 ExoPlayer playback proof and should be shared with testers via
Firebase App Distribution rather than manually sending APK files.

This PR intentionally does not add Gradle Wrapper files because the wrapper JAR is
a binary artifact. If `gradlew.bat` is not present in your checkout, generate or
install the Gradle Wrapper locally before running the Windows commands below, and
do not commit the generated wrapper files as part of this text-only Firebase App
Distribution setup.

## Prerequisites

- Android Studio or the Android SDK installed.
- A physical Android device with USB debugging enabled for device testing.
- The Firebase Android app registered with package name `com.wavezero.player`.
- A Firebase App Distribution tester group with alias `internal-testers`.
- No Google Play Internal Testing setup is required for this phase.

## Required local files and secrets

Do **not** commit Firebase credentials or local machine configuration.

Keep these files local only:

- `apps/android/local.properties`
- `apps/android/app/google-services.json`, if you download one for local Firebase tooling
- Any service account JSON key used for Firebase App Distribution uploads

The Gradle configuration reads the Firebase App ID from either the
`FIREBASE_APP_ID` environment variable or a local Gradle property named
`firebaseAppId`. Prefer the environment variable so the value does not end up in
source control.

For upload credentials, use Application Default Credentials by setting
`GOOGLE_APPLICATION_CREDENTIALS` to the local service account JSON path. The
service account should have the Firebase App Distribution Admin role. Never copy
that JSON file into the repository.

## Build a debug APK on Windows

From PowerShell:

```powershell
cd C:\Users\dell\Desktop\wavezero\apps\android
.\gradlew.bat :app:assembleDebug
.\gradlew.bat :app:testDebugUnitTest
```

The debug APK is written to:

```text
apps\android\app\build\outputs\apk\debug\app-debug.apk
```

## Run on a physical Android device

1. Enable Developer Options and USB debugging on the Android device.
2. Connect the device over USB.
3. Confirm the device is visible:

   ```powershell
   adb devices
   ```

4. Build and install the debug APK:

   ```powershell
   cd C:\Users\dell\Desktop\wavezero\apps\android
   .\gradlew.bat :app:assembleDebug
   adb install -r .\app\build\outputs\apk\debug\app-debug.apk
   ```

You can also open `apps/android` in Android Studio and use **Run** with the
connected device selected.

## Distribute to Firebase App Distribution

Manual APK sharing is no longer the default workflow. Upload internal tester
builds through Firebase App Distribution so testers receive organized release
notifications and install links.

### One-time local setup

1. In Firebase Console, register the Android app with package name
   `com.wavezero.player`.
2. Copy the app's Firebase App ID from Firebase project settings.
3. Create the App Distribution tester group alias:

   ```text
   internal-testers
   ```

4. Create or obtain a service account key with the Firebase App Distribution
   Admin role, store it outside the repository, and set local environment
   variables in PowerShell:

   ```powershell
   $env:FIREBASE_APP_ID = "1:YOUR_PROJECT_NUMBER:android:YOUR_APP_ID"
   $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\dell\secrets\wavezero-firebase-app-distribution.json"
   ```

### Upload a debug tester build

From PowerShell:

```powershell
cd C:\Users\dell\Desktop\wavezero\apps\android
.\gradlew.bat :app:assembleDebug
.\gradlew.bat :app:testDebugUnitTest
.\gradlew.bat :app:appDistributionUploadDebug
```

The `Debug` Firebase App Distribution configuration uploads an APK and targets
the `internal-testers` group. After the upload finishes, Gradle prints Firebase
release links, including the tester install link and Firebase Console link.

## Where testers receive and install builds

Testers in the `internal-testers` group receive Firebase App Distribution email
invitations or new-build notifications. They accept the invitation with their
Google account, install the Firebase App Tester app if prompted, and install the
WaveZero build from the tester experience.

## Future CI TODO

GitHub Actions should later build the Android debug/internal tester APK and
upload it to Firebase App Distribution automatically on merges to `main`. Do not
add CI until the Firebase App ID and service account credentials are stored as
GitHub Actions secrets and the workflow can upload without committing secret
files.
