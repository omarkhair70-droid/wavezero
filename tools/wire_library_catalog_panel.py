from __future__ import annotations

import re
from pathlib import Path

TARGET = Path("apps/flutter/wavezero_app/lib/app/wavezero_app.dart")
NEW_IMPORT = "import '../features/library/library_catalog_panel.dart';\n"
OLD_IMPORTS = [
    "import '../features/library/library_source_overview.dart';\n",
    "import '../features/library/library_catalog_items.dart';\n",
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


def main() -> None:
    text = TARGET.read_text(encoding="utf-8")
    original = text

    for old_import in OLD_IMPORTS:
        if old_import not in text:
            raise RuntimeError(f"Expected old Library import missing: {old_import.strip()}")
        text = text.replace(old_import, "", 1)

    if NEW_IMPORT not in text:
        anchor = "import '../features/library/library_controls.dart';\n"
        if anchor not in text:
            raise RuntimeError("Library controls import anchor missing")
        text = text.replace(anchor, anchor + NEW_IMPORT, 1)

    call_old = "          _CatalogListCard("
    call_new = "          WzLibraryCatalogPanel("
    if text.count(call_old) != 1:
        raise RuntimeError("Expected exactly one active _CatalogListCard callsite")
    text = text.replace(call_old, call_new, 1)

    text = remove_class(text, "_CatalogListCard")

    if re.search(r"\b_CatalogListCard\b", text):
        raise RuntimeError("Refusing wiring: _CatalogListCard is still referenced")
    if text.count("WzLibraryCatalogPanel(") != 1:
        raise RuntimeError("Expected exactly one WzLibraryCatalogPanel callsite")
    if text == original:
        raise RuntimeError("Wiring produced no change")

    TARGET.write_text(text, encoding="utf-8")
    print(f"Wired Library catalog panel; net line delta: {text.count(chr(10)) - original.count(chr(10))}.")


if __name__ == "__main__":
    main()
