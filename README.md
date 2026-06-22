# Jac Blog

A Jac web app (built on jac-client + jac-scale) that serves the Jaseci Labs engineering blog, with Jac syntax highlighting and interactive, runnable Jac code blocks. Posts are authored as markdown under `docs/blog/posts/` and rendered by the Jac app at request time.

## Contributing

We welcome contributions from anyone in the community! If you'd like to write a blog post, we'd love to hear from you. Topics can include anything relevant to:

- **Jac & Jaseci** -- tutorials, tips, deep dives, project showcases
- **AI & Machine Learning** -- techniques, tools, research, opinions
- **Cool Open Source Tools** -- discoveries, comparisons, how-tos
- **Open Source News** -- notable releases, ecosystem updates, community happenings
- **Anything Nerdy** -- if it's insightful, creative, or just plain fun for a technical audience, we're interested

We'll review all submissions and happily accept anything that's insightful or otherwise enjoyable to the community. Don't be shy -- submit a PR!

### How to Submit a Post

1. Fork the repo and create a new branch
2. Add your post as a markdown file in `docs/blog/posts/`:
   ```bash
   touch docs/blog/posts/my-awesome-post.md
   ```
3. Add frontmatter to the top of your post. **`draft: true` is required** — a PR check will reject any new post without it. This is the safety rail that keeps an accidental merge from publishing a post. An editor flips it live later via the scheduling workflows.
   ```yaml
   ---
   date: 2026-03-12
   authors:
     - your_author_id
   categories:
     - Your Category
   slug: my-awesome-post
   draft: true
   ---
   ```
4. Write your post in markdown (see [Adding Jac Code Blocks](#adding-jac-code-blocks) for interactive code examples). We also love [Mermaid](https://mermaid.js.org/) diagrams -- use ` ```mermaid ` code blocks to add flowcharts, sequence diagrams, and more. For custom graphics, we prefer SVGs since they scale nicely and keep the site looking crisp
5. If you need images (e.g., screenshots of what you built), place them in `docs/assets/` and keep file sizes reasonable -- aim for under 100KB per image when possible. Compress PNGs/JPGs before committing
6. Open a pull request

> **Note on publish timing:** an editor decides when your post goes live. Your post must include `draft: true` (a PR check enforces this); the editor removes it via the scheduling workflows once a publish time is decided. If you have a target date in mind, mention it in the PR description. See [Editorial Scheduling](#editorial-scheduling) for how it works.

### Editorial Scheduling

Posts are not published the instant they merge. An editor schedules each post for a specific UTC publish time. The source of truth is [docs/blog/.schedule.yml](docs/blog/.schedule.yml), and there are three ways for editors to drive it -- none require cloning the repo:

**1. Slash-commands on the PR.** Right in the PR conversation:

```
/schedule 2026-06-01T14:00:00Z
/schedule 2026-06-01T14:00:00Z waiting on marketing
/hold
/cancel
/publish-now
/hide outdated benchmarks, will revisit       (draft in place — reversible)
/unlist author asked to retract               (move to unlisted/)
/archive superseded by 2026 retrospective     (move to archived_posts/)
```

These work both in a PR conversation and on the auto-created **scheduling issue** (see [the release flow](#the-release-flow-at-a-glance) below). The post's slug is inferred from the PR's changed files, or from the scheduling issue itself. To target a different post from any thread, append `slug=<name>`.

**2. "Schedule a post" workflow.** Under the repo's **Actions** tab, run the *Schedule a post* workflow. It's a form with `action` (add / hold / cancel / publish-now), `slug`, `publish_at`, and `notes` inputs. Use this for posts that have already merged.

**3. "Take down a post" workflow.** Also under the Actions tab. Pulls a live post off the site with a `destination` choice:

| Destination | What it does | Use when |
|---|---|---|
| `draft` | Sets `draft: true` in the post's frontmatter, file stays in `docs/blog/posts/` | Temporary hide. Easy to re-publish with `/publish-now`. |
| `unlist` | Moves the file to `docs/blog/unlisted/` and adds `draft: true` defensively | You may revisit it but don't want it anywhere near the live site. |
| `archive` | Moves the file to `docs/blog/archived_posts/` | Permanently retired (outdated, superseded by another post). |

The blog plugin only indexes `docs/blog/posts/`, so `unlist` and `archive` make the post invisible by location, not by frontmatter — there's no way it can accidentally render.

**4. "List schedulable posts" workflow.** Run it (no inputs) to dump a markdown table of every post with its draft state and active schedule entry — handy when you need to look up a slug.

**5. Hourly auto-publisher.** A cron workflow runs at five-past every hour, finds entries whose `publish_at` has passed, removes `draft: true` from each post's frontmatter, and commits. That commit triggers the existing deploy. Precision is ~1 hour (GitHub-hosted cron is best-effort and can lag by 10–20 minutes under load).

On a **first** publish the post's `date:` is rewritten to the actual publish day, so readers see when the post went live. On a **re-publish** (a previously-live post that was `/hide`d and is going back up), the original `date:` is preserved — RSS feeds, bookmarks, and "originally published on" attributions stay stable.

Every scheduling action -- add, hold, cancel, manual publish, auto-publish -- is a real commit on `main` made by `github-actions[bot]`, so `git log docs/blog/.schedule.yml` is the full editorial history.

Anyone with write access on the repo can run these. The slash-command workflow additionally checks `author_association` so random PR commenters can't trigger it.

### The release flow at a glance

When a post PR passes CI, the bot opens a **scheduling issue** (labelled `blog-schedule`) and links it on the PR. That issue — not the PR — is where editors schedule the post, so scheduling is decoupled from the merge:

1. **Author** opens a PR adding `docs/blog/posts/<slug>.md` with `draft: true`.
2. **CI** (*Lint new posts*) checks the draft flag. On success the bot opens a scheduling issue (+ a docs-reference issue in the Jac docs repo if configured) and posts a sticky comment on the PR.
3. **Reviewer** approves and merges — the merge is gated on CI + review, **not** on scheduling.
4. **Editor** comments `/schedule <ISO8601 UTC>` on the scheduling issue (the same slash-commands as above; they take effect once the post is on `main`).
5. **Auto-publisher** flips the post live at the scheduled time, closes the scheduling issue with the final URL, and the commit to `main` triggers the deploy.

A post's URL is permanent and slug-only — `https://blogs.jaseci.org/blog/posts/<slug>` — and the Jac app shows an in-page "coming soon" state for that URL until the post is live, then the same link serves the article. The scheduling issue stays open until the post publishes, so a merged-but-unscheduled post is never silently forgotten.

Full details — triggers, tokens, idempotency markers, deploy coupling, and the one-time GitHub App setup — are in [.github/RELEASE_FLOW.md](.github/RELEASE_FLOW.md).

### Adding Yourself as an Author

If you're a new contributor, add yourself to `docs/blog/.authors.yml`:

```yaml
authors:
  # ... existing authors ...
  your_author_id:
    name: Your Name
    description: A short bio about yourself
    avatar: https://avatars.githubusercontent.com/u/YOUR_GITHUB_USER_ID?v=4
```

To get your GitHub avatar URL, just replace `YOUR_GITHUB_USER_ID` with your numeric GitHub user ID. You can find your ID by visiting `https://api.github.com/users/YOUR_GITHUB_USERNAME` -- look for the `id` field in the response. This will make your profile picture show up nicely alongside your posts.

## Features

- **Jac Web App**: Served by `jac start main.jac` (jac-client React frontend + Jac backend walkers)
- **Jac Syntax Highlighting**: Highlighting for Jac code blocks via python-markdown `codehilite`
- **Interactive Code Blocks**: Run Jac code directly in the browser using Pyodide (WebAssembly)
- **Markdown content**: Posts authored as markdown under `docs/blog/posts/`, parsed and rendered at request time

## Prerequisites

- Python 3.12
- Git
- Node/bun toolchain is fetched by jac-client at build time (you do not install it directly)

## Installation

1. **Clone this repository** (if you haven't already).

2. **Install the Jac toolchain and project dependencies**:
   ```bash
   pip install jaclang
   jac install
   ```

   `jac install` reads the `[dependencies]` table in [jac.toml](jac.toml) and installs jac-scale, jac-client, and the Python/npm deps into the project venv at `.jac/venv`.

3. **(Optional) Generate the playground runtime** so runnable code blocks work locally:
   ```bash
   python scripts/handle_jac_compile_data.py
   ```

   This downloads a pre-compiled `jaclang` from PyPI and writes `docs/playground/jaclang.zip`, which the app serves to the in-browser Pyodide runner ([main.jac](main.jac) `JACLANG_ZIP`). The zip is gitignored and regenerated on demand.

## Usage

### Running the app locally

```bash
jac start main.jac
```

This serves the bundled client and the Jac backend from a single origin. For frontend HMR, jac-client splits the vite dev server (`:8000`) and the API (`:8001`) — see the comments in [jac.toml](jac.toml) under `[plugins.client]`.

### Deploying

Deployment is automated: pushing to `main` triggers [.github/workflows/deploy.yml](.github/workflows/deploy.yml), which runs `jac start main.jac --scale` to deploy to the Jaseci EKS cluster via jac-scale (config under `[plugins.scale]` in [jac.toml](jac.toml)).

## Writing Blog Posts

### Creating a New Post

1. Create a new markdown file in `docs/blog/posts/`:
   ```bash
   touch docs/blog/posts/my-new-post.md
   ```

2. Add the frontmatter shown in [How to Submit a Post](#how-to-submit-a-post). There is no navigation file to edit — the app discovers posts by scanning `docs/blog/posts/` and orders them by their frontmatter `date:`.

### Adding Jac Code Blocks

#### Static Syntax Highlighting Only

For code that just needs syntax highlighting:

````markdown
```jac
with entry {
    print("Hello, World!");
}
```
````

#### Interactive/Runnable Code Blocks

For code that users can edit and run in the browser:

````markdown
<div class="code-block">
```jac
with entry {
    print("Hello, World!");
}
```
</div>
````

This will add a "Run" button that executes the code in the browser.

#### Additional Options

You can customize the buttons shown:

- **Run only** (default): `<div class="code-block">`
- **Run and Serve**: `<div class="code-block run-serve">`
- **Serve only**: `<div class="code-block serve-only">`

Example:

````markdown
<div class="code-block run-serve">
```jac
with entry {
    print("This has both Run and Serve buttons!");
}
```
</div>
````

## Project Structure

```
jaseci-blogs/
├── main.jac                       # Backend walkers: parse posts/authors, render markdown, serve runtime zip
├── jac.toml                       # Project config: serve, jac-client, jac-scale, dependencies
├── pages/                         # jac-client routes (React via Jac)
│   ├── index.jac                  # Landing
│   ├── layout.jac                 # Shared layout / chrome
│   └── blog/                      # Blog index + posts/[slug] routes
├── components/                    # Client components
│   ├── PostBody.cl.jac            # Renders post HTML, boots Pyodide
│   └── RunnableJacBlock.cl.jac    # Interactive "Run" code blocks
├── styles/                        # App CSS (main.css, prose.css, typography.css)
├── public/                        # Static assets served at /
├── docs/
│   ├── assets/                    # Images, referenced as /assets/<file>
│   └── blog/
│       ├── posts/                 # Published + draft blog posts (markdown)
│       ├── archived_posts/        # Retired posts (invisible to the app)
│       ├── unlisted/              # Retracted posts (invisible to the app)
│       ├── .authors.yml           # Author metadata
│       └── .schedule.yml          # Bot-owned editorial schedule
├── scripts/
│   ├── schedule_lib.py            # Editorial scheduler (source of truth for .schedule.yml)
│   └── handle_jac_compile_data.py # Generates docs/playground/jaclang.zip for the in-browser runtime
└── .github/workflows/             # Deploy + editorial scheduling automation
```

## How It Works

### Rendering

[main.jac](main.jac) reads each post from `docs/blog/posts/`, parses its frontmatter, and renders the markdown body to HTML with python-markdown (`fenced_code` + `codehilite` + `md_in_html`). Authors and the editorial schedule come from `.authors.yml` and `.schedule.yml`. The jac-client frontend in [pages/](pages/) and [components/](components/) renders that HTML.

### Interactive Code Execution

Runnable code blocks (authored by wrapping a fenced block in `<div class="code-block">`) use:

1. **Pyodide**: a Python runtime compiled to WebAssembly that runs in the browser
2. **jaclang.zip**: the pre-compiled Jac runtime, generated by [scripts/handle_jac_compile_data.py](scripts/handle_jac_compile_data.py) and served by the `GetRuntimeZip` walker in [main.jac](main.jac); the client extracts it onto Pyodide's `sys.path`

When you click "Run", the client boots Pyodide (once), loads the Jac runtime from the zip, executes the code, and streams output back to the page. See [notes.md](notes.md) for the authoring options (`run-serve`, `serve-only`, `run-dot`, `data-lang="python"`).

## Customization

### Theme & styles

Edit the CSS in [styles/](styles/) (`main.css`, `prose.css`, `typography.css`) and the page chrome in [pages/layout.jac](pages/layout.jac).

## Troubleshooting

### Runnable code blocks not working

- Ensure `docs/playground/jaclang.zip` exists — generate it with `python scripts/handle_jac_compile_data.py`
- Check the browser console for Pyodide errors

### Posts not appearing

- The app only sees `docs/blog/posts/`. Posts in `archived_posts/` and `unlisted/` are intentionally invisible
- Drafts (`draft: true`) are excluded from the published list — see [Editorial Scheduling](#editorial-scheduling)

## Dependencies

Declared in [jac.toml](jac.toml) `[dependencies]` (installed by `jac install`):
- `jaclang`: the Jac toolchain and `jac` CLI
- `jac-client`: React frontend served from Jac
- `jac-scale[deploy]`: Kubernetes/Docker deploy via `jac start --scale`
- `markdown`, `pyyaml`, `pygments`: post parsing and rendering

## License

[Add your license here]


## Acknowledgments

- Built as a [Jac](https://www.jac-lang.org/) web app with jac-client and jac-scale
- Interactive code execution powered by [Pyodide](https://pyodide.org/)
- Part of the [Jaseci project](https://github.com/Jaseci-Labs/jaseci)
