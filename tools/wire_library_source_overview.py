from __future__ import annotations

import re
from pathlib import Path

TARGET = Path("apps/flutter/wavezero_app/lib/app/wavezero_app.dart")
IMPORT = "import '../features/library/library_source_overview.dart';\n"


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


def main() -> None:
    text = TARGET.read_text(encoding="utf-8")
    original = text

    if IMPORT not in text:
        anchor = "import '../features/library/library_controls.dart';\n"
        if anchor not in text:
            raise RuntimeError("Library controls import anchor missing")
        text = text.replace(anchor, anchor + IMPORT, 1)

    class_start = text.index("class _CatalogListCard extends StatelessWidget")
    build_anchor = text.index("    final hasQuery = searchController.text.trim().isNotEmpty;", class_start)
    start_marker = "        Row(children: [\n"
    start = text.index(start_marker, build_anchor)
    end_marker = "        const SizedBox(height: 12),\n        _FeaturedDemoLibraryShelf"
    end = text.index(end_marker, start)

    replacement = """        WzLibrarySourceOverview(\n          apiTrackCount: apiTrackCount,\n          deviceTrackCount: deviceTrackCount,\n          cachedTrackCount: cachedTrackCount,\n          cloudTrackCount: cloudTrackCount,\n          combinedTrackCount: combinedTrackCount,\n          cacheBytes: cacheBytes,\n          status: status,\n          loading: loading,\n          refreshDisabled: refreshDisabled,\n          librarySourceFilter: librarySourceFilter,\n          devicePermissionStatus: devicePermissionStatus,\n          deviceScanStatus: deviceScanStatus,\n          deviceLastError: deviceLastError,\n          onSourceFilterChanged: onSourceFilterChanged,\n          onRefresh: onRefresh,\n          onImportDeviceMusic: onImportDeviceMusic,\n          onOpenCollections: onOpenCollections,\n          onOpenFullSearch: onOpenFullSearch,\n          onOpenCloudVault: onOpenCloudVault,\n        ),\n"""
    text = text[:start] + replacement + text[end:]

    text = remove_class(text, "_LibrarySourceSummaryCard")

    helper_start_marker = "\nIconData _librarySourceFilterIcon(WzLibrarySourceFilter filter)"
    helper_end_marker = "\n\nclass _SourceBadge extends StatelessWidget"
    helper_start = text.find(helper_start_marker)
    helper_end = text.find(helper_end_marker, helper_start)
    if helper_start < 0 or helper_end < 0:
        raise RuntimeError("Library source helper block was not found")
    text = text[:helper_start] + text[helper_end:]

    for retired in ("_LibrarySourceSummaryCard", "_librarySourceFilterIcon", "_librarySourceFilterShortLabel"):
        if re.search(rf"\b{re.escape(retired)}\b", text):
            raise RuntimeError(f"Refusing wiring: retired symbol still referenced: {retired}")

    if "WzLibrarySourceOverview(" not in text:
        raise RuntimeError("New Library source overview callsite was not installed")
    if text.count("WzLibrarySourceOverview(") != 1:
        raise RuntimeError("Expected exactly one Library source overview callsite")
    if text == original:
        raise RuntimeError("Wiring produced no change")

    TARGET.write_text(text, encoding="utf-8")
    print(f"Wired Library source overview; net line delta: {text.count(chr(10)) - original.count(chr(10))}.")


if __name__ == "__main__":
    main()
