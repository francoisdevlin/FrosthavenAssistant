#!/usr/bin/env python3
"""
Inject left-sidebar and sub-TOC into each chapter of the manual.

Each chapter file in docs/manual/ gets:
  - A left sidebar listing every chapter (§1–§13). The current chapter
    is marked .active and expanded to show its sub-sections.
  - A "In this chapter" sub-TOC at the top of the content area listing
    just that chapter's §X.Y sub-sections, sourced from <h3 id="sX-Y">
    elements in the chapter file itself.

The generated regions are bounded by HTML comments so the script is
idempotent. On first run for a file, content is wrapped in a layout
container (<aside class="sidebar"> + <main class="content">). On
subsequent runs, only the bounded regions are replaced.

Run from repo root:
    python3 scripts/inject_nav.py
"""

from __future__ import annotations

import re
from pathlib import Path

CHAPTERS: list[tuple[int, str, str]] = [
    (1, "welcome", "Welcome"),
    (2, "quick-start", "Quick Start"),
    (3, "anatomy", "The Main Screen"),
    (4, "setting-up", "Setting Up"),
    (5, "round-step-by-step", "A Round, Step by Step"),
    (6, "special-mechanics", "Special Scenario Mechanics"),
    (7, "frosthaven", "Frosthaven Specifics"),
    (8, "edition-differences", "Edition Differences"),
    (9, "multiplayer", "Multiplayer"),
    (10, "mistakes-undo", "Mistakes, Undo, Customization"),
    (11, "settings", "Settings Reference"),
    (12, "walkthrough", "Walkthrough: Black Barrow"),
    (13, "reference", "Reference Appendix"),
]

SIDEBAR_BEGIN = "<!-- BEGIN GENERATED SIDEBAR -->"
SIDEBAR_END = "<!-- END GENERATED SIDEBAR -->"
SUBTOC_BEGIN = "<!-- BEGIN GENERATED SUBTOC -->"
SUBTOC_END = "<!-- END GENERATED SUBTOC -->"


def filename_for(num: int) -> str:
    slug = next(s for n, s, _ in CHAPTERS if n == num)
    return f"{num:02d}-{slug}.html"


def extract_subsections(html: str, num: int) -> list[tuple[str, str]]:
    """Return list of (id, title) tuples for §N.M sections in this chapter.

    Sub-sections are typically <h3 id="sN-M">, but some chapters render as
    a single table where groupings are <th id="sN-M"> spanning rows. We
    pick up both patterns so navigation works the same either way.
    """
    pattern = (
        rf'<(?:h3|th)[^>]*\bid="(s{num}-\d+)"[^>]*>(.*?)</(?:h3|th)>'
    )
    found = re.findall(pattern, html, re.DOTALL)
    # Deduplicate by id while preserving document order
    seen: set[str] = set()
    out: list[tuple[str, str]] = []
    for id_, raw_title in found:
        if id_ in seen:
            continue
        seen.add(id_)
        # Strip the <span class="secnum">§N.M</span> prefix
        title = re.sub(r'<span class="(?:secnum|group-num)">[^<]*</span>\s*', "", raw_title)
        # Strip any remaining tags
        title = re.sub(r"<[^>]+>", "", title)
        out.append((id_, title.strip()))
    return out


def render_sidebar(current_num: int, all_subsections: dict[int, list[tuple[str, str]]]) -> str:
    lines = ['<nav class="sidebar-nav"><ol class="sidebar-toc">']
    for n, _slug, title in CHAPTERS:
        active_cls = ' class="active"' if n == current_num else ""
        lines.append(f"  <li{active_cls}>")
        lines.append(
            f'    <a href="{filename_for(n)}">'
            f'<span class="num">§{n}</span> {title}</a>'
        )
        if n == current_num and all_subsections.get(n):
            lines.append('    <ol class="sub-toc">')
            for sub_id, sub_title in all_subsections[n]:
                sec_num = sub_id[1:].replace("-", ".")
                lines.append(
                    f'      <li><a href="#{sub_id}">'
                    f'<span class="num">§{sec_num}</span> {sub_title}</a></li>'
                )
            lines.append("    </ol>")
        lines.append("  </li>")
    lines.append("</ol></nav>")
    return "\n".join(lines)


def render_subtoc(subsections: list[tuple[str, str]]) -> str:
    if not subsections:
        return '<!-- chapter has no sub-sections -->'
    lines = ['<nav class="chapter-toc">', "  <h2>In this chapter</h2>", "  <ol>"]
    for sub_id, sub_title in subsections:
        sec_num = sub_id[1:].replace("-", ".")
        lines.append(
            f'    <li><a href="#{sub_id}">'
            f'<span class="num">§{sec_num}</span> {sub_title}</a></li>'
        )
    lines.append("  </ol>")
    lines.append("</nav>")
    return "\n".join(lines)


def replace_marked(html: str, begin: str, end: str, payload: str) -> str:
    pattern = re.compile(re.escape(begin) + r"[\s\S]*?" + re.escape(end))
    return pattern.sub(f"{begin}\n{payload}\n{end}", html)


def first_run_wrap(html: str, sidebar: str, subtoc: str, num: int) -> str:
    """First-time wrap: introduces the layout container + marker comments."""
    body_match = re.search(r"<body>([\s\S]*)</body>", html)
    assert body_match, "no <body> tag found"
    inner = body_match.group(1).strip()

    # Find the existing top chapter-nav (if any) to keep it inside <main>
    new_inner = (
        '<div class="layout">\n'
        '<aside class="sidebar">\n'
        f"{SIDEBAR_BEGIN}\n{sidebar}\n{SIDEBAR_END}\n"
        "</aside>\n"
        '<main class="content">\n'
        f"{inner}\n"
        "</main>\n"
        "</div>"
    )
    html = html.replace(body_match.group(0), f"<body>\n{new_inner}\n</body>")

    # Inject sub-TOC just before the chapter's <section id="sN">
    section_open = f'<section id="s{num}">'
    if section_open in html:
        html = html.replace(
            section_open,
            f"{SUBTOC_BEGIN}\n{subtoc}\n{SUBTOC_END}\n{section_open}",
            1,
        )
    return html


def main() -> None:
    repo = Path(__file__).resolve().parent.parent
    manual_dir = repo / "docs" / "manual"

    all_subsections: dict[int, list[tuple[str, str]]] = {}
    for n, _, _ in CHAPTERS:
        path = manual_dir / filename_for(n)
        all_subsections[n] = extract_subsections(path.read_text(), n)

    for n, _slug, _title in CHAPTERS:
        path = manual_dir / filename_for(n)
        html = path.read_text()

        sidebar = render_sidebar(n, all_subsections)
        subtoc = render_subtoc(all_subsections[n])

        if SIDEBAR_BEGIN in html:
            html = replace_marked(html, SIDEBAR_BEGIN, SIDEBAR_END, sidebar)
            html = replace_marked(html, SUBTOC_BEGIN, SUBTOC_END, subtoc)
        else:
            html = first_run_wrap(html, sidebar, subtoc, n)

        path.write_text(html)
        print(f"  {filename_for(n)}: {len(all_subsections[n])} sub-sections")

    print(f"Processed {len(CHAPTERS)} chapter files.")


if __name__ == "__main__":
    main()
