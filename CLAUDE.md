# Guide for Claude on this repo

This repo is the source for [blogs.jaseci.org](https://blogs.jaseci.org) — an MkDocs Material site with a custom editorial scheduling system on top. Two roles you may be asked to help with: **author** (writing or refining a post) and **reviewer** (evaluating an open PR). The rules differ.

## Shared invariants (apply to everyone, always)

- **Never force-push `main`.** Force-push history rewrites silently dropped three merged blog posts in May 2026 — see [issue #21](https://github.com/jaseci-labs/jaseci-blogs/issues/21). If your local branch is behind, `git pull --rebase` or merge — never `git push --force` on `main`.
- **`docs/blog/.schedule.yml` is bot-owned.** Do not hand-edit it. Mutations go through `scripts/schedule_lib.py` (or the workflows that wrap it), which adds audit fields (`added_by`, `added_at`, etc).
- **The blog plugin only sees `docs/blog/posts/`.** Files in `docs/blog/unlisted/` and `docs/blog/archived_posts/` are invisible to the site by location alone. Don't move things between these dirs by hand — use the *Take down a post* workflow or `/hide` / `/unlist` / `/archive` slash-commands so the audit trail is preserved.
- **Posts identify by `slug:` frontmatter**, not filename. When the user says "the topology post," match against the `slug:` field first, fall back to the filename stem.
- **File references in chat: use markdown links**, e.g. [scripts/schedule_lib.py](scripts/schedule_lib.py) — never backticks for paths.

## When helping a PR author

Your job is to help them produce a PR that passes the *Lint new posts* check and is easy for an editor to merge + schedule.

**Frontmatter** — every new post in `docs/blog/posts/<slug>.md` needs exactly this shape:

```yaml
---
date: 2026-MM-DD                # placeholder; auto-publisher will overwrite when post goes live
authors:
  - their_author_id
categories:
  - One of the categories allowed in mkdocs.yml
slug: my-post-slug              # kebab-case, matches the filename ideally
draft: true                     # REQUIRED — PR check rejects without it
---
```

- The `categories_allowed` list lives in [mkdocs.yml](mkdocs.yml) under the `blog:` plugin — if the author wants a new category, add it there in the same PR.
- New authors need an entry in [docs/blog/.authors.yml](docs/blog/.authors.yml) with `name`, `description`, and `avatar`. Use `https://avatars.githubusercontent.com/u/<numeric-id>?v=4` for the avatar.
- **Do not suggest removing `draft: true`.** That's the editor's call, executed by the scheduling workflows.
- **Do not suggest a precise future `date:` to "schedule" the post.** Dates in frontmatter do not gate publishing here. The scheduler overrides `date:` when it publishes.
- Don't put draft posts in `docs/blog/unlisted/` to hide them during review — that's a legacy pattern. `draft: true` does the same job and stays in `posts/` where the lint and scheduler see it.

**Other authoring rules** documented in [README.md](README.md#how-to-submit-a-post):

- Images: `docs/assets/`, under 100KB each, compress before committing.
- Custom diagrams: prefer SVG or Mermaid (` ```mermaid ` fences) over PNGs.
- Interactive Jac code blocks: wrap in `<div class="code-block">` (see README for variants).

## When helping a PR reviewer

Your job is to evaluate the post and flag anything an editor needs to know before merging.

**Verify mechanically** (these usually catch themselves but call them out if they don't):

- `draft: true` is present (the *Lint new posts* check enforces this; if it's missing the PR can't merge anyway).
- The `slug:` is kebab-case and unique (grep existing posts for collisions).
- Author is registered in `.authors.yml`.
- Category is in `categories_allowed` in [mkdocs.yml](mkdocs.yml).
- No oversized images committed under `docs/assets/`.

**Verify editorially**:

- Read the post end-to-end. Flag typos, broken claims, unclear sections, code samples that won't actually run.
- Mermaid diagrams render correctly (the dark-mode contrast fix in PR #18 is one example of a thing reviewers caught).
- External links resolve.

**Post-merge actions** (only do these if the user explicitly asks):

- An editor needs to schedule the post for a publish time. The clean path: have them comment on the PR with `/schedule 2026-MM-DDTHH:MM:SSZ` (or use the *Schedule a post* workflow from the Actions tab). Don't merge and then leave the post sitting in draft indefinitely — the queue gets confusing.
- If something looks dropped from `main` (a post you remember merging is missing), don't assume it never existed. Check `git ls-tree upstream/main docs/blog/posts/` and look for the PR's head ref on the contributor's fork — see [issue #21](https://github.com/jaseci-labs/jaseci-blogs/issues/21) for the recovery procedure.

## Editorial workflow cheat-sheet

The scheduling system is documented in detail in [README.md](README.md#editorial-scheduling). Quick reference for what to suggest when:

| Situation | Recommend |
|---|---|
| Author wants their merged post to go live next Tuesday at 14:00 UTC | `/schedule 2026-MM-DDT14:00:00Z` on the PR, or the *Schedule a post* workflow |
| Editor wants to publish a queued post right now | `/publish-now` on the PR |
| Editor needs to pull a live post for a quick fix | `/hide <reason>` (reversible — leaves file in `posts/`, just sets `draft: true`) |
| Editor wants to retract a post that may never ship | `/unlist <reason>` |
| Editor wants to retire an old post permanently | `/archive <reason>` |
| Editor wants to see what's scheduled / queued | Run the *List schedulable posts* workflow from the Actions tab |
| Auto-publish ran and surprised someone | Check `git log docs/blog/.schedule.yml` — every action is committed by `github-actions[bot]` with a link to the run |

All four slash-commands and the workflows write commits to `main` via `github-actions[bot]`, so the editorial history lives in `git log` alongside the content history.

## Build & serve (when working locally)

```bash
pip install -e .                       # install deps + the Jac syntax highlighter
python scripts/mkdocs_serve.py         # serves with the CORS headers Pyodide needs
mkdocs build                           # static build into site/
```

`mkdocs serve` works for everything except runnable Jac code blocks — those need the custom server.

## Things to NOT do

- Don't add `draft: false` explicitly anywhere. The scheduler removes the `draft:` key entirely when it publishes; "no draft key" and `draft: false` mean the same thing to MkDocs but the former is cleaner in `git log`.
- Don't bypass the *Lint new posts* check by force-merging. If it's failing, fix the post.
- Don't write to `.schedule.yml` from code other than `scripts/schedule_lib.py`. The header comment block is preserved by `save_schedule()`; ad-hoc yaml writes will lose it.
- Don't suggest skipping CI hooks (`--no-verify`) for any reason.
