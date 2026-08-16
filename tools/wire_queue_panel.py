from __future__ import annotations

import re
from pathlib import Path

TARGET = Path("apps/flutter/wavezero_app/lib/app/wavezero_app.dart")
IMPORT = "import '../features/queue/queue_panel.dart';\n"
RETIRED = ["_QueueCard", "_QueueStateChip", "_QueueRow"]


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
        anchor = "import '../features/queue/queue_position.dart';\n"
        if anchor not in text:
            raise RuntimeError("Queue import anchor missing")
        text = text.replace(anchor, anchor + IMPORT, 1)

    old = "          _QueueCard("
    new = "          WzQueuePanel("
    if text.count(old) != 1:
        raise RuntimeError("Expected exactly one active _QueueCard callsite")
    text = text.replace(old, new, 1)

    for name in RETIRED:
        text = remove_class(text, name)

    for name in RETIRED:
        if re.search(rf"\b{re.escape(name)}\b", text):
            raise RuntimeError(f"Refusing wiring: retired Queue symbol still referenced: {name}")
    if text.count("WzQueuePanel(") != 1:
        raise RuntimeError("Expected exactly one WzQueuePanel callsite")
    if text == original:
        raise RuntimeError("Wiring produced no change")

    TARGET.write_text(text, encoding="utf-8")
    print(f"Wired Queue panel; net line delta: {text.count(chr(10)) - original.count(chr(10))}.")


if __name__ == "__main__":
    main()
