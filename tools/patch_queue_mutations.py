from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    text = text.replace(old, new, 1)


replace_once(
    """import '../features/queue/queue_session_store.dart';
import '../features/queue/queue_position.dart';
import '../features/queue/smart_queue_policy.dart';""",
    """import '../features/queue/queue_session_store.dart';
import '../features/queue/queue_mutations.dart';
import '../features/queue/queue_position.dart';
import '../features/queue/smart_queue_policy.dart';""",
    'queue import',
)

replace_once(
    """  void _addToQueue(CatalogTrackSummary track) {
    final exists = _queue.any((item) => item.trackId == track.trackId);
    setState(() {
      if (!exists) _queue = [..._queue, track];
      _queueCurrentTrackId ??= track.trackId;
      _queueStatus = exists ? '${track.title} is already in queue.' : '${track.title} added to queue.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exists ? 'Already in Queue' : 'Added to Queue')));
  }""",
    """  void _addToQueue(CatalogTrackSummary track) {
    final mutation = addWzQueueTrack(
      queue: _queue,
      track: track,
      currentTrackId: _queueCurrentTrackId,
    );
    setState(() {
      _queue = mutation.queue;
      _queueCurrentTrackId = mutation.currentTrackId;
      _queueStatus = mutation.alreadyPresent ? '${track.title} is already in queue.' : '${track.title} added to queue.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mutation.alreadyPresent ? 'Already in Queue' : 'Added to Queue')));
  }""",
    'add queue method',
)

replace_once(
    """  void _moveQueueTrack(CatalogTrackSummary track, int delta) {
    if (_queueDisabled) return;
    final index = _queue.indexWhere((item) => item.trackId == track.trackId);
    if (index < 0) return;
    final target = (index + delta).clamp(0, _queue.length - 1).toInt();
    if (target == index) return;
    final nextQueue = [..._queue];
    final moved = nextQueue.removeAt(index);
    nextQueue.insert(target, moved);
    setState(() {
      _queue = nextQueue;
      _queueStatus = '${track.title} moved ${delta < 0 ? 'up' : 'down'}.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }""",
    """  void _moveQueueTrack(CatalogTrackSummary track, int delta) {
    if (_queueDisabled) return;
    final mutation = moveWzQueueTrack(
      queue: _queue,
      trackId: track.trackId,
      delta: delta,
    );
    if (!mutation.changed) return;
    setState(() {
      _queue = mutation.queue;
      _queueStatus = '${track.title} moved ${delta < 0 ? 'up' : 'down'}.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }""",
    'move queue method',
)

replace_once(
    """  void _playTrackNext(CatalogTrackSummary track) {
    if (_queueDisabled) return;
    final currentIndex = _queueIndex;
    final sourceIndex = _queue.indexWhere((item) => item.trackId == track.trackId);
    if (currentIndex < 0 || sourceIndex < 0 || sourceIndex == currentIndex) return;
    final nextQueue = [..._queue];
    final moved = nextQueue.removeAt(sourceIndex);
    final adjustedCurrentIndex = nextQueue.indexWhere((item) => item.trackId == _queueCurrentTrackId);
    final insertIndex = (adjustedCurrentIndex + 1).clamp(0, nextQueue.length).toInt();
    nextQueue.insert(insertIndex, moved);
    setState(() {
      _queue = nextQueue;
      _queueStatus = '${track.title} will play next.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }""",
    """  void _playTrackNext(CatalogTrackSummary track) {
    if (_queueDisabled) return;
    final mutation = moveWzQueueTrackNext(
      queue: _queue,
      trackId: track.trackId,
      resolvedCurrentIndex: _queueIndex,
      currentTrackId: _queueCurrentTrackId,
    );
    if (!mutation.changed) return;
    setState(() {
      _queue = mutation.queue;
      _queueStatus = '${track.title} will play next.';
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }""",
    'play next queue method',
)

replace_once(
    """  void _removeFromQueue(CatalogTrackSummary track) {
    if (_queueDisabled) return;
    setState(() {
      final index = _queue.indexWhere((item) => item.trackId == track.trackId);
      final wasCurrent = track.trackId == _queueCurrentTrackId;
      _queue = _queue.where((item) => item.trackId != track.trackId).toList(growable: false);
      if (_queue.isEmpty) {
        _queueCurrentTrackId = null;
        _queueStatus = 'Queue cleared.';
      } else if (wasCurrent) {
        final nextIndex = index.clamp(0, _queue.length - 1).toInt();
        _queueCurrentTrackId = _queue[nextIndex].trackId;
        _queueStatus = 'Removed current track. Queue moved to ${_queue[nextIndex].title}.';
      } else {
        _queueStatus = '${track.title} removed from queue.';
      }
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }""",
    """  void _removeFromQueue(CatalogTrackSummary track) {
    if (_queueDisabled) return;
    final mutation = removeWzQueueTrack(
      queue: _queue,
      trackId: track.trackId,
      currentTrackId: _queueCurrentTrackId,
    );
    setState(() {
      _queue = mutation.queue;
      _queueCurrentTrackId = mutation.currentTrackId;
      if (_queue.isEmpty) {
        _queueStatus = 'Queue cleared.';
      } else if (mutation.wasCurrent) {
        _queueStatus = 'Removed current track. Queue moved to ${mutation.currentTrack!.title}.';
      } else {
        _queueStatus = '${track.title} removed from queue.';
      }
      _sessionStatus = 'Session saved.';
    });
    unawaited(_saveSession());
    unawaited(_pushNotificationQueueSnapshot());
    unawaited(_updatePredictivePreloadCandidate());
    unawaited(_maybeAutoCacheNextQueuedTrack());
  }""",
    'remove queue method',
)

path.write_text(text)
