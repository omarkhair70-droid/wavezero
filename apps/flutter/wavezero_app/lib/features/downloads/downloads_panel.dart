import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/wavezero_design_system.dart';
import '../../shared/media/media_presentation.dart';
import '../../shared/widgets/wavezero_artwork.dart';
import '../../shared/widgets/wavezero_empty_message.dart';
import '../imports/import_inbox_service.dart';
import '../web/web_download_service.dart';
import 'cache_service.dart';
import 'downloads_presentation.dart';

class WzDownloadsPanel extends StatelessWidget {
  const WzDownloadsPanel({
    super.key,
    required this.downloads,
    required this.cacheBytes,
    required this.controlsDisabled,
    required this.onPlay,
    required this.onDelete,
    required this.onClearAll,
    required this.onManageStorage,
    this.onRefreshDeviceMusic,
    this.onOpenDeviceMusic,
  });

  final List<CachedTrackMetadata> downloads;
  final int cacheBytes;
  final bool controlsDisabled;
  final ValueChanged<CachedTrackMetadata> onPlay;
  final ValueChanged<CachedTrackMetadata> onDelete;
  final VoidCallback onClearAll;
  final VoidCallback onManageStorage;
  final Future<void> Function()? onRefreshDeviceMusic;
  final VoidCallback? onOpenDeviceMusic;

  @override
  Widget build(BuildContext context) => WzGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: WzSpacing.sm,
              runSpacing: WzSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Downloads', style: WzText.title),
                      SizedBox(height: 4),
                      Text(
                        'Downloads in progress and the music already here with you.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: WzText.body,
                      ),
                    ],
                  ),
                ),
                WzStatusPill(
                  label: '${downloads.length} offline • ${formatWzCacheBytes(cacheBytes)}',
                  active: downloads.isNotEmpty,
                  icon: Icons.download_done_rounded,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onManageStorage,
                      icon: const Icon(Icons.storage_rounded),
                      label: const Text('Manage Storage'),
                    ),
                    const SizedBox(width: WzSpacing.xs),
                    WzSculptedIconButton(
                      tooltip: 'Clear all offline downloads',
                      icon: Icons.clear_all,
                      size: 42,
                      iconSize: 19,
                      onPressed: downloads.isEmpty || controlsDisabled ? null : onClearAll,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: WzSpacing.md),
            _DirectAudioDownloads(
              onRefreshDeviceMusic: onRefreshDeviceMusic,
              onOpenDeviceMusic: onOpenDeviceMusic,
            ),
            const SizedBox(height: WzSpacing.md),
            Text('Offline library', style: WzText.sectionTitle),
            const SizedBox(height: 4),
            Text(
              'Catalog tracks cached by WaveZero for offline playback.',
              style: WzText.caption,
            ),
            const SizedBox(height: WzSpacing.sm),
            if (downloads.isEmpty)
              const WzEmptyCatalogMessage(
                message: 'No cached catalog tracks yet. Download tracks from Library to listen offline.',
              )
            else
              ...downloads.map(
                (track) => _DownloadRow(
                  track: track,
                  disabled: controlsDisabled,
                  onPlay: () => onPlay(track),
                  onDelete: () => onDelete(track),
                ),
              ),
          ],
        ),
      );
}

class _DirectAudioDownloads extends StatefulWidget {
  const _DirectAudioDownloads({
    this.onRefreshDeviceMusic,
    this.onOpenDeviceMusic,
  });

  final Future<void> Function()? onRefreshDeviceMusic;
  final VoidCallback? onOpenDeviceMusic;

  @override
  State<_DirectAudioDownloads> createState() => _DirectAudioDownloadsState();
}

class _DirectAudioDownloadsState extends State<_DirectAudioDownloads>
    with WidgetsBindingObserver {
  final WzImportInboxService _inbox = const WzImportInboxService();
  final WzWebDownloadService _downloads = WzWebDownloadService();
  List<WzImportInboxEntry> _entries = const [];
  Map<int, WzWebDownloadTask> _tasks = const {};
  Timer? _poller;
  bool _loading = true;
  String? _busyEntryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reload());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reload());
  }

  Future<void> _reload() async {
    final entries = (await _inbox.load())
        .where((entry) => entry.hasDownloadTask)
        .toList(growable: false);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
    await _sync();
  }

  Future<void> _sync() async {
    if (_entries.isEmpty) {
      _poller?.cancel();
      _poller = null;
      if (mounted && _tasks.isNotEmpty) setState(() => _tasks = const {});
      return;
    }

    final next = <int, WzWebDownloadTask>{};
    var completedNow = false;
    for (final entry in _entries) {
      final id = entry.downloadId!;
      try {
        final task = await _downloads.query(id);
        next[id] = task;
        if (task.isSuccessful && _tasks[id]?.isSuccessful != true) {
          completedNow = true;
        }
      } catch (_) {
        final previous = _tasks[id];
        if (previous != null) next[id] = previous;
      }
    }
    if (!mounted) return;
    setState(() => _tasks = next);

    if (completedNow) await widget.onRefreshDeviceMusic?.call();
    if (!mounted) return;
    if (next.values.any((task) => !task.isTerminal)) {
      _poller ??= Timer.periodic(const Duration(seconds: 2), (_) => unawaited(_sync()));
    } else {
      _poller?.cancel();
      _poller = null;
    }
  }

  Future<void> _cancel(WzImportInboxEntry entry) async {
    final id = entry.downloadId;
    if (id == null) return;
    setState(() => _busyEntryId = entry.id);
    try {
      await _downloads.cancel(id);
      await _sync();
    } finally {
      if (mounted) setState(() => _busyEntryId = null);
    }
  }

  Future<void> _retry(WzImportInboxEntry entry) async {
    setState(() => _busyEntryId = entry.id);
    try {
      final task = await _downloads.enqueueDirectAudio(entry.value);
      if (task.id <= 0) {
        throw const PlatformException(
          code: 'download_unavailable',
          message: 'WaveZero could not start this retry.',
        );
      }
      final updated = await _inbox.replaceDownloadTask(
        entryId: entry.id,
        downloadId: task.id,
        title: task.fileName,
      );
      if (!mounted) return;
      setState(() {
        _entries = updated
            .where((item) => item.hasDownloadTask)
            .toList(growable: false);
        _tasks = <int, WzWebDownloadTask>{task.id: task};
      });
      await _sync();
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'WaveZero could not retry this download.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WaveZero could not retry this download.')),
      );
    } finally {
      if (mounted) setState(() => _busyEntryId = null);
    }
  }

  Future<void> _removeHistory(WzImportInboxEntry entry) async {
    setState(() => _busyEntryId = entry.id);
    try {
      await _inbox.dismiss(entry.id);
      await _reload();
    } finally {
      if (mounted) setState(() => _busyEntryId = null);
    }
  }

  Future<void> _openReady() async {
    await widget.onRefreshDeviceMusic?.call();
    widget.onOpenDeviceMusic?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Direct audio', style: WzText.sectionTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Audio links shared to WaveZero use Android DownloadManager and show up here.',
                    style: WzText.caption,
                  ),
                ],
              ),
            ),
            if (_entries.isNotEmpty)
              WzStatusPill(
                label: '${_entries.length}',
                active: _tasks.values.any((task) => !task.isTerminal),
                icon: Icons.downloading_rounded,
              ),
          ],
        ),
        const SizedBox(height: WzSpacing.sm),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (_entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WzColors.surfaceMuted.withValues(alpha: .56),
              borderRadius: BorderRadius.circular(WzRadius.lg),
              border: Border.all(color: WzColors.borderSoft),
            ),
            child: const Text(
              'No direct-audio downloads in your recent Music Inbox.',
              style: WzText.caption,
            ),
          )
        else
          ..._entries.map((entry) {
            final task = _tasks[entry.downloadId!];
            return _DirectDownloadRow(
              entry: entry,
              task: task,
              busy: _busyEntryId == entry.id,
              onCancel: task != null && !task.isTerminal
                  ? () => _cancel(entry)
                  : null,
              onRetry: task?.canRetry == true ? () => _retry(entry) : null,
              onOpen: task?.isSuccessful == true && widget.onOpenDeviceMusic != null
                  ? _openReady
                  : null,
              onRemove: task?.isTerminal == true ? () => _removeHistory(entry) : null,
            );
          }),
      ],
    );
  }
}

class _DirectDownloadRow extends StatelessWidget {
  const _DirectDownloadRow({
    required this.entry,
    required this.task,
    required this.busy,
    required this.onCancel,
    required this.onRetry,
    required this.onOpen,
    required this.onRemove,
  });

  final WzImportInboxEntry entry;
  final WzWebDownloadTask? task;
  final bool busy;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final status = task?.status ?? 'checking';
    final progress = task?.progress;
    final transferred = task == null || task!.downloadedBytes <= 0
        ? null
        : task!.totalBytes > 0
            ? '${formatWzCacheBytes(task!.downloadedBytes)} / ${formatWzCacheBytes(task!.totalBytes)}'
            : formatWzCacheBytes(task!.downloadedBytes);
    final label = switch (status) {
      'pending' => 'Waiting for Android',
      'running' => [
          progress == null ? 'Downloading' : 'Downloading ${(progress * 100).round()}%',
          if (transferred != null) transferred,
        ].join(' • '),
      'paused' => 'Paused by Android',
      'successful' => 'Ready in Device Music',
      'failed' => 'Download failed • tap retry',
      'cancelled' => 'Cancelled • tap retry',
      'missing' => 'Download record missing • tap retry',
      _ => 'Checking download',
    };
    final terminal = task?.isTerminal == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      decoration: WzSurface.sculpted(selected: !terminal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WzSculptedIcon(
                icon: task?.isSuccessful == true
                    ? Icons.download_done_rounded
                    : Icons.audio_file_rounded,
                size: 42,
                iconSize: 19,
                color: task?.isSuccessful == true ? WzColors.success : WzColors.accent,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task?.fileName ?? entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WzText.sectionTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(label, style: WzText.caption),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                if (onOpen != null)
                  WzSculptedIconButton(
                    tooltip: 'Open Device Music',
                    icon: Icons.library_music_rounded,
                    size: 38,
                    iconSize: 17,
                    onPressed: onOpen,
                  ),
                if (onRetry != null)
                  WzSculptedIconButton(
                    tooltip: 'Retry download',
                    icon: Icons.refresh_rounded,
                    size: 38,
                    iconSize: 17,
                    onPressed: onRetry,
                  ),
                if (onCancel != null)
                  WzSculptedIconButton(
                    tooltip: 'Cancel download',
                    icon: Icons.close_rounded,
                    size: 38,
                    iconSize: 17,
                    onPressed: onCancel,
                  ),
                if (onRemove != null)
                  WzSculptedIconButton(
                    tooltip: 'Remove from download history',
                    icon: Icons.delete_outline_rounded,
                    size: 38,
                    iconSize: 17,
                    onPressed: onRemove,
                  ),
              ],
            ],
          ),
          if (!terminal && progress != null) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: WzColors.borderSoft,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.track, required this.disabled, required this.onPlay, required this.onDelete});

  final CachedTrackMetadata track;
  final bool disabled;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(11),
        decoration: WzSurface.sculpted(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(WzRadius.md), boxShadow: WzSurface.softShadows),
              child: WzArtwork(
                artworkUrl: track.artworkUrl,
                size: 52,
                trackId: track.trackId,
                title: track.title,
                artist: track.artistName,
              ),
            ),
            const SizedBox(width: WzSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                  const SizedBox(height: 4),
                  Text(
                    '${track.subtitle} • ${wzProductQualityLabel(track.qualityLabel)}${track.codec == null ? '' : ' • ${track.codec}'}${track.bitrateKbps == null ? '' : ' • ${track.bitrateKbps}kbps'} • ${wzDownloadSourceLabel(track.downloadSource)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: WzSpacing.sm),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WzSculptedIconButton(
                  tooltip: 'Play downloaded track',
                  icon: Icons.play_arrow_rounded,
                  size: 40,
                  iconSize: 19,
                  onPressed: disabled ? null : onPlay,
                ),
                const SizedBox(height: 6),
                WzSculptedIconButton(
                  tooltip: 'Remove from device',
                  icon: Icons.delete_outline_rounded,
                  size: 40,
                  iconSize: 18,
                  onPressed: disabled ? null : onDelete,
                ),
              ],
            ),
          ],
        ),
      );
}
