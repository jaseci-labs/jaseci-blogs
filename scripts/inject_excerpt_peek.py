"""Inject a faded "peek" of the next lines after <!-- more --> into blog index cards.

The mkdocs-material blog plugin truncates each post's excerpt at <!-- more -->,
so the index card's HTML only contains pre-more content. This hook reads the
source post, captures a few lines after the <!-- more --> marker, renders them
to HTML, and injects them into the card on the blog index (and paginated index)
pages — wrapped in a `.md-post__peek` div so CSS can fade them out.

Authors do not need to change <!-- more --> placement; the peek is purely a
build-time enhancement of the index page.
"""

from __future__ import annotations

import re
from pathlib import Path

import markdown as _markdown

# Number of non-blank source lines to capture after <!-- more -->.
PEEK_LINES = 3

_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)
_SLUG_RE = re.compile(r"^slug:\s*(.+)$", re.MULTILINE)
_MORE_RE = re.compile(r"<!--\s*more\s*-->")
_ARTICLE_RE = re.compile(
    r'<article class="md-post md-post--excerpt">.*?</article>',
    re.DOTALL,
)
_HREF_RE = re.compile(r'<nav class="md-post__action">\s*<a href="([^"]+)"')
_ACTION_RE = re.compile(r'(\s*<nav class="md-post__action">)')

_peek_cache: dict[str, str] = {}


def _extract_peek_markdown(body: str) -> str:
    """Return the next PEEK_LINES non-blank, non-heading lines after <!-- more -->."""
    m = _MORE_RE.search(body)
    if not m:
        return ""
    after = body[m.end():]
    kept: list[str] = []
    non_blank = 0
    for raw in after.split("\n"):
        line = raw.rstrip()
        stripped = line.strip()
        if not stripped:
            if kept:
                kept.append("")
            continue
        # Skip structural noise: horizontal rules, headings, html comments
        if stripped.startswith(("---", "#", "<!--")):
            continue
        kept.append(line)
        non_blank += 1
        if non_blank >= PEEK_LINES:
            break
    return "\n".join(kept).strip()


def _parse_post(path: Path) -> tuple[str, str] | None:
    text = path.read_text(encoding="utf-8")
    fm = _FRONTMATTER_RE.match(text)
    if not fm:
        return None
    front, body = fm.group(1), fm.group(2)
    slug_m = _SLUG_RE.search(front)
    if not slug_m:
        return None
    snippet = _extract_peek_markdown(body)
    if not snippet:
        return None
    html = _markdown.markdown(snippet)
    return slug_m.group(1).strip(), html


def on_config(config):  # noqa: D401
    """Build slug -> peek-html map once per build."""
    posts_dir = Path(config["docs_dir"]) / "blog" / "posts"
    _peek_cache.clear()
    if not posts_dir.is_dir():
        return config
    for path in posts_dir.glob("*.md"):
        parsed = _parse_post(path)
        if parsed:
            slug, html = parsed
            _peek_cache[slug] = html
    return config


def _is_index_page(url: str) -> bool:
    url = url.rstrip("/")
    return url == "blog" or bool(re.match(r"^blog/page/\d+$", url))


def on_post_page(output: str, page, config):  # noqa: D401
    """Inject .md-post__peek into each excerpt card on blog index pages.

    Using `on_post_page` (after template rendering) because the blog plugin
    injects post excerpts into the page during template rendering, so they are
    not visible to the earlier `on_page_content` event.
    """
    if not _is_index_page(page.url):
        return output
    if "md-post--excerpt" not in output:
        return output
    html = output

    def replace_article(match: re.Match[str]) -> str:
        article = match.group(0)
        href_match = _HREF_RE.search(article)
        if not href_match:
            return article
        slug = href_match.group(1).rstrip("/").rsplit("/", 1)[-1]
        peek_html = _peek_cache.get(slug)
        if not peek_html:
            return article
        peek_div = f'<div class="md-post__peek" aria-hidden="true">{peek_html}</div>'
        return _ACTION_RE.sub(peek_div + r"\1", article, count=1)

    return _ARTICLE_RE.sub(replace_article, html)
