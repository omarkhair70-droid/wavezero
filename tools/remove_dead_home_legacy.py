from __future__ import annotations

import re
from pathlib import Path

TARGET = Path("apps/flutter/wavezero_app/lib/app/wavezero_app.dart")
NAMES = [
    "_CuratedDemoHomeSection",
    "_CuratedDemoShelfView",
    "_CuratedPickCard",
    "_CuratedPickText",
    "_HomeHistorySection",
    "_ContinueListeningCard",
    "_HomeHero",
    "_HomeContinueListeningSummary",
    "_CurrentListeningCard",
    "_HomeCollectionsOfflineSection",
    "_SmartEngineCards",
    "_HomeQuickActions",
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
                marker = quote * 3
                if text.startswith(marker, i):
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

    raise RuntimeError(f"Unbalanced class body starting at offset {opening}")


def class_span(text: str, name: str) -> tuple[int, int]:
    match = re.search(rf"(?m)^class\s+{re.escape(name)}\b", text)
    if match is None:
        raise RuntimeError(f"Expected class {name} was not found")

    opening = text.find("{", match.end())
    if opening < 0:
        raise RuntimeError(f"Opening brace for {name} was not found")
    closing = find_matching_brace(text, opening)

    start = match.start()
    if start >= 1 and text[start - 1] == "\n":
        start -= 1
    end = closing + 1
    while end < len(text) and text[end] in " \t":
        end += 1
    if end < len(text) and text[end] == "\n":
        end += 1
    return start, end


def main() -> None:
    original = TARGET.read_text(encoding="utf-8")
    spans: list[tuple[int, int, str]] = []

    for name in NAMES:
        start, end = class_span(original, name)
        spans.append((start, end, name))

    # Remove the complete legacy group in one proposal, then prove none of the
    # removed private symbols are referenced by the remaining production file.
    cleaned = original
    for start, end, _ in sorted(spans, reverse=True):
        cleaned = cleaned[:start] + cleaned[end:]

    for name in NAMES:
        if re.search(rf"\b{re.escape(name)}\b", cleaned):
            raise RuntimeError(f"Refusing cleanup: {name} is still referenced outside its legacy class block")

    cleaned = re.sub(r"\n{4,}", "\n\n\n", cleaned)
    if cleaned == original:
        raise RuntimeError("Cleanup produced no change")

    TARGET.write_text(cleaned, encoding="utf-8")
    removed_lines = original.count("\n") - cleaned.count("\n")
    print(f"Removed {len(NAMES)} dead legacy Home classes ({removed_lines} lines).")


if __name__ == "__main__":
    main()
