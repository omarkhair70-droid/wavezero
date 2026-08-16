from __future__ import annotations

import re
from pathlib import Path

TARGET = Path("apps/flutter/wavezero_app/lib/app/wavezero_app.dart")
IMPORT = "import '../features/library/library_catalog_items.dart';\n"
RETIRED_CLASSES = [
    "_FeaturedDemoLibraryShelf",
    "_CuratedPickCard",
    "_CuratedPickText",
    "_SourceBadge",
    "_LicenseBadge",
    "_CatalogRow",
]


def find_matching_brace(text: str, opening: int) -> int:
    depth = 0
    i = opening
    quote: str | None = None
    triple = False
    line_comment = False
    block_comment = 0
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if line_comment:
            if ch == "\n":
                line_comment = False
            i += 1
            continue
        if block_comment:
            if ch == "/" and nxt == "*":
                block_comment += 1
                i += 2
                continue
            if ch == "*" and nxt == "/":
                block_comment -= 1
                i += 2
                continue
            i += 1
            continue
        if quote is not None:
            if triple:
                if text.startswith(quote * 3, i):
                    quote = None
                    triple = False
                    i += 3
                    continue
                i += 1
                continue
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch == "/" and nxt == "/":
            line_comment = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            block_comment = 1
            i += 2
            continue
        if ch in {"'", '"'}:
            if text.startswith(ch * 3, i):
                quote = ch
                triple = True
                i += 3
            else:
                quote = ch
                i += 1
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise RuntimeError("Unbalanced Dart braces")


def remove_class(text: str, name: str) -> str:
    match = re.search(rf"(?m)^class\s+{re.escape(name)}\b", text)
    if match is None:
        raise RuntimeError(f"Expected class {name} was not found")
    opening = text.find("{", match.end())
    closing = find_matching_brace(text, opening)
    start = match.start()
    if start > 0 and text[start - 1] == "\n":
        start -= 1
    end = closing + 1
    while end < len(text) and text[end] in " \t":
        end += 1
    if end < len(text) and text[end] == "\n":
        end += 1
    return text[:start] + text[end:]


def remove_function(text: str, signature: str) -> str:
    match = re.search(rf"(?m)^String\s+{re.escape(signature)}\b", text)
    if match is None:
        raise RuntimeError(f"Expected function {signature} was not found")
    opening = text.find("{", match.end())
    if opening < 0:
        raise RuntimeError(f"Opening brace for function {signature} not found")
    closing = find_matching_brace(text, opening)
    start = match.start()
    if start > 0 and text[start - 1] == "\n":
        start -= 1
    end = closing + 1
    if end < len(text) and text[end] == "\n":
        end += 1
    return text[:start] + text[end:]


def main() -> None:
    text = TARGET.read_text(encoding="utf-8")
    original = text

    if IMPORT not in text:
        anchor = "import '../features/library/library_source_overview.dart';\n"
        if anchor not in text:
            raise RuntimeError("Library source overview import anchor missing")
        text = text.replace(anchor, anchor + IMPORT, 1)

    featured_old = "        _FeaturedDemoLibraryShelf(picks: curatedPicks, onPlayPick: onPlayCuratedPick),"
    featured_new = "        WzFeaturedDemoLibraryShelf(picks: curatedPicks, onPlayPick: onPlayCuratedPick),"
    if text.count(featured_old) != 1:
        raise RuntimeError("Expected exactly one active featured Library shelf callsite")
    text = text.replace(featured_old, featured_new, 1)

    row_old = "                return _CatalogRow("
    row_new = "                return WzLibraryCatalogRow("
    if text.count(row_old) != 1:
        raise RuntimeError("Expected exactly one active Catalog row callsite")
    text = text.replace(row_old, row_new, 1)

    for name in RETIRED_CLASSES:
        text = remove_class(text, name)

    text = remove_function(text, "_licenseBadgeLabel")

    subtitle_pattern = re.compile(r"(?m)^String _trackSubtitle\(CatalogTrackSummary track\) \{.*\}\n?")
    text, subtitle_count = subtitle_pattern.subn("", text, count=1)
    if subtitle_count != 1:
        raise RuntimeError("Expected one _trackSubtitle helper")

    retired_symbols = RETIRED_CLASSES + ["_licenseBadgeLabel", "_trackSubtitle"]
    for retired in retired_symbols:
        if re.search(rf"\b{re.escape(retired)}\b", text):
            raise RuntimeError(f"Refusing wiring: retired symbol still referenced: {retired}")

    if text.count("WzFeaturedDemoLibraryShelf(") != 1:
        raise RuntimeError("Featured Library shelf wiring count is not exactly one")
    if text.count("WzLibraryCatalogRow(") != 1:
        raise RuntimeError("Library Catalog row wiring count is not exactly one")
    if text == original:
        raise RuntimeError("Wiring produced no change")

    TARGET.write_text(text, encoding="utf-8")
    print(f"Wired Library catalog items; net line delta: {text.count(chr(10)) - original.count(chr(10))}.")


if __name__ == "__main__":
    main()
