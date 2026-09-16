from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


manager_path = Path(
    "apps/android/app/src/main/java/com/wavezero/player/playback/AudioPlayerManager.kt"
)
manager = manager_path.read_text()
old = """            } else {
                if (!player.playWhenReady) positionJob?.cancel()
                publish(metricsTracker.markNotPlaying(player.currentPosition))
"""
new = """            } else {
                if (player.playbackState == Player.STATE_ENDED) return
                if (!player.playWhenReady) positionJob?.cancel()
                publish(metricsTracker.markNotPlaying(player.currentPosition))
"""
manager = replace_once(manager, old, new, "preserve ended event")
manager_path.write_text(manager)

test_path = Path(
    "apps/flutter/wavezero_app/test/features/playback/end_of_track_reliability_contract_test.dart"
)
test = test_path.read_text()
old_test = """    expect(metrics, contains('update(\"playback_ended\")'));
"""
new_test = old_test + """    expect(
      manager,
      contains('if (player.playbackState == Player.STATE_ENDED) return'),
    );
"""
test = replace_once(test, old_test, new_test, "ended callback contract")
test_path.write_text(test)

Path(".github/workflows/tmp-preserve-ended-patch.yml").unlink(missing_ok=True)
Path("tools/tmp_preserve_ended_patch.py").unlink(missing_ok=True)
