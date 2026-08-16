from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_live_metrics_app_v3.dart')
text = path.read_text()

anchor = "import '../shared/media/media_presentation.dart';\n"
if text.count(anchor) != 1:
    raise SystemExit(f'expected one shared media import, found {text.count(anchor)}')
text = text.replace(anchor, anchor + "import '../shared/media/track_source.dart';\n", 1)

for line in [
    "bool _isDeviceTrackId(String? trackId) => trackId != null && trackId.startsWith('device-audio-');\n\n",
    "bool _isDeviceUrl(String? url) => url != null && url.startsWith('content://');\n\n",
    "bool _isDeviceCatalogTrack(CatalogTrackSummary track) => track.source == 'device' || _isDeviceTrackId(track.trackId) || _isDeviceUrl(track.primaryAsset?.manifestUrl);\n\n",
    "bool _isCachedCatalogTrack(CatalogTrackSummary track) => track.source == 'cached' || track.primaryAsset?.assetId.startsWith('cached-') == true;\n\n",
]:
    if text.count(line) != 1:
        raise SystemExit(f'expected one source helper: {line[:48]!r}, found {text.count(line)}')
    text = text.replace(line, '', 1)

for old, new in {
    '_isDeviceTrackId': 'isWzDeviceTrackId',
    '_isDeviceUrl': 'isWzDeviceUrl',
    '_isDeviceCatalogTrack': 'isWzDeviceCatalogTrack',
    '_isCachedCatalogTrack': 'isWzCachedCatalogTrack',
}.items():
    text = text.replace(old, new)

path.write_text(text)
