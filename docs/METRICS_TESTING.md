# WaveZero Metrics Testing

Phase 0G makes local playback metrics stable enough for repeatable Android testing.

## What each metric means

- `appScreenReadyMs`: time from Android activity creation to the Flutter/native playback screen marking itself ready.
- `attemptId`: increments every time the user taps Play or Retry.
- `tapToReadyMs`: time from Play tap to Media3 `STATE_READY`.
- `tapToIsPlayingMs`: time from Play tap to Media3 reporting `isPlaying=true`.
- `tapToPositionAdvanceMs`: time from Play tap until playback position first advances beyond the attempt start position.
- `tapToFirstAudioMs`: currently aligned to first position advance. This is the best available no-audio-tap proxy before adding audio sink instrumentation.
- `manifestLoadMs`: Media3 manifest load duration for the HLS manifest.
- `bufferCount`: total buffer entries during the current play attempt.
- `startupBufferMs`: buffering time before first position advance.
- `rebufferCount`: buffer entries after playback position has advanced.
- `rebufferMs`: buffering time after playback position has advanced.
- `totalBufferMs`: startup buffer plus rebuffer time for the current play attempt.
- `playbackError`: current playback error, or empty/null when healthy.

## Manual test matrix

Run each scenario three times and copy metrics after 10 seconds of playback.

### Wi-Fi cold start

1. Force-stop WaveZero.
2. Connect the phone to Wi-Fi.
3. Open the app.
4. Tap Load Track.
5. Tap Play.
6. Wait 10 seconds.
7. Copy metrics.

### 4G cold start

1. Force-stop WaveZero.
2. Disable Wi-Fi and use mobile data.
3. Open the app.
4. Tap Load Track.
5. Tap Play.
6. Wait 10 seconds.
7. Copy metrics.

### Pause/resume

1. Start playback.
2. Wait 10 seconds.
3. Pause.
4. Wait 3 seconds.
5. Play again.
6. Copy metrics after 10 seconds.

### Lock-screen controls

1. Start playback.
2. Lock the phone.
3. Pause from the notification or lock screen.
4. Resume from the notification or lock screen.
5. Unlock and copy metrics.

## Healthy baseline expectations

For a healthy run:

- `playbackError` should be empty/null.
- `attemptId` should match the current play attempt count.
- `tapToReadyMs`, `tapToIsPlayingMs`, and `tapToPositionAdvanceMs` should be non-null after playback starts.
- `currentPositionMs` should advance while playing.
- `startupBufferMs` may be greater than zero.
- `rebufferCount` and `rebufferMs` should stay low on stable Wi-Fi.
