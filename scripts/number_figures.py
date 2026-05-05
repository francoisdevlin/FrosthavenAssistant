#!/usr/bin/env python3
"""
Number every <figure> in each manual chapter as 'Figure N.M' where N is
the chapter number and M is the chapter-scoped sequential index.

Numbering continues across subsections within a chapter and restarts at
chapter boundaries. Each <figure> also gets an id="fig-N-M" so callers
can deep-link (e.g. '07-frosthaven.html#fig-7-2').

Run from repo root:
    python3 scripts/number_figures.py

Idempotent — re-running on unchanged input produces byte-identical output.
"""

from __future__ import annotations

import re
from pathlib import Path

# Same canonical chapter list as inject_nav.py
CHAPTERS: list[tuple[int, str]] = [
    (1, "welcome"),
    (2, "quick-start"),
    (3, "anatomy"),
    (4, "setting-up"),
    (5, "round-step-by-step"),
    (6, "special-mechanics"),
    (7, "frosthaven"),
    (8, "edition-differences"),
    (9, "multiplayer"),
    (10, "mistakes-undo"),
    (11, "settings"),
    (12, "walkthrough"),
    (13, "reference"),
]


def filename_for(num: int, slug: str) -> str:
    return f"{num:02d}-{slug}.html"


# Matches a single <figure> block, including any existing id attribute.
# Captures: (1) any pre-id attrs, (2) existing id value or None, (3) any
# post-id attrs, (4) inner content up to </figure>.
FIGURE_OPEN_RE = re.compile(
    r"<figure\b([^>]*?)>",
    re.IGNORECASE,
)
FIGCAPTION_RE = re.compile(
    r"(<figcaption\b[^>]*>)(.*?)(</figcaption>)",
    re.IGNORECASE | re.DOTALL,
)
EXISTING_FIG_PREFIX_RE = re.compile(
    r"^\s*<strong>Figure \d+\.\d+\.</strong>\s*",
)


def renumber_chapter(html: str, chapter_num: int) -> tuple[str, int]:
    """Renumber all <figure> elements in this chapter. Returns (new_html, count)."""

    counter = {"n": 0}

    def replace_figure_open(m: re.Match[str]) -> str:
        attrs = m.group(1)
        counter["n"] += 1
        fig_num = counter["n"]
        new_id = f"fig-{chapter_num}-{fig_num}"
        # Strip any existing id attribute, then add the new one.
        attrs = re.sub(r'\s+id="[^"]*"', "", attrs).strip()
        attrs_str = f" {attrs}" if attrs else ""
        return f'<figure id="{new_id}"{attrs_str}>'

    # Step 1: rewrite each <figure> opening tag with its new id.
    new_html = FIGURE_OPEN_RE.sub(replace_figure_open, html)

    # Step 2: walk through and renumber captions in document order.
    # We pass through the html splitting on <figure ...>...</figure> blocks
    # to keep figure-N-M and caption-prefix-N-M aligned without needing a
    # parser.
    figure_block_re = re.compile(
        r'(<figure\s+id="fig-(\d+)-(\d+)"[^>]*>)([\s\S]*?)(</figure>)',
        re.IGNORECASE,
    )

    def replace_block(m: re.Match[str]) -> str:
        opening = m.group(1)
        chap = int(m.group(2))
        idx = int(m.group(3))
        body = m.group(4)
        closing = m.group(5)

        def rewrite_caption(cm: re.Match[str]) -> str:
            cap_open = cm.group(1)
            cap_inner = cm.group(2)
            cap_close = cm.group(3)
            # Strip any existing "Figure X.Y." prefix
            cap_inner = EXISTING_FIG_PREFIX_RE.sub("", cap_inner)
            return f"{cap_open}<strong>Figure {chap}.{idx}.</strong> {cap_inner}{cap_close}"

        new_body = FIGCAPTION_RE.sub(rewrite_caption, body, count=1)
        return f"{opening}{new_body}{closing}"

    new_html = figure_block_re.sub(replace_block, new_html)
    return new_html, counter["n"]


def main() -> None:
    repo = Path(__file__).resolve().parent.parent
    manual_dir = repo / "docs" / "manual"

    total = 0
    for num, slug in CHAPTERS:
        path = manual_dir / filename_for(num, slug)
        if not path.exists():
            continue
        html = path.read_text()
        new_html, count = renumber_chapter(html, num)
        if new_html != html:
            path.write_text(new_html)
        if count:
            print(f"  {filename_for(num, slug)}: {count} figure(s)")
        total += count

    print(f"Numbered {total} figures across {len(CHAPTERS)} chapter files.")


if __name__ == "__main__":
    main()
