# WaveZero V1 Android Release Closure

Policy snapshot: 2026-08-27.

This is the release source of truth for WaveZero V1. V1 is intentionally Android-first and local/offline-first. Do not add new features to satisfy this checklist.

## Frozen V1 scope

Ship the working consumer product that exists today:

- Android Flutter consumer shell: Home, Search, Library, Now Playing, Queue, Downloads/Storage, Collections, Listening History, and Settings.
- Kotlin/AndroidX Media3 playback through the existing MethodChannel bridge.
- MediaSession notification/lock-screen controls.
- Android MediaStore Device Music import and playback.
- Queue/session persistence, shuffle, repeat, sleep timer, collections, history, and local settings.
- Local downloads/cache and offline playback where playable catalog content is available.
- Existing prepared-next/prebuffer and native playback hardening.

Explicitly deferred after V1:

- Cloud Vault provider integrations.
- Production cloud catalog/backend operations.
- Auth/accounts/cloud sync.
- Payments/subscriptions.
- DRM.
- iOS.
- Native DSP/effects beyond the current hidden/foundation state.
- Artist upload/dashboard systems.

## Release-gap classification

### Google Play submission blockers

These must be closed before production submission:

- [ ] Final package ID is approved before the first Play upload. The repository currently uses com.wavezero.flutter. Keep it only if it is the intended permanent identifier; do not casually rename it after Play creation.
- [x] Target Android 16 / API 36. Google Play requires new apps and updates to target API 36 starting 2026-08-31. The V1 release branch targets 36.
- [x] Version comes from Flutter's single source of truth. V1 is 1.0.0+1.
- [x] CI exercises the AAB release path. The Flutter workflow builds a release app bundle, not only an APK.
- [x] Repository supports local upload-key signing without committing secrets. android/key.properties, JKS, and keystore files are ignored.
- [ ] Generate and securely store the upload key, then configure android/key.properties locally.
- [ ] Build the signed release AAB and verify it before upload.
- [ ] Provide a public privacy-policy URL and an in-app privacy-policy entry before production review.
- [ ] Complete Data safety truthfully for the exact production binary and any production endpoint.
- [ ] Complete the foreground-service declaration for mediaPlayback, including the required Play Console explanation and demonstration video.
- [ ] Complete Content rating, Target audience, Ads, App access, and other App content declarations.
- [ ] Provide Play listing assets: 512x512 Play icon, 1024x500 feature graphic, phone screenshots, and final store copy.

### Real product release gates

These are not future feature work, but V1 should not go public until they are verified:

- [ ] Add/approve the real WaveZero launcher icon. The shipping Android manifest currently has no explicit branded launcher icon resource.
- [ ] Run the Samsung physical-device RC smoke matrix below on the same code/config intended for release.
- [ ] Confirm first launch and the local/offline experience are coherent when no production catalog URL is configured.
- [ ] Confirm no consumer surface exposes developer URLs, raw IDs, stack traces, local paths, or unfinished Cloud/DSP promises.
- [ ] Review the exported MediaSessionService boundary once, without redesigning playback. The service is intentionally exported for Media3; verify external/custom intents cannot create harmful user-visible behavior.
- [ ] Review Google Play's bundle report for native-library/16 KB page-size compatibility. WaveZero uses Flutter/native libraries; Play currently warns on incompatible bundles and blocks incompatible updates starting 2027-02-01.

### Not V1 blockers

Do not delay V1 for Cloud Vault, hosted production catalog, subscriptions, DRM, accounts/sync, iOS, new DSP/effects, artist uploads, a Rust FFI rewrite, or another UI redesign.

## Release signing setup

Keep the upload key outside the repository.

PowerShell example:

~~~powershell
keytool -genkey -v ^
~~~

For PowerShell, the simplest reliable form is one line:

~~~powershell
keytool -genkey -v -keystore "$env:USERPROFILE\wavezero-upload-key.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
~~~

Create apps/flutter/wavezero_app/android/key.properties locally:

~~~properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=C:/Users/<you>/wavezero-upload-key.jks
~~~

Never commit the upload key or key.properties. Back up the upload key and passwords somewhere independent of the development machine.

Use Google Play App Signing for the production app-signing key. The locally held key is the upload key.

## Release-candidate build

For the narrow local/offline-first V1, do not invent a production catalog dependency. Omit WAVEZERO_API_BASE_URL unless a real HTTPS production endpoint is intentionally being shipped.

From PowerShell:

~~~powershell
cd apps/flutter/wavezero_app
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build appbundle --release --dart-define=WAVEZERO_APP_ENV=production --dart-define=WAVEZERO_CONTENT_MODE_LABEL="Device music"
~~~

Expected artifact:

~~~text
apps/flutter/wavezero_app/build/app/outputs/bundle/release/app-release.aab
~~~

Verify the bundle is signed with the upload key:

~~~powershell
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
~~~

Record the exact Git commit SHA used to build the AAB. Do not rebuild from an uncommitted working tree.

## Samsung physical-device RC smoke matrix

Use a real Samsung phone on the Android version intended for first release testing. Test a fresh install first, then a warm/restart path.

### Install and first launch

- [ ] Uninstall any old WaveZero build or clear app data.
- [ ] Install the release candidate derived from the V1 branch/AAB code.
- [ ] Launch from the launcher and confirm the real WaveZero name/icon.
- [ ] Confirm there is no crash, blank-screen loop, debug banner, developer panel, raw URL, or stack trace.
- [ ] Confirm first launch does not request notification permission just for media playback.
- [ ] Confirm Home, Search, and Library are reachable and visually stable.
- [ ] Confirm unavailable hosted catalog state does not block Device Music or local product navigation.

### Device Music permission and import

- [ ] Open Library and start Device Music import.
- [ ] Confirm Android audio-library permission is requested only at that action.
- [ ] Deny once; confirm WaveZero stays usable and explains the state without crashing.
- [ ] Grant the permission and import again.
- [ ] Confirm real songs from Samsung MediaStore appear with usable title/artist metadata.
- [ ] Confirm no raw filesystem path is shown to the consumer.
- [ ] Play at least MP3/M4A content; if FLAC exists on the device, play one FLAC track too.

### Playback and system integration

- [ ] Start a track and open Now Playing.
- [ ] Play, pause, seek forward/back, and resume.
- [ ] Lock the phone; confirm lock-screen/media controls identify WaveZero and the current track.
- [ ] From the media notification/system media panel: Pause, Play, Next, and Previous.
- [ ] While paused, press Next/Previous from media controls and confirm playback stays paused.
- [ ] During a buffering/start transition, rapidly tap Play/Pause and confirm the final intent wins.
- [ ] Background WaveZero for at least one minute; playback and controls remain healthy.
- [ ] Turn the screen off and back on; playback state remains coherent.
- [ ] Disconnect wired/Bluetooth audio during playback where practical; confirm playback does not continue unexpectedly through the speaker after an audio-route/noisy event.
- [ ] Receive or simulate an audio-focus interruption if practical; confirm recovery is sane.

### Queue, transition, and persistence

- [ ] Add several tracks to Queue.
- [ ] Exercise Next/Previous repeatedly, including quick taps; no double advance or wrong-track UI.
- [ ] Let a track auto-advance naturally at least once.
- [ ] Verify selected/current/up-next state remains coherent after prepared handoff/fallback.
- [ ] Enable shuffle, move through the queue, then disable it.
- [ ] Exercise repeat modes.
- [ ] Set and cancel the sleep timer.
- [ ] Background and foreground the app while a queue is active.
- [ ] Force-stop/kill the UI process after creating a queue, relaunch, and confirm persisted queue/session state is sane.

### Collections, history, search, downloads

- [ ] Like/add a track to a collection, rename a collection, and remove an item; restart and confirm persistence.
- [ ] Play multiple tracks and verify Listening History order/count/position remains coherent after restart.
- [ ] Search local state and confirm results are local/user-facing, not developer diagnostics.
- [ ] If the RC is configured with a rights-safe HTTPS validation catalog, download a test track, play it offline, delete it during/after download, and verify it stays deleted.
- [ ] If downloads are active, start a download and use Clear Downloads; confirm files/metadata do not reappear.
- [ ] With network disabled, confirm Device Music and already-downloaded tracks remain usable.

### Lifecycle and regression stress

- [ ] Rotate/change configuration if the device allows it; no playback-session reset.
- [ ] Open/close Now Playing repeatedly while audio runs.
- [ ] Dismiss media controls using WaveZero's stop/dismiss path, then return to the live app; no dead ExoPlayer/session.
- [ ] Start playback again after dismissal.
- [ ] Pause for several minutes, then resume; no runaway position polling symptom or stale UI.
- [ ] Finish a track, replay it, and confirm end-state recovery.
- [ ] Trigger one intentional unavailable/bad source only in a validation build; Retry must recover without corrupting the queue.
- [ ] Reboot the phone only if part of the chosen release test matrix; WaveZero must not surface a ghost DemoTrack notification on boot/process recreation.

### Pass condition

The RC fails if there is a crash/ANR, broken first-launch permission flow, playback that cannot recover, notification/session desynchronization, wrong queue transitions, lost local persistence, consumer-facing developer data, or a release-only configuration failure.

Cosmetic differences that do not break the approved Porcelain consumer product should be logged for a later patch rather than reopening broad redesign work.

## Final AAB/version/release checklist

- [ ] V1 commit is on the intended release branch and CI is green.
- [ ] pubspec.yaml version is 1.0.0+1 for the first upload; every future Play upload increments the build number/versionCode.
- [ ] targetSdk is 36 and compileSdk is 36.
- [ ] Final package ID is intentionally approved.
- [ ] Release manifest keeps cleartext disabled.
- [ ] Debug/profile cleartext overrides are not present in the release manifest.
- [ ] allowBackup=false remains intentional for device-local state.
- [ ] No secrets, keystores, copyrighted test songs, local catalogs, or service-account files are tracked.
- [ ] Upload-key signing is active locally.
- [ ] flutter analyze passes.
- [ ] flutter test passes.
- [ ] Rust CI remains green; no Rust runtime rewrite is required for V1.
- [ ] flutter build appbundle --release succeeds with production defines.
- [ ] jarsigner -verify succeeds on the generated AAB.
- [ ] Samsung RC smoke matrix passes.
- [ ] Upload AAB to an internal Play track first and inspect App Bundle Explorer/pre-launch report.
- [ ] Resolve any Play-reported manifest, signing, native-library, 16 KB, permission, or policy blocker before promoting.
- [ ] Save the final AAB, commit SHA, version, upload timestamp, and Play release notes together as the release record.

## Google Play listing package

Prepare these after the binary is stable, but before production submission.

### Store identity

- App name: WaveZero
- Category: Music & Audio
- Short description draft: A calm, local-first music player for your Android device.
- Full-description positioning: Lead with Device Music, local playback, queue, collections/history, offline behavior, and the calm WaveZero interface. Do not advertise Cloud Vault, subscriptions, cloud sync, commercial catalog breadth, DRM, iOS, or DSP features that V1 does not ship.

Required assets:

- 512 x 512 Play Store icon (PNG).
- 1024 x 500 feature graphic.
- At least the required phone screenshots; capture real V1 screens from the Samsung RC rather than mockups.
- Final launcher icon inside the Android app.

Recommended screenshot set:

1. Home.
2. Now Playing.
3. Library with Device Music.
4. Queue.
5. Search.
6. Collections or offline/storage.

### App content / policy answers to prepare

- Privacy policy public HTTPS URL.
- In-app route/link to the same privacy policy.
- Data safety answers based on the exact binary and backend behavior.
- Foreground service declaration: mediaPlayback; explain that music playback continues while the app is backgrounded/locked and that interruption would stop an active user-requested playback session.
- A short demonstration video showing the user starting music in WaveZero, backgrounding/locking the phone, and the active media playback controls.
- Content rating questionnaire.
- Target audience.
- Ads declaration.
- App access: no account/login required for V1.
- Contact email and support website/page.
- Any permission declarations Play Console asks for based on the final manifest.

### Data safety caution

Do not answer "no data collected" merely because the product is local-first. Before submitting, verify the exact production build has no analytics/ads SDK, no production API that receives user/device data beyond what the store disclosure permits, and no unexpected telemetry. Android Device Music read locally on the device is not automatically equivalent to transmitting that music off-device.

## Release decision

WaveZero V1 is release-candidate ready when the targeted release-engineering PR is merged, CI is green, the final package ID/icon/privacy URL are supplied, a signed AAB is built, Play Console declarations/assets are complete, and the Samsung smoke matrix passes.

Optional roadmap work must not reopen V1.
