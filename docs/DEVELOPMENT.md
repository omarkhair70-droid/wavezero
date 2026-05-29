# WaveZero Development Guide

Phase 0E keeps the app feature set unchanged and focuses on the daily developer loop. The default path is to run the app directly from Android Studio or Flutter tooling, then use Firebase App Distribution only when a build needs to be shared with testers.

## Recommended daily Android loop

Use **Android Studio Run** for normal Android development:

1. Open Android Studio.
2. Choose **File > Open** and select `apps/android`.
3. Let Gradle sync finish.
4. Select a connected physical Android device.
5. Press **Run** for the `app` configuration.

This is preferred over manually building and sending APKs because it keeps install, logcat, and debugger workflows in one place.

## Wireless Debugging setup

Wireless Debugging is useful when the device and development machine are on the same trusted network.

1. On the Android device, enable **Developer options**.
2. Enable **Wireless debugging**.
3. In Android Studio, open **Device Manager > Pair Devices Using Wi-Fi**.
4. Pair using the QR code or pairing code shown by the device.
5. After pairing, choose the wireless device in Android Studio and press **Run**.

PowerShell verification commands:

```powershell
adb devices
adb connect <device-ip-and-port>
adb devices
```

If `adb` is not found, install Android Studio or add the Android SDK `platform-tools` directory to `PATH`.

## Java environment on Windows

Android Studio includes a Java runtime that works for the local Gradle build. If a PowerShell build cannot find Java, set `JAVA_HOME` to Android Studio's bundled JBR:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

The helper scripts set this automatically when that path exists and `JAVA_HOME` is not already set.

## Manual debug APK fallback

Manual APK generation is only a fallback for debugging or temporary local install. Prefer Android Studio Run for development and Firebase App Distribution for tester sharing.

From the repository root:

```powershell
.\scripts\dev\android-assemble-debug.ps1
```

The generated native Android APK appears at:

```text
apps\android\app\build\outputs\apk\debug\app-debug.apk
```

Install the fallback APK on a connected device:

```powershell
.\scripts\dev\android-install-debug.ps1
```

## Flutter Android loop after Flutter SDK install

After installing Flutter and Android Studio support, run the Flutter host from PowerShell:

```powershell
.\scripts\dev\flutter-run-android.ps1
```

The script runs `flutter pub get` in `apps/flutter/wavezero_app` and then runs `flutter run`. You can also run the commands manually:

```powershell
cd apps\flutter\wavezero_app
flutter pub get
flutter run
```

## Verify the Phase 0D Flutter bridge

The Phase 0D bridge is healthy when the Flutter app can command Android Media3 through the `wavezero/playback` MethodChannel.

1. Start the Flutter app on an Android device with `flutter run` or Android Studio.
2. Use the playback controls to load and play the test track.
3. Confirm audio plays through the native Android Media3 adapter.
4. Confirm the metrics panel updates fields such as session ID, attempt ID, playback state, current position, `tapToReadyMs`, `tapToIsPlayingMs`, `tapToPositionAdvanceMs`, last event, track title, and track URL.
5. If the Android channel is missing, the Flutter UI should remain open and show a readable playback error instead of crashing.

## Local environment check

Run this before sharing a build or debugging a local setup:

```powershell
.\scripts\dev\check-local-env.ps1
```

It prints the current Git branch and checks Java, `adb`, Flutter, `FIREBASE_APP_ID`, and expected project directories.

## CI status

Phase 0E adds stable Rust CI only. Android and Flutter CI are intentionally documented as future work until the local Android and Flutter build paths are verified without committing Gradle wrapper binaries or secrets.
