#!/usr/bin/env python3
"""
Split docs/manual.html (single big doc) into per-chapter files in docs/manual/.

Chapter filenames follow the §N number → 0N-slug.html pattern. Cross-section
href="#sX-Y" links are rewritten to point at the owning chapter's file. The
shared <style> block is extracted to docs/manual/shared.css. Image paths in
each chapter are rewritten from screenshots/manual/X.png to
../screenshots/manual/X.png so the existing screenshots directory keeps its
single home.

Run from repo root:
    python3 scripts/split_manual.py

Re-running is idempotent (overwrites existing per-chapter files).
"""

import re
from pathlib import Path

CHAPTERS = [
    (1, "welcome", "Welcome"),
    (2, "quick-start", "Quick Start: Your First Scenario (Black Barrow)"),
    (3, "anatomy", "The Main Screen"),
    (4, "setting-up", "Setting Up"),
    (5, "round-step-by-step", "A Round, Step by Step"),
    (6, "special-mechanics", "Special Scenario Mechanics"),
    (7, "frosthaven", "Frosthaven Specifics"),
    (8, "edition-differences", "Edition Differences"),
    (9, "multiplayer", "Multiplayer"),
    (10, "mistakes-undo", "Mistakes, Undo, and Customization"),
    (11, "settings", "Settings Reference"),
    (12, "walkthrough", "Walkthrough: Black Barrow Round-by-Round"),
    (13, "reference", "Reference Appendix"),
]


def filename_for(num: int) -> str:
    slug = next(s for n, s, _ in CHAPTERS if n == num)
    return f"{num:02d}-{slug}.html"


def main() -> None:
    repo = Path(__file__).resolve().parent.parent
    src = repo / "docs" / "manual.html"
    out_dir = repo / "docs" / "manual"
    out_dir.mkdir(parents=True, exist_ok=True)

    html = src.read_text()

    # Extract <style>...</style> -> shared.css
    style_match = re.search(r"<style>([\s\S]*?)</style>", html)
    assert style_match, "no <style> block found"
    css = style_match.group(1).strip()
    (out_dir / "shared.css").write_text(css + "\n")

    # Find all top-level sections
    sections = re.findall(
        r'<section id="s(\d+)">[\s\S]*?</section>', html
    )
    assert len(sections) == len(CHAPTERS), \
        f"found {len(sections)} sections, expected {len(CHAPTERS)}"

    # Cross-reference rewrite: href="#sN-M" -> href="0N-slug.html#sN-M"
    # (when target section is in a different file from the current one)
    def rewrite_links(content: str, current_num: int) -> str:
        def repl(m: "re.Match[str]") -> str:
            target_num = int(m.group(1))
            if target_num == current_num:
                return m.group(0)  # same-file anchor; leave as-is
            return m.group(0).replace(
                f'href="#s{m.group(1)}', f'href="{filename_for(target_num)}#s{m.group(1)}'
            )
        return re.sub(r'href="#s(\d+)(?:-\d+)?"', repl, content)

    def rewrite_imgs(content: str) -> str:
        return content.replace(
            'src="screenshots/manual/', 'src="../screenshots/manual/'
        )

    # Write each chapter
    for num, slug, title in CHAPTERS:
        section_match = re.search(
            rf'<section id="s{num}">([\s\S]*?)</section>', html
        )
        assert section_match, f"missing section s{num}"
        section_html = section_match.group(0)
        section_html = rewrite_links(section_html, num)
        section_html = rewrite_imgs(section_html)

        prev_link = (
            f'<a href="{filename_for(num - 1)}">← §{num - 1}</a>'
            if num > 1
            else '<span class="nav-disabled">←</span>'
        )
        next_link = (
            f'<a href="{filename_for(num + 1)}">§{num + 1} →</a>'
            if num < len(CHAPTERS)
            else '<span class="nav-disabled">→</span>'
        )

        body = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>§{num} {title} — X-Haven Assistant Manual</title>
<link rel="stylesheet" href="shared.css">
</head>
<body>
<nav class="chapter-nav">
  {prev_link} &middot; <a href="index.html">Contents</a> &middot; {next_link}
</nav>
<h1>X-Haven Assistant — User Manual</h1>
{section_html}
<nav class="chapter-nav">
  {prev_link} &middot; <a href="index.html">Contents</a> &middot; {next_link}
</nav>
</body>
</html>
"""
        (out_dir / filename_for(num)).write_text(body)

    # Write index.html with TOC
    toc_items = "\n".join(
        f'  <li><span class="toc-num">§{n}</span><a href="{filename_for(n)}">{t}</a></li>'
        for n, _, t in CHAPTERS
    )
    index_body = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>X-Haven Assistant — User Manual</title>
<link rel="stylesheet" href="shared.css">
</head>
<body>
<h1>X-Haven Assistant — User Manual</h1>
<p class="meta"><strong>Status:</strong> draft. Anchored to <code>upstream/main</code>. Section numbers are stable identifiers — tests, bug reports, and forum threads can cite them as <code>§X.Y</code>. Goldens for §3 and §4 are generated from <code>frosthaven_assistant/test/widget/manual_goldens_test.dart</code>; regenerate with <code>flutter test --update-goldens</code>. The same goldens render byte-identically on the <code>claude_refactor</code> branch — they can serve as a regression check that the refactor preserves visible UI.</p>
<h2>Contents</h2>
<ol class="toc">
{toc_items}
</ol>
</body>
</html>
"""
    (out_dir / "index.html").write_text(index_body)

    # Add chapter-nav styles to shared.css
    extra_css = """
/* Per-chapter navigation */
.chapter-nav { font-size: 0.95em; color: var(--muted); padding: 0.6em 0; border-bottom: 1px solid var(--rule); margin-bottom: 1em; }
.chapter-nav:last-of-type { border-bottom: none; border-top: 1px solid var(--rule); margin-top: 2em; margin-bottom: 0; }
.chapter-nav a { text-decoration: none; color: var(--accent); }
.chapter-nav a:hover { text-decoration: underline; }
.nav-disabled { color: #ccc; }
"""
    with (out_dir / "shared.css").open("a") as f:
        f.write(extra_css)

    print(f"Wrote {len(CHAPTERS)} chapter files + index.html + shared.css to {out_dir}")


if __name__ == "__main__":
    main()
