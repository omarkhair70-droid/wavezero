import 'package:flutter/material.dart';

import '../../catalog/catalog_track_manifest.dart';
import '../../design/wavezero_design_system.dart';
import '../web/web_browser_page.dart';
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

class _WzMusicInboxPageState extends State<WzMusicInboxPage> with WidgetsBindingObserver {
  List<WzImportInboxEntry> _entries = const <WzImportInboxEntry>[];
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
  }

  Future<void> _dismiss(WzImportInboxEntry entry) async {
    final next = await widget.service.dismiss(entry.id);
    if (!mounted) return;
    setState(() => _entries = next);
  }

  Future<void> _clear() async {
    await widget.service.clear();
    if (!mounted) return;
    setState(() => _entries = const <WzImportInboxEntry>[]);
  }

  void _openLink(WzImportInboxEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WzWebBrowserPage(initialQuery: entry.value),
      ),
    );
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
                        Text('Music Inbox', style: WzText.pageTitle.copyWith(fontSize: 30)),
                        const SizedBox(height: 3),
                        Text('Files and links you share to WaveZero land here.', style: WzText.caption),
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
                const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
              else if (_entries.isEmpty)
                _EmptyInbox()
              else
                ..._entries.map(
                  (entry) {
                    final projected = wzCatalogTrackFromInboxEntry(entry);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InboxEntryCard(
                        entry: entry,
                        busy: _busyEntryId == entry.id,
                        liked: projected != null && (widget.isLiked?.call(projected) ?? false),
                        onPrimary: entry.isLink ? () => _openLink(entry) : () => _loadAudio(entry),
                        onQueue: projected == null || widget.onAddToQueue == null ? null : () => _queueAudio(entry),
                        onToggleLike: projected == null || widget.onToggleLike == null ? null : () => _toggleLike(entry),
                        onAddToCollection: projected == null || widget.onAddToCollection == null
                            ? null
                            : () => _addToCollection(entry),
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
            const WzSculptedIcon(icon: Icons.ios_share_rounded, size: 46, iconSize: 20, color: WzColors.accent),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Share → WaveZero', style: WzText.sectionTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Shared audio is copied into Music/WaveZero/Imports. Shared links stay here until you open or dismiss them.',
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
            const WzSculptedIcon(icon: Icons.inbox_rounded, size: 52, iconSize: 23, color: WzColors.textMuted),
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
    this.onQueue,
    this.onToggleLike,
    this.onAddToCollection,
  });

  final WzImportInboxEntry entry;
  final bool busy;
  final bool liked;
  final VoidCallback onPrimary;
  final VoidCallback onDismiss;
  final VoidCallback? onQueue;
  final VoidCallback? onToggleLike;
  final VoidCallback? onAddToCollection;

  @override
  Widget build(BuildContext context) {
    final audio = entry.isAudio;
    return WzPressableSurface(
      onTap: busy ? null : onPrimary,
      radius: 30,
      decoration: WzSurface.sculpted(selected: audio),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WzSculptedIcon(
                icon: audio ? Icons.audio_file_rounded : Icons.link_rounded,
                size: 50,
                iconSize: 22,
                color: audio ? WzColors.accent : WzColors.textPrimary,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.subtitle} • ${_relativeTime(entry.createdAtMs)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WzText.caption,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      audio
                          ? entry.duplicateOfExisting
                              ? 'Already in Device Music'
                              : 'Ready in Device Music'
                          : entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WzText.caption.copyWith(color: audio ? WzColors.accent : WzColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                IconButton(
                  tooltip: 'Dismiss from Inbox',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: busy ? null : onPrimary,
                icon: Icon(audio ? Icons.library_music_rounded : Icons.open_in_browser_rounded, size: 17),
                label: Text(audio ? 'Load' : 'Open'),
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
                  icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 17),
                  label: Text(liked ? 'Liked' : 'Like'),
                ),
              if (audio && onAddToCollection != null)
                TextButton.icon(
                  onPressed: busy ? null : onAddToCollection,
                  icon: const Icon(Icons.playlist_add_circle_outlined, size: 17),
                  label: const Text('Collection'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _relativeTime(int timestampMs) {
  if (timestampMs <= 0) return 'recently';
  final difference = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestampMs));
  if (difference.inMinutes < 1) return 'now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  return '${date.day}/${date.month}';
}
