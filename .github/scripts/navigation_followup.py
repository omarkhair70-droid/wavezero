from pathlib import Path

repo = Path(__file__).resolve().parents[2]
path = repo / 'apps/flutter/wavezero_app/lib/app/wavezero_app.dart'
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one match, got {count}')
    text = text.replace(old, new, 1)


replace_once(
    '''  List<CatalogTrackSummary> get _libraryTracks => composeWzLibraryTracks(
    filter: _librarySourceFilter,
    catalogTracks: _catalog,
    deviceTracks: _deviceCatalogTracks,
    downloadedTracks: _cachedCatalogTracks,
    cloudTracks: _developerMode
        ? _cloudCatalogTracks
        : const <CatalogTrackSummary>[],
  );

  int get _libraryTotalTrackCount => _libraryTracks.length;
''',
    '''  List<CatalogTrackSummary> get _libraryTracks => composeWzLibraryTracks(
    filter: _librarySourceFilter,
    catalogTracks: _catalog,
    deviceTracks: _deviceCatalogTracks,
    downloadedTracks: _cachedCatalogTracks,
    cloudTracks: _developerMode
        ? _cloudCatalogTracks
        : const <CatalogTrackSummary>[],
  );

  List<CatalogTrackSummary> get _resolvableLibraryTracks => composeWzLibraryTracks(
    filter: WzLibrarySourceFilter.all,
    catalogTracks: _catalog,
    deviceTracks: _deviceCatalogTracks,
    downloadedTracks: _cachedCatalogTracks,
    cloudTracks: _developerMode
        ? _cloudCatalogTracks
        : const <CatalogTrackSummary>[],
  );

  int get _libraryTotalTrackCount => _libraryTracks.length;
''',
    'unfiltered resolver library',
)

replace_once(
    '''  CatalogTrackSummary? _resolveCollectionTrack(
    WzCollectionTrackSnapshot snapshot,
  ) => wzResolveCollectionTrack(
    libraryTracks: _libraryTracks,
    snapshot: snapshot,
  );

  CatalogTrackSummary? _resolveHistoryEntry(WzListeningHistoryEntry entry) {
    final restoredDeviceTrack = _findDeviceTrack(entry.trackId);
    return wzResolveHistoryEntry(
      libraryTracks: _libraryTracks,
''',
    '''  CatalogTrackSummary? _resolveCollectionTrack(
    WzCollectionTrackSnapshot snapshot,
  ) => wzResolveCollectionTrack(
    libraryTracks: _resolvableLibraryTracks,
    snapshot: snapshot,
  );

  CatalogTrackSummary? _resolveHistoryEntry(WzListeningHistoryEntry entry) {
    final restoredDeviceTrack = _findDeviceTrack(entry.trackId);
    return wzResolveHistoryEntry(
      libraryTracks: _resolvableLibraryTracks,
''',
    'collection and history resolution',
)

replace_once(
    '''  Future<void> _createCollectionFromPage() async {
    final collection = await _createCollection(
      name: _userCollections.isEmpty ? 'My Collection' : 'New Collection',
    );
    if (!mounted) return;
    setState(() {
      _selectedCollectionId = collection.id;
      _selectedTab = WzAppTab.collectionDetail;
    });
  }

  void _openCollection(WzCollection collection) {
    setState(() {
      _selectedCollectionId = collection.id;
      _selectedTab = WzAppTab.collectionDetail;
    });
  }
''',
    '''  Future<void> _createCollectionFromPage() async {
    final collection = await _createCollection(
      name: _userCollections.isEmpty ? 'My Collection' : 'New Collection',
    );
    if (!mounted) return;
    _selectedCollectionId = collection.id;
    _navigateTo(WzAppTab.collectionDetail);
  }

  void _openCollection(WzCollection collection) {
    _selectedCollectionId = collection.id;
    _navigateTo(WzAppTab.collectionDetail);
  }
''',
    'collection detail navigation',
)

replace_once(
    '''  Future<void> _deleteCollection(WzCollection collection) async {
    if (collection.type == WzCollectionType.liked) return;
    await _persistCollections(
      wzDeleteCollection(
        collections: _collections,
        collectionId: collection.id,
      ),
    );
    if (!mounted) return;
    setState(() => _selectedCollectionId = likedTracksCollectionId);
  }
''',
    '''  Future<void> _deleteCollection(WzCollection collection) async {
    if (collection.type == WzCollectionType.liked) return;
    final deletingOpenDetail =
        _selectedTab == WzAppTab.collectionDetail &&
        _selectedCollectionId == collection.id;
    await _persistCollections(
      wzDeleteCollection(
        collections: _collections,
        collectionId: collection.id,
      ),
    );
    if (!mounted) return;
    setState(() => _selectedCollectionId = likedTracksCollectionId);
    if (deletingOpenDetail) _navigateBack(fallback: WzAppTab.collections);
  }
''',
    'delete open collection navigation',
)

path.write_text(text)
