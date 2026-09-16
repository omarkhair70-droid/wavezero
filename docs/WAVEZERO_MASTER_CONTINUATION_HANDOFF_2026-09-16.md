# WaveZero — Master Continuation Handoff — 2026-09-16

> Read this first in a new chat before changing code.
>
> Repo: `omarkhair70-droid/wavezero`
> Default branch: `main`
> Code baseline immediately before this handoff file: `3d4ed0177f95cd182c402bddb1a53677bcc7e34f`
> There are **no open PRs** at handoff time.

## 1. Product direction

WaveZero is being built as a local-first daily-driver music app: **the place where any music/audio on the phone naturally ends up**.

Core direction:

**Import everything → Organize everything → Understand the listener → Sound excellent → Integrate everywhere.**

Work incrementally. Do not start a giant rewrite or create WaveZero V4/V5. Reuse the existing Flutter consumer UI, Android Media3 playback path, Device Music model, DownloadManager bridge, collections/history services, and native sound-engine ownership.

Every feature lane follows the same gate:

1. branch from latest `main`
2. focused implementation
3. focused tests/contracts
4. Flutter Analyze
5. full Flutter tests
6. Android release AAB
7. merge only when all are green
8. physical Alpha/daily-driver testing for audio behavior

Never auto-publish Production. Play release workflow is manual-only.

---

## 2. Current code state

### Main architecture

- Flutter owns consumer UI and product orchestration.
- Android Media3 / ExoPlayer owns native playback, audio session, MediaSession, notification/background lifecycle.
- Rust `wavezero-core` remains the deterministic decision-model layer where already used.
- Do not add a second playback engine.
- Flutter Android host shares the common native playback source directory from `apps/android/.../playback`.

Important native playback files:

- `apps/android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt`
- `apps/android/app/src/main/java/com/wavezero/player/playback/NativeDspController.kt`
- `apps/android/app/src/main/java/com/wavezero/player/playback/ReplayGainMetadata.kt`
- `apps/android/app/src/main/java/com/wavezero/player/playback/WaveZeroChannelAudioProcessor.kt`

Important Flutter host/settings files:

- `apps/flutter/wavezero_app/android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt`
- `apps/flutter/wavezero_app/lib/audio/audio_effects.dart`
- `apps/flutter/wavezero_app/lib/features/playback/custom_equalizer_page.dart`
- `apps/flutter/wavezero_app/lib/features/settings/settings_page.dart`

---

## 3. Recent completed work — do not rebuild it

### Collections / portability

PR #209 completed Collections 2.0 fundamentals:

- multi-select / select all
- batch Queue / Remove / Add to Collection
- M3U import/export
- playlist resolution by stable track ID first, then URI / filename / unique metadata fallback

### PR #210 — Real native EQ

Merged before the later sound-engine slices.

Implemented real Android `Equalizer` attached to WaveZero's own Media3 audio session. Existing presets are no longer UI-only placeholders. `Off / Original` is a true native EQ-off path. EQ state reattaches when the primary audio session changes / prepared-next player becomes primary.

### PR #211 — Custom 10-band EQ

Merge baseline after #211: `be0da86f1d2984014f6dc4e9ed5f85671e25a715`

Implemented:

- Custom EQ profile persisted as `custom`
- control points: 31 / 62 / 125 / 250 / 500 / 1k / 2k / 4k / 8k / 16k Hz
- UI range ±6 dB
- automatic negative preamp headroom equal to strongest positive boost
- native curve persistence
- logarithmic interpolation from ten user points to the actual EQ bands exposed by the Android device
- presets continue using the same native DSP owner

### PR #212 — ReplayGain loudness normalization

Merged at: `fc0c1affd172c72f993148dfb909bbefedf0808c`

Implemented:

- parses standard `REPLAYGAIN_TRACK_GAIN`, `REPLAYGAIN_ALBUM_GAIN`, `REPLAYGAIN_TRACK_PEAK`, `REPLAYGAIN_ALBUM_PEAK`
- reads Vorbis comments and ID3 TXXX metadata where exposed through Media3
- track gain preferred, album gain fallback
- gain clamped to -12..+6 dB
- boost limited by declared peak metadata
- negative ReplayGain uses ExoPlayer attenuation
- positive ReplayGain uses session-scoped Android `LoudnessEnhancer` when available
- EQ preamp + ReplayGain are owned by the same `NativeDspController` so gain owners do not fight each other
- EQ headroom is applied only when the native EQ actually attached successfully
- old ReplayGain is cleared during track/retry transitions
- metadata refresh comes from selected Media3 track metadata / dynamic metadata
- normalization state survives MediaSession/background creation through native preferences
- Playback settings has an opt-in Loudness normalization switch
- untagged files are **not analyzed or guessed**; their normalization level remains unchanged

Important CI history for #212: first run had **265 passed / 2 failed** because two source-contract tests still expected the old pre-ReplayGain implementation strings. The implementation itself had intentionally centralized gain staging. Tests were corrected to assert the new `profilePreampGainDb` / centralized gain model. Final run passed Analyze + full tests + Release AAB + artifact upload, then #212 was merged. Do **not** revert the implementation to satisfy the old string expectations.

### PR #213 — Live balance + mono output

Merged at: `3d4ed0177f95cd182c402bddb1a53677bcc7e34f`

Implemented:

- `WaveZeroChannelAudioProcessor` for supported PCM16 stereo playback
- one audio processor instance per ExoPlayer / AudioSink
- thread-safe shared balance/mono state between primary and prebuffer players
- both WaveZero ExoPlayers routed through custom Media3 `DefaultRenderersFactory` / `DefaultAudioSink` processor chain
- balance: -1 full-left → 0 center → +1 full-right
- balance is attenuation-only; it never boosts a channel
- mono averages L/R first, then balance is applied
- PCM16 output clamps safely
- neutral path has a fast copy path
- unsupported non-stereo / non-PCM16 paths bypass processing instead of pretending it is active
- balance and mono persist in native `wavezero_sound_engine` preferences
- MethodChannel controls/status: `setChannelBalance`, `setMonoOutput`, `channelAudioStatus`
- Playback settings exposes live debounced balance slider + Mono output switch
- channel diagnostics included in native metrics

This slice deliberately did **not** add gapless or crossfade.

---

## 4. Immediate next task

### NEXT: Sound Engine — Gapless hardening + Crossfade

Start from latest `main`; do not continue an old sound-engine branch. At handoff time there is no open PR.

Recommended branch:

`feat/sound-engine-gapless-crossfade-20260916`

### Before writing code

Read current versions of:

- `AudioPlayerManager.kt`
- `NativeDspController.kt`
- `WaveZeroChannelAudioProcessor.kt`
- existing smart queue / prebuffer tests
- playback settings
- `docs/WAVEZERO_PRODUCT_EVOLUTION_2026-09-15.md`

The player already has a **primary player + prepared/prebuffer next player** concept. Reuse that architecture. Do not introduce a third independent playback engine or a second queue state.

### Gapless target

First prove/harden the existing prepared-next handoff so compatible local tracks can transition with the smallest possible discontinuity.

Acceptance direction:

- preserve the existing queue identity and current-track authority
- keep EQ, Custom EQ, ReplayGain, balance and mono valid across primary-player handoff
- avoid resetting gain/channel effects to defaults during handoff
- no duplicate track-start events/history increments
- no audible fake fade when gapless mode is intended
- if a source/decoder path cannot be gapless, degrade truthfully rather than reporting guaranteed gapless
- add metrics/diagnostics sufficient for Alpha verification

### Crossfade target

Implement only after the gapless handoff is stable.

Recommended first scope:

- Off by default
- explicit durations, e.g. Off / 2s / 4s / 6s (exact choices can be adjusted after inspecting existing settings patterns)
- use the existing prepared-next player
- coordinated outgoing/incoming volume envelopes
- **do not overwrite the sound engine's EQ/ReplayGain headroom model**; crossfade must multiply/factor the final player gain rather than become another competing absolute volume owner
- manual skip behavior should be decided explicitly and tested separately from natural end-of-track crossfade
- avoid crossfading spoken/very-short tracks only if there is a clear deterministic rule; do not add hidden heuristic complexity in the first slice
- physical headphones/device QA required before calling crossfade finished

### Important design constraint

There are now several things that affect amplitude:

- EQ preamp/headroom
- ReplayGain attenuation/boost
- crossfade envelope (future)

Keep one coherent gain composition model. Do **not** scatter independent `player.volume = ...` assignments around unrelated callbacks.

---

## 5. Sound Engine after gapless/crossfade

Once the above is green and physically tested, the Real Sound Engine lane is effectively at its first complete daily-driver milestone:

- real native EQ ✅
- presets ✅
- Custom 10-band EQ ✅
- ReplayGain / tagged loudness normalization ✅
- balance ✅
- mono ✅
- gapless hardening ⏭
- crossfade ⏭

Do not claim ReplayGain scanning for untagged music; it does not exist yet. A later separate lane can consider local loudness analysis if there is a good battery/performance-safe design.

---

## 6. Product roadmap after Sound Engine

After gapless/crossfade, continue roughly in this order unless real daily-driver testing exposes higher-priority friction:

1. **Now Playing / playback integration hardening**
   - Bluetooth/headset behavior
   - lock screen / notification QA
   - session restore / transition polish

2. **Smart Playlists / “WaveZero understands you”**
   - On Repeat
   - Back to This
   - Forgotten Favorites
   - Recently Added
   - meaningful unfinished/resume shelves
   - later user-defined smart rules

3. **Android integration**
   - home-screen widget
   - Android Auto
   - Media Browser
   - stronger external-control QA

4. **Backup & Transfer**
   - settings
   - collections/playlists
   - likes/history
   - local metadata overrides
   - lyrics
   - optional media transfer later

5. **Cloud sources later**
   - user-owned Drive / Dropbox / OneDrive / Nextcloud if APIs and product boundaries remain sensible
   - local-first cache; do not turn WaveZero into an unauthorized streaming/ripping product

6. **Daily-driver reliability**
   - 5k–20k song libraries
   - corrupted files
   - Arabic/English metadata/search
   - low-memory behavior
   - background playback / battery
   - OEM Android quirks
   - migrations / startup / crash hardening

---

## 7. Other already-completed product areas

Do not accidentally rebuild these from scratch:

- Music Inbox / universal audio share
- multi-file audio sharing
- duplicate-safe modern MediaStore imports
- direct audio URL DownloadManager path
- direct-download progress / speed / ETA / retry
- Web 2.0 history/bookmarks/share/open-external
- Local Video → Audio (local file, audio extraction into WaveZero import flow)
- Device Music local Fix Info metadata overrides
- Artists / Albums library grouping
- Fresh on your device / recently-added behavior
- local Lyrics + `.lrc` sync/edit/remove
- Collections reorder + bulk operations + M3U import/export
- Now Playing drag-down-from-content interaction and newer generated artwork fallback

---

## 8. Known technical debt / truth to preserve

- Music Inbox ledger still has a theoretical cross-runtime race because native and Flutter can mutate the JSON ledger independently.
- Pre-Android-Q import path remains app-specific storage rather than modern public MediaStore behavior.
- Direct audio URL recognition is extension/MIME-style and does not HEAD-probe opaque generic URLs.
- Repeating the same direct audio URL can still enqueue multiple DownloadManager tasks; ledger identity improvements do not necessarily prevent duplicate enqueue.
- Web download was reported by the user as feeling somewhat slow on a real device. Download UI now exposes bytes/speed/ETA, but no claim has been made that raw network throughput was fixed. Measure first; do not rewrite DownloadManager based on guesswork.
- Fix Info changes WaveZero's local presentation metadata; it does not rewrite embedded tags in the source audio file.
- ReplayGain normalization only acts on usable ReplayGain metadata. Untagged music remains unchanged.
- Balance/mono only process supported stereo PCM16 paths and must report/bypass unsupported formats truthfully.
- Google Play build must not add YouTube-to-MP3 or protected-stream ripping. User-directed local media, direct downloadable audio links, normal browser use, and local video→audio are the intended boundary.

---

## 9. Release discipline

Current Play automation is manual-only.

- Alpha can be published when explicitly requested after the feature set is stable.
- Production must remain a separate explicit action; never auto-publish it.
- Existing release secrets are already configured in GitHub; never ask the user to paste keystore/service-account secrets into chat.

---

## 10. New-chat execution prompt

Use this as the first instruction after reading this file:

> Continue WaveZero from `docs/WAVEZERO_MASTER_CONTINUATION_HANDOFF_2026-09-16.md`. First verify current `main` and that there is no newer active PR/branch changing playback. Then continue the next unfinished Sound Engine slice: gapless hardening first, then crossfade, reusing the existing primary/prebuffer Media3 architecture and the unified native gain/effects ownership. Do not rebuild completed EQ, ReplayGain, balance, mono, Collections, Lyrics, Web, Inbox, or Video→Audio work. Use a fresh feature branch, add focused tests, run Analyze + full tests + Android release AAB, and merge only if everything is green. Do not publish Production.

---

## 11. Current handoff checkpoint

At the moment this document was created:

- latest code baseline: `3d4ed0177f95cd182c402bddb1a53677bcc7e34f`
- latest completed feature: PR #213 — live balance and mono output
- PR #212 ReplayGain is merged and green after test-contract correction
- no open PRs
- next intended implementation: **gapless hardening → crossfade**
