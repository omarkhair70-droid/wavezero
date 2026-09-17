import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/wavezero_design_system.dart';
import '../device_music/device_music_service.dart';
import 'web_download_service.dart';
import 'web_library_service.dart';

String wzResolveWebLocation(String input) {
  final value = input.trim();
  if (value.isEmpty) return 'https://www.google.com';
  final parsed = Uri.tryParse(value);
  if (parsed != null && (parsed.scheme == 'https' || parsed.scheme == 'http') && parsed.host.isNotEmpty) {
    return parsed.toString();
  }
  return Uri.https('www.google.com', '/search', {'q': value}).toString();
}

String wzFormatWebTransferBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

String wzFormatWebTransferRate(double bytesPerSecond) {
  if (bytesPerSecond <= 0) return '';
  return '${wzFormatWebTransferBytes(bytesPerSecond.round())}/s';
}

String wzFormatWebTransferEta({
  required int downloadedBytes,
  required int totalBytes,
  required double bytesPerSecond,
}) {
  if (bytesPerSecond <= 0 || totalBytes <= downloadedBytes || totalBytes <= 0) return '';
  final seconds = ((totalBytes - downloadedBytes) / bytesPerSecond).ceil();
  if (seconds < 60) return '~${seconds}s left';
  final minutes = (seconds / 60).ceil();
  return '~${minutes}m left';
}

class WzWebBrowserPage extends StatefulWidget {
  const WzWebBrowserPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<WzWebBrowserPage> createState() => _WzWebBrowserPageState();
}

class _WzWebBrowserPageState extends State<WzWebBrowserPage> {
  static const MethodChannel _handsFreeChannel = MethodChannel('wavezero/handsfree');

  final WzWebDownloadService _downloadService = WzWebDownloadService();
  final DeviceMusicService _deviceMusicService = DeviceMusicService();
  final WzWebLibraryService _webLibraryService = const WzWebLibraryService();
  late final TextEditingController _addressController;

  MethodChannel? _webChannel;
  Timer? _downloadPoller;
  WzWebDownloadTask? _download;
  WzWebLibraryState _webLibrary = const WzWebLibraryState();
  String _currentUrl = '';
  String _pageTitle = '';
  String? _pendingVoiceUrl;
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _pageError;
  int? _lastDownloadSampleBytes;
  DateTime? _lastDownloadSampleAt;
  double? _downloadBytesPerSecond;

  @override
  void initState() {
    super.initState();
    _currentUrl = wzResolveWebLocation(widget.initialQuery);
    _addressController = TextEditingController(
      text: widget.initialQuery.trim().isEmpty ? _currentUrl : widget.initialQuery.trim(),
    );
    unawaited(_loadWebLibrary());
    if (widget.initialQuery.trim().isEmpty) {
      unawaited(_adoptPendingVoiceAcquisition());
    }
  }

  @override
  void dispose() {
    _downloadPoller?.cancel();
    _webChannel?.setMethodCallHandler(null);
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadWebLibrary() async {
    final state = await _webLibraryService.load();
    if (!mounted) return;
    setState(() => _webLibrary = state);
  }

  Future<void> _adoptPendingVoiceAcquisition() async {
    if (!Platform.isAndroid) return;
    try {
      final pending = await _handsFreeChannel.invokeMapMethod<Object?, Object?>(
        'consumePendingAcquisition',
      );
      final query = pending?['query']?.toString().trim() ?? '';
      if (!mounted || query.isEmpty) return;
      final url = wzResolveWebLocation(query);
      setState(() {
        _addressController.text = query;
        _currentUrl = url;
        _pageError = null;
        _pendingVoiceUrl = url;
      });
      final channel = _webChannel;
      if (channel != null) {
        _pendingVoiceUrl = null;
        await channel.invokeMethod<void>('loadUrl', {'url': url});
      }
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice request: searching the Web for “$query”')),
        );
      });
    } on MissingPluginException {
      // Non-Android/test hosts simply keep the normal Web start page.
    } on PlatformException {
      // A stale/missing voice request must never block the browser itself.
    }
  }

  void _onWebViewCreated(int id) {
    final channel = MethodChannel('wavezero/webview/$id');
    channel.setMethodCallHandler(_handleWebEvent);
    final pendingVoiceUrl = _pendingVoiceUrl;
    if (pendingVoiceUrl != null) {
      _pendingVoiceUrl = null;
      unawaited(channel.invokeMethod<void>('loadUrl', {'url': pendingVoiceUrl}));
    }
    if (!mounted) return;
    setState(() => _webChannel = channel);
  }

  Future<Object?> _handleWebEvent(MethodCall call) async {
    final raw = call.arguments;
    final args = raw is Map ? raw.cast<Object?, Object?>() : const <Object?, Object?>{};
    switch (call.method) {
      case 'pageStarted':
        if (!mounted) break;
        setState(() {
          _currentUrl = args['url']?.toString() ?? _currentUrl;
          _progress = 4;
          _pageError = null;
        });
        break;
      case 'pageFinished':
        if (!mounted) break;
        final url = args['url']?.toString() ?? _currentUrl;
        final title = args['title']?.toString().trim() ?? '';
        setState(() {
          _currentUrl = url;
          _pageTitle = title;
          _addressController.text = _currentUrl;
          _canGoBack = args['canGoBack'] == true;
          _canGoForward = args['canGoForward'] == true;
          _progress = 100;
        });
        unawaited(_recordVisit(url: url, title: title));
        break;
      case 'progress':
        if (!mounted) break;
        final rawProgress = args['progress'] is num ? (args['progress'] as num).toInt() : 0;
        setState(() => _progress = rawProgress.clamp(0, 100).toInt());
        break;
      case 'downloadStarted':
        final task = WzWebDownloadTask.fromMap(args);
        if (!mounted) break;
        setState(() {
          _download = task;
          _lastDownloadSampleBytes = task.downloadedBytes;
          _lastDownloadSampleAt = DateTime.now();
          _downloadBytesPerSecond = null;
        });
        _startDownloadPolling(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading ${task.fileName} to Music/WaveZero')),
        );
        break;
      case 'downloadRejected':
        if (!mounted) break;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(args['message']?.toString() ?? 'WaveZero only saves supported audio files.')),
        );
        break;
      case 'webError':
        if (!mounted) break;
        setState(() => _pageError = args['description']?.toString() ?? 'This page could not be loaded.');
        break;
    }
    return null;
  }

  Future<void> _recordVisit({required String url, required String title}) async {
    final next = _webLibrary.recordVisit(
      url: url,
      title: title,
      visitedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (identical(next, _webLibrary)) return;
    _webLibrary = next;
    await _webLibraryService.save(next);
    if (mounted) setState(() {});
  }

  void _startDownloadPolling(int id) {
    _downloadPoller?.cancel();
    _downloadPoller = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      try {
        final task = await _downloadService.query(id);
        if (!mounted) return;
        _updateDownloadRate(task);
        setState(() => _download = task);
        if (!task.isTerminal) return;
        _downloadPoller?.cancel();
        if (task.isSuccessful) {
          unawaited(_deviceMusicService.scanDeviceAudioLibrary());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${task.fileName} is ready in WaveZero Device Music.')),
          );
        }
      } catch (_) {
        // Android DownloadManager remains the source of truth. A transient
        // polling failure should not cancel a download already in progress.
      }
    });
  }

  void _updateDownloadRate(WzWebDownloadTask task) {
    final now = DateTime.now();
    final previousBytes = _lastDownloadSampleBytes;
    final previousAt = _lastDownloadSampleAt;
    if (previousBytes != null && previousAt != null && task.downloadedBytes >= previousBytes) {
      final seconds = now.difference(previousAt).inMilliseconds / 1000;
      final delta = task.downloadedBytes - previousBytes;
      if (seconds > 0 && delta > 0) {
        final instant = delta / seconds;
        _downloadBytesPerSecond = _downloadBytesPerSecond == null
            ? instant
            : (_downloadBytesPerSecond! * .6) + (instant * .4);
      }
    }
    _lastDownloadSampleBytes = task.downloadedBytes;
    _lastDownloadSampleAt = now;
  }

  Future<void> _loadAddress() async {
    final url = wzResolveWebLocation(_addressController.text);
    await _loadLocation(url);
  }

  Future<void> _loadLocation(String url) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _currentUrl = wzResolveWebLocation(url);
      _pageError = null;
    });
    await _webChannel?.invokeMethod<void>('loadUrl', {'url': _currentUrl});
  }

  Future<void> _goBack() async {
    await _webChannel?.invokeMethod<void>('goBack');
  }

  Future<void> _goForward() async {
    await _webChannel?.invokeMethod<void>('goForward');
  }

  Future<void> _reload() async {
    await _webChannel?.invokeMethod<void>('reload');
  }

  Future<void> _toggleBookmark() async {
    final next = _webLibrary.toggleBookmark(
      url: _currentUrl,
      title: _pageTitle,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _webLibraryService.save(next);
    if (!mounted) return;
    setState(() => _webLibrary = next);
  }

  Future<void> _clearHistory() async {
    final next = _webLibrary.clearHistory();
    await _webLibraryService.save(next);
    if (!mounted) return;
    setState(() => _webLibrary = next);
  }

  Future<void> _openExternal() async {
    await _webChannel?.invokeMethod<void>('openExternal', {'url': _currentUrl});
  }

  Future<void> _shareCurrent() async {
    await _webChannel?.invokeMethod<void>('shareUrl', {'url': _currentUrl});
  }

  Future<void> _openSavedAndRecent() async {
    final selectedUrl = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: WzColors.canvas,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .76,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 10, 8),
                child: Row(
                  children: [
                    Expanded(child: Text('Web library', style: WzText.title.copyWith(fontSize: 19))),
                    TextButton(
                      onPressed: _webLibrary.history.isEmpty
                          ? null
                          : () async {
                              await _clearHistory();
                              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                            },
                      child: const Text('Clear history'),
                    ),
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Saved'),
                  Tab(text: 'Recent'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _WebPageList(
                      pages: _webLibrary.bookmarks,
                      emptyLabel: 'No saved pages yet.',
                      onOpen: (url) => Navigator.of(sheetContext).pop(url),
                    ),
                    _WebPageList(
                      pages: _webLibrary.history,
                      emptyLabel: 'No browsing history yet.',
                      onOpen: (url) => Navigator.of(sheetContext).pop(url),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selectedUrl == null) return;
    _addressController.text = selectedUrl;
    await _loadLocation(selectedUrl);
  }

  Future<void> _cancelDownload() async {
    final task = _download;
    if (task == null || task.isTerminal) return;
    await _downloadService.cancel(task.id);
    _downloadPoller?.cancel();
    if (!mounted) return;
    setState(() {
      _download = WzWebDownloadTask(
        id: task.id,
        status: 'cancelled',
        fileName: task.fileName,
        downloadedBytes: task.downloadedBytes,
        totalBytes: task.totalBytes,
      );
      _downloadBytesPerSecond = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final download = _download;
    final bookmarked = _webLibrary.isBookmarked(_currentUrl);
    return Scaffold(
      backgroundColor: WzColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _BrowserHeader(onClose: () => Navigator.of(context).pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: _AddressBar(
                controller: _addressController,
                onSubmitted: (_) => _loadAddress(),
                onGo: _loadAddress,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 10, 8),
              child: Row(
                children: [
                  WzSculptedIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    size: 42,
                    iconSize: 20,
                    onPressed: _canGoBack ? _goBack : null,
                  ),
                  const SizedBox(width: 7),
                  WzSculptedIconButton(
                    icon: Icons.arrow_forward_rounded,
                    tooltip: 'Forward',
                    size: 42,
                    iconSize: 20,
                    onPressed: _canGoForward ? _goForward : null,
                  ),
                  const SizedBox(width: 7),
                  WzSculptedIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh',
                    size: 42,
                    iconSize: 19,
                    onPressed: _reload,
                  ),
                  const Spacer(),
                  WzSculptedIconButton(
                    icon: bookmarked ? Icons.star_rounded : Icons.star_border_rounded,
                    tooltip: bookmarked ? 'Remove bookmark' : 'Save page',
                    selected: bookmarked,
                    size: 42,
                    iconSize: 19,
                    onPressed: _toggleBookmark,
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Web options',
                    icon: const Icon(Icons.more_horiz_rounded, color: WzColors.textMuted),
                    onSelected: (value) {
                      switch (value) {
                        case 'library':
                          unawaited(_openSavedAndRecent());
                        case 'external':
                          unawaited(_openExternal());
                        case 'share':
                          unawaited(_shareCurrent());
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'library', child: Text('Saved & recent')),
                      PopupMenuItem(value: 'external', child: Text('Open in browser')),
                      PopupMenuItem(value: 'share', child: Text('Share link')),
                    ],
                  ),
                ],
              ),
            ),
            if (_progress > 0 && _progress < 100)
              LinearProgressIndicator(value: _progress / 100, minHeight: 2),
            if (_pageError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Text(_pageError!, style: WzText.caption.copyWith(color: WzColors.warning)),
              ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                child: Platform.isAndroid
                    ? AndroidView(
                        viewType: 'wavezero/native_webview',
                        creationParams: <String, Object?>{'url': _currentUrl},
                        creationParamsCodec: const StandardMessageCodec(),
                        onPlatformViewCreated: _onWebViewCreated,
                      )
                    : const Center(child: Text('WaveZero Web is available on Android.')),
              ),
            ),
            if (download != null)
              _DownloadStrip(
                task: download,
                bytesPerSecond: _downloadBytesPerSecond,
                onCancel: download.isTerminal ? null : _cancelDownload,
                onClose: download.isTerminal ? () => setState(() => _download = null) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _BrowserHeader extends StatelessWidget {
  const _BrowserHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 7),
        child: Row(
          children: [
            const WzSculptedIcon(icon: Icons.language_rounded, size: 42, iconSize: 19, color: WzColors.accent),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WaveZero Web', style: WzText.title.copyWith(fontSize: 19)),
                  Text('Find it. Save it. It lands in Device Music.', style: WzText.caption),
                ],
              ),
            ),
            IconButton(onPressed: onClose, tooltip: 'Back to WaveZero', icon: const Icon(Icons.close_rounded)),
          ],
        ),
      );
}

class _AddressBar extends StatelessWidget {
  const _AddressBar({required this.controller, required this.onSubmitted, required this.onGo});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(13, 2, 4, 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: WzColors.borderSoft),
          boxShadow: WzSurface.softShadows,
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20, color: WzColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.go,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: onSubmitted,
                decoration: const InputDecoration(
                  hintText: 'Search the web or enter an address',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            IconButton(onPressed: onGo, tooltip: 'Go', icon: const Icon(Icons.arrow_forward_rounded, size: 20)),
          ],
        ),
      );
}

class _WebPageList extends StatelessWidget {
  const _WebPageList({
    required this.pages,
    required this.emptyLabel,
    required this.onOpen,
  });

  final List<WzWebPageRecord> pages;
  final String emptyLabel;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) return Center(child: Text(emptyLabel, style: WzText.caption));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      itemCount: pages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 7),
      itemBuilder: (context, index) {
        final page = pages[index];
        final host = Uri.tryParse(page.url)?.host ?? page.url;
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          leading: const Icon(Icons.language_rounded, color: WzColors.accent),
          title: Text(page.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(host, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          onTap: () => onOpen(page.url),
        );
      },
    );
  }
}

class _DownloadStrip extends StatelessWidget {
  const _DownloadStrip({
    required this.task,
    this.bytesPerSecond,
    this.onCancel,
    this.onClose,
  });

  final WzWebDownloadTask task;
  final double? bytesPerSecond;
  final VoidCallback? onCancel;
  final VoidCallback? onClose;

  String get _statusLabel => switch (task.status) {
        'pending' => 'Waiting…',
        'running' => 'Downloading…',
        'paused' => 'Paused',
        'successful' => 'Added to Device Music',
        'failed' => 'Download failed',
        'cancelled' => 'Cancelled',
        _ => task.status,
      };

  String get _transferLabel {
    if (task.downloadedBytes <= 0) return _statusLabel;
    final parts = <String>[_statusLabel];
    if (task.totalBytes > 0) {
      parts.add('${wzFormatWebTransferBytes(task.downloadedBytes)} / ${wzFormatWebTransferBytes(task.totalBytes)}');
    } else {
      parts.add(wzFormatWebTransferBytes(task.downloadedBytes));
    }
    final rate = wzFormatWebTransferRate(bytesPerSecond ?? 0);
    if (rate.isNotEmpty && !task.isTerminal) parts.add(rate);
    final eta = wzFormatWebTransferEta(
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
      bytesPerSecond: bytesPerSecond ?? 0,
    );
    if (eta.isNotEmpty && !task.isTerminal) parts.add(eta);
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final progress = task.progress;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
      decoration: WzSurface.sculpted(selected: task.isSuccessful),
      child: Row(
        children: [
          Icon(task.isSuccessful ? Icons.download_done_rounded : Icons.downloading_rounded, color: task.isSuccessful ? WzColors.success : WzColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.sectionTitle.copyWith(fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(_transferLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: WzText.caption),
                if (progress != null && !task.isTerminal) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: progress, minHeight: 3),
                ],
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(onPressed: onCancel, tooltip: 'Cancel download', icon: const Icon(Icons.close_rounded, size: 19))
          else if (onClose != null)
            IconButton(onPressed: onClose, tooltip: 'Dismiss', icon: const Icon(Icons.done_rounded, size: 19)),
        ],
      ),
    );
  }
}
