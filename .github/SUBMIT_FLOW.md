# Blog submission portal — setup & flow

This documents the **`/submit`** (author) and **`/editor`** (editor) pages added
to the Jac app, and the one-time credential setup they need. GitHub is the only
datastore — there is no database, and **there is no GitHub App**: every GitHub
action runs as the *signed-in user* via their OAuth token. For the publishing
pipeline these feed into, see [RELEASE_FLOW.md](RELEASE_FLOW.md).

## What it does

```
Visitor → /submit
  ├─ "Sign in with GitHub"  (OAuth, scope `public_repo`)
  ├─ writes a post (markdown + images + live preview)
  └─ Submit ──► SubmitPost walker — acting AS THE USER with their token:
                 • validates (kebab slug, allowed category, ≤8 imgs ≤100KB, forces draft:true)
                 • forks jaseci-blogs to the user's account (idempotent)
                 • commits one branch on the fork:
                     docs/blog/posts/<slug>.md
                     docs/assets/<slug>/<images…>
                     docs/blog/.authors.yml   ← appended if a new author
                 • opens a DRAFT cross-fork PR upstream, body stamped
                   `<!-- blog-submission slug=… by=… -->`
                       │
                       ▼
        Existing pipeline takes over UNCHANGED:
        Lint new posts ✓ → post-ci-automation opens the tracker issue → editor schedules

Author → /submit ▸ "My submissions"   → MySubmissions (status derived live from GitHub)
Editor → /editor                       → review queue + rendered preview, and:
        • Approve & merge          → a link to the PR page (editor merges there)
        • Schedule/publish/hold/…  → generates the `/schedule …` slash-command +
                                     a Copy button + a link to paste it on the PR
        • Take down a live post    → generates `/hide` / `/unlist` / `/archive`
```

**No app, no elevated permissions anywhere.** Submitting is a normal fork-and-PR,
done with the contributor's own `public_repo` access. Editor write-actions run
with the *editor's* own access — merge on the PR page; scheduling/take-down are
the existing slash-commands the editor pastes as a PR comment (gated by the
slash-command workflow on the commenter's write access). So `.schedule.yml` stays
bot-owned and every action stays in `git log` as before.

## Identity & authorization

- Sign-in is **GitHub OAuth** (classic OAuth App, `public_repo` scope). The
  code→token exchange happens server-side in `GithubOAuthExchange`.
- The user's token is needed again at submit time, so it rides **inside** the
  signed session — but **encrypted** (Fernet, key derived from
  `SUBMIT_SESSION_SECRET`). The browser (sessionStorage) only ever holds
  ciphertext; the server decrypts per request. Sessions are HS256-signed, 8h TTL.
- **Editor access** = repo write permission, read live via `GET /repos/{repo}`
  → the `permissions` block for the authenticated user. No list to maintain.

> **Security note.** Because a classic OAuth token is account-wide (not per-repo),
> this design accepts that the user's `public_repo` token is held — encrypted — in
> their session. Encryption means an XSS reading sessionStorage gets unusable
> ciphertext; the residual risk is that an active session can invoke the submit
> walker. This trade buys a setup that needs **no org-owned app and no install
> approval**. If that trade isn't acceptable, the alternative is an org-owned
> GitHub App holding the privileged token server-side (see git history).

## One-time setup

### 1. Create a **classic OAuth App** (sign-in + acts as the user)

GitHub → *Settings ▸ Developer settings ▸ OAuth Apps ▸ New OAuth App*
(your **personal** account is fine — no org ownership or install approval needed,
because all actions are the user's own fork + PR on a public repo):

- **Application name:** e.g. `Jaseci Blogs — Submit`
- **Homepage URL:** `https://blogs.jaseci.org`
- **Authorization callback URL:** `https://blogs.jaseci.org/submit`
  - For local dev, register a second OAuth App with callback `http://localhost:8001/submit`.
- Note the **Client ID**; generate a **Client secret**.

That's the only GitHub credential needed. (The app requests the `public_repo`
scope at sign-in so it can fork the repo and open the PR as the user.)

### 2. Generate a session secret

```bash
openssl rand -hex 32      # value for SUBMIT_SESSION_SECRET (signs + encrypts sessions)
```

### 3. Add repo **secrets** and **variables**

GitHub → *Settings ▸ Secrets and variables ▸ Actions* (needs **repo admin**):

| Kind | Name | Value |
|---|---|---|
| Variable | `BLOG_OAUTH_CLIENT_ID` | the OAuth App **Client ID** (step 1) |
| Secret | `BLOG_OAUTH_CLIENT_SECRET` | the OAuth App **client secret** (step 1) |
| Secret | `BLOG_SESSION_SECRET` | the `openssl rand` value (step 2) |

[deploy.yml](workflows/deploy.yml) maps these into the deploy step's env, and
[jac.toml](../jac.toml) `[plugins.scale.secrets]` interpolates them into the
`jaseci-blogs-secrets` k8s Secret (injected as env in the pod). Nothing sensitive
is committed.

### 4. Deploy

Push to `main` (or run the *Deploy* workflow). On boot the pod reads the env;
until the values exist, `/submit` and `/editor` simply report "not configured".

## Runtime env (read by `main.jac`)

| Env var | Source | Required |
|---|---|---|
| `GH_OAUTH_CLIENT_ID` / `GH_OAUTH_CLIENT_SECRET` | OAuth App | yes (sign-in + acting as user) |
| `SUBMIT_SESSION_SECRET` | random | yes (session sign + token encryption) |
| `GH_REPO` (default `jaseci-labs/jaseci-blogs`) / `GH_BASE_BRANCH` (default `main`) | static in jac.toml | no |

## Local development

`/submit` and `/editor` need the env vars above. Export them in your shell before
the Jac dev server, and use the local-callback OAuth App from step 1. The rest of
the blog runs without any of this.

## Guardrails baked in

- `draft: true` is written server-side — the form cannot publish anything.
- Every submission is a PR from the contributor's own fork, tied to their verified
  GitHub account (abuse trail + author identity).
- Image type/size (≤100KB, png/jpg/gif/webp/svg) and slug uniqueness enforced before commit.
- The user's GitHub token is encrypted at rest in the session (browser holds ciphertext only).
- Editor write-actions use the editor's own GitHub access; the server re-checks
  repo write permission on every editor call.
- `.schedule.yml` is never written directly — only via the existing audited workflows.
