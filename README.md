# Jac Blog

A clean MkDocs blog setup with Jac syntax highlighting and interactive, runnable Jac code blocks.

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

### Reposting an external article

Sometimes the thing worth sharing already lives somewhere else — a talk write-up, a partner's engineering blog, a paper. Instead of copying it, write a short take on *why it matters* and link out. The post renders a rich card to the original at the top, and it's tagged **↗ Repost** in the home stream so readers know it points outward.

It's a normal post with three extra frontmatter keys:

```yaml
---
date: 2026-03-12
authors:
  - your_author_id
categories:
  - Your Category
slug: my-repost
draft: true
repost: true                              # the "this is a repost" switch
repost_url: https://example.com/original  # required — the external article
repost_source: Example Engineering Blog   # optional — friendly label on the card
---

# My short take

A few paragraphs on why this is worth your readers' time.
```

- `repost: true` does nothing on its own — a post only becomes a repost when `repost_url` is also set.
- The card's title, description, and thumbnail are pulled automatically from the linked page's OpenGraph tags (GitHub repos and YouTube links get richer cards). If that fetch fails, the card falls back to `repost_source` and the link's domain, so it always renders something sensible.
- Everything else (scheduling, `draft: true`, images, code blocks) works exactly as for a normal post.

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

- **Jac Syntax Highlighting**: Beautiful syntax highlighting for Jac code using custom Pygments and Monaco lexers
- **Interactive Code Blocks**: Run Jac code directly in the browser using Pyodide (WebAssembly)
- **Clean Design**: Built with MkDocs Material theme
- **Easy to Use**: Simple markdown-based content creation
- **Fast**: Static site generation for optimal performance

## Prerequisites

- Python 3.8 or higher
- pip (Python package installer)
- Git

## Installation

1. **Clone this repository** (if you haven't already):
   ```bash
   cd ~/blog
   ```

2. **Install all dependencies and the Jac syntax highlighter**:
   ```bash
   pip install -e .
   ```

   This will install all required dependencies (mkdocs-material, pymdown-extensions, pygments, mkdocs-video, starlette, uvicorn) and register the Jac syntax highlighter.

## Usage

### Development Server

To start the development server with interactive code execution:

```bash
python scripts/mkdocs_serve.py
```

This will start a server at `http://127.0.0.1:8000` with the necessary CORS headers for Pyodide to work.

> **Note**: The custom server (`mkdocs_serve.py`) is required for runnable code blocks to work properly because it sets up the CORS headers needed for SharedArrayBuffer support.

Alternatively, for basic preview without runnable code blocks:

```bash
mkdocs serve
```

### Building the Site

To build the static site:

```bash
mkdocs build
```

The built site will be in the `site/` directory.

### Deploying

Deploy to GitHub Pages:

```bash
mkdocs gh-deploy
```

## Writing Blog Posts

### Creating a New Post

1. Create a new markdown file in `docs/posts/`:
   ```bash
   touch docs/posts/my-new-post.md
   ```

2. Add the post to the navigation in `mkdocs.yml`:
   ```yaml
   nav:
     - Posts:
       - My New Post: posts/my-new-post.md
   ```

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
~/blog/
├── docs/                          # Documentation source files
│   ├── index.md                   # Homepage
│   ├── about.md                   # About page
│   ├── posts/                     # Blog posts
│   │   └── welcome.md            # Example post
│   ├── js/                        # JavaScript files
│   │   ├── jac.monarch.js        # Monaco Editor Jac syntax
│   │   ├── run-code.js           # Interactive code execution
│   │   └── pyodide-worker.js     # Pyodide web worker
│   ├── playground/                # Playground resources
│   │   ├── language-configuration.json
│   │   └── jaclang.zip           # (Generated by build hook)
│   ├── extra.css                  # Custom CSS styling
│   └── assets/                    # Images and other assets
├── scripts/                       # Build and serve scripts
│   ├── handle_jac_compile_data.py # Build hook for Jac compiler
│   └── mkdocs_serve.py           # Custom dev server
├── overrides/                     # Theme overrides (optional)
├── jac_syntax_highlighter.py     # Pygments lexer for Jac
├── mkdocs.yml                     # MkDocs configuration
└── README.md                      # This file
```

## How It Works

### Syntax Highlighting

The blog uses two lexers for syntax highlighting:

1. **Pygments Lexer** (`jac_syntax_highlighter.py`): Used for server-side static code highlighting during build
2. **Monaco Monarch Lexer** (`docs/js/jac.monarch.js`): Used for client-side syntax highlighting in the interactive code editor

### Interactive Code Execution

The runnable code blocks use:

1. **Pyodide**: A Python runtime compiled to WebAssembly that runs in the browser
2. **Monaco Editor**: The same code editor that powers VS Code
3. **Web Workers**: For isolated code execution without blocking the UI
4. **SharedArrayBuffer**: For synchronous input handling (requires special CORS headers)

When you click "Run":
1. The code is loaded into Monaco Editor
2. A web worker initializes Pyodide and loads the Jac compiler
3. The code is executed in the browser
4. Output is streamed back to the page in real-time

## Customization

### Changing Theme Colors

Edit the `palette` section in `mkdocs.yml`:

```yaml
theme:
  palette:
    scheme: slate        # Use 'default' for light mode
    primary: black       # Primary color
    accent: orange       # Accent color
```

### Adding Social Links

Edit the `extra.social` section in `mkdocs.yml`:

```yaml
extra:
  social:
    - icon: fontawesome/brands/github
      link: https://github.com/yourusername
    - icon: fontawesome/brands/twitter
      link: https://twitter.com/yourusername
```

### Custom CSS

Add your custom styles to `docs/extra.css`.

## Troubleshooting

### Runnable code blocks not working

- Make sure you're using the custom server: `python scripts/mkdocs_serve.py`
- The custom server sets CORS headers required for SharedArrayBuffer
- Check browser console for errors

### Syntax highlighting not working

- Ensure `jac_syntax_highlighter.py` is installed properly
- Try rebuilding: `mkdocs build --clean`

### Build hook errors

- Make sure you have the Jac compiler installed
- The hook tries to create `docs/playground/jaclang.zip` from your Jac installation
- If you don't have Jac installed, comment out the hook in `mkdocs.yml`

## Dependencies

Core dependencies:
- `mkdocs-material`: Material theme for MkDocs
- `pymdown-extensions`: Markdown extensions for code highlighting
- `pygments`: Syntax highlighting library
- `starlette`: ASGI framework for custom server
- `uvicorn`: ASGI server

Optional dependencies:
- `mkdocs-video`: Video embedding support

## License

[Add your license here]


## Acknowledgments

- Built with [MkDocs](https://www.mkdocs.org/) and [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/)
- Interactive code execution powered by [Pyodide](https://pyodide.org/)
- Code editor powered by [Monaco Editor](https://microsoft.github.io/monaco-editor/)
- Based on the excellent documentation setup from the [Jaseci project](https://github.com/Jaseci-Labs/jaseci)
