from __future__ import annotations

import re
from pathlib import Path

TARGET = Path("apps/flutter/wavezero_app/lib/app/wavezero_app.dart")
NAMES = [
    "_CuratedDemoHomeSection",
    "_CuratedDemoShelfView",
    "_CuratedPickCard",
    "_CuratedPickText",
    "_CuratedTryPicksPanel",
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
    cleaned = original

    # Recompute offsets after every deletion. This avoids stale offsets when
    # neighboring legacy classes sit close together in the monolith.
    for name in NAMES:
        start, end = class_span(cleaned, name)
        cleaned = cleaned[:start] + cleaned[end:]

    # Strict safety guard: every retired private symbol must disappear from
    # the remaining production file. If not, write nothing.
    for name in NAMES:
        match = re.search(rf"\b{re.escape(name)}\b", cleaned)
        if match:
            left = max(0, match.start() - 220)
            right = min(len(cleaned), match.end() + 220)
            context = cleaned[left:right].replace("\n", "\\n")
            raise RuntimeError(
                f"Refusing cleanup: {name} is still referenced outside its legacy class block. Context: {context}"
            )

    cleaned = re.sub(r"\n{4,}", "\n\n\n", cleaned)
    if cleaned == original:
        raise RuntimeError("Cleanup produced no change")

    TARGET.write_text(cleaned, encoding="utf-8")
    removed_lines = original.count("\n") - cleaned.count("\n")
    print(f"Removed {len(NAMES)} dead legacy Home classes ({removed_lines} lines).")


if __name__ == "__main__":
    main()
