import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../web/web_browser_page.dart';
import 'import_inbox_service.dart';

class WzMusicInboxPage extends StatefulWidget {
  const WzMusicInboxPage({super.key, this.service = const WzImportInboxService()});

  final WzImportInboxService service;

  @override
  State<WzMusicInboxPage> createState() => _WzMusicInboxPageState();
}

class _WzMusicInboxPageState extends State<WzMusicInboxPage> with WidgetsBindingObserver {
  List<WzImportInboxEntry> _entries = const <WzImportInboxEntry>[];
  bool _loading = true;

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
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InboxEntryCard(
                      entry: entry,
                      onPrimary: entry.isLink
                          ? () => _openLink(entry)
                          : () => Navigator.of(context).maybePop(),
                      onDismiss: () => _dismiss(entry),
                    ),
                  ),
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
  const _InboxEntryCard({required this.entry, required this.onPrimary, required this.onDismiss});

  final WzImportInboxEntry entry;
  final VoidCallback onPrimary;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final audio = entry.isAudio;
    return WzPressableSurface(
      onTap: onPrimary,
      radius: 30,
      decoration: WzSurface.sculpted(selected: audio),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Row(
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
                  audio ? 'Ready in Device Music' : entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WzText.caption.copyWith(color: audio ? WzColors.accent : WzColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onPrimary,
            child: Text(audio ? 'Library' : 'Open'),
          ),
          IconButton(
            tooltip: 'Dismiss from Inbox',
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
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
