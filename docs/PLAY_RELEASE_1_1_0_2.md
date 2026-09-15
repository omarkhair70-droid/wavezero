# WaveZero 1.1.0+2 — Google Play Internal Release

Date: 2026-09-15
Package: `com.omarkhair.wavezero`
Target track: Google Play **Internal testing**

## Release contents

- Daily-driver Library and Search scroll fixes.
- Device Music refresh-on-open behavior.
- Cleaner Home history and reduced repeated tracks.
- Smaller Home hero and tighter bottom navigation.
- `Your music | Web` entry in Search.
- Native Android WebView inside WaveZero.
- Supported audio downloads through Android DownloadManager.
- Downloads saved to public `Music/WaveZero` and followed by a Device Music rescan attempt.

## Version

- versionName: `1.1.0`
- versionCode: `2`

## Publishing path

`.github/workflows/play-internal-release.yml` builds a signed release AAB and uploads it to Google Play Internal testing on a release/version push to `main`, or by manual workflow dispatch.

The workflow expects these GitHub Actions secrets:

- `WAVEZERO_UPLOAD_KEYSTORE_BASE64`
- `WAVEZERO_UPLOAD_KEYSTORE_PASSWORD`
- `WAVEZERO_UPLOAD_KEY_PASSWORD`
- `WAVEZERO_PLAY_SERVICE_ACCOUNT_JSON`

The key alias remains `upload`, matching the existing release handoff. Secrets must never be committed to the repository or written into CI logs.

## Privacy / listing note

WaveZero still does not upload the user's Device Music library to the developer. The new Web surface is user-directed browsing: web pages and download hosts may receive ordinary web requests, cookies, user-agent and referer information as part of browser/download behavior. The public privacy policy and Play declarations should describe this Web surface before any production promotion.
