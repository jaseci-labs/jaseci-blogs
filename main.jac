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
import json;
import time;
import uuid;
import base64;
import hashlib;
import requests;
import markdown as md;
import from cryptography.fernet { Fernet }
import from jac_scale.user_manager { JacScaleUserManager }
import from datetime { date as date_cls }
import from pathlib { Path }


glob JACLANG_ZIP = "docs/playground/jaclang.zip";


cl {
    def:pub app(props: any) -> JsxElement {
        can with entry {
            document.title = "Jaseci Blogs · engineering writing from the Jaseci & Jac ecosystem";
            existing = document.querySelector("link[rel='icon']");
            if not existing {
                icon = document.createElement("link");
                icon.rel = "icon";
                icon.type = "image/png";
                icon.href = "https://www.jaseci.org/images/logo.png";
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
    in_fence = False;
    for raw in after.split("\n") {
        line = raw.rstrip();
        stripped = line.strip();
        # Skip fenced code blocks entirely — a partial fence renders as raw
        # "```" text in the teaser, and code is noise in a prose peek anyway.
        if stripped.startswith("```") or stripped.startswith("~~~") {
            in_fence = not in_fence;
            continue;
        }
        if in_fence {
            continue;
        }
        if not stripped {
            if kept {
                kept.append("");
            }
            continue;
        }
        # Skip structural noise and HTML/markup-only lines.
        if stripped.startswith("---") or stripped.startswith("#") or stripped.startswith("<!--") or stripped.startswith("<") {
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


def:priv normalize_avatar(avatar: str) -> str {
    # Absolute URLs and root-relative paths pass through. Bare "assets/..."
    # (or "./assets/...") from .authors.yml gets rooted to /assets/ so it
    # resolves regardless of the current page path.
    if not avatar {
        return "";
    }
    if avatar.startswith("http://") or avatar.startswith("https://") or avatar.startswith("/") {
        return avatar;
    }
    cleaned = avatar;
    while cleaned.startswith("./") or cleaned.startswith("../") {
        cleaned = cleaned.split("/", 1)[1];
    }
    if cleaned.startswith("assets/") {
        return "/" + cleaned;
    }
    return "/assets/" + cleaned;
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
                "avatar": normalize_avatar(str(entry.get("avatar", ""))),
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


def:priv peek_unpublished(slug: str) -> dict | None {
    # parse_post_file drops drafts entirely (returns None), so GetPost can't
    # otherwise tell an unpublished post apart from a genuinely missing one.
    # This does a lightweight frontmatter-only scan for a draft whose slug
    # matches, returning just enough to render the "coming soon" page.
    dir_path = Path(POSTS_DIR);
    if not dir_path.exists() {
        return None;
    }
    for path in sorted(dir_path.glob("*.md")) {
        if path.name.startswith("_") {
            continue;
        }
        try {
            text = path.read_text(encoding="utf-8");
        } except Exception {
            continue;
        }
        if not text.startswith("---") {
            continue;
        }
        parts = text.split("---", 2);
        if len(parts) < 3 {
            continue;
        }
        try {
            meta = yaml.safe_load(parts[1]);
        } except Exception {
            continue;
        }
        if not isinstance(meta, dict) {
            continue;
        }
        if not meta.get("draft", False) {
            continue;  # published posts are served by the normal path
        }
        file_slug = str(meta.get("slug", path.stem));
        if file_slug != slug {
            continue;
        }
        raw_body = parts[2].strip();
        title = str(meta.get("title", ""));
        if not title {
            h1_found = re.search(r"(?m)^#\s+(.+)$", raw_body);
            title = h1_found.group(1).strip() if h1_found else slug.replace("-", " ").title();
        }
        return {"slug": slug, "title": strip_markdown_inline(title)};
    }
    return None;
}


walker:pub GetPost {
    has slug: str = "";
    has preview: str = "";

    can get with Root entry {
        if not self.slug {
            report {"ok": False, "status": "error", "error": "missing slug"};
            return;
        }

        # Shareable draft preview: a valid token returns the stored snapshot even
        # though the post is still draft:true, so the page renders it in full.
        if self.preview {
            shared_root = root.shared;  # jac:ignore[E1030] runtime attr, no static stub
            doc = match_preview([shared_root -->][?:PreviewDoc], self.preview);
            if doc is not None and doc.slug == self.slug {
                report doc.data;
                return;
            }
        }

        registry = load_authors();
        dir_path = Path(POSTS_DIR);
        if not dir_path.exists() {
            report {"ok": False, "status": "error", "error": "posts directory not found"};
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
            pending = peek_unpublished(self.slug);
            if pending is not None {
                report {
                    "ok": False,
                    "status": "coming_soon",
                    "slug": pending["slug"],
                    "title": pending["title"],
                    "error": "not yet published",
                };
                return;
            }
            report {"ok": False, "status": "not_found", "error": "not found"};
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


walker:pub GetRuntimeZip {
    # Serves the prebuilt jaclang.zip as base64 for the in-browser Pyodide
    # runner. Delivered via walker (not static) because the dev/static server
    # doesn't serve arbitrary public/ files and filters non-image extensions.
    can get with Root entry {
        path = Path(JACLANG_ZIP);
        if not path.exists() {
            report {"ok": False, "error": "runtime bundle not found"};
            return;
        }
        try {
            data = path.read_bytes();
            b64 = base64.b64encode(data).decode("ascii");
            report {"ok": True, "b64": b64};
        } except Exception as e {
            report {"ok": False, "error": str(e)};
        }
    }
}


# ───────────────────────── Blog submission portal ─────────────────────────
#
# A /submit page lets a GitHub-authenticated visitor open a blog-post PR
# (with images) without touching git. GitHub is the only datastore — there is
# no DB, and there is NO GitHub App: every GitHub action runs AS THE SIGNED-IN
# USER via their OAuth token. Submitting forks the repo to the user's account,
# commits to a branch on that fork, and opens a cross-fork PR upstream — exactly
# how any open-source contribution works. So a plain (personally-creatable)
# OAuth App with `public_repo` scope is all that's needed; no org-owned app, no
# installation approval.
#
# The session is a jac-scale JWT (the browser stores it as `jac_token`). The
# user's OAuth token is needed again at submit time, so it's returned ENCRYPTED
# (Fernet) and the browser only ever holds ciphertext, passing it back per
# request as `gh_enc` for the server to decrypt. Reviewers (repo write access,
# read live from GitHub) get a review dashboard; its write-actions (merge,
# schedule, take-down) run with the reviewer's OWN access — merge on the PR page,
# slash-commands pasted as a PR comment — so nothing here needs elevated perms.
#
# Required env (k8s secrets — see .github/SUBMIT_FLOW.md):
#   GH_OAUTH_CLIENT_ID / GH_OAUTH_CLIENT_SECRET  — the OAuth App (sign-in + acts as user)
#   JWT_SECRET                                   — jac-scale's session JWT signing key
#   SUBMIT_SESSION_SECRET                        — Fernet key for the GitHub token at rest
#   GH_REPO (default jaseci-labs/jaseci-blogs) / GH_BASE_BRANCH (default main)

glob ALLOWED_CATEGORIES = [
    "Jac Programming", "Tutorials", "Fixing the Broken",
    "AI", "Web Development", "Developers", "Community",
];  # keep in sync with mkdocs.yml -> blog.categories_allowed
glob MAX_IMAGE_BYTES = 100 * 1024;
glob MAX_IMAGES = 8;
glob ALLOWED_IMAGE_EXT = ["png", "jpg", "jpeg", "gif", "webp", "svg"];
# Marker text stamped into each submission PR body; also the search term that
# finds submissions (we can't add a label as the contributor, so the body
# marker is the index instead).
glob SUBMISSION_TAG = "blog-submission";
# Same idea for edits to ALREADY-PUBLISHED posts: stamped into the edit PR's body
# so open edit PRs for a given slug are findable with one search (collision check).
glob EDIT_TAG = "blog-edit";
glob GH_API = "https://api.github.com";
glob PREVIEW_TTL = 60 * 60 * 24 * 30;  # shareable draft previews live 1 month


node PreviewDoc {
    # A persisted, public draft-preview snapshot. Hung off the shared public root
    # (root.shared) and granted ReadPerm, so anyone with the random token can read
    # it regardless of sign-in state. Holds the fully-rendered GetPost-shaped
    # payload so the real post page renders it with runnable code blocks, mermaid,
    # etc. Expires after PREVIEW_TTL.
    has token: str = "";
    has slug: str = "";
    has data: dict = {};
    has created_at: float = 0.0;
}


def:priv env_str(name: str, fallback: str = "") -> str {
    val = os.environ.get(name, fallback);
    if val is None {
        return fallback;
    }
    return str(val);
}


def:priv gh_repo() -> str {
    return env_str("GH_REPO", "jaseci-labs/jaseci-blogs");
}


def:priv gh_base_branch() -> str {
    return env_str("GH_BASE_BRANCH", "main");
}


def:priv public_site_url() -> str {
    return env_str("PUBLIC_SITE_URL", "https://blogs.jaseci.org").rstrip("/");
}


def:priv fernet() -> any {
    # Symmetric cipher for the GitHub user token at rest in the session. Key is
    # derived from SUBMIT_SESSION_SECRET so no extra secret to manage.
    secret = env_str("SUBMIT_SESSION_SECRET") or "dev-only-insecure-secret";
    key = base64.urlsafe_b64encode(hashlib.sha256(secret.encode("utf-8")).digest());
    return Fernet(key);
}


def:priv encrypt_token(tok: str) -> str {
    if not tok {
        return "";
    }
    try {
        return fernet().encrypt(tok.encode("utf-8")).decode("ascii");
    } except Exception {
        return "";
    }
}


def:priv decrypt_gh(ct: str) -> str {
    # Decrypt the GitHub user token the browser hands back. The browser only ever
    # holds Fernet ciphertext; the server decrypts it per request to act on
    # GitHub as the user. jac-scale's bearer token handles WHO the caller is;
    # this ciphertext is the separate "act on GitHub" capability.
    if not ct {
        return "";
    }
    try {
        return str(fernet().decrypt(ct.encode("ascii")).decode("utf-8"));
    } except Exception {
        return "";
    }
}


def:priv mint_session_token(login: str) -> str {
    # Hand the session off to jac-scale instead of hand-rolling a JWT. Each
    # GitHub identity maps to a jac-scale user (created on first sign-in); we mint
    # a token for it. jac-scale signs/validates with JWT_SECRET — no key
    # management here. The user's password is random and never used: identity is
    # proven by GitHub OAuth, and we mint the token directly rather than via
    # /user/login.
    if not login {
        return "";
    }
    um = JacScaleUserManager(base_path="");
    user = um.find_user_by_identity(login);
    if user is not None {
        user_id = str(user.get("user_id", ""));
    } else {
        # Use the high-level convenience (username + password) rather than the
        # low-level create_user(identities=...): its signature differs across
        # jac-scale versions, so create_internal_user keeps us version-agnostic.
        created = um.create_internal_user(login, uuid.uuid4().hex);
        user_id = str(created.get("user_id", ""));
    }
    if not user_id {
        return "";
    }
    # include_role=False: skip the extra user-store role lookup — this app gates
    # on live GitHub repo permission (has_write_access), not jac-scale roles.
    return str(um.create_jwt_token(user_id, include_role=False));
}


def:priv gh_headers(token: str) -> dict {
    return {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "jaseci-blogs-submit",
    };
}


def:priv gh_ok(r: any, what: str) -> dict {
    # Return the JSON dict on a 2xx; otherwise raise with the status + GitHub's
    # message so failures surface as "create blob failed [403] ..." instead of a
    # bare KeyError('sha') three calls later.
    try {
        data = r.json();
    } except Exception {
        data = {};
    }
    if r.status_code >= 200 and r.status_code < 300 {
        return data if isinstance(data, dict) else {"_data": data};
    }
    msg = str(data.get("message", "")) if isinstance(data, dict) else "";
    raise ValueError(f"{what} failed [{r.status_code}] {msg}");
}


def:priv oauth_exchange_code(code: str, redirect_uri: str) -> dict | None {
    client_id = env_str("GH_OAUTH_CLIENT_ID");
    client_secret = env_str("GH_OAUTH_CLIENT_SECRET");
    if not client_id or not client_secret or not code {
        return None;
    }
    body = {"client_id": client_id, "client_secret": client_secret, "code": code};
    if redirect_uri {
        body["redirect_uri"] = redirect_uri;
    }
    try {
        r = requests.post(
            "https://github.com/login/oauth/access_token",
            headers={"Accept": "application/json", "User-Agent": "jaseci-blogs-submit"},
            json=body, timeout=30,
        );
        tok = r.json().get("access_token", "");
        if not tok {
            return None;
        }
        u = requests.get(
            f"{GH_API}/user",
            headers={
                "Authorization": f"token {tok}",
                "Accept": "application/vnd.github+json",
                "User-Agent": "jaseci-blogs-submit",
            },
            timeout=30,
        ).json();
    } except Exception {
        return None;
    }
    if not isinstance(u, dict) or "login" not in u {
        return None;
    }
    return {
        "login": str(u.get("login", "")),
        "uid": int(u.get("id", 0)),
        "name": str(u.get("name") or u.get("login", "")),
        "avatar": str(u.get("avatar_url", "")),
        "token": str(tok),
    };
}


def:priv has_write_access(token: str) -> bool {
    # Ask GitHub what THIS user can do on the repo: GET /repos returns a
    # `permissions` block for the authenticated caller. push/maintain/admin = reviewer.
    if not token {
        return False;
    }
    try {
        r = requests.get(f"{GH_API}/repos/{gh_repo()}", headers=gh_headers(token), timeout=30);
        if r.status_code != 200 {
            return False;
        }
        perms = r.json().get("permissions", {});
        if not isinstance(perms, dict) {
            return False;
        }
        return bool(perms.get("admin") or perms.get("maintain") or perms.get("push"));
    } except Exception {
        return False;
    }
}


def:priv gh_user(token: str) -> dict {
    # The signed-in user's GitHub identity, read live from their own token (so
    # it's authoritative — used to authorize "edit/list your own submissions" and
    # to build the author entry). Replaces the profile that used to ride inside
    # the hand-rolled session JWT; shaped like oauth_exchange_code's profile.
    if not token {
        return {};
    }
    try {
        u = requests.get(f"{GH_API}/user", headers=gh_headers(token), timeout=30).json();
    } except Exception {
        return {};
    }
    if not isinstance(u, dict) or "login" not in u {
        return {};
    }
    return {
        "login": str(u.get("login", "")),
        "uid": int(u.get("id", 0)),
        "name": str(u.get("name") or u.get("login", "")),
        "avatar": str(u.get("avatar_url", "")),
    };
}


def:priv is_valid_slug(slug: str) -> bool {
    return bool(re.match(r"^[a-z0-9]+(?:-[a-z0-9]+)*$", slug));
}


def:priv slug_taken(slug: str) -> bool {
    dir_path = Path(POSTS_DIR);
    if not dir_path.exists() {
        return False;
    }
    for path in dir_path.glob("*.md") {
        if path.name.startswith("_") {
            continue;
        }
        try {
            text = path.read_text(encoding="utf-8");
        } except Exception {
            continue;
        }
        if not text.startswith("---") {
            continue;
        }
        parts = text.split("---", 2);
        if len(parts) < 3 {
            continue;
        }
        try {
            meta = yaml.safe_load(parts[1]);
        } except Exception {
            continue;
        }
        if isinstance(meta, dict) and str(meta.get("slug", path.stem)) == slug {
            return True;
        }
    }
    return False;
}


def:priv load_scheduled_slugs() -> dict {
    # Map slug -> publish_at for entries still queued (scheduled or held).
    path = Path("docs/blog/.schedule.yml");
    result: dict = {};
    if not path.exists() {
        return result;
    }
    try {
        data = yaml.safe_load(path.read_text(encoding="utf-8"));
    } except Exception {
        return result;
    }
    if not isinstance(data, dict) {
        return result;
    }
    entries = data.get("schedule", []);
    if not isinstance(entries, list) {
        return result;
    }
    for e in entries {
        if not isinstance(e, dict) {
            continue;
        }
        if e.get("status") in ["scheduled", "held"] {
            s = str(e.get("slug", ""));
            if s {
                result[s] = str(e.get("publish_at", ""));
            }
        }
    }
    return result;
}


def:priv resolve_author_id(profile: dict, bio: str) -> tuple {
    # Returns (author_id, new_entry_or_None). Reuse an existing .authors.yml
    # entry whose avatar references this GitHub numeric id, or whose key matches
    # the login. Otherwise create a new entry keyed by the (sanitized) login.
    registry = load_authors();
    login = str(profile.get("login", "")).lower();
    uid = str(profile.get("uid", ""));
    for (key, entry) in registry.items() {
        if not isinstance(entry, dict) {
            continue;
        }
        avatar = str(entry.get("avatar", ""));
        if uid and f"/u/{uid}" in avatar {
            return (str(key), None);
        }
        if str(key).lower() == login {
            return (str(key), None);
        }
    }
    new_id = re.sub(r"[^a-z0-9-]", "-", login) or "contributor";
    new_entry = {
        "id": new_id,
        "name": str(profile.get("name", login)),
        "description": bio or "Contributor",
        "avatar": str(profile.get("avatar", "")),
    };
    return (new_id, new_entry);
}


def:priv build_post_markdown(
    title: str, slug: str, categories: list, description: str,
    author_id: str, body: str
) -> str {
    today = date_cls.today().isoformat();
    lines: list = ["---", f"date: {today}", "authors:", f"  - {author_id}", "categories:"];
    for c in categories {
        lines.append(f"  - {c}");
    }
    if description {
        lines.append(f"description: {json.dumps(description)}");
    }
    lines.append(f"slug: {slug}");
    lines.append("draft: true");
    lines.append("---");
    fm = "\n".join(lines);
    body_text: str = body.strip();
    if not body_text.startswith("#") {
        body_text = f"# {title}\n\n{body_text}";
    }
    return f"{fm}\n\n{body_text}\n";
}


def:priv authors_yml_with(new_entry: dict) -> str | None {
    path = Path(AUTHORS_PATH);
    try {
        text = path.read_text(encoding="utf-8");
    } except Exception {
        return None;
    }
    block = (
        f"  {new_entry['id']}:\n"
        + f"    name: {json.dumps(new_entry['name'])}\n"
        + f"    description: {json.dumps(new_entry['description'])}\n"
        + f"    avatar: {json.dumps(new_entry['avatar'])}\n"
    );
    if not text.endswith("\n") {
        text = f"{text}\n";
    }
    return f"{text}{block}";
}


def:priv ensure_fork(token: str, login: str) -> str {
    # Fork the upstream repo into the user's account (idempotent — returns the
    # existing fork if present). Forking is ASYNC: GitHub returns the repo record
    # before the git objects are copied, so poll the branch *ref* (not just the
    # repo) until it resolves — that's when blobs/trees/commits will succeed.
    repo = gh_repo();
    base_branch = gh_base_branch();
    name = repo.split("/", 1)[1] if "/" in repo else repo;
    fork_full = f"{login}/{name}";
    h = gh_headers(token);
    gh_ok(requests.post(f"{GH_API}/repos/{repo}/forks", headers=h, timeout=30), "fork repo");
    i = 0;
    while i < 30 {
        r = requests.get(f"{GH_API}/repos/{fork_full}/git/ref/heads/{base_branch}", headers=h, timeout=30);
        if r.status_code == 200 and isinstance(r.json().get("object"), dict) {
            return fork_full;
        }
        time.sleep(2);
        i = i + 1;
    }
    raise ValueError("fork did not become ready in time — try again in a moment");
}


def:priv build_commit(token: str, repo_full: str, base_sha: str, files: list, message: str) -> str {
    # Create blobs/tree/commit on top of base_sha; return the new commit sha.
    # Text files go inline in the tree; images become base64 blobs first.
    h = gh_headers(token);
    base_commit = gh_ok(requests.get(f"{GH_API}/repos/{repo_full}/git/commits/{base_sha}", headers=h, timeout=30), "read base commit");
    base_tree = str(base_commit["tree"]["sha"]);

    tree_items = [];
    for f in files {
        if f.get("binary") {
            blob = gh_ok(requests.post(
                f"{GH_API}/repos/{repo_full}/git/blobs",
                headers=h, json={"content": f["content"], "encoding": "base64"}, timeout=30,
            ), "create image blob");
            tree_items.append({"path": f["path"], "mode": "100644", "type": "blob", "sha": str(blob["sha"])});
        } else {
            tree_items.append({"path": f["path"], "mode": "100644", "type": "blob", "content": f["content"]});
        }
    }
    new_tree = gh_ok(requests.post(
        f"{GH_API}/repos/{repo_full}/git/trees",
        headers=h, json={"base_tree": base_tree, "tree": tree_items}, timeout=30,
    ), "create tree");
    new_commit = gh_ok(requests.post(
        f"{GH_API}/repos/{repo_full}/git/commits",
        headers=h, json={"message": message, "tree": str(new_tree["sha"]), "parents": [base_sha]}, timeout=30,
    ), "create commit");
    return str(new_commit["sha"]);
}


def:priv commit_to_repo(
    token: str, repo_full: str, branch: str, base_branch: str,
    files: list, message: str
) -> None {
    # First commit on a NEW branch (forked off base_branch).
    h = gh_headers(token);
    ref = gh_ok(requests.get(f"{GH_API}/repos/{repo_full}/git/ref/heads/{base_branch}", headers=h, timeout=30), "read base ref");
    new_sha = build_commit(token, repo_full, str(ref["object"]["sha"]), files, message);
    gh_ok(requests.post(
        f"{GH_API}/repos/{repo_full}/git/refs",
        headers=h, json={"ref": f"refs/heads/{branch}", "sha": new_sha}, timeout=30,
    ), "create branch");
}


def:priv commit_update(token: str, repo_full: str, branch: str, files: list, message: str) -> None {
    # Add a commit ON TOP of an existing branch (updates an open PR). Bases the
    # commit on the branch's current head and fast-forwards the ref.
    h = gh_headers(token);
    ref = gh_ok(requests.get(f"{GH_API}/repos/{repo_full}/git/ref/heads/{branch}", headers=h, timeout=30), "read branch ref");
    new_sha = build_commit(token, repo_full, str(ref["object"]["sha"]), files, message);
    gh_ok(requests.patch(
        f"{GH_API}/repos/{repo_full}/git/refs/heads/{branch}",
        headers=h, json={"sha": new_sha, "force": False}, timeout=30,
    ), "update branch");
}


def:priv submit_via_fork(
    token: str, login: str, branch: str, files: list, message: str,
    pr_title: str, pr_body: str
) -> dict {
    # Open the PR entirely AS THE USER: fork → sync fork's default branch →
    # commit to a branch on the fork → open a cross-fork PR to upstream. No app,
    # no privileged token — just the contributor's own public_repo access.
    base_branch = gh_base_branch();
    fork_full = ensure_fork(token, login);
    # Bring the fork's default branch up to date with upstream (no-op for a fresh
    # fork; matters for a returning contributor whose fork is stale).
    try {
        requests.post(
            f"{GH_API}/repos/{fork_full}/merge-upstream",
            headers=gh_headers(token), json={"branch": base_branch}, timeout=30,
        );
    } except Exception {
        _ignore = None;
    }
    commit_to_repo(token, fork_full, branch, base_branch, files, message);
    pr = gh_ok(requests.post(
        f"{GH_API}/repos/{gh_repo()}/pulls",
        headers=gh_headers(token),
        json={
            "title": pr_title, "head": f"{login}:{branch}", "base": base_branch,
            "body": pr_body,
        },
        timeout=30,
    ), "open pull request");
    return pr;
}


def:priv rewrite_assets_to_raw(body: str, repo: str, sha: str) -> str {
    # For reviewer previews: point asset references at the raw blobs on the PR's
    # head ref, so images render before the post is merged + deployed.
    base = f"https://raw.githubusercontent.com/{repo}/{sha}/docs/assets/";
    body = re.sub(r"(!\[[^\]]*\]\()(?:\.\./)+assets/", r"\1" + base, body);
    body = re.sub(r"(<img[^>]+src=[\"'])(?:\.\./)+assets/", r"\1" + base, body);
    body = body.replace("](/assets/", f"]({base}");
    body = body.replace('src="/assets/', f'src="{base}');
    body = body.replace("src='/assets/", f"src='{base}");
    return body;
}


def:priv render_submitted_markdown(text: str, raw_repo: str, raw_sha: str) -> dict {
    # Draft-tolerant render of a raw post file (parse_post_file drops drafts).
    # Reuses the same pipeline GetPost uses so previews match the live look.
    meta: dict = {};
    raw_body = text;
    if text.startswith("---") {
        parts = text.split("---", 2);
        if len(parts) >= 3 {
            try {
                loaded = yaml.safe_load(parts[1]);
                meta = loaded if isinstance(loaded, dict) else {};
            } except Exception {
                meta = {};
            }
            raw_body = parts[2].strip();
        }
    }
    registry = load_authors();
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
    title = str(meta.get("title", ""));
    if not title {
        h1 = re.search(r"(?m)^#\s+(.+)$", raw_body);
        title = h1.group(1).strip() if h1 else str(meta.get("slug", "")).replace("-", " ").title();
    }
    title = strip_markdown_inline(title);
    if raw_repo and raw_sha {
        body = rewrite_assets_to_raw(raw_body, raw_repo, raw_sha);
    } else {
        body = rewrite_asset_paths(raw_body);
    }
    body = convert_mermaid_fences(body);
    body = inject_markdown_attr(body);
    html = render_markdown(body);
    return {
        "title": title,
        "slug": str(meta.get("slug", "")),
        "description": str(meta.get("description", "")),
        "authors": authors,
        "categories": categories,
        "draft": bool(meta.get("draft", False)),
        "reading_minutes": estimate_reading_minutes(raw_body),
        "html": html,
    };
}


def:priv fetch_pr_post(token: str, pr_number: int) -> dict | None {
    # Read the single post file a PR touches (from the PR's head ref). Defensive
    # by design: any malformed or error GitHub response — rate-limit object, a
    # deleted/inaccessible head fork, a transient 5xx — returns None instead of
    # raising, so callers report a clean "could not load that PR" rather than a
    # 500 that surfaces to the user as "Network error". Shared by the reviewer
    # preview, the shareable-preview creator, and the edit walkers.
    try {
        h = gh_headers(token);
        repo = gh_repo();
        pr = requests.get(f"{GH_API}/repos/{repo}/pulls/{pr_number}", headers=h, timeout=30).json();
        if not isinstance(pr, dict) or not isinstance(pr.get("head"), dict) {
            return None;
        }
        head = pr["head"];
        head_repo_obj = head.get("repo");
        if not isinstance(head_repo_obj, dict) {
            return None;
        }
        head_sha = str(head.get("sha", ""));
        head_repo = str(head_repo_obj.get("full_name", ""));
        owner_obj = head_repo_obj.get("owner");
        head_owner = str(owner_obj.get("login", "")) if isinstance(owner_obj, dict) else "";
        if not head_repo {
            return None;
        }
        files = requests.get(
            f"{GH_API}/repos/{repo}/pulls/{pr_number}/files",
            headers=h, params={"per_page": 100}, timeout=30,
        ).json();
        if not isinstance(files, list) {
            # e.g. a rate-limit / error object instead of the file array.
            return None;
        }
        post_path = "";
        for f in files {
            if not isinstance(f, dict) {
                continue;
            }
            fn = str(f.get("filename", ""));
            if fn.startswith("docs/blog/posts/") and fn.endswith(".md") {
                post_path = fn;
                break;
            }
        }
        if not post_path {
            return None;
        }
        blob = requests.get(
            f"{GH_API}/repos/{head_repo}/contents/{post_path}",
            headers=h, params={"ref": head_sha}, timeout=30,
        ).json();
        if not isinstance(blob, dict) {
            return None;
        }
        content = base64.b64decode(str(blob.get("content", ""))).decode("utf-8");
    } except Exception {
        return None;
    }
    return {
        "content": content,
        "post_path": post_path,
        "head_repo": head_repo,
        "head_ref": str(head.get("ref", "")),
        "head_owner": head_owner,
        "head_sha": head_sha,
        "state": str(pr.get("state", "")),
        "merged": bool(pr.get("merged_at")),
        "pr_url": str(pr.get("html_url", "")),
        "mergeable": pr.get("mergeable"),
        "mergeable_state": str(pr.get("mergeable_state", "")),
    };
}


def:priv preview_payload(rendered: dict) -> dict {
    # Shape render_submitted_markdown output into the GetPost-style payload the
    # post page expects, so a preview renders identically to a live post.
    return {
        "ok": True,
        "slug": str(rendered["slug"]),
        "title": str(rendered["title"]),
        "description": str(rendered["description"]),
        "authors": rendered["authors"],
        "categories": rendered["categories"],
        "date": "",
        "date_long": "Preview",
        "reading_minutes": rendered["reading_minutes"],
        "cover": "",
        "html": rendered["html"],
        "prev": None,
        "next": None,
        "related": [],
        "is_preview": True,
    };
}


def:priv match_preview(docs: list, token: str) -> any {
    # Pick a non-expired PreviewDoc matching token from a pre-collected list
    # (the edge traversal happens in the walker ability where it's valid).
    if not token {
        return None;
    }
    now = float(time.time());
    for d in docs {
        if d.token == token and (now - d.created_at) <= PREVIEW_TTL {
            return d;
        }
    }
    return None;
}


walker:priv CreatePreview {
    has gh_enc: str = "";
    has pr_number: int = 0;
    # The browser's current origin, so the shareable link points at THIS
    # deployment (localhost in dev, blogs.jaseci.org in prod) instead of the
    # hardcoded PUBLIC_SITE_URL fallback. Falls back to public_site_url() if
    # the caller doesn't pass one.
    has origin: str = "";

    can make with Root entry {
        gh_token = decrypt_gh(self.gh_enc);
        if not gh_token {
            report {"ok": False, "error": "not signed in"};
            return;
        }
        if not self.pr_number {
            report {"ok": False, "error": "missing pr_number"};
            return;
        }
        try {
            pr = fetch_pr_post(gh_token, self.pr_number);
        } except Exception as e {
            report {"ok": False, "error": f"could not load PR: {e}"};
            return;
        }
        if pr is None {
            report {"ok": False, "error": "no post file found in this PR"};
            return;
        }
        rendered = render_submitted_markdown(str(pr["content"]), str(pr["head_repo"]), str(pr["head_sha"]));
        token = uuid.uuid4().hex;
        # Previews are public (opened anonymously via /preview/<token>), so they
        # live on the shared public root, not the caller's per-user root, and are
        # granted ReadPerm so anonymous readers can see them.
        shared_root = root.shared;  # jac:ignore[E1030] runtime attr, no static stub
        fresh = shared_root ++> PreviewDoc(
            token=token, slug=str(rendered["slug"]),
            data=preview_payload(rendered), created_at=float(time.time()),
        );
        grant(fresh[0], level=ReadPerm);
        base = self.origin.rstrip("/") if self.origin else public_site_url();
        report {"ok": True, "token": token, "slug": str(rendered["slug"]), "url": f"{base}/preview/{token}"};
    }
}


walker:pub GetPreview {
    # Resolve a preview token -> slug, so /preview/<token> can redirect to the
    # real post page (which renders the snapshot with full enhancements).
    has token: str = "";

    can get with Root entry {
        shared_root = root.shared;  # jac:ignore[E1030] runtime attr, no static stub
        doc = match_preview([shared_root -->][?:PreviewDoc], self.token);
        if doc is None {
            report {"ok": False, "error": "This preview link is invalid or has expired."};
            return;
        }
        report {"ok": True, "slug": doc.slug};
    }
}


walker:pub GithubOAuthConfig {
    # Hands the browser the OAuth client id so it can build the authorize URL.
    can get with Root entry {
        client_id = env_str("GH_OAUTH_CLIENT_ID");
        report {"ok": True, "client_id": client_id, "configured": bool(client_id)};
    }
}


walker:pub GithubOAuthExchange {
    has code: str = "";
    has redirect_uri: str = "";

    can get with Root entry {
        if not self.code {
            report {"ok": False, "error": "missing code"};
            return;
        }
        profile = oauth_exchange_code(self.code, self.redirect_uri);
        if profile is None {
            report {"ok": False, "error": "github authentication failed"};
            return;
        }
        gh_token = str(profile["token"]);
        token = mint_session_token(str(profile["login"]));
        if not token {
            report {"ok": False, "error": "could not start session"};
            return;
        }
        # token: jac-scale session JWT (the browser stores it as `jac_token`, the
        # runtime sends it as a Bearer on every walker call). gh_enc: the GitHub
        # token as Fernet ciphertext — the browser holds only this, and passes it
        # back per request so the server can act on GitHub as the user.
        report {
            "ok": True,
            "token": token,
            "gh_enc": encrypt_token(gh_token),
            "profile": {
                "login": profile["login"],
                "name": profile["name"],
                "avatar": profile["avatar"],
            },
            "is_reviewer": has_write_access(gh_token),
        };
    }
}


def:priv collect_images(images: list, slug: str) -> dict {
    # Validate + turn uploaded images into tree-file entries under the slug's
    # asset dir. Returns {"ok": True, "files": [...]} or {"ok": False, "error": ...}.
    if len(images) > MAX_IMAGES {
        return {"ok": False, "error": f"too many images (max {MAX_IMAGES})"};
    }
    out = [];
    for img in images {
        name = str(img.get("name", "")).strip();
        b64 = str(img.get("b64", ""));
        if not name or not b64 {
            continue;
        }
        ext = name.rsplit(".", 1)[-1].lower() if "." in name else "";
        if ext not in ALLOWED_IMAGE_EXT {
            return {"ok": False, "error": f"unsupported image type: {name}"};
        }
        try {
            raw = base64.b64decode(b64);
        } except Exception {
            return {"ok": False, "error": f"could not decode image: {name}"};
        }
        if len(raw) > MAX_IMAGE_BYTES {
            return {"ok": False, "error": f"image {name} exceeds 100KB"};
        }
        safe_name = re.sub(r"[^A-Za-z0-9._-]", "-", name);
        out.append({"path": f"docs/assets/{slug}/{safe_name}", "content": b64, "binary": True});
    }
    return {"ok": True, "files": out};
}


def:priv parse_post_for_edit(content: str) -> dict {
    # Split a stored post .md into the form fields for editing. Body keeps its
    # leading H1; slug/categories/description come from frontmatter.
    meta: dict = {};
    raw_body = content;
    if content.startswith("---") {
        parts = content.split("---", 2);
        if len(parts) >= 3 {
            try {
                loaded = yaml.safe_load(parts[1]);
                meta = loaded if isinstance(loaded, dict) else {};
            } except Exception {
                meta = {};
            }
            raw_body = parts[2].strip();
        }
    }
    categories = meta.get("categories", []);
    if not isinstance(categories, list) {
        categories = [categories];
    }
    author_ids = meta.get("authors", []);
    if not isinstance(author_ids, list) {
        author_ids = [author_ids];
    }
    title = str(meta.get("title", ""));
    if not title {
        h1 = re.search(r"(?m)^#\s+(.+)$", raw_body);
        title = strip_markdown_inline(h1.group(1).strip()) if h1 else "";
    }
    return {
        "title": title,
        "slug": str(meta.get("slug", "")),
        "categories": [str(c) for c in categories],
        "authors": [str(a) for a in author_ids],
        "description": str(meta.get("description", "")),
        "body_md": raw_body,
    };
}


def:priv find_post_path(slug: str) -> str | None {
    # Posts identify by their frontmatter `slug:`, NOT their filename (files are
    # snake_case, slugs kebab-case), so resolve the real repo path for a slug by
    # scanning the posts dir. Falls back to a filename-stem match.
    dir_path = Path(POSTS_DIR);
    if not slug or not dir_path.exists() {
        return None;
    }
    fallback = "";
    for path in sorted(dir_path.glob("*.md")) {
        if path.name.startswith("_") {
            continue;
        }
        if path.stem == slug {
            fallback = f"{POSTS_DIR}/{path.name}";
        }
        try {
            text = path.read_text(encoding="utf-8");
        } except Exception {
            continue;
        }
        if text.startswith("---") {
            parts = text.split("---", 2);
            if len(parts) >= 3 {
                try {
                    meta = yaml.safe_load(parts[1]);
                } except Exception {
                    meta = None;
                }
                if isinstance(meta, dict) and str(meta.get("slug", "")) == slug {
                    return f"{POSTS_DIR}/{path.name}";
                }
            }
        }
    }
    return fallback if fallback else None;
}


def:priv fetch_main_post(token: str, slug: str) -> dict | None {
    # Current markdown for a published post, read from the base branch (so a
    # recent edit on main isn't missed). The path is resolved by slug — see
    # find_post_path. Falls back to the local file if the API read is empty.
    path = find_post_path(slug);
    if path is None {
        return None;
    }
    content = "";
    try {
        blob = requests.get(
            f"{GH_API}/repos/{gh_repo()}/contents/{path}",
            headers=gh_headers(token), params={"ref": gh_base_branch()}, timeout=30,
        ).json();
        content = base64.b64decode(str(blob.get("content", ""))).decode("utf-8");
    } except Exception {
        content = "";
    }
    if not content {
        try {
            content = Path(path).read_text(encoding="utf-8");
        } except Exception {
            return None;
        }
    }
    return {"content": content, "post_path": path};
}


def:priv post_path_to_slug() -> dict[str, str] {
    # Map each post's repo-relative path -> its frontmatter slug, so a PR's
    # changed-file path can be associated back to a post (filename != slug).
    out: dict[str, str] = {};
    dir_path = Path(POSTS_DIR);
    if not dir_path.exists() {
        return out;
    }
    for path in sorted(dir_path.glob("*.md")) {
        if path.name.startswith("_") {
            continue;
        }
        slug = path.stem;
        try {
            text = path.read_text(encoding="utf-8");
            if text.startswith("---") {
                parts = text.split("---", 2);
                if len(parts) >= 3 {
                    meta = yaml.safe_load(parts[1]);
                    if isinstance(meta, dict) and meta.get("slug") {
                        slug = str(meta.get("slug"));
                    }
                }
            }
        } except Exception {
            _ignore = None;
        }
        out[f"{POSTS_DIR}/{path.name}"] = slug;
    }
    return out;
}


def:priv open_edit_prs_by_slug(token: str) -> dict[str, list] {
    # ALL open PRs that EDIT an existing post, grouped by the post's slug. Found by
    # the file a PR changes (not a marker), so it picks up edit PRs opened through
    # the portal AND directly on GitHub. (Submission PRs add a NEW file, which
    # isn't in the path map, so they don't match — only edits to live posts do.)
    grouped: dict[str, list] = {};
    path_to_slug = post_path_to_slug();
    try {
        prs = requests.get(
            f"{GH_API}/repos/{gh_repo()}/pulls",
            headers=gh_headers(token),
            params={"state": "open", "per_page": 100, "sort": "created", "direction": "desc"},
            timeout=30,
        ).json();
    } except Exception {
        return grouped;
    }
    if not isinstance(prs, list) {
        return grouped;
    }
    for pr in prs {
        n = int(pr.get("number", 0));
        try {
            files = requests.get(
                f"{GH_API}/repos/{gh_repo()}/pulls/{n}/files",
                headers=gh_headers(token), params={"per_page": 100}, timeout=30,
            ).json();
        } except Exception {
            continue;
        }
        if not isinstance(files, list) {
            continue;
        }
        touched: list = [];
        for f in files {
            fn = str(f.get("filename", ""));
            if fn in path_to_slug {
                s = str(path_to_slug[fn]);
                if s not in touched {
                    touched.append(s);
                }
            }
        }
        if not touched {
            continue;
        }
        user = pr.get("user");
        author = str(user.get("login", "")) if isinstance(user, dict) else "";
        entry = {
            "number": n,
            "url": str(pr.get("html_url", "")),
            "title": str(pr.get("title", "")),
            "author": author,
        };
        for s in touched {
            if s in grouped {
                grouped[s].append(entry);
            } else {
                grouped[s] = [entry];
            }
        }
    }
    return grouped;
}


def:priv find_open_edit_prs(token: str, slug: str) -> list {
    # Open edit PRs for one post — the collision check on the edit form.
    return open_edit_prs_by_slug(token).get(slug, []);
}


def:priv build_edited_markdown(
    original_content: str, title: str, categories: list, description: str, body: str
) -> str {
    # Rebuild a post's .md PRESERVING its frontmatter — date, authors, slug, and
    # crucially the draft state (a live post has no draft key, so the edit stays
    # live and deploys on merge) — while applying the edited categories,
    # description, and body. Contrast build_post_markdown, which is for NEW drafts
    # (date=today, draft:true).
    meta: dict = {};
    if original_content.startswith("---") {
        parts = original_content.split("---", 2);
        if len(parts) >= 3 {
            try {
                loaded = yaml.safe_load(parts[1]);
                meta = loaded if isinstance(loaded, dict) else {};
            } except Exception {
                meta = {};
            }
        }
    }
    meta["categories"] = [str(c) for c in categories];
    if description {
        meta["description"] = description;
    } else {
        meta.pop("description", None);
    }
    fm = str(yaml.safe_dump(meta, sort_keys=False, allow_unicode=True)).strip();
    body_text: str = body.strip();
    if not body_text.startswith("#") {
        body_text = f"# {title}\n\n{body_text}";
    }
    return f"---\n{fm}\n---\n\n{body_text}\n";
}


walker:priv SubmitPost {
    has gh_enc: str = "";
    has title: str = "";
    has slug: str = "";
    has categories: list = [];
    has description: str = "";
    has body_md: str = "";
    has author_bio: str = "";
    has images: list = [];

    can submit with Root entry {
        gh_token = decrypt_gh(self.gh_enc);
        if not gh_token {
            report {"ok": False, "error": "session expired — please sign in again"};
            return;
        }
        profile = gh_user(gh_token);
        if not profile.get("login") {
            report {"ok": False, "error": "session expired — please sign in again"};
            return;
        }
        title = self.title.strip();
        slug = self.slug.strip().lower();
        body = self.body_md;

        if not title {
            report {"ok": False, "error": "title is required"};
            return;
        }
        if not is_valid_slug(slug) {
            report {"ok": False, "error": "slug must be kebab-case (lowercase letters, digits, hyphens)"};
            return;
        }
        if slug_taken(slug) {
            report {"ok": False, "error": f"slug '{slug}' is already taken"};
            return;
        }
        if len(body.strip()) < 50 {
            report {"ok": False, "error": "post body is too short"};
            return;
        }
        cats = [str(c) for c in self.categories if str(c) in ALLOWED_CATEGORIES];
        if not cats {
            report {"ok": False, "error": "select at least one valid category"};
            return;
        }
        img_res = collect_images(self.images, slug);
        if not img_res["ok"] {
            report {"ok": False, "error": img_res["error"]};
            return;
        }
        image_files = img_res["files"];

        (author_id, new_entry) = resolve_author_id(profile, self.author_bio.strip());
        post_md = build_post_markdown(title, slug, cats, self.description.strip(), author_id, body);
        files = [{"path": f"docs/blog/posts/{slug}.md", "content": post_md, "binary": False}];
        files = files + image_files;
        if new_entry is not None {
            updated = authors_yml_with(new_entry);
            if updated is not None {
                files.append({"path": "docs/blog/.authors.yml", "content": updated, "binary": False});
            }
        }

        branch = f"submit/{slug}-{int(time.time())}";
        marker = f"\n\n<!-- blog-submission slug={slug} by={profile['login']} -->";
        pr_body = (
            "Blog submission via the /submit form.\n\n"
            + f"**Title:** {title}\n"
            + f"**Author:** @{profile['login']} (`{author_id}`)\n"
            + f"**Categories:** {', '.join(cats)}\n\n"
            + "Opened from the author's fork via the /submit form. "
            + "`draft: true` is set; a reviewer will schedule publication."
            + marker
        );

        try {
            pr = submit_via_fork(gh_token, str(profile["login"]), branch, files, f"Add blog post: {title}", title, pr_body);
        } except Exception as e {
            report {"ok": False, "error": f"could not open PR: {e}"};
            return;
        }
        if not pr.get("number") {
            report {"ok": False, "error": "PR creation failed", "detail": pr};
            return;
        }
        report {"ok": True, "pr_number": pr["number"], "pr_url": pr.get("html_url", ""), "slug": slug};
    }
}


walker:priv GetSubmissionForEdit {
    has gh_enc: str = "";
    has pr_number: int = 0;

    can get with Root entry {
        gh_token = decrypt_gh(self.gh_enc);
        if not gh_token {
            report {"ok": False, "error": "not signed in"};
            return;
        }
        try {
            pr = fetch_pr_post(gh_token, self.pr_number);
        } except Exception as e {
            report {"ok": False, "error": f"could not load submission: {e}"};
            return;
        }
        if pr is None {
            report {"ok": False, "error": "no post file found in this PR"};
            return;
        }
        if str(pr["head_owner"]).lower() != str(gh_user(gh_token).get("login", "")).lower() {
            report {"ok": False, "error": "you can only edit your own submissions"};
            return;
        }
        if pr["state"] != "open" or pr["merged"] {
            report {"ok": False, "error": "this submission can no longer be edited (already merged or closed)"};
            return;
        }
        fields = parse_post_for_edit(str(pr["content"]));
        report {"ok": True, "pr_number": self.pr_number, "branch": str(pr["head_ref"]), **fields};
    }
}


walker:priv UpdatePost {
    has gh_enc: str = "";
    has pr_number: int = 0;
    has title: str = "";
    has slug: str = "";
    has categories: list = [];
    has description: str = "";
    has body_md: str = "";
    has images: list = [];

    can update with Root entry {
        gh_token = decrypt_gh(self.gh_enc);
        if not gh_token {
            report {"ok": False, "error": "not signed in"};
            return;
        }
        profile = gh_user(gh_token);
        if not profile.get("login") {
            report {"ok": False, "error": "not signed in"};
            return;
        }
        try {
            pr = fetch_pr_post(gh_token, self.pr_number);
        } except Exception as e {
            report {"ok": False, "error": f"could not load submission: {e}"};
            return;
        }
        if pr is None {
            report {"ok": False, "error": "no post file found in this PR"};
            return;
        }
        if str(pr["head_owner"]).lower() != str(profile["login"]).lower() {
            report {"ok": False, "error": "you can only edit your own submissions"};
            return;
        }
        if pr["state"] != "open" or pr["merged"] {
            report {"ok": False, "error": "this submission can no longer be edited"};
            return;
        }

        title = self.title.strip();
        slug = self.slug.strip().lower();  # slug is fixed for an edit
        body = self.body_md;
        if not title {
            report {"ok": False, "error": "title is required"};
            return;
        }
        if len(body.strip()) < 50 {
            report {"ok": False, "error": "post body is too short"};
            return;
        }
        cats = [str(c) for c in self.categories if str(c) in ALLOWED_CATEGORIES];
        if not cats {
            report {"ok": False, "error": "select at least one valid category"};
            return;
        }
        img_res = collect_images(self.images, slug);
        if not img_res["ok"] {
            report {"ok": False, "error": img_res["error"]};
            return;
        }

        # Resolve the author's id (reuses their existing .authors.yml entry);
        # don't re-touch .authors.yml on edit — the entry already exists.
        (author_id, _new) = resolve_author_id(profile, "");
        post_md = build_post_markdown(title, slug, cats, self.description.strip(), author_id, body);
        files = [{"path": f"docs/blog/posts/{slug}.md", "content": post_md, "binary": False}];
        files = files + img_res["files"];

        try {
            commit_update(gh_token, str(pr["head_repo"]), str(pr["head_ref"]), files, f"Update blog post: {title}");
        } except Exception as e {
            report {"ok": False, "error": f"could not save changes: {e}"};
            return;
        }
        report {"ok": True, "pr_number": self.pr_number, "pr_url": str(pr["pr_url"]), "slug": slug};
    }
}


walker:priv ListEditablePosts {
    # Published posts the caller may edit: reviewers (repo write) get every live
    # post; everyone else gets only posts they're a registered author of.
    has gh_enc: str = "";

    can get with Root entry {
        gh_token = decrypt_gh(self.gh_enc);
        if not gh_token {
            report {"ok": False, "error": "not signed in"};
            return;
        }
        is_reviewer = has_write_access(gh_token);
        my_author_id = "";
        if not is_reviewer {
            (my_author_id, _e) = resolve_author_id(gh_user(gh_token), "");
        }
        # All live posts come from the files on main (list_all_posts reads disk),
        # so this covers posts published through the app AND by direct push.
        # Open edit PRs are fetched once and attached per slug.
        prs_by_slug = open_edit_prs_by_slug(gh_token);
        out: list = [];
        for p in list_all_posts() {
            author_ids = [str(a["id"]) for a in p["authors"]];
            if is_reviewer or (my_author_id and my_author_id in author_ids) {
                slug = str(p["slug"]);
                out.append({
                    "slug": slug,
                    "title": str(p["title"]),
                    "date": str(p["date"]),
                    "authors": author_ids,
                    "edit_prs": prs_by_slug.get(slug, []),
                });
            }
        }
        report {"ok": True, "posts": out, "is_reviewer": is_reviewer};
    }
}


walker:priv GetPublishedPostForEdit {
    # Load a published post's current source into the edit form, and surface any
    # open edit PRs for it (collision check).
    has gh_enc: str = "";
    has slug: str = "";

    can get with Root entry {
        gh_token = decrypt_gh(self.gh_enc);
        if not gh_token {
            report {"ok": False, "error": "not signed in"};
            return;
        }
        if not self.slug {
            report {"ok": False, "error": "missing slug"};
            return;
        }
        main_post = fetch_main_post(gh_token, self.slug);
        if main_post is None {
            report {"ok": False, "error": "no published post with that slug"};
            return;
        }
        fields = parse_post_for_edit(str(main_post["content"]));
        if not has_write_access(gh_token) {
            (my_author_id, _e) = resolve_author_id(gh_user(gh_token), "");
            if not my_author_id or my_author_id not in fields["authors"] {
                report {"ok": False, "error": "you can only edit posts you authored"};
                return;
            }
        }
        report {"ok": True, "existing_prs": find_open_edit_prs(gh_token, self.slug), **fields};
    }
}


walker:priv EditPublishedPost {
    # Open a NEW PR editing a published post (or add a commit to the caller's own
    # open edit PR). The post stays live; frontmatter is preserved so merging just
    # ships the edit.
    has gh_enc: str = "";
    has slug: str = "";
    has title: str = "";
    has categories: list = [];
    has description: str = "";
    has body_md: str = "";
    has images: list = [];
    has pr_number: int = 0;  # >0 = continue the caller's own open edit PR

    can edit with Root entry {
        gh_token = decrypt_gh(self.gh_enc);
        if not gh_token {
            report {"ok": False, "error": "not signed in"};
            return;
        }
        profile = gh_user(gh_token);
        login = str(profile.get("login", ""));
        if not login {
            report {"ok": False, "error": "not signed in"};
            return;
        }
        slug = self.slug.strip().lower();
        main_post = fetch_main_post(gh_token, slug);
        if main_post is None {
            report {"ok": False, "error": "no published post with that slug"};
            return;
        }
        original = str(main_post["content"]);
        if not has_write_access(gh_token) {
            base_fields = parse_post_for_edit(original);
            (my_author_id, _e) = resolve_author_id(profile, "");
            if not my_author_id or my_author_id not in base_fields["authors"] {
                report {"ok": False, "error": "you can only edit posts you authored"};
                return;
            }
        }
        title = self.title.strip();
        if not title {
            report {"ok": False, "error": "title is required"};
            return;
        }
        cats = [str(c) for c in self.categories if str(c) in ALLOWED_CATEGORIES];
        if not cats {
            report {"ok": False, "error": "select at least one valid category"};
            return;
        }
        if len(self.body_md.strip()) < 50 {
            report {"ok": False, "error": "post body is too short"};
            return;
        }
        img_res = collect_images(self.images, slug);
        if not img_res["ok"] {
            report {"ok": False, "error": img_res["error"]};
            return;
        }
        post_md = build_edited_markdown(original, title, cats, self.description.strip(), self.body_md);
        # Write back to the post's ACTUAL file (filename != slug), so the PR edits
        # the existing post instead of creating a new file.
        files = [{"path": str(main_post["post_path"]), "content": post_md, "binary": False}];
        files = files + img_res["files"];

        if self.pr_number {
            # Continue the caller's OWN open edit PR (we can only push to own fork).
            pr = fetch_pr_post(gh_token, self.pr_number);
            if pr is None {
                report {"ok": False, "error": "could not load that PR"};
                return;
            }
            if str(pr["head_owner"]).lower() != login.lower() {
                report {"ok": False, "error": "you can only add to your own edit PR"};
                return;
            }
            if pr["state"] != "open" or pr["merged"] {
                report {"ok": False, "error": "that PR is already merged or closed"};
                return;
            }
            try {
                commit_update(gh_token, str(pr["head_repo"]), str(pr["head_ref"]), files, f"Edit blog post: {title}");
            } except Exception as e {
                report {"ok": False, "error": f"could not save changes: {e}"};
                return;
            }
            report {"ok": True, "pr_number": self.pr_number, "pr_url": str(pr["pr_url"]), "slug": slug};
            return;
        }

        branch = f"edit/{slug}-{int(time.time())}";
        marker = f"\n\n<!-- {EDIT_TAG} slug={slug} by={login} -->";
        pr_body = (
            "Edit to a published post via the /submit ▸ Edit a post form.\n\n"
            + f"**Post:** {title} (`{slug}`)\n"
            + f"**Editor:** @{login}\n\n"
            + "The post stays live; merging publishes the edit. Frontmatter (date, "
            + "authors, published status) is preserved."
            + marker
        );
        try {
            pr = submit_via_fork(gh_token, login, branch, files, f"Edit blog post: {title}", title, pr_body);
        } except Exception as e {
            report {"ok": False, "error": f"could not open edit PR: {e}"};
            return;
        }
        report {"ok": True, "pr_number": int(pr["number"]), "pr_url": str(pr["html_url"]), "slug": slug};
    }
}


walker:priv MySubmissions {
    has gh_enc: str = "";

    can get with Root entry {
        gh_token = decrypt_gh(self.gh_enc);
        if not gh_token {
            report {"ok": False, "error": "not signed in"};
            return;
        }
        login = str(gh_user(gh_token).get("login", ""));
        if not login {
            report {"ok": False, "error": "not signed in"};
            return;
        }
        try {
            q = f'repo:{gh_repo()} type:pr "{SUBMISSION_TAG}" in:body';
            r = requests.get(
                f"{GH_API}/search/issues",
                headers=gh_headers(gh_token),
                params={"q": q, "per_page": 50, "sort": "created", "order": "desc"},
                timeout=30,
            );
            data = r.json();
        } except Exception as e {
            report {"ok": False, "error": f"could not load submissions: {e}"};
            return;
        }
        items = data.get("items", []) if isinstance(data, dict) else [];
        live_slugs = {p["slug"] for p in list_all_posts()};
        scheduled = load_scheduled_slugs();
        out = [];
        for it in items {
            body = str(it.get("body", "") or "");
            bym = re.search(r"by=([A-Za-z0-9-]+)", body);
            if (bym.group(1) if bym else "") != login {
                continue;  # only this author's submissions
            }
            m = re.search(r"slug=([a-z0-9-]+)", body);
            slug = m.group(1) if m else "";
            state = str(it.get("state", "open"));
            pr_info = it.get("pull_request", {}) or {};
            merged = bool(pr_info.get("merged_at"));
            status: str = "in_review";
            published_url: str = "";
            schedule_at: str = "";
            if state == "open" {
                status = "in_review";
            } elif merged {
                if slug and slug in live_slugs {
                    status = "published";
                    published_url = f"{public_site_url()}/blog/posts/{slug}";
                } elif slug and slug in scheduled {
                    status = "scheduled";
                    schedule_at = scheduled[slug];
                } else {
                    status = "accepted";
                }
            } else {
                status = "declined";
            }
            out.append({
                "title": str(it.get("title", "")),
                "slug": slug,
                "pr_number": it.get("number"),
                "pr_url": str(it.get("html_url", "")),
                "status": status,
                "published_url": published_url,
                "schedule_at": schedule_at,
                "created_at": str(it.get("created_at", "")),
            });
        }
        # The author's own open edits to ALREADY-PUBLISHED posts (file-based, so
        # it also catches edit PRs opened directly on GitHub).
        my_edits: list = [];
        for (eslug, eprs) in open_edit_prs_by_slug(gh_token).items() {
            for epr in eprs {
                if str(epr["author"]).lower() == login.lower() {
                    my_edits.append({
                        "slug": eslug,
                        "number": epr["number"],
                        "url": epr["url"],
                        "title": epr["title"],
                    });
                }
            }
        }
        report {"ok": True, "submissions": out, "edits": my_edits};
    }
}


walker:priv ListSubmissions {
    has gh_enc: str = "";

    can get with Root entry {
        gh_token = decrypt_gh(self.gh_enc);
        if not has_write_access(gh_token) {
            report {"ok": False, "error": "reviewer access required"};
            return;
        }
        try {
            q = f'repo:{gh_repo()} type:pr state:open "{SUBMISSION_TAG}" in:body';
            r = requests.get(
                f"{GH_API}/search/issues",
                headers=gh_headers(gh_token),
                params={"q": q, "per_page": 50, "sort": "created", "order": "desc"},
                timeout=30,
            );
            data = r.json();
        } except Exception as e {
            report {"ok": False, "error": f"could not load queue: {e}"};
            return;
        }
        items = data.get("items", []) if isinstance(data, dict) else [];
        out = [];
        for it in items {
            body = str(it.get("body", "") or "");
            m = re.search(r"slug=([a-z0-9-]+)", body);
            bm = re.search(r"by=([A-Za-z0-9-]+)", body);
            out.append({
                "title": str(it.get("title", "")),
                "slug": m.group(1) if m else "",
                "author": bm.group(1) if bm else "",
                "pr_number": it.get("number"),
                "pr_url": str(it.get("html_url", "")),
                "created_at": str(it.get("created_at", "")),
            });
        }
        report {"ok": True, "submissions": out};
    }
}


walker:priv PreviewSubmission {
    has gh_enc: str = "";
    has pr_number: int = 0;

    can get with Root entry {
        gh_token = decrypt_gh(self.gh_enc);
        if not has_write_access(gh_token) {
            report {"ok": False, "error": "reviewer access required"};
            return;
        }
        if not self.pr_number {
            report {"ok": False, "error": "missing pr_number"};
            return;
        }
        try {
            h = gh_headers(gh_token);
            repo = gh_repo();
            pr = requests.get(f"{GH_API}/repos/{repo}/pulls/{self.pr_number}", headers=h, timeout=30).json();
            head_sha = str(pr["head"]["sha"]);
            head_repo = str(pr["head"]["repo"]["full_name"]);
            files = requests.get(
                f"{GH_API}/repos/{repo}/pulls/{self.pr_number}/files",
                headers=h, params={"per_page": 100}, timeout=30,
            ).json();
            post_path = "";
            for f in files {
                fn = str(f.get("filename", ""));
                if fn.startswith("docs/blog/posts/") and fn.endswith(".md") {
                    post_path = fn;
                    break;
                }
            }
            if not post_path {
                report {"ok": False, "error": "no post file found in this PR"};
                return;
            }
            blob = requests.get(
                f"{GH_API}/repos/{head_repo}/contents/{post_path}",
                headers=h, params={"ref": head_sha}, timeout=30,
            ).json();
            content = base64.b64decode(str(blob.get("content", ""))).decode("utf-8");
        } except Exception as e {
            report {"ok": False, "error": f"could not load PR content: {e}"};
            return;
        }
        rendered = render_submitted_markdown(content, head_repo, head_sha);
        slug = str(rendered["slug"]);

        # Find the scheduling tracker issue (opened by post-ci-automation) for
        # this slug, so the dashboard can link straight to it.
        issue_url = "";
        try {
            iq = f'repo:{gh_repo()} type:issue label:blog-schedule "{slug}"';
            ir = requests.get(
                f"{GH_API}/search/issues", headers=h,
                params={"q": iq, "per_page": 5}, timeout=30,
            ).json();
            its = ir.get("items", []) if isinstance(ir, dict) else [];
            if its and len(its) > 0 {
                issue_url = str(its[0].get("html_url", ""));
            }
        } except Exception {
            _ignore = None;
        }

        report {
            "ok": True,
            "pr_number": self.pr_number,
            "pr_url": str(pr.get("html_url", "")),
            "issue_url": issue_url,
            "live_url": f"{public_site_url()}/blog/posts/{slug}" if slug else "",
            "mergeable": pr.get("mergeable"),
            "mergeable_state": str(pr.get("mergeable_state", "")),
            **rendered,
        };
    }
}

