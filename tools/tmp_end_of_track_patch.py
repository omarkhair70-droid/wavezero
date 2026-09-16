from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


def sub_once(text: str, pattern: str, repl: str, label: str) -> str:
    updated, count = re.subn(pattern, repl, text, count=1, flags=re.DOTALL)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return updated


app_path = Path("apps/flutter/wavezero_app/lib/app/wavezero_app.dart")
app = app_path.read_text()

app = replace_once(
    app,
    "import '../features/queue/queue_panel.dart';\n",
    "import '../features/queue/queue_panel.dart';\nimport '../features/queue/playback_context.dart';\n",
    "queue playback-context import",
)

helper_marker = "  Future<void> _loadDeviceMusicTrack(\n"
helper = """  void _adoptPlaybackContextForTrackId(String trackId) {
    if (!mounted ||
        trackId.isEmpty ||
        _queue.any((track) => track.trackId == trackId)) {
      return;
    }

    final context = wzPlaybackContextForTrack(
      preferredTracks: _filteredCatalog,
      fallbackTracks: _resolvableLibraryTracks,
      currentTrackId: trackId,
      maxTracks: _initialVisibleTrackCount,
    );
    if (context.isEmpty) return;

    setState(() {
      _queue = context;
      _queueCurrentTrackId = trackId;
      _queueStatus = 'Playing from your music.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
  }

"""
app = replace_once(
    app,
    helper_marker,
    helper + helper_marker,
    "playback-context helper insertion",
)

app = sub_once(
    app,
    r"(  Future<void> _loadDeviceMusicTrack\(.*?return _runOperation\(operation, \(\) async \{\n)(\s*)await _clearNativeNextPrebuffer\(\);",
    r"\1\2_adoptPlaybackContextForTrackId(track.trackId);\n\2await _clearNativeNextPrebuffer();",
    "device-music playback context",
)

app = replace_once(
    app,
    "    if (id == null) return Future<void>.value();\n    final deviceTrack = _findDeviceTrack(id);\n",
    "    if (id == null) return Future<void>.value();\n    _adoptPlaybackContextForTrackId(id);\n    final deviceTrack = _findDeviceTrack(id);\n",
    "catalog playback context",
)

app = sub_once(
    app,
    r"(  Future<void> _playCloudVaultTrack\(\n\s*CloudVaultTrack track, \{\n\s*bool autoPlay = true,\n\s*\}\) async \{\n)(\s*)if \(!track\.isResolvable\) \{",
    r"\1\2_adoptPlaybackContextForTrackId(track.trackId);\n\2if (!track.isResolvable) {",
    "cloud playback context",
)

app = replace_once(
    app,
    "            onSelectTrack: (track) => _loadCatalogTrack(trackId: track.trackId),\n",
    """            onSelectTrack: (track) => _loadCatalogTrack(
              trackId: track.trackId,
              autoPlay: true,
            ),
""",
    "library tap autoplay",
)

app = replace_once(
    app,
    "            onPlayTrack: (track) =>\n                _playQueueTrack(track, autoStart: _metrics.isPlaying),\n",
    "            onPlayTrack: (track) =>\n                _playQueueTrack(track, autoStart: true),\n",
    "queue-row tap autoplay",
)

app_path.write_text(app)

metrics_path = Path(
    "apps/android/app/src/main/java/com/wavezero/player/playback/PlaybackMetrics.kt"
)
metrics = metrics_path.read_text()
ended_method = """    fun markEnded(positionMs: Long): PlaybackMetrics {
        nativeHandoffStartedAtMs = null
        return update("playback_ended") {
            copy(isPlaying = false, currentPositionMs = positionMs.coerceAtLeast(0))
        }
    }

"""
metrics = replace_once(
    metrics,
    "    fun markSeekStarted(targetPositionMs: Long): PlaybackMetrics {\n",
    ended_method + "    fun markSeekStarted(targetPositionMs: Long): PlaybackMetrics {\n",
    "explicit playback-ended metrics event",
)
metrics_path.write_text(metrics)

manager_path = Path(
    "apps/android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt"
)
manager = manager_path.read_text()
manager = sub_once(
    manager,
    r"(Player\.STATE_ENDED -> \{.*?positionJob\?\.cancel\(\)\n\s*)publish\(metricsTracker\.markNotPlaying\(player\.currentPosition\)\)",
    r"\1publish(metricsTracker.markEnded(player.currentPosition))",
    "native STATE_ENDED event",
)
manager_path.write_text(manager)

# The patch mechanism is intentionally temporary. Keep only the product changes.
Path(".github/workflows/tmp-end-of-track-reliability-patch.yml").unlink(missing_ok=True)
Path("tools/tmp_end_of_track_patch.py").unlink(missing_ok=True)
