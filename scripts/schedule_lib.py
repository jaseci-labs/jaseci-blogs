"""Editorial scheduling helper for blogs.jaseci.org.

Single source of truth for mutating docs/blog/.schedule.yml and the
draft/date frontmatter of posts in docs/blog/posts/. Used by:

  - .github/workflows/schedule.yml         (workflow_dispatch form)
  - .github/workflows/auto-publish.yml     (hourly cron publisher)
  - .github/workflows/slash-schedule.yml   (/schedule PR comments)

CLI surface (all subcommands print a JSON result to stdout):

  python -m scripts.schedule_lib add        --slug X --publish-at ISO [--notes ...] --actor LOGIN
  python -m scripts.schedule_lib hold       --slug X --actor LOGIN
  python -m scripts.schedule_lib cancel     --slug X --actor LOGIN
  python -m scripts.schedule_lib publish-now --slug X --actor LOGIN
  python -m scripts.schedule_lib publish-due --actor LOGIN
  python -m scripts.schedule_lib list

Exit code is 0 on success, 1 on any user-facing error (unknown slug,
bad datetime, etc). The workflow surfaces the JSON `error` field back
to the operator.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEDULE_PATH = REPO_ROOT / "docs" / "blog" / ".schedule.yml"
POSTS_DIR = REPO_ROOT / "docs" / "blog" / "posts"
ARCHIVED_DIR = REPO_ROOT / "docs" / "blog" / "archived_posts"
UNLISTED_DIR = REPO_ROOT / "docs" / "blog" / "unlisted"

# Takedown destinations. `None` means "leave file in posts/ but mark draft" —
# i.e. a temporary, reversible hide. The other two move the file out of posts/
# so the blog plugin stops seeing it at all.
TAKEDOWN_DESTINATIONS: dict[str, Path | None] = {
    "archive": ARCHIVED_DIR,
    "unlist": UNLISTED_DIR,
    "draft":   None,
}

TAKEDOWN_STATUS = {
    "archive": "archived",
    "unlist":  "unlisted",
    "draft":   "hidden",
}

FRONTMATTER_RE = re.compile(r"\A---\n(.*?)\n---\n", re.DOTALL)


# ---------------------------------------------------------------------------
# Schedule file I/O
# ---------------------------------------------------------------------------


def load_schedule() -> dict[str, Any]:
    with SCHEDULE_PATH.open() as f:
        data = yaml.safe_load(f) or {}
    data.setdefault("schedule", [])
    return data


def save_schedule(data: dict[str, Any]) -> None:
    # Preserve the leading comment block by reading it back from disk.
    raw = SCHEDULE_PATH.read_text()
    header_lines = []
    for line in raw.splitlines():
        if line.startswith("#") or line.strip() == "":
            header_lines.append(line)
        else:
            break
    body = yaml.safe_dump(data, sort_keys=False, default_flow_style=False)
    SCHEDULE_PATH.write_text("\n".join(header_lines) + "\n" + body)


# ---------------------------------------------------------------------------
# Post frontmatter helpers
# ---------------------------------------------------------------------------


@dataclass
class Post:
    path: Path
    meta: dict[str, Any]
    body: str

    def write(self) -> None:
        fm = yaml.safe_dump(self.meta, sort_keys=False, default_flow_style=False).strip()
        self.path.write_text(f"---\n{fm}\n---\n{self.body}")


def find_post(slug: str) -> Post:
    """Locate a post by `slug:` frontmatter, falling back to filename."""
    candidates: list[Post] = []
    filename_match: Post | None = None
    for md in POSTS_DIR.glob("*.md"):
        post = _read_post(md)
        if post is None:
            continue
        if post.meta.get("slug") == slug:
            candidates.append(post)
        if md.stem == slug:
            filename_match = post

    if len(candidates) == 1:
        return candidates[0]
    if len(candidates) > 1:
        paths = ", ".join(str(p.path.relative_to(REPO_ROOT)) for p in candidates)
        raise UserError(f"Multiple posts have slug '{slug}': {paths}")
    if filename_match is not None:
        return filename_match
    raise UserError(f"No post found with slug '{slug}' (looked in {POSTS_DIR.relative_to(REPO_ROOT)})")


def _read_post(path: Path) -> Post | None:
    text = path.read_text()
    m = FRONTMATTER_RE.match(text)
    if not m:
        return None
    meta = yaml.safe_load(m.group(1)) or {}
    body = text[m.end() :]
    return Post(path=path, meta=meta, body=body)


# ---------------------------------------------------------------------------
# Time helpers
# ---------------------------------------------------------------------------


def parse_iso(value: str) -> dt.datetime:
    s = value.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(s)
    except ValueError as e:
        raise UserError(f"Could not parse '{value}' as ISO 8601 datetime: {e}")
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.astimezone(dt.timezone.utc)


def now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def iso(value: dt.datetime) -> str:
    return value.strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# Operations
# ---------------------------------------------------------------------------


class UserError(Exception):
    """Surfaced back to the workflow operator. Not a bug."""


def _find_entry(data: dict[str, Any], slug: str) -> dict[str, Any] | None:
    for entry in data["schedule"]:
        if entry.get("slug") == slug and entry.get("status") in ("scheduled", "held"):
            return entry
    return None


def add(slug: str, publish_at: str, actor: str, notes: str | None = None) -> dict[str, Any]:
    post = find_post(slug)
    publish_dt = parse_iso(publish_at)
    if publish_dt <= now_utc():
        raise UserError(f"publish_at {iso(publish_dt)} is not in the future")

    post.meta["draft"] = True
    post.write()

    data = load_schedule()
    if _find_entry(data, slug):
        raise UserError(f"'{slug}' is already in the schedule. Use /cancel first, or update it.")
    entry = {
        "slug": slug,
        "publish_at": iso(publish_dt),
        "status": "scheduled",
        "added_by": actor,
        "added_at": iso(now_utc()),
    }
    if notes:
        entry["notes"] = notes
    data["schedule"].append(entry)
    save_schedule(data)
    return {"ok": True, "action": "add", "entry": entry, "post": str(post.path.relative_to(REPO_ROOT))}


def hold(slug: str, actor: str) -> dict[str, Any]:
    data = load_schedule()
    entry = _find_entry(data, slug)
    if entry is None:
        # Allow holding a post that has no schedule entry yet: mark draft + create a held entry.
        post = find_post(slug)
        post.meta["draft"] = True
        post.write()
        entry = {
            "slug": slug,
            "status": "held",
            "added_by": actor,
            "added_at": iso(now_utc()),
        }
        data["schedule"].append(entry)
    else:
        entry["status"] = "held"
        entry.pop("publish_at", None)
        entry["held_by"] = actor
        entry["held_at"] = iso(now_utc())
        post = find_post(slug)
        post.meta["draft"] = True
        post.write()
    save_schedule(data)
    return {"ok": True, "action": "hold", "entry": entry, "post": str(post.path.relative_to(REPO_ROOT))}


def cancel(slug: str, actor: str) -> dict[str, Any]:
    data = load_schedule()
    entry = _find_entry(data, slug)
    if entry is None:
        raise UserError(f"No active schedule entry for '{slug}'")
    entry["status"] = "cancelled"
    entry["cancelled_by"] = actor
    entry["cancelled_at"] = iso(now_utc())
    entry.pop("publish_at", None)
    save_schedule(data)
    return {"ok": True, "action": "cancel", "entry": entry}


def publish_now(slug: str, actor: str) -> dict[str, Any]:
    post = find_post(slug)
    now = now_utc()
    post.meta.pop("draft", None)
    post.meta["date"] = now.date().isoformat()
    post.write()

    data = load_schedule()
    entry = _find_entry(data, slug)
    if entry is not None:
        entry["status"] = "published"
        entry["published_at"] = iso(now)
        entry["published_by"] = actor
        entry.pop("publish_at", None)
    else:
        data["schedule"].append({
            "slug": slug,
            "status": "published",
            "published_at": iso(now),
            "published_by": actor,
        })
        entry = data["schedule"][-1]
    save_schedule(data)
    return {"ok": True, "action": "publish-now", "entry": entry, "post": str(post.path.relative_to(REPO_ROOT))}


def takedown(slug: str, destination: str, actor: str, reason: str | None = None) -> dict[str, Any]:
    if destination not in TAKEDOWN_DESTINATIONS:
        raise UserError(
            f"destination must be one of {sorted(TAKEDOWN_DESTINATIONS)}, got '{destination}'"
        )
    target_dir = TAKEDOWN_DESTINATIONS[destination]
    post = find_post(slug)
    if not post.path.is_relative_to(POSTS_DIR):
        raise UserError(
            f"'{slug}' is not in {POSTS_DIR.relative_to(REPO_ROOT)} "
            f"(found at {post.path.relative_to(REPO_ROOT)}). Already taken down?"
        )

    from_rel = str(post.path.relative_to(REPO_ROOT))

    if target_dir is None:
        # "draft" destination — hide in place. File stays in posts/.
        post.meta["draft"] = True
        post.write()
        to_rel = from_rel
    else:
        if destination == "unlist":
            # Defensive: ensure draft: true so the post can never accidentally
            # ship even if it gets moved back to posts/ later.
            post.meta["draft"] = True
            post.write()
        target_dir.mkdir(parents=True, exist_ok=True)
        new_path = target_dir / post.path.name
        if new_path.exists():
            raise UserError(f"Refusing to overwrite existing {new_path.relative_to(REPO_ROOT)}")
        post.path.rename(new_path)
        to_rel = str(new_path.relative_to(REPO_ROOT))

    data = load_schedule()
    entry: dict[str, Any] = {
        "slug": slug,
        "status": TAKEDOWN_STATUS[destination],
        "taken_down_by": actor,
        "taken_down_at": iso(now_utc()),
        "from_path": from_rel,
        "to_path": to_rel,
    }
    if reason:
        entry["reason"] = reason
    data["schedule"].append(entry)
    save_schedule(data)
    return {"ok": True, "action": "takedown", "destination": destination, "entry": entry}


def publish_due(actor: str = "auto-publisher") -> dict[str, Any]:
    data = load_schedule()
    now = now_utc()
    published: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    for entry in data["schedule"]:
        if entry.get("status") != "scheduled":
            continue
        publish_at = entry.get("publish_at")
        if not publish_at:
            continue
        try:
            when = parse_iso(publish_at)
        except UserError as e:
            errors.append({"slug": entry.get("slug"), "error": str(e)})
            continue
        if when > now:
            continue
        slug = entry.get("slug")
        try:
            post = find_post(slug)
        except UserError as e:
            errors.append({"slug": slug, "error": str(e)})
            continue
        post.meta.pop("draft", None)
        post.meta["date"] = now.date().isoformat()
        post.write()
        entry["status"] = "published"
        entry["published_at"] = iso(now)
        entry["published_by"] = actor
        entry.pop("publish_at", None)
        published.append({"slug": slug, "post": str(post.path.relative_to(REPO_ROOT))})

    if published:
        save_schedule(data)
    return {"ok": True, "action": "publish-due", "published": published, "errors": errors}


def list_entries() -> dict[str, Any]:
    data = load_schedule()
    return {"ok": True, "action": "list", "schedule": data["schedule"]}


def posts_status() -> dict[str, Any]:
    """Join every post in POSTS_DIR with its current schedule entry."""
    data = load_schedule()
    active_by_slug: dict[str, dict[str, Any]] = {}
    for entry in data["schedule"]:
        if entry.get("status") in ("scheduled", "held"):
            active_by_slug[entry["slug"]] = entry

    rows: list[dict[str, Any]] = []
    for md in sorted(POSTS_DIR.glob("*.md")):
        post = _read_post(md)
        if post is None:
            continue
        slug = post.meta.get("slug", md.stem)
        rows.append({
            "slug": slug,
            "file": str(md.relative_to(REPO_ROOT)),
            "title": post.meta.get("title") or _extract_h1(post.body) or "",
            "draft": bool(post.meta.get("draft", False)),
            "post_date": str(post.meta.get("date", "")),
            "schedule": active_by_slug.get(slug),
        })
    return {"ok": True, "action": "posts-status", "posts": rows}


def lint_new_posts(paths: list[str]) -> dict[str, Any]:
    """Return ok=False if any given path is a post missing `draft: true`.

    Used by the pull_request CI to guarantee that a PR cannot accidentally
    publish a post on merge — the auto-publisher / publish-now workflows
    are the only legitimate way for draft: true to be removed.
    """
    failures: list[dict[str, Any]] = []
    checked: list[str] = []
    for raw in paths:
        path = (REPO_ROOT / raw).resolve()
        if not path.exists():
            failures.append({"path": raw, "error": "file not found in working tree"})
            continue
        if not path.is_relative_to(POSTS_DIR):
            continue  # only enforce on docs/blog/posts/
        if path.suffix != ".md":
            continue
        post = _read_post(path)
        if post is None:
            failures.append({"path": raw, "error": "no YAML frontmatter — every post needs a `---` block"})
            continue
        if post.meta.get("draft") is not True:
            failures.append({
                "path": raw,
                "error": "new post must include `draft: true` in frontmatter. "
                         "Editors will flip it live via the scheduling workflows.",
            })
        checked.append(raw)
    return {"ok": not failures, "action": "lint-new-posts", "checked": checked, "failures": failures}


def _extract_h1(body: str) -> str | None:
    for line in body.splitlines():
        stripped = line.strip()
        if stripped.startswith("# "):
            return stripped[2:].strip()
        if stripped and not stripped.startswith("<!--"):
            return None
    return None


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="schedule_lib")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_add = sub.add_parser("add")
    p_add.add_argument("--slug", required=True)
    p_add.add_argument("--publish-at", required=True)
    p_add.add_argument("--actor", required=True)
    p_add.add_argument("--notes", default=None)

    p_hold = sub.add_parser("hold")
    p_hold.add_argument("--slug", required=True)
    p_hold.add_argument("--actor", required=True)

    p_cancel = sub.add_parser("cancel")
    p_cancel.add_argument("--slug", required=True)
    p_cancel.add_argument("--actor", required=True)

    p_now = sub.add_parser("publish-now")
    p_now.add_argument("--slug", required=True)
    p_now.add_argument("--actor", required=True)

    p_due = sub.add_parser("publish-due")
    p_due.add_argument("--actor", default="auto-publisher")

    p_td = sub.add_parser("takedown")
    p_td.add_argument("--slug", required=True)
    p_td.add_argument("--destination", required=True, choices=sorted(TAKEDOWN_DESTINATIONS))
    p_td.add_argument("--actor", required=True)
    p_td.add_argument("--reason", default=None)

    sub.add_parser("list")
    sub.add_parser("posts-status")

    p_lint = sub.add_parser("lint-new-posts")
    p_lint.add_argument("paths", nargs="*")

    args = parser.parse_args(argv)

    try:
        if args.cmd == "add":
            result = add(args.slug, args.publish_at, args.actor, args.notes)
        elif args.cmd == "hold":
            result = hold(args.slug, args.actor)
        elif args.cmd == "cancel":
            result = cancel(args.slug, args.actor)
        elif args.cmd == "publish-now":
            result = publish_now(args.slug, args.actor)
        elif args.cmd == "publish-due":
            result = publish_due(args.actor)
        elif args.cmd == "takedown":
            result = takedown(args.slug, args.destination, args.actor, args.reason)
        elif args.cmd == "list":
            result = list_entries()
        elif args.cmd == "posts-status":
            result = posts_status()
        elif args.cmd == "lint-new-posts":
            result = lint_new_posts(args.paths)
            if not result["ok"]:
                json.dump(result, sys.stdout, indent=2)
                sys.stdout.write("\n")
                return 1
        else:
            parser.error(f"Unknown command {args.cmd!r}")
            return 2
    except UserError as e:
        json.dump({"ok": False, "error": str(e)}, sys.stdout)
        sys.stdout.write("\n")
        return 1

    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
