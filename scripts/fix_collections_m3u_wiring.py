from pathlib import Path

path = Path('apps/flutter/wavezero_app/lib/app/wavezero_app.dart')
text = path.read_text()
anchor = "      WzCollectionDetailPage(\n        collection: _selectedCollection ?? _likedCollection,\n"
replacement = anchor + "        collections: _collections,\n"
if replacement not in text:
    if anchor not in text:
        raise SystemExit('collection detail anchor not found')
    text = text.replace(anchor, replacement, 1)
path.write_text(text)
