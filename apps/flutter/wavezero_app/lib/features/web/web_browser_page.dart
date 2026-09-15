import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/wavezero_design_system.dart';
import '../device_music/device_music_service.dart';
import 'web_download_service.dart';

String wzResolveWebLocation(String input) {
  final value = input.trim();
  if (value.isEmpty) return 'https://www.google.com';
  final parsed = Uri.tryParse(value);
  if (parsed != null && (parsed.scheme == 'https' || parsed.scheme == 'http') && parsed.host.isNotEmpty) {
    return parsed.toString();
  }
  return Uri.https('www.google.com', '/search', {'q': value}).toString();
}

class WzWebBrowserPage extends StatefulWidget {
  const WzWebBrowserPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<WzWebBrowserPage> createState() => _WzWebBrowserPageState();
}

class _WzWebBrowserPageState extends State<WzWebBrowserPage> {
  final WzWebDownloadService _downloadService = WzWebDownloadService();
  final DeviceMusicService _deviceMusicService = DeviceMusicService();
  late final TextEditingController _addressController;

  MethodChannel? _webChannel;
  Timer? _downloadPoller;
  WzWebDownloadTask? _download;
  String _currentUrl = '';
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _currentUrl = wzResolveWebLocation(widget.initialQuery);
    _addressController = TextEditingController(text: widget.initialQuery.trim().isEmpty ? _currentUrl : widget.initialQuery.trim());
  }

  @override
  void dispose() {
    _downloadPoller?.cancel();
    _webChannel?.setMethodCallHandler(null);
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _onWebViewCreated(int id) async {
    final channel = MethodChannel('wavezero/webview/$id');
    await channel.setMethodCallHandler(_handleWebEvent);
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
        setState(() {
          _currentUrl = args['url']?.toString() ?? _currentUrl;
          _addressController.text = _currentUrl;
          _canGoBack = args['canGoBack'] == true;
          _canGoForward = args['canGoForward'] == true;
          _progress = 100;
        });
        break;
      case 'progress':
        if (!mounted) break;
        setState(() => _progress = (args['progress'] is num ? (args['progress'] as num).toInt() : 0).clamp(0, 100));
        break;
      case 'downloadStarted':
        final task = WzWebDownloadTask.fromMap(args);
        if (!mounted) break;
        setState(() => _download = task);
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

  void _startDownloadPolling(int id) {
    _downloadPoller?.cancel();
    _downloadPoller = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      try {
        final task = await _downloadService.query(id);
        if (!mounted) return;
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
        // Android's DownloadManager remains the source of truth. A transient
        // polling failure should not cancel a download already in progress.
      }
    });
  }

  Future<void> _loadAddress() async {
    final url = wzResolveWebLocation(_addressController.text);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _currentUrl = url;
      _pageError = null;
    });
    await _webChannel?.invokeMethod<void>('loadUrl', {'url': url});
  }

  Future<void> _goBack() async => _webChannel?.invokeMethod<void>('goBack');
  Future<void> _goForward() async => _webChannel?.invokeMethod<void>('goForward');
  Future<void> _reload() async => _webChannel?.invokeMethod<void>('reload');

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final download = _download;
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
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  WzSculptedIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    size: 42,
                    iconSize: 20,
                    onPressed: _canGoBack ? _goBack : null,
                  ),
                  const SizedBox(width: 8),
                  WzSculptedIconButton(
                    icon: Icons.arrow_forward_rounded,
                    tooltip: 'Forward',
                    size: 42,
                    iconSize: 20,
                    onPressed: _canGoForward ? _goForward : null,
                  ),
                  const SizedBox(width: 8),
                  WzSculptedIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh',
                    size: 42,
                    iconSize: 19,
                    onPressed: _reload,
                  ),
                  const Spacer(),
                  Text('Web', style: WzText.eyebrow),
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

class _DownloadStrip extends StatelessWidget {
  const _DownloadStrip({required this.task, this.onCancel, this.onClose});

  final WzWebDownloadTask task;
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
                Text(_statusLabel, style: WzText.caption),
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
