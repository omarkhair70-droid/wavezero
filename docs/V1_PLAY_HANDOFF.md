# WaveZero V1 — Google Play RC Handoff

Policy and repository snapshot: 2026-08-27.

This handoff is for the first Android Google Play release only. It does not expand product scope.

## Final Android identity

- Application ID: `com.omarkhair.wavezero`
- Android namespace: `com.omarkhair.wavezero`
- App name: `WaveZero`
- Version name: `1.0.0`
- Version code: `1`
- Target SDK: 36
- Compile SDK: 36
- Category: Music & Audio

The shared native playback implementation remains under `com.wavezero.player.playback`. That is an internal Kotlin source package, not the shipping application identity.

## Launcher identity

**ICON ASSET REQUIRED**

No usable WaveZero logo, icon, PNG, SVG, JPEG, WebP, mipmap, or drawable brand asset exists in the repository at this snapshot. Do not ship a generic Android icon and do not invent a placeholder.

Provide:

- one master vector (SVG preferred) or at least 1024 x 1024 px transparent PNG containing the final WaveZero mark;
- a defined adaptive-icon background color or background artwork;
- critical foreground content that fits inside Android's centered 66 x 66 dp safe zone on a 108 x 108 dp adaptive-icon canvas;
- optional monochrome mark for themed icons;
- a separate 512 x 512 px, 32-bit PNG Play Store icon, sRGB, max 1024 KB.

Visual brief: calm Porcelain / soft-sculpture identity, milk-white and restrained pale-blue language, one simple recognizable WaveZero mark, no text inside the icon, no fake depth or tiny detail.

## Play Store listing

### Title

WaveZero

### Short description

A calm, local-first music player for your Android device.

### Full description

WaveZero is a calm, local-first music player built for Android.

Bring music already on your device into a focused listening experience designed around the music rather than the interface. Browse your device library, search locally, build a queue, and keep playback close with a clean Now Playing surface and Android media controls.

WaveZero V1 includes:

- Device Music import from the Android media library, only after you choose to grant access.
- Native Android playback with background, notification, and lock-screen controls.
- Queue controls with previous, next, shuffle, repeat, and sleep timer.
- Local search across available music and WaveZero state.
- Collections and likes stored on your device.
- Listening history stored on your device.
- Local downloads and offline playback when downloadable content is available.
- Storage controls for music saved by WaveZero.
- A quiet, light Porcelain interface designed for everyday listening.

WaveZero V1 does not require an account. It does not include ads, subscriptions, cloud sync, artist uploads, or a claim of a commercial music catalog.

Your Device Music stays on your device. WaveZero does not upload your personal audio library.

## Privacy Policy draft

# WaveZero Privacy Policy

Last updated: 27 August 2026

WaveZero is an Android music player published by Omar Khair. This Privacy Policy describes the data behavior of the WaveZero V1 Android application.

Privacy contact before publication: **[PUBLIC SUPPORT EMAIL OR CONTACT PAGE REQUIRED]**

### 1. Device Music access

WaveZero can access audio files and audio metadata in your Android media library only after you choose to grant the Android audio-library permission.

The app uses this access to display and play music on your device. Metadata used by the app can include information such as track title, artist, album, duration, media identifier, media content URI, file size, codec/format information, and album artwork references exposed by Android MediaStore.

WaveZero V1 does not upload your Device Music or its library contents to the developer.

### 2. Data stored locally

WaveZero stores product state on the device so the app can work across sessions. This can include:

- playback and queue state;
- user settings;
- collections and liked tracks;
- recent searches;
- listening history and saved playback position;
- download/cache metadata and audio files downloaded by WaveZero;
- local permission/request state.

This information is stored locally in app storage and is not used for advertising or cross-app tracking.

### 3. Data collection and sharing

The WaveZero V1 production application does not include:

- advertising SDKs;
- analytics or telemetry SDKs;
- user accounts;
- cloud sync;
- Device Music upload;
- contact, location, camera, microphone, or advertising-ID collection.

For the V1 production configuration described by this release handoff, the developer does not collect or share Google Play Data Safety user-data categories through the app.

If a later release adds analytics, accounts, a hosted catalog that collects user information, cloud sync, advertising, uploads, or other remote data handling, this Privacy Policy and the Google Play Data Safety declaration must be reviewed and updated before that release.

### 4. Network access

The Android application declares Internet access because WaveZero contains support for retrieving explicitly configured catalog/audio resources and downloading supported content. The V1 Play release is local-first and must not be submitted with an unreviewed production service or telemetry endpoint.

Release builds disable cleartext HTTP traffic. Any production network service added to a Play build must use secure transport and must be reflected in this policy and in Google Play Data Safety disclosures when applicable.

### 5. Retention and deletion

Device Music remains part of the user's Android media library and is not owned or copied to a developer account.

WaveZero-local settings, queue state, collections, recent searches, and listening history remain on the device until the user clears the relevant state, clears WaveZero app data, or uninstalls the app.

Audio files downloaded into WaveZero's app storage remain until the user removes them, clears downloads/app data, or uninstalls the app.

Because WaveZero V1 has no user account or cloud sync, the developer does not maintain a server-side user profile that requires an account-deletion request.

### 6. Security

WaveZero V1 keeps its product state in application-local storage, disables Android app-data backup for this release, and disables cleartext network traffic in the release manifest.

No software can guarantee absolute security. WaveZero limits the V1 data surface by avoiding accounts, analytics, advertising, and cloud upload.

### 7. Children

WaveZero V1 is a general-purpose music player and is not designed specifically for children. The final Google Play target-audience selections must match the audience the publisher actually intends to serve.

### 8. Changes

If WaveZero's data practices materially change, this policy and the corresponding Google Play disclosures will be updated before the changed behavior is distributed.

### 9. Contact

Before publication, replace the placeholder above with a public support email address or public contact page controlled by the publisher.

**Publication status:** Draft only. No Privacy Policy URL is claimed to be published yet.

## Google Play Data Safety answers

These answers apply to the exact local-first V1 binary described above. Re-audit if the final Play binary adds a production backend, analytics/telemetry, advertising, accounts, uploads, or another SDK.

- Does the app collect or share any of the required user data types? **No.**
- Is any user data shared with other companies or organizations? **No.**
- Data types collected: **None.**
- Data types shared: **None.**
- Advertising or marketing data use: **No.**
- Analytics data use: **No.**
- Personalization based on transmitted user data: **No.**
- Account creation: **No.**
- Account deletion mechanism: **Not applicable; V1 has no user account.**
- Device Music processing: **On-device only; not transmitted by WaveZero.**
- Local queue, collections, search history, listening history, settings, and cache metadata: **On-device only; not transmitted by WaveZero.**
- Data deletion available to the user: **Local history/search/download state can be cleared in app where exposed; all app-local data can also be removed by clearing app data or uninstalling WaveZero.**
- Data encrypted in transit: **No Play Data Safety user data is transmitted in this V1 configuration. Release cleartext traffic is disabled.**

Important: the form must be rechecked against the exact uploaded AAB and every included SDK immediately before submission.

## Foreground Service declaration — mediaPlayback

### Functionality description

WaveZero uses the `mediaPlayback` foreground-service type only for user-requested music playback. After the user starts a track, the foreground media service keeps the active MediaSession and playback controls available so music can continue while WaveZero is in the background or the device is locked. The service presents user-visible Android media controls for the active playback session.

### User impact if the task is deferred

If the media playback foreground service does not start promptly after the user requests playback, the requested music may not continue reliably when the app moves to the background, and the expected notification/lock-screen media controls may not become available at the correct time.

### User impact if the task is interrupted

If Android interrupts the foreground media playback service during an active user-requested session, playback may stop or lose its background continuity and the user-visible media controls may disappear. The user may need to return to WaveZero and resume playback.

### Why this work cannot be deferred

Continuous audio playback is the direct, user-initiated core function of the app. Deferring the work would break the active listening session rather than perform a background maintenance task.

## 30–60 second FGS demonstration-video script

Record on the final Samsung RC build. Keep the package/build visible where practical and do not edit the video to imply behavior the app does not have.

- **0–5 s:** Start on the Android launcher. Open WaveZero.
- **5–12 s:** Open Library / Device Music and select a real local track.
- **12–20 s:** Tap Play. Show Now Playing with the track audibly playing.
- **20–28 s:** Press Home so WaveZero goes to the background while playback continues.
- **28–38 s:** Pull down the Samsung notification shade. Show WaveZero's active media notification/session controls.
- **38–46 s:** Tap Pause, then Play from the Android media control and show that the same playback session responds.
- **46–54 s:** Lock the device, wake the lock screen, and show WaveZero media controls while the active session is present.
- **54–60 s:** Unlock and return to WaveZero, showing the same current track/session.

The demonstration should make it obvious that the foreground service begins because the user starts music and exists to maintain that user-visible playback session.

## Screenshot shot list

Capture from the final Samsung RC build with real, rights-safe local/device music and no developer UI.

1. **Home** — WaveZero Porcelain home with current/ready music state.
2. **Now Playing** — artwork, title/artist, transport controls, progress.
3. **Library / Device Music** — imported Android device library, no raw file paths.
4. **Queue** — several tracks with clear current/up-next context.
5. **Search** — useful local search results.
6. **Collections or Offline/Storage** — choose the cleaner real V1 state.

Capture portrait phone screenshots at the device's native resolution. Avoid debug banners, empty developer states, permission dialogs, copyrighted marketing artwork without rights, and mock features not present in V1.

## Feature graphic brief

Required Play asset: 1024 x 500 px JPEG or 24-bit PNG with no alpha.

Direction: WaveZero's light Porcelain world — milk-white field, soft pale-blue sculptural wave/audio form, spacious composition, restrained depth, and one clear focal rhythm. Use the WaveZero wordmark only if the final brand mark/wordmark is supplied. Do not fake a catalog, artist imagery, subscriptions, clouds, or headphones/product hardware. Keep critical content away from edges and avoid fine detail.

## Windows / PowerShell signing handoff

The upload key must remain outside the repository.

### 1. Create a private local folder

~~~powershell
$WaveZeroSecrets = Join-Path $env:USERPROFILE "WaveZero-Secrets"
New-Item -ItemType Directory -Force -Path $WaveZeroSecrets | Out-Null
~~~

Recommended key path:

~~~text
C:\Users\<WindowsUser>\WaveZero-Secrets\wavezero-upload-key.jks
~~~

### 2. Generate the upload key

Run this interactively so `keytool` asks for passwords itself. Do not place passwords in the command line, repository, shell history, or chat.

~~~powershell
keytool -genkeypair -v -keystore "$env:USERPROFILE\WaveZero-Secrets\wavezero-upload-key.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
~~~

Back up the JKS file and its credentials independently of the development machine.

### 3. Create local key.properties

Create:

~~~text
apps\flutter\wavezero_app\android\key.properties
~~~

Contents:

~~~properties
storePassword=<ENTER LOCALLY>
keyPassword=<ENTER LOCALLY>
keyAlias=upload
storeFile=C:/Users/<WindowsUser>/WaveZero-Secrets/wavezero-upload-key.jks
~~~

This file is Git-ignored.

### 4. Build the signed V1 AAB

~~~powershell
cd <repo>\apps\flutter\wavezero_app
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build appbundle --release --dart-define=WAVEZERO_APP_ENV=production --dart-define=WAVEZERO_CONTENT_MODE_LABEL="Device music"
~~~

Expected output:

~~~text
apps\flutter\wavezero_app\build\app\outputs\bundle\release\app-release.aab
~~~

### 5. Verify the AAB signature

~~~powershell
jarsigner -verify -verbose -certs .\build\app\outputs\bundle\release\app-release.aab
~~~

### NEVER commit or paste

- `android/key.properties`
- any `.jks` or `.keystore`
- upload-key passwords
- key aliases plus passwords as a combined secret record
- Play service-account JSON
- Google credentials
- signing certificates' private keys
- any generated secret copied into an issue, PR, chat, screenshot, or CI log

## Manual Play Console steps after the RC gate

1. Create the Play Console app as **WaveZero** with package ID `com.omarkhair.wavezero`.
2. Enroll in Google Play App Signing and use the locally held JKS only as the upload key.
3. Publish the Privacy Policy draft at a public, non-editable HTTPS page, replace the support-contact placeholder, and add the same policy link or policy text in the app before production review.
4. Upload the signed `1.0.0+1` AAB to Internal testing first.
5. Inspect App Bundle Explorer and the pre-launch report.
6. Complete App content: Data Safety, `mediaPlayback` foreground-service declaration, content rating, target audience, ads declaration, and app access.
7. Upload the FGS demonstration-video link.
8. Add Play Store icon, feature graphic, and final Samsung screenshots.
9. Review the Store listing copy above and publish only claims demonstrated by the V1 binary.
10. Run the Samsung physical-device smoke matrix against the RC/Play-internal build.
11. Promote only after no Play policy/bundle blocker and no physical-device release blocker remains.
