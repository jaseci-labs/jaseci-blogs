# Blog release flow (detailed)

This is the maintainer reference for how a blog post travels from a pull request
to a live page, with a GitHub **issue** as the scheduling surface — decoupled
from the merge. For the short version, see the *Editorial Scheduling* section of
the [README](../README.md#editorial-scheduling).

## Lifecycle at a glance

```
Author opens PR (new docs/blog/posts/<slug>.md, draft: true)
        │
        ▼
 Lint new posts  ── fail ──▶ explainer comment (add draft: true)
        │ success
        ▼
 Post-CI blog automation   (workflow_run, runs in base-repo context)
        ├─ opens/updates a SCHEDULING TRACKER issue   (this repo, label blog-schedule)
        ├─ opens/updates a DOCS-REFERENCE issue        (Jac docs repo — needs App token)
        └─ posts ONE sticky comment on the PR linking both
        │
        ▼
 Reviewer approves → MERGE     (gate = lint green + review; NOT scheduling)
        │
        ▼
 Editor comments  /schedule <ISO8601 UTC>  on the TRACKER ISSUE
        │  → scripts/schedule_lib.py writes docs/blog/.schedule.yml on main
        ▼
 Auto-publish (hourly cron) flips the post live when due
        ├─ removes draft:, rewrites date: (first publish), commits to main
        ├─ commit to main → deploy.yml rebuilds + ships the site
        ├─ closes the tracker issue (its post URL now serves the article)
        └─ comments the live URL on the docs-reference issue
```

The post's public URL is **slug-only and permanent** (`/blog/posts/<slug>`): the
Jac app serves an in-page "coming soon" state for an unpublished slug and the full
article once it's live — the **same link** throughout. There is no separate
placeholder page and no date in the URL.

**Design choice:** merge is intentionally **not** gated on scheduling. The tracker
issue is the safety net — it stays open until the post actually publishes, so a
merged-but-unscheduled post stays visible instead of being silently lost.

## Files involved

| File | Role | New/Changed |
|---|---|---|
| [workflows/lint-new-posts.yml](workflows/lint-new-posts.yml) | Draft-gate CI on every PR. | unchanged |
| [workflows/post-ci-automation.yml](workflows/post-ci-automation.yml) | Opens tracker + docs issues, sticky PR comment. | **new** |
| [workflows/slash-schedule.yml](workflows/slash-schedule.yml) | `/schedule` etc. — now also accepts commands on tracker issues. | **changed** |
| [workflows/auto-publish.yml](workflows/auto-publish.yml) | Hourly publisher — now closes/updates issues on publish. | **changed** |
| [workflows/schedule.yml](workflows/schedule.yml) | *Schedule a post* dispatch form. | unchanged |
| [workflows/takedown.yml](workflows/takedown.yml) | *Take down a post* dispatch form. | unchanged |
| [workflows/deploy.yml](workflows/deploy.yml) | Builds + ships the site image on push to `main`. | unchanged |
| [scripts/schedule_lib.py](../scripts/schedule_lib.py) | Single writer of `.schedule.yml` + post frontmatter. | unchanged |
| [main.jac](../main.jac) | `GetPost` now returns a `coming_soon` status for an unpublished slug (vs. `not_found`). | **changed** |
| [pages/blog/posts/[slug].jac](../pages/blog/posts/%5Bslug%5D.jac) | Renders the in-page "coming soon" view (vs. a 404). | **changed** |

## Stage by stage

### 0. Author opens a PR
A new file under `docs/blog/posts/<slug>.md` with `draft: true`. `lint-new-posts.yml`
enforces `draft: true` on every newly added post and runs on every PR (passing
trivially when no posts are added) so it is safe to mark **required**.

### 1. Post-CI automation (`post-ci-automation.yml`)
- **Trigger:** `workflow_run` of *Lint new posts*, gated on
  `conclusion == 'success'` and `event == 'pull_request'`. Using `workflow_run`
  (rather than a step inside the lint workflow) is deliberate: it runs in the
  **base-repo context with secrets available even for fork PRs**, and it never
  checks out or executes PR code, so the cross-repo token is never exposed to an
  untrusted contribution.
- **Resolve step:** finds the PR (looks it up by head ref when
  `workflow_run.pull_requests` is empty, as it is for forks), confirms the PR adds
  **exactly one** post, and reads its `slug:` from the post's frontmatter (falling
  back to the filename stem).
- **Tracker issue (this repo):** created/updated with label `blog-schedule`, a
  machine-readable marker, the permanent post URL (`/blog/posts/<slug>`), and the
  editorial command menu. Idempotent — re-runs update the same issue.
- **Docs-reference issue (Jac docs repo):** created/updated via a GitHub App
  token. **Skipped automatically** when the App is not configured
  (`vars.ISSUE_BOT_APP_ID` empty), so the rest of the flow works without it.
- **Sticky PR comment:** one find-or-update comment (keyed by a hidden marker)
  linking both issues and explaining that scheduling happens on the tracker issue.

### 2. Review and merge
Merge is gated by the branch ruleset on `main` — require *Lint new posts* plus a
review approval. **Scheduling is not part of the gate.** Do **not** put closing
keywords (`Closes #…`) pointing at the tracker issue in the PR body — that would
auto-close it on merge and defeat the safety net.

### 3. Scheduling (on the tracker issue)
An editor comments one of these **on the tracker issue**:

```
/schedule 2026-MM-DDTHH:MM:SSZ   # queue for a publish time (UTC)
/publish-now                     # publish immediately
/hold                            # keep drafted, no publish time
/cancel                          # drop a pending schedule
```

`slash-schedule.yml` now fires for comments on a PR **or** on any issue labelled
`blog-schedule`. On a tracker issue it reads the slug from the issue body's hidden
marker; on a PR it infers the slug from the changed files (legacy behaviour). The
commenter must have OWNER / MEMBER / COLLABORATOR association. The command runs
`schedule_lib.py`, which writes `.schedule.yml` and the post frontmatter on `main`
and commits as `github-actions[bot]`.

> **`/schedule` only takes effect post-merge.** `schedule_lib.add()` resolves the
> post by globbing `docs/blog/posts/` on `main`, so a pre-merge `/schedule` reports
> "no post found". This is on-model for the decoupled design.

### 4. Auto-publish (`auto-publish.yml`)
Hourly cron runs `schedule_lib.py publish-due`: entries whose `publish_at` has
passed get `draft:` removed, `date:` rewritten on first publish, and the change is
committed to `main`. New behaviour added for this flow:
- **Closes the tracker issue** for each published slug, commenting the live URL
  (`https://blogs.jaseci.org/blog/posts/<slug>` — the same permanent link the
  tracker already advertised; no date computation needed).
- **Comments the live URL on the docs-reference issue** (App token; skipped when
  not configured).

## Scope: which PRs the flow acts on

- **Infrastructure / design / non-post PRs.** `lint-new-posts` still *runs* (it has
  no `paths:` filter and **must not** — a required check has to report on every PR
  or non-post PRs hang on "Expected"), but it passes trivially. `post-ci-automation`
  fires on its completion, finds **zero added posts**, and exits early — so **no
  tracker issue, docs issue, or sticky comment** is created. Net effect: a short
  no-op runner and a green check.
- **A PR that adds exactly one post** is the only thing that opens issues. (A PR
  adding two posts is intentionally skipped — pass `slug=` explicitly or split it.)

## Editing an existing post

The automation keys on **added** files (`f.status === 'added'`), and lint checks
**added** files only — so editing a post behaves differently from adding one:

| You edit… | Lint | Automation | On merge |
|---|---|---|---|
| an already-**live** post (no `draft:` key) | passes | no issue | deploys live immediately — it's already published |
| a still-**draft** post, keeping `draft: true` | passes | no new issue | stays drafted; publishes via its existing schedule |
| a still-**draft** post and you **remove `draft: true`** | **fails** (un-draft guard) | — | blocked until you restore `draft: true` |

That last row is the **un-draft guard** in `lint-new-posts.yml`: it diffs modified
posts, and if a post was `draft: true` on the base ref but isn't on the PR head, the
check fails. This preserves the core invariant — *a PR merge can never publish a
post; only the scheduler can* — without interfering with the auto-publisher (which
removes `draft:` via direct commits to `main`, never through a PR). Editing a live
post is unaffected because its base version already has no `draft:` key.

## Coming-soon handling (in the Jac app)

The site is a Jac app (not mkdocs), and a post's URL is **slug-only and stable**:
`/blog/posts/<slug>`. So there is no separate placeholder page — the canonical post
URL handles the unpublished case itself:

- **Server** — [main.jac](../main.jac): `parse_post_file` drops drafts entirely, so
  a draft slug would otherwise be indistinguishable from a missing one. `GetPost`
  now does a frontmatter-only `peek_unpublished` scan: a draft whose slug matches
  reports `{"ok": false, "status": "coming_soon", "title": …}`; a genuinely missing
  slug reports `status: "not_found"`.
- **Client** — [pages/blog/posts/[slug].jac](../pages/blog/posts/%5Bslug%5D.jac):
  on `coming_soon` it renders a "Coming soon" view (with the post title) explaining
  the link is permanent; on `not_found` it renders a 404; otherwise a generic load
  error. (Note: the status is read into a local before use — reading a reactive
  `has` field back in the same effect block returns the stale value.)

Because the link is permanent, the tracker/docs issues advertise this exact URL,
and it simply upgrades from the coming-soon view to the article when the post
publishes.

## Marker reference (how steps find things)

Hidden HTML markers make every lookup idempotent and slug-exact:

| Marker | Lives in | Read by |
|---|---|---|
| `<!-- blog-tracker: pr=<n> slug=<slug> -->` | tracker issue body | post-ci-automation (dedupe by `pr=`), slash-schedule (slug), auto-publish (close by `slug=`) |
| `<!-- blog-docs: src=<repo> pr=<n> slug=<slug> -->` | docs issue body | post-ci-automation (dedupe), auto-publish (URL comment) |
| `<!-- blog-ci-bot -->` | sticky PR comment | post-ci-automation (find-or-update) |

Slug matches use a trailing space (`slug=<slug> `) so `foo` never matches `foo-bar`.

## Coupling to deployment

The publish flow depends on **one** property of `deploy.yml`: *a deploy runs after
a commit to `main`* (drafts are filtered server-side by `parse_post_file` in
[main.jac](../main.jac)). Everything else in `deploy.yml` (image tagging, ECR/AWS
details, buildx, the nightly rebuild, the `release`/`workflow_dispatch` triggers)
is free to change.

Note the mutation workflows (`auto-publish`, `schedule`, `slash-schedule`,
`takedown`) push with the default `GITHUB_TOKEN`, and a `GITHUB_TOKEN` push does
**not** fire another workflow's `on: push` (GitHub's anti-recursion rule). So each
one fires the deploy explicitly with `gh workflow run deploy.yml --ref main` after
pushing (needs `actions: write`); `workflow_dispatch` is exempt from that rule.
The `push: branches: [main]` trigger remains as the safety net for *human* pushes.

**Don't** remove/narrow the `push: branches: [main]` trigger or add a `paths:`
filter excluding `docs/blog/posts/` — auto-publish would still mark the post
`published` and the tracker issue would close claiming "now live at …", but no image
would rebuild, so the post's URL would keep serving the **coming-soon view** (not a
404 — it degrades gracefully) until the daily cron rebuild (or never). Note also
that the tracker issue is closed the moment auto-publish pushes, slightly **before**
deploy finishes and the CD rolls the new image; if you want "live" claimed only
after the site is actually served, move the issue-close step to a `workflow_run` on
*Build and Deploy Mars Blog* success.

## Testing

A pytest suite guards the parts that can break silently. Run it locally:

```bash
pip install pytest pyyaml
pytest -q
```

It runs in CI on every PR and push to `main` via
[workflows/test.yml](workflows/test.yml), and is safe to mark as a required check.

| File | Covers |
|---|---|
| [tests/test_schedule_lib.py](../tests/test_schedule_lib.py) | The scheduler logic: `check_draft` + the un-draft guard transition, the draft-gate lint, `find_post` slug/filename resolution, the `add → publish-due → re-publish` lifecycle, **date preservation on re-publish**, takedown moves (draft/unlist/archive), and the **bot-owned header preservation** in `.schedule.yml`. |
| [tests/test_workflows.py](../tests/test_workflows.py) | Every workflow YAML parses, and every inline `actions/github-script` block passes `node --check` (with `${{ }}` expressions substituted the way GitHub does at runtime) — catching JS typos that would otherwise only fail mid-run. |

The scheduler tests redirect `schedule_lib`'s path constants at a tmp sandbox
(see [tests/conftest.py](../tests/conftest.py)) so nothing touches the real
`docs/blog/` tree. When you add a `schedule_lib` subcommand or a new
`github-script` step, add/extend a test in the same shape — the workflow-syntax
test picks up new steps automatically.

## One-time setup (admin — not done by code)

The workflows degrade gracefully without step 2 (cross-repo issue steps are gated
and simply skip).

1. **Required checks on `main`.** Branch ruleset: require `Lint new posts`,
   `Tests`, and at least one review approval. This is the merge gate.
2. **Cross-repo issue credential.** Create a **GitHub App** in `jaseci-labs` with
   **Issues: Read and write**, install it on the docs repo only, then add repo
   **variable** `ISSUE_BOT_APP_ID` and repo **secret** `ISSUE_BOT_PRIVATE_KEY`.
   Optionally set `DOCS_REPO_OWNER` (default `jaseci-labs`) and `DOCS_REPO_NAME`
   (default `jaseci`). The default `GITHUB_TOKEN` cannot write issues cross-repo —
   that is why the App is required. (IDE "context access might be invalid" warnings
   on these names are expected until the var/secret exist.)
3. **Labels.** `blog-schedule` (this repo) and `blog-docs-sync` (docs repo) are
   auto-created on first run — no action needed.

## Intentionally out of scope

- **Copilot auto-PR** (assigning the docs issue to `copilot-swe-agent[bot]` to open
  a draft docs PR) was dropped. If added later it needs a **user** PAT with a
  Copilot seat — App tokens / `GITHUB_TOKEN` do not work — and only opens a draft
  PR for human review.
- **A hard "must be scheduled before merge" gate.** Deliberately replaced by the
  open tracker issue + (optionally) a stale-tracker nag.
