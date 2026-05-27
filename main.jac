"""Jaseci Blogs backend.

Walkers that parse markdown posts and author metadata from the content
directory and serve them as JSON to the editorial frontend.

Content layout (read-only from this app's perspective):
  content/posts/*.md       — published + draft posts (draft: true is filtered)
  content/authors.yml      — author profiles
  docs/assets/             — images, referenced as /assets/<file>

Posts identify by the `slug:` frontmatter field, not filename. Files starting
with `_` are skipped (templates).
"""

import os;
import re;
import yaml;
import markdown as md;
import from datetime { date as date_cls }
import from pathlib { Path }


cl {
    def:pub app(props: any) -> JsxElement {
        can with entry {
            document.title = "Jaseci Blogs · engineering writing from the Jaseci & Jac ecosystem";
            existing = document.querySelector("link[rel='icon']");
            if not existing {
                icon = document.createElement("link");
                icon.rel = "icon";
                icon.type = "image/png";
                icon.href = "/logo.png";
                document.head.appendChild(icon);
            }
        }
        return <>{props.children}</>;
    }
}


# Content roots. During the migration we read from the legacy docs/blog/
# location so the mkdocs site keeps working as a reference. Step 10 of the
# migration moves these to content/posts/ + content/authors.yml.
glob POSTS_DIR = "docs/blog/posts";
glob AUTHORS_PATH = "docs/blog/.authors.yml";
glob EXCERPT_MARKER = "<!-- more -->";
glob READING_WPM = 220;
glob PEEK_LINES = 3;


def:priv format_date_long(date_str: str) -> str {
    try {
        parsed = date_cls.fromisoformat(date_str);
        return parsed.strftime("%B %d, %Y");
    } except Exception {
        return date_str;
    }
}


def:priv format_date_short(date_str: str) -> str {
    try {
        parsed = date_cls.fromisoformat(date_str);
        return parsed.strftime("%b %d, %Y");
    } except Exception {
        return date_str;
    }
}


def:priv _add_md_attr(m: any) -> str {
    tag = m.group(1);
    attrs = m.group(2) or "";
    return "<" + str(tag) + str(attrs) + ' markdown="1">';
}


def:priv inject_markdown_attr(body: str) -> str {
    # Lets authors mix raw HTML with markdown inside divs / figures / anchors,
    # matching the python-markdown md_in_html behavior used by mkdocs-material.
    # Skip tags that already carry an explicit markdown="..." attribute — we
    # use markdown="0" on mermaid blocks so their source survives unmodified.
    def _maybe_inject(m: any) -> str {
        tag = m.group(1);
        attrs = m.group(2) or "";
        if "markdown=" in attrs {
            return m.group(0);
        }
        return "<" + str(tag) + str(attrs) + ' markdown="1">';
    }
    return re.sub(r"<(div|figure|a)(\s+[^>]*)?>", _maybe_inject, body);
}


def:priv _escape_html(text: str) -> str {
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
}


def:priv convert_mermaid_fences(body: str) -> str {
    # Replace ```mermaid …``` fenced blocks with raw HTML that survives the
    # python-markdown pipeline (markdown="0" tells md_in_html to leave the
    # body alone). The client then calls mermaid.run on .mermaid-block.
    def _replace(m: any) -> str {
        source = m.group(1);
        return f'<div class="mermaid-block" markdown="0">{_escape_html(source)}</div>';
    }
    return re.sub(r"(?ms)^[ \t]*```mermaid[ \t]*\n(.*?)\n[ \t]*```[ \t]*$", _replace, body);
}


def:priv rewrite_asset_paths(body: str) -> str {
    # Posts authored against the mkdocs layout use relative links like
    # ../../assets/foo.png (from docs/blog/posts/) or ../assets/foo.png.
    # The Jac app serves static files from /assets/ instead.
    body = re.sub(r"(!\[[^\]]*\]\()(?:\.\./)+assets/", r"\1/assets/", body);
    body = re.sub(r"(<img[^>]+src=[\"'])(?:\.\./)+assets/", r"\1/assets/", body);
    return body;
}


def:priv strip_markdown_inline(text: str) -> str {
    # Used when deriving plain-text titles from a markdown H1 — drops bold,
    # italic, inline-code, and link syntax while preserving the visible text.
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text);
    text = re.sub(r"__([^_]+)__", r"\1", text);
    text = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"\1", text);
    text = re.sub(r"(?<!_)_([^_]+)_(?!_)", r"\1", text);
    text = re.sub(r"`([^`]+)`", r"\1", text);
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text);
    return text.strip();
}


def:priv estimate_reading_minutes(body: str) -> int {
    word_count = len(re.findall(r"\w+", body));
    minutes = max(1, round(word_count / READING_WPM));
    return int(minutes);
}


def:priv split_excerpt(body: str) -> tuple[str, str] {
    # Returns (excerpt_md, full_md). The excerpt is everything before the
    # <!-- more --> marker, falling back to the first paragraph.
    if EXCERPT_MARKER in body {
        parts = body.split(EXCERPT_MARKER, 1);
        return (parts[0].strip(), body.replace(EXCERPT_MARKER, "").strip());
    }
    # Fallback: first non-heading paragraph.
    paragraphs = re.split(r"\n\s*\n", body.strip());
    for p in paragraphs {
        stripped = p.strip();
        if stripped and not stripped.startswith("#") {
            return (stripped, body);
        }
    }
    return ("", body);
}


def:priv extract_peek_markdown(body: str) -> str {
    # Mirror of scripts/inject_excerpt_peek.py:_extract_peek_markdown — the
    # next PEEK_LINES non-blank, non-heading lines after the <!-- more -->
    # marker, used as a faded teaser on the index card.
    if EXCERPT_MARKER not in body {
        return "";
    }
    after = body.split(EXCERPT_MARKER, 1)[1];
    kept: list[str] = [];
    non_blank = 0;
    for raw in after.split("\n") {
        line = raw.rstrip();
        stripped = line.strip();
        if not stripped {
            if kept {
                kept.append("");
            }
            continue;
        }
        if stripped.startswith("---") or stripped.startswith("#") or stripped.startswith("<!--") {
            continue;
        }
        kept.append(line);
        non_blank = non_blank + 1;
        if non_blank >= PEEK_LINES {
            break;
        }
    }
    return "\n".join(kept).strip();
}


def:priv render_markdown(body: str) -> str {
    return md.markdown(
        body,
        extensions=[
            "fenced_code",
            "codehilite",
            "tables",
            "attr_list",
            "md_in_html",
            "footnotes",
            "toc",
            "admonition",
        ],
        extension_configs={
            "codehilite": {"guess_lang": False, "css_class": "highlight"},
            "toc": {"permalink": True, "permalink_class": "headerlink"},
        },
    );
}


def:priv load_authors() -> dict {
    path = Path(AUTHORS_PATH);
    if not path.exists() {
        return {};
    }
    try {
        text = path.read_text(encoding="utf-8");
        data = yaml.safe_load(text);
    } except Exception {
        return {};
    }
    if not isinstance(data, dict) {
        return {};
    }
    authors = data.get("authors", {});
    if not isinstance(authors, dict) {
        return {};
    }
    return authors;
}


def:priv resolve_authors(author_ids: list, registry: dict) -> list {
    resolved = [];
    for aid in author_ids {
        key = str(aid);
        entry = registry.get(key);
        if isinstance(entry, dict) {
            resolved.append({
                "id": key,
                "name": str(entry.get("name", key)),
                "description": str(entry.get("description", "")),
                "avatar": str(entry.get("avatar", "")),
            });
        } else {
            resolved.append({"id": key, "name": key, "description": "", "avatar": ""});
        }
    }
    return resolved;
}


def:priv parse_post_file(path: Path, registry: dict) -> dict | None {
    try {
        text = path.read_text(encoding="utf-8");
    } except Exception {
        return None;
    }

    if not text.startswith("---") {
        return None;
    }

    parts = text.split("---", 2);
    if len(parts) < 3 {
        return None;
    }

    frontmatter_text = parts[1];
    raw_body = parts[2].strip();

    try {
        meta = yaml.safe_load(frontmatter_text);
    } except Exception {
        return None;
    }

    if not isinstance(meta, dict) {
        return None;
    }

    if meta.get("draft", False) {
        return None;
    }

    slug = str(meta.get("slug", path.stem));
    raw_date = str(meta.get("date", ""));

    author_ids = meta.get("authors", []);
    if not isinstance(author_ids, list) {
        author_ids = [author_ids];
    }
    authors = resolve_authors(author_ids, registry);

    categories = meta.get("categories", []);
    if not isinstance(categories, list) {
        categories = [categories];
    }
    categories = [str(c) for c in categories];

    (excerpt_md, full_md) = split_excerpt(raw_body);
    peek_md = extract_peek_markdown(raw_body);
    full_md = rewrite_asset_paths(full_md);
    excerpt_md = rewrite_asset_paths(excerpt_md);
    peek_md = rewrite_asset_paths(peek_md);
    # Replace ```mermaid fences with markdown="0" raw HTML so the source
    # survives through python-markdown to the browser.
    full_md = convert_mermaid_fences(full_md);
    excerpt_md = convert_mermaid_fences(excerpt_md);
    peek_md = convert_mermaid_fences(peek_md);
    full_md_html_ready = inject_markdown_attr(full_md);
    excerpt_md_html_ready = inject_markdown_attr(excerpt_md);
    peek_md_html_ready = inject_markdown_attr(peek_md);

    # Derive title from first H1 if frontmatter doesn't give one.
    title = str(meta.get("title", ""));
    if not title {
        h1_found = re.search(r"(?m)^#\s+(.+)$", raw_body);
        title = h1_found.group(1).strip() if h1_found else slug.replace("-", " ").title();
    }
    title = strip_markdown_inline(title);

    description = str(meta.get("description", ""));

    return {
        "slug": slug,
        "filename": path.stem,
        "title": title,
        "date": raw_date,
        "date_long": format_date_long(raw_date),
        "date_short": format_date_short(raw_date),
        "authors": authors,
        "categories": categories,
        "description": description,
        "excerpt_md": excerpt_md_html_ready,
        "peek_md": peek_md_html_ready,
        "body_md": full_md_html_ready,
        "reading_minutes": estimate_reading_minutes(raw_body),
        "cover": str(meta.get("cover", "")),
    };
}


def:priv list_all_posts() -> list {
    dir_path = Path(POSTS_DIR);
    if not dir_path.exists() {
        return [];
    }
    registry = load_authors();
    items = [];
    for path in sorted(dir_path.glob("*.md")) {
        if path.name.startswith("_") {
            continue;
        }
        parsed = parse_post_file(path, registry);
        if parsed is None {
            continue;
        }
        items.append(parsed);
    }
    # Newest first.
    items.sort(key=lambda x: dict -> str { return x["date"]; }, reverse=True);
    return items;
}


def:priv post_summary(post: dict) -> dict {
    excerpt_html = md.markdown(
        post["excerpt_md"],
        extensions=["fenced_code", "attr_list", "md_in_html"],
    ) if post["excerpt_md"] else "";
    peek_html = md.markdown(
        post["peek_md"],
        extensions=["fenced_code", "attr_list", "md_in_html"],
    ) if post["peek_md"] else "";
    return {
        "slug": post["slug"],
        "title": post["title"],
        "date": post["date"],
        "date_long": post["date_long"],
        "date_short": post["date_short"],
        "authors": post["authors"],
        "categories": post["categories"],
        "description": post["description"],
        "excerpt_html": excerpt_html,
        "peek_html": peek_html,
        "reading_minutes": post["reading_minutes"],
        "cover": post["cover"],
    };
}


walker:pub GetPosts {
    has page: int = 1;
    has per_page: int = 10;
    has category: str = "";
    has author: str = "";

    can get with Root entry {
        all_posts = list_all_posts();

        if self.category {
            all_posts = [p for p in all_posts if self.category in p["categories"]];
        }
        if self.author {
            all_posts = [
                p for p in all_posts
                if any(a["id"] == self.author for a in p["authors"])
            ];
        }

        total = len(all_posts);
        per = max(1, self.per_page);
        page_num = max(1, self.page);
        start = (page_num - 1) * per;
        end = start + per;
        window = all_posts[start:end];

        report {
            "ok": True,
            "total": total,
            "page": page_num,
            "per_page": per,
            "has_prev": page_num > 1,
            "has_next": end < total,
            "posts": [post_summary(p) for p in window],
        };
    }
}


walker:pub GetPost {
    has slug: str = "";

    can get with Root entry {
        if not self.slug {
            report {"ok": False, "error": "missing slug"};
            return;
        }

        registry = load_authors();
        dir_path = Path(POSTS_DIR);
        if not dir_path.exists() {
            report {"ok": False, "error": "posts directory not found"};
            return;
        }

        found = None;
        for path in dir_path.glob("*.md") {
            if path.name.startswith("_") {
                continue;
            }
            parsed = parse_post_file(path, registry);
            if parsed is None {
                continue;
            }
            if parsed["slug"] == self.slug {
                found = parsed;
                break;
            }
        }

        if found is None {
            report {"ok": False, "error": "not found"};
            return;
        }

        html = render_markdown(found["body_md"]);

        # Adjacent posts (prev/next by date).
        all_posts = list_all_posts();
        prev_post = None;
        next_post = None;
        for (i, p) in enumerate(all_posts) {
            if p["slug"] == found["slug"] {
                if i + 1 < len(all_posts) {
                    nxt = all_posts[i + 1];
                    next_post = {
                        "slug": nxt["slug"],
                        "title": nxt["title"],
                        "date_short": nxt["date_short"],
                    };
                }
                if i > 0 {
                    prv = all_posts[i - 1];
                    prev_post = {
                        "slug": prv["slug"],
                        "title": prv["title"],
                        "date_short": prv["date_short"],
                    };
                }
                break;
            }
        }

        # Related: same primary category, excluding self, capped at 3.
        related = [];
        if found["categories"] {
            primary = found["categories"][0];
            for p in all_posts {
                if p["slug"] == found["slug"] {
                    continue;
                }
                if primary in p["categories"] {
                    related.append(post_summary(p));
                }
                if len(related) >= 3 {
                    break;
                }
            }
        }

        report {
            "ok": True,
            "slug": found["slug"],
            "title": found["title"],
            "date": found["date"],
            "date_long": found["date_long"],
            "authors": found["authors"],
            "categories": found["categories"],
            "description": found["description"],
            "cover": found["cover"],
            "reading_minutes": found["reading_minutes"],
            "html": html,
            "prev": prev_post,
            "next": next_post,
            "related": related,
        };
    }
}


walker:pub GetAuthor {
    has id: str = "";

    can get with Root entry {
        if not self.id {
            report {"ok": False, "error": "missing author id"};
            return;
        }
        registry = load_authors();
        entry = registry.get(self.id);
        if not isinstance(entry, dict) {
            report {"ok": False, "error": "not found"};
            return;
        }
        all_posts = list_all_posts();
        authored = [
            post_summary(p) for p in all_posts
            if any(a["id"] == self.id for a in p["authors"])
        ];
        report {
            "ok": True,
            "id": self.id,
            "name": str(entry.get("name", self.id)),
            "description": str(entry.get("description", "")),
            "avatar": str(entry.get("avatar", "")),
            "posts": authored,
        };
    }
}


walker:pub GetCategories {
    can get with Root entry {
        all_posts = list_all_posts();
        counts: dict = {};
        for p in all_posts {
            for c in p["categories"] {
                counts[c] = counts.get(c, 0) + 1;
            }
        }
        items = [{"name": k, "count": v} for (k, v) in counts.items()];
        items.sort(key=lambda x: dict -> int { return x["count"]; }, reverse=True);
        report {"ok": True, "categories": items};
    }
}


walker:pub GetArchive {
    can get with Root entry {
        all_posts = list_all_posts();
        # Group by year.
        years: dict = {};
        for p in all_posts {
            year = p["date"][:4] if len(p["date"]) >= 4 else "Undated";
            if year not in years {
                years[year] = [];
            }
            years[year].append({
                "slug": p["slug"],
                "title": p["title"],
                "date_short": p["date_short"],
                "categories": p["categories"],
            });
        }
        grouped = [
            {"year": y, "posts": years[y]}
            for y in sorted(years.keys(), reverse=True)
        ];
        report {"ok": True, "years": grouped, "total": len(all_posts)};
    }
}


walker:pub GetSearchIndex {
    can get with Root entry {
        all_posts = list_all_posts();
        index = [];
        for p in all_posts {
            # Plain-text body for indexing — strip the most common markdown.
            plain = re.sub(r"`[^`]*`", "", p["body_md"]);
            plain = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", plain);
            plain = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", plain);
            plain = re.sub(r"[#>*_~]+", " ", plain);
            plain = re.sub(r"\s+", " ", plain).strip();
            index.append({
                "slug": p["slug"],
                "title": p["title"],
                "description": p["description"],
                "categories": p["categories"],
                "authors": [a["name"] for a in p["authors"]],
                "date_short": p["date_short"],
                "body": plain[:8000],
            });
        }
        report {"ok": True, "documents": index};
    }
}
