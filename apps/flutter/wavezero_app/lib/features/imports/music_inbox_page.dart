import 'dart:async';

import 'package:flutter/material.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../device_music/device_music_metadata_overrides.dart';
import '../web/web_browser_page.dart';
import '../web/web_download_service.dart';
import 'import_inbox_projection.dart';
import 'import_inbox_service.dart';

class WzMusicInboxPage extends StatefulWidget {
  const WzMusicInboxPage({
    super.key,
    this.service = const WzImportInboxService(),
    this.onRefreshDeviceMusic,
    this.onLoadTrack,
    this.onAddToQueue,
    this.onToggleLike,
    this.onAddToCollection,
    this.isLiked,
    this.onShowDeviceMusic,
  });

  final WzImportInboxService service;
  final Future<void> Function()? onRefreshDeviceMusic;
  final ValueChanged<CatalogTrackSummary>? onLoadTrack;
  final ValueChanged<CatalogTrackSummary>? onAddToQueue;
  final ValueChanged<CatalogTrackSummary>? onToggleLike;
  final ValueChanged<CatalogTrackSummary>? onAddToCollection;
  final bool Function(CatalogTrackSummary track)? isLiked;
  final VoidCallback? onShowDeviceMusic;

  @override
  State<WzMusicInboxPage> createState() => _WzMusicInboxPageState();
}

class _WzMusicInboxPageState extends State<WzMusicInboxPage>
    with WidgetsBindingObserver {
  final WzWebDownloadService _downloadService = WzWebDownloadService();
  final WzDeviceMusicMetadataOverridesService _metadataOverrides =
      const WzDeviceMusicMetadataOverridesService();
  List<WzImportInboxEntry> _entries = const <WzImportInboxEntry>[];
  Map<int, WzWebDownloadTask> _downloadTasks =
      const <int, WzWebDownloadTask>{};
  Timer? _downloadPoller;
  bool _loading = true;
  String? _busyEntryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    _downloadPoller?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final entries = await widget.service.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
    await _syncDownloadTasks();
  }

  Future<void> _syncDownloadTasks() async {
    final ids = _entries
        .where((entry) => entry.hasDownloadTask)
        .map((entry) => entry.downloadId!)
        .toSet();
    if (ids.isEmpty) {
      _downloadPoller?.cancel();
      _downloadPoller = null;
      if (mounted && _downloadTasks.isNotEmpty) {
        setState(() => _downloadTasks = const {});
      }
      return;
    }

    final next = <int, WzWebDownloadTask>{};
    var completedNow = false;
    for (final id in ids) {
      try {
        final task = await _downloadService.query(id);
        next[id] = task;
        if (task.isSuccessful && _downloadTasks[id]?.isSuccessful != true) {
          completedNow = true;
        }
      } catch (_) {
        final previous = _downloadTasks[id];
        if (previous != null) next[id] = previous;
      }
    }
    if (!mounted) return;
    setState(() => _downloadTasks = next);

    if (completedNow) await widget.onRefreshDeviceMusic?.call();
    final hasActive = next.values.any((task) => !task.isTerminal);
    if (hasActive) {
      _downloadPoller ??= Timer.periodic(
        const Duration(seconds: 2),
        (_) => _syncDownloadTasks(),
      );
    } else {
      _downloadPoller?.cancel();
      _downloadPoller = null;
    }
  }

  Future<void> _dismiss(WzImportInboxEntry entry) async {
    final next = await widget.service.dismiss(entry.id);
    if (!mounted) return;
    setState(() => _entries = next);
    await _syncDownloadTasks();
  }

  Future<void> _clear() async {
    await widget.service.clear();
    _downloadPoller?.cancel();
    _downloadPoller = null;
    if (!mounted) return;
    setState(() {
      _entries = const <WzImportInboxEntry>[];
      _downloadTasks = const <int, WzWebDownloadTask>{};
    });
  }

  void _openLink(WzImportInboxEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WzWebBrowserPage(initialQuery: entry.value),
      ),
    );
  }

  Future<void> _openCompletedDownload(WzImportInboxEntry entry) async {
    setState(() => _busyEntryId = entry.id);
    try {
      await widget.onRefreshDeviceMusic?.call();
      widget.onShowDeviceMusic?.call();
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _busyEntryId = null);
    }
  }

  Future<void> _cancelDownload(WzImportInboxEntry entry) async {
    final id = entry.downloadId;
    if (id == null) return;
    setState(() => _busyEntryId = entry.id);
    try {
      await _downloadService.cancel(id);
      if (!mounted) return;
      setState(() {
        _downloadTasks = <int, WzWebDownloadTask>{
          ..._downloadTasks,
          id: WzWebDownloadTask(
            id: id,
            status: 'cancelled',
            fileName: entry.title,
          ),
        };
      });
    } finally {
      if (mounted) setState(() => _busyEntryId = null);
    }
  }

  Future<CatalogTrackSummary?> _prepareAudio(WzImportInboxEntry entry) async {
    final track = wzCatalogTrackFromInboxEntry(entry);
    if (track == null) return null;
    setState(() => _busyEntryId = entry.id);
    try {
      await widget.onRefreshDeviceMusic?.call();
      return track;
    } finally {
      if (mounted) setState(() => _busyEntryId = null);
    }
  }

  Future<void> _loadAudio(WzImportInboxEntry entry) async {
    final track = await _prepareAudio(entry);
    if (!mounted) return;
    if (track == null || widget.onLoadTrack == null) {
      await widget.onRefreshDeviceMusic?.call();
      widget.onShowDeviceMusic?.call();
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    widget.onLoadTrack!(track);
    widget.onShowDeviceMusic?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _queueAudio(WzImportInboxEntry entry) async {
    final track = await _prepareAudio(entry);
    if (!mounted || track == null || widget.onAddToQueue == null) return;
    widget.onAddToQueue!(track);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${track.title} added to queue')),
    );
  }

  Future<void> _toggleLike(WzImportInboxEntry entry) async {
    final track = await _prepareAudio(entry);
    if (!mounted || track == null || widget.onToggleLike == null) return;
    widget.onToggleLike!(track);
  }

  Future<void> _addToCollection(WzImportInboxEntry entry) async {
    final track = await _prepareAudio(entry);
    if (!mounted || track == null || widget.onAddToCollection == null) return;
    widget.onAddToCollection!(track);
  }

  Future<void> _fixInfo(WzImportInboxEntry entry) async {
    final trackId = entry.trackId?.trim();
    if (trackId == null || trackId.isEmpty) return;

    final existing = (await _metadataOverrides.load())[trackId];
    if (!mounted) return;
    final titleController = TextEditingController(
      text: existing?.title ?? _titleFromInboxName(entry.title),
    );
    final artistController = TextEditingController(
      text: existing?.artistName ?? '',
    );
    final albumController = TextEditingController(
      text: existing?.albumName ?? '',
    );

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fix track info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: artistController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Artist',
                  hintText: 'Leave blank to keep device metadata',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: albumController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Album',
                  hintText: 'Leave blank to keep device metadata',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'WaveZero keeps this as a local correction. The original audio file is not rewritten.',
                style: WzText.caption,
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('reset'),
              child: const Text('Reset'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (action == null || !mounted) {
      titleController.dispose();
      artistController.dispose();
      albumController.dispose();
      return;
    }

    setState(() => _busyEntryId = entry.id);
    try {
      if (action == 'reset') {
        await _metadataOverrides.remove(trackId);
      } else {
        await _metadataOverrides.save(
          WzDeviceMusicMetadataOverride(
            trackId: trackId,
            title: titleController.text,
            artistName: artistController.text,
            albumName: albumController.text,
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      await widget.onRefreshDeviceMusic?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'reset'
                ? 'Track info reset to device metadata.'
                : 'Track info updated in WaveZero.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WaveZero could not save this track info.')),
        );
      }
    } finally {
      titleController.dispose();
      artistController.dispose();
      albumController.dispose();
      if (mounted) setState(() => _busyEntryId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: WzColors.canvas,
        body: SafeArea(
          child: WzPageScaffold(
            children: [
              Row(
                children: [
                  WzSculptedIconButton(
                    tooltip: 'Back',
                    icon: Icons.arrow_back_rounded,
                    size: 44,
                    iconSize: 20,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Music Inbox',
                          style: WzText.pageTitle.copyWith(fontSize: 30),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Files, direct audio downloads, and links you share to WaveZero land here.',
                          style: WzText.caption,
                        ),
                      ],
                    ),
                  ),
                  if (_entries.isNotEmpty)
                    TextButton(
                      onPressed: _clear,
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _InboxHowItWorksCard(),
              const SizedBox(height: 18),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_entries.isEmpty)
                _EmptyInbox()
              else
                ..._entries.map(
                  (entry) {
                    final projected = wzCatalogTrackFromInboxEntry(entry);
                    final downloadTask = entry.downloadId == null
                        ? null
                        : _downloadTasks[entry.downloadId!];
                    final downloadReady = downloadTask?.isSuccessful == true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InboxEntryCard(
                        entry: entry,
                        downloadTask: downloadTask,
                        busy: _busyEntryId == entry.id,
                        liked: projected != null &&
                            (widget.isLiked?.call(projected) ?? false),
                        onPrimary: entry.isLink
                            ? () => _openLink(entry)
                            : entry.isDownload
                                ? downloadReady
                                    ? () => _openCompletedDownload(entry)
                                    : () => _openLink(entry)
                                : () => _loadAudio(entry),
                        onQueue: projected == null ||
                                widget.onAddToQueue == null
                            ? null
                            : () => _queueAudio(entry),
                        onToggleLike: projected == null ||
                                widget.onToggleLike == null
                            ? null
                            : () => _toggleLike(entry),
                        onAddToCollection: projected == null ||
                                widget.onAddToCollection == null
                            ? null
                            : () => _addToCollection(entry),
                        onFixInfo: entry.hasResolvableDeviceTrack
                            ? () => _fixInfo(entry)
                            : null,
                        onCancelDownload: entry.isDownload &&
                                downloadTask != null &&
                                !downloadTask.isTerminal
                            ? () => _cancelDownload(entry)
                            : null,
                        onDismiss: () => _dismiss(entry),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
}

class _InboxHowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WzGlassCard(
        borderRadius: 30,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WzSculptedIcon(
              icon: Icons.ios_share_rounded,
              size: 46,
              iconSize: 20,
              color: WzColors.accent,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Share → WaveZero', style: WzText.sectionTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Audio files are imported. Direct audio links start a normal Android download. Other links stay here for WaveZero Web.',
                    style: WzText.body,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WzGlassCard(
        borderRadius: 32,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WzSculptedIcon(
              icon: Icons.inbox_rounded,
              size: 52,
              iconSize: 23,
              color: WzColors.textMuted,
            ),
            const SizedBox(height: 14),
            Text('Nothing waiting here', style: WzText.title),
            const SizedBox(height: 5),
            Text(
              'From Files, Telegram, WhatsApp, a browser, or another app: tap Share and choose WaveZero.',
              style: WzText.body,
            ),
          ],
        ),
      );
}

class _InboxEntryCard extends StatelessWidget {
  const _InboxEntryCard({
    required this.entry,
    required this.busy,
    required this.liked,
    required this.onPrimary,
    required this.onDismiss,
    this.downloadTask,
    this.onQueue,
    this.onToggleLike,
    this.onAddToCollection,
    this.onFixInfo,
    this.onCancelDownload,
  });

  final WzImportInboxEntry entry;
  final WzWebDownloadTask? downloadTask;
  final bool busy;
  final bool liked;
  final VoidCallback onPrimary;
  final VoidCallback onDismiss;
  final VoidCallback? onQueue;
  final VoidCallback? onToggleLike;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onFixInfo;
  final VoidCallback? onCancelDownload;

  @override
  Widget build(BuildContext context) {
    final audio = entry.isAudio;
    final download = entry.isDownload;
    final downloadActive =
        download && downloadTask != null && !downloadTask!.isTerminal;
    final downloadReady = downloadTask?.isSuccessful == true;
    final detail = audio
        ? entry.duplicateOfExisting
            ? 'Already in Device Music'
            : 'Ready in Device Music'
        : download
            ? _downloadStatusLabel(downloadTask)
            : entry.value;

    return WzPressableSurface(
      onTap: busy || downloadActive ? null : onPrimary,
      radius: 30,
      decoration: WzSurface.sculpted(selected: audio || downloadReady),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WzSculptedIcon(
                icon: audio
                    ? Icons.audio_file_rounded
                    : download
                        ? downloadReady
                            ? Icons.download_done_rounded
                            : Icons.downloading_rounded
                        : Icons.link_rounded,
                size: 50,
                iconSize: 22,
                color: audio || downloadReady
                    ? WzColors.accent
                    : WzColors.textPrimary,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WzText.sectionTitle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.subtitle} • ${_relativeTime(entry.createdAtMs)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WzText.caption,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WzText.caption.copyWith(
                        color: audio || downloadReady
                            ? WzColors.accent
                            : WzColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Dismiss from Inbox',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
          if (downloadActive) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: downloadTask?.progress,
                minHeight: 3,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (!downloadActive)
                TextButton.icon(
                  onPressed: busy ? null : onPrimary,
                  icon: Icon(
                    audio || downloadReady
                        ? Icons.library_music_rounded
                        : Icons.open_in_browser_rounded,
                    size: 17,
                  ),
                  label: Text(
                    audio ? 'Load' : downloadReady ? 'Library' : 'Open',
                  ),
                ),
              if (download)
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WzWebBrowserPage(
                                initialQuery: entry.value,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 17),
                  label: const Text('Source'),
                ),
              if (onCancelDownload != null)
                TextButton.icon(
                  onPressed: busy ? null : onCancelDownload,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('Cancel'),
                ),
              if (audio && onQueue != null)
                TextButton.icon(
                  onPressed: busy ? null : onQueue,
                  icon: const Icon(Icons.playlist_add_rounded, size: 17),
                  label: const Text('Queue'),
                ),
              if (audio && onToggleLike != null)
                TextButton.icon(
                  onPressed: busy ? null : onToggleLike,
                  icon: Icon(
                    liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 17,
                  ),
                  label: Text(liked ? 'Liked' : 'Like'),
                ),
              if (audio && onAddToCollection != null)
                TextButton.icon(
                  onPressed: busy ? null : onAddToCollection,
                  icon: const Icon(
                    Icons.playlist_add_circle_outlined,
                    size: 17,
                  ),
                  label: const Text('Collection'),
                ),
              if (audio && onFixInfo != null)
                TextButton.icon(
                  onPressed: busy ? null : onFixInfo,
                  icon: const Icon(Icons.edit_note_rounded, size: 17),
                  label: const Text('Fix info'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _downloadStatusLabel(WzWebDownloadTask? task) {
  if (task == null) return 'Checking download…';
  return switch (task.status) {
    'pending' => 'Waiting to download',
    'running' => task.progress == null
        ? 'Downloading…'
        : 'Downloading ${(task.progress! * 100).round()}%',
    'paused' => 'Download paused',
    'successful' => 'Ready in Device Music',
    'failed' => 'Download failed — open source to retry',
    'cancelled' => 'Download cancelled',
    'missing' => 'Download is no longer available',
    _ => 'Download ${task.status}',
  };
}

String _titleFromInboxName(String value) {
  final trimmed = value.trim();
  final dot = trimmed.lastIndexOf('.');
  if (dot <= 0 || dot == trimmed.length - 1) return trimmed;
  final extension = trimmed.substring(dot + 1).toLowerCase();
  const audioExtensions = <String>{
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
  };
  return audioExtensions.contains(extension) ? trimmed.substring(0, dot) : trimmed;
}

String _relativeTime(int timestampMs) {
  if (timestampMs <= 0) return 'recently';
  final difference = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(timestampMs),
  );
  if (difference.inMinutes < 1) return 'now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  return '${date.day}/${date.month}';
}
