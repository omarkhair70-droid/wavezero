from pathlib import Path

repo = Path('.')
app_path = repo / 'apps/flutter/wavezero_app/lib/app/wavezero_app.dart'
main_path = repo / 'apps/flutter/wavezero_app/android/app/src/main/kotlin/com/omarkhair/wavezero/MainActivity.kt'

app = app_path.read_text()

import_anchor = "import '../features/collections/collection_mutations.dart';\n"
portability_import = "import '../features/collections/playlist_portability.dart';\n"
if portability_import not in app:
    if import_anchor not in app:
        raise SystemExit('collection import anchor not found')
    app = app.replace(import_anchor, import_anchor + portability_import, 1)

method_anchor = "  Future<void> _renameCollection(WzCollection collection, String name) async {\n"
if 'Future<void> _bulkRemoveCollectionTracks(' not in app:
    if method_anchor not in app:
        raise SystemExit('rename collection method anchor not found')
    methods = r'''  Future<void> _bulkRemoveCollectionTracks(
    WzCollection collection,
    List<WzCollectionTrackSnapshot> tracks,
  ) async {
    if (tracks.isEmpty) return;
    final ids = tracks.map((track) => track.trackId).toSet();
    final nextCollections = wzRemoveCollectionTracks(
      collections: _collections,
      collectionId: collection.id,
      trackIds: ids,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistCollections(nextCollections);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed ${tracks.length} tracks from ${collection.name}')),
    );
  }

  Future<void> _bulkAddCollectionTracks(
    WzCollection destination,
    List<WzCollectionTrackSnapshot> tracks,
  ) async {
    if (tracks.isEmpty) return;
    final nextCollections = wzUpsertCollectionTracks(
      collections: _collections,
      collectionId: destination.id,
      snapshots: tracks,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistCollections(nextCollections);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${tracks.length} tracks to ${destination.name}')),
    );
  }

  Future<void> _bulkQueueCollectionTracks(
    WzCollection collection,
    List<WzCollectionTrackSnapshot> tracks,
  ) async {
    if (tracks.isEmpty) return;
    final nextQueue = _queue.toList(growable: true);
    final existing = nextQueue.map((track) => track.trackId).toSet();
    var added = 0;
    var unavailable = 0;
    for (final snapshot in tracks) {
      final resolved = _resolveCollectionTrack(snapshot);
      if (resolved == null) {
        unavailable += 1;
        continue;
      }
      if (existing.add(resolved.trackId)) {
        nextQueue.add(resolved);
        added += 1;
      }
    }
    if (added > 0) {
      setState(() {
        _queue = nextQueue;
        _queueCurrentTrackId ??= _queue.isEmpty ? null : _queue.first.trackId;
        _queueStatus = 'Added $added selected tracks. $unavailable unavailable.';
        _sessionStatus = 'Session saved.';
      });
      unawaited(_saveSession());
      unawaited(_pushNotificationQueueSnapshot());
      unawaited(_updatePredictivePreloadCandidate());
      unawaited(_maybeAutoCacheNextQueuedTrack());
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Queued $added tracks. $unavailable unavailable.')),
    );
  }

  Future<void> _importM3uCollection() async {
    try {
      if (_deviceMusicPermissionStatus.status == 'granted') {
        await _importDeviceMusic();
      }
      final payload = await const WzPlaylistFileService().importM3u();
      if (payload == null || !mounted) return;
      final entries = wzParseM3u(payload.content);
      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That playlist does not contain any tracks.')),
        );
        return;
      }
      final resolution = wzResolveM3uEntries(
        entries: entries,
        libraryTracks: _resolvableLibraryTracks,
      );
      if (resolution.matched.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No matching tracks found for ${entries.length} playlist entries.')),
        );
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final collection = WzCollection(
        id: 'collection-m3u-$now',
        name: wzPlaylistNameFromFile(payload.name),
        type: WzCollectionType.user,
        createdAtMs: now,
        updatedAtMs: now,
        tracks: resolution.matched.map(_snapshotForTrack).toList(growable: false),
      );
      await _persistCollections([..._collections, collection]);
      if (!mounted) return;
      setState(() => _selectedCollectionId = collection.id);
      _navigateTo(WzAppTab.collectionDetail);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${resolution.matched.length} tracks'
            '${resolution.unmatched.isEmpty ? '' : ' • ${resolution.unmatched.length} unmatched'}',
          ),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not import playlist.')),
      );
    }
  }

  Future<void> _exportCollectionM3u(WzCollection collection) async {
    if (collection.tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add tracks before exporting this playlist.')),
      );
      return;
    }
    try {
      final uri = await const WzPlaylistFileService().exportM3u(
        fileName: wzPlaylistFileName(collection.name),
        content: wzSerializeM3u(collection),
      );
      if (uri == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported ${collection.name} as M3U')),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not export playlist.')),
      );
    }
  }

'''
    app = app.replace(method_anchor, methods + method_anchor, 1)

collections_anchor = "        onCreate: _createCollectionFromPage,\n        onRename: _showRenameCollectionDialog,\n"
if 'onImportM3u:' not in app:
    if collections_anchor not in app:
        raise SystemExit('collections page wiring anchor not found')
    app = app.replace(
        collections_anchor,
        "        onCreate: _createCollectionFromPage,\n        onImportM3u: () => unawaited(_importM3uCollection()),\n        onRename: _showRenameCollectionDialog,\n",
        1,
    )

detail_anchor = "      WzCollectionDetailPage(\n        collection: _selectedCollection ?? _likedCollection,\n"
if '        collections: _collections,\n' not in app:
    if detail_anchor not in app:
        raise SystemExit('collection detail anchor not found')
    app = app.replace(
        detail_anchor,
        detail_anchor + "        collections: _collections,\n",
        1,
    )

reorder_anchor = "        onReorderTrack: (collection, oldIndex, newIndex) =>\n            unawaited(_reorderCollectionTracks(collection, oldIndex, newIndex)),\n        resolver: _resolveCollectionTrack,\n"
if 'onBulkAddToQueue:' not in app:
    if reorder_anchor not in app:
        raise SystemExit('collection reorder wiring anchor not found')
    replacement = """        onReorderTrack: (collection, oldIndex, newIndex) =>
            unawaited(_reorderCollectionTracks(collection, oldIndex, newIndex)),
        onBulkAddToQueue: (collection, tracks) =>
            unawaited(_bulkQueueCollectionTracks(collection, tracks)),
        onBulkRemove: (collection, tracks) =>
            unawaited(_bulkRemoveCollectionTracks(collection, tracks)),
        onBulkAddToCollection: (source, destination, tracks) =>
            unawaited(_bulkAddCollectionTracks(destination, tracks)),
        onExportM3u: (collection) => unawaited(_exportCollectionM3u(collection)),
        resolver: _resolveCollectionTrack,
"""
    app = app.replace(reorder_anchor, replacement, 1)

app_path.write_text(app)

main = main_path.read_text()
if 'import android.content.Intent\n' not in main:
    main = main.replace('import android.content.Context\n', 'import android.content.Context\nimport android.content.Intent\n', 1)

property_anchor = '    private var pendingDeviceMusicPermissionResult: MethodChannel.Result? = null\n'
if 'private var playlistFileBridge:' not in main:
    if property_anchor not in main:
        raise SystemExit('MainActivity property anchor not found')
    main = main.replace(
        property_anchor,
        property_anchor + '    private var playlistFileBridge: WaveZeroPlaylistFileBridge? = null\n',
        1,
    )

webview_anchor = '''        flutterEngine.platformViewsController.registry.registerViewFactory(
            WaveZeroWebViewFactory.VIEW_TYPE,
            WaveZeroWebViewFactory(this, flutterEngine.dartExecutor.binaryMessenger),
        )

'''
if 'WaveZeroPlaylistFileBridge.CHANNEL_NAME' not in main:
    if webview_anchor not in main:
        raise SystemExit('WebView registration anchor not found')
    playlist_channel = '''        val playlistBridge = WaveZeroPlaylistFileBridge(this)
        playlistFileBridge = playlistBridge
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WaveZeroPlaylistFileBridge.CHANNEL_NAME,
        ).setMethodCallHandler(playlistBridge)

'''
    main = main.replace(webview_anchor, webview_anchor + playlist_channel, 1)

permission_anchor = '    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {\n'
if 'override fun onActivityResult(' not in main:
    if permission_anchor not in main:
        raise SystemExit('permission callback anchor not found')
    activity_result = '''    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (playlistFileBridge?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

'''
    main = main.replace(permission_anchor, activity_result + permission_anchor, 1)

destroy_anchor = '''        pendingDeviceMusicPermissionResult = null
        audioPlayerManager = null
        super.onDestroy()
'''
if 'playlistFileBridge?.dispose()' not in main:
    if destroy_anchor not in main:
        raise SystemExit('onDestroy anchor not found')
    main = main.replace(
        destroy_anchor,
        '''        pendingDeviceMusicPermissionResult = null
        playlistFileBridge?.dispose()
        playlistFileBridge = null
        audioPlayerManager = null
        super.onDestroy()
''',
        1,
    )

main_path.write_text(main)
