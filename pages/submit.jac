"""Blog submission portal (/submit).

GitHub-authenticated visitors write a post (with images) and open a draft PR
without touching git. Identity is GitHub OAuth: we bounce to GitHub, exchange
the returned code server-side for a signed session token, and keep that token
in sessionStorage. The token (not the GitHub token) is sent with every walker
call. Two tabs: "Write a post" and "My submissions" (live status from GitHub).

Live preview renders markdown client-side via marked (loaded from CDN) — good
enough for authoring; the real article render happens on the post page.
"""

sv import from .main { GithubOAuthConfig, GithubOAuthExchange, SubmitPost, MySubmissions, CreatePreview, GetSubmissionForEdit, UpdatePost }

to cl:

import from "@jac/runtime" { Link }


glob SUBMIT_CATEGORIES = [
    "Jac Programming", "Tutorials", "Fixing the Broken",
    "AI", "Web Development", "Developers", "Community",
];
glob SESSION_KEY = "blog_submit_session";


def install_submit_helpers() -> None {
    # Promise-owning helpers injected as raw JS (Jac can't emit `new Promise`).
    # __readFileB64 -> {name, b64}; __loadScriptOnce -> resolves when loaded.
    if window.__readFileB64 {
        return;
    }
    s = document.createElement("script");
    s.textContent = "window.__readFileB64=function(file){return new Promise(function(res,rej){var r=new FileReader();r.onload=function(){var s=String(r.result||'');var i=s.indexOf('base64,');res({name:file.name,b64:i>=0?s.slice(i+7):''});};r.onerror=function(){rej(new Error('read failed'));};r.readAsDataURL(file);});};window.__loadScriptOnce=function(src){return new Promise(function(res,rej){var f=document.querySelector('script[data-so=\"'+src+'\"]');if(f){res();return;}var el=document.createElement('script');el.src=src;el.setAttribute('data-so',src);el.onload=function(){res();};el.onerror=function(){rej(new Error('load failed'));};document.head.appendChild(el);});};";
    document.head.appendChild(s);
}


async def ensure_marked() -> None {
    if window.marked {
        return;
    }
    install_submit_helpers();
    try {
        await window.__loadScriptOnce("https://cdn.jsdelivr.net/npm/marked@12/marked.min.js");
    } except Exception {
        _ignore = None;
    }
}


def slugify(text: str) -> str {
    # No Python `re` in the browser build — fold to [a-z0-9-] by hand.
    low = text.lower();
    res = "";
    prev_dash = False;
    i = 0;
    n = len(low);
    while i < n {
        ch = low[i];
        if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") {
            res = res + ch;
            prev_dash = False;
        } else {
            if not prev_dash {
                res = res + "-";
                prev_dash = True;
            }
        }
        i = i + 1;
    }
    while len(res) > 0 and res[0] == "-" {
        res = res[1:];
    }
    while len(res) > 0 and res[len(res) - 1] == "-" {
        res = res[:len(res) - 1];
    }
    return res;
}


def safe_filename(name: str) -> str {
    res = "";
    i = 0;
    n = len(name);
    while i < n {
        ch = name[i];
        keep = (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "." or ch == "_" or ch == "-";
        res = res + (ch if keep else "-");
        i = i + 1;
    }
    return res;
}


def read_session() -> any {
    try {
        raw = window.sessionStorage.getItem(SESSION_KEY);
        if raw {
            return JSON.parse(raw);
        }
    } except Exception {
        _ignore = None;
    }
    return None;
}


def save_session(data: any) -> None {
    try {
        window.sessionStorage.setItem(SESSION_KEY, JSON.stringify(data));
    } except Exception {
        _ignore = None;
    }
}


def clear_session() -> None {
    try {
        window.sessionStorage.removeItem(SESSION_KEY);
    } except Exception {
        _ignore = None;
    }
}


def query_param(name: str) -> str {
    # Manual parse — URLSearchParams is a JS constructor (needs `new`, which
    # Jac can't emit), so we read window.location.search ourselves.
    try {
        search = str(window.location.search or "");
        if search.startswith("?") {
            search = search[1:];
        }
        for pair in search.split("&") {
            if "=" in pair {
                kv = pair.split("=", 1);
                if kv[0] == name {
                    return str(decodeURIComponent(kv[1].replace("+", " ")));
                }
            }
        }
    } except Exception {
        _ignore = None;
    }
    return "";
}


def site_origin() -> str {
    try {
        return str(window.location.origin);
    } except Exception {
        return "";
    }
}


def redirect_uri() -> str {
    o = site_origin();
    return (o + "/submit") if o else "";
}


def status_label(status: str) -> str {
    mapping = {
        "in_review": "🟡 In review",
        "scheduled": "🗓️ Scheduled",
        "published": "🟢 Published",
        "accepted": "🔵 Accepted",
        "declined": "⚪ Not accepted",
    };
    return mapping.get(status, status);
}


def:pub page() -> JsxElement {
    has booting: bool = True;
    has signed_in: bool = False;
    has profile: any = None;
    has token: str = "";
    has is_editor: bool = False;
    has auth_error: str = "";

    has tab: str = "write";

    # Form state.
    has title: str = "";
    has slug: str = "";
    has slug_touched: bool = False;
    has description: str = "";
    has body: str = "";
    has bio: str = "";
    has cats: list = [];
    has images: list = [];
    has preview_html: str = "";
    has edit_pr: int = 0;  # 0 = new submission; >0 = editing that PR

    has submitting: bool = False;
    has submit_error: str = "";
    has result: any = None;

    # My submissions.
    has subs: list = [];
    has subs_loading: bool = False;
    has subs_error: str = "";
    has subs_busy: str = "";  # slug currently doing a preview/edit action

    async can with entry {
        window.scrollTo(0, 0);
        install_submit_helpers();
        # 1) returning from GitHub with ?code=...
        code = query_param("code");
        if code {
            try {
                res = root spawn GithubOAuthExchange(code=code, redirect_uri=redirect_uri());
                if res.reports and len(res.reports) > 0 {
                    data = res.reports[0];
                    if data["ok"] {
                        sess = {
                            "token": str(data["token"]),
                            "profile": data["profile"],
                            "is_editor": bool(data["is_editor"]),
                        };
                        save_session(sess);
                        token = sess["token"];
                        profile = sess["profile"];
                        is_editor = sess["is_editor"];
                        signed_in = True;
                    } else {
                        auth_error = str(data["error"]);
                    }
                }
            } except Exception {
                auth_error = "Sign-in failed. Please try again.";
            }
            # Strip the ?code= from the URL so a refresh doesn't re-exchange.
            try {
                window.history.replaceState({}, "", "/submit");
            } except Exception {
                _ignore = None;
            }
            booting = False;
            return;
        }
        # 2) restore an existing session
        existing = read_session();
        if existing {
            token = str(existing["token"]);
            profile = existing["profile"];
            is_editor = bool(existing["is_editor"]);
            signed_in = True;
        }
        booting = False;
    }

    async def begin_signin() -> None {
        try {
            cfg = root spawn GithubOAuthConfig();
            client_id = "";
            if cfg.reports and len(cfg.reports) > 0 and cfg.reports[0]["ok"] {
                client_id = str(cfg.reports[0]["client_id"]);
            }
            if not client_id {
                auth_error = "Not available at this moment, check again later.";
                return;
            }
            ru = encodeURIComponent(redirect_uri());
            # public_repo: lets us fork the repo + open the PR AS the user.
            url = f"https://github.com/login/oauth/authorize?client_id={client_id}&redirect_uri={ru}&scope=public_repo";
            window.location.href = url;
        } except Exception {
            auth_error = "Could not start sign-in.";
        }
    }

    def sign_out() -> None {
        clear_session();
        signed_in = False;
        profile = None;
        token = "";
        is_editor = False;
    }

    def on_title(v: str) -> None {
        title = v;
        if not slug_touched {
            slug = slugify(v);
        }
    }

    def cat_selected(c: str) -> bool {
        for x in cats {
            if x == c {
                return True;
            }
        }
        return False;
    }

    def toggle_cat(c: str) -> None {
        if cat_selected(c) {
            cats = [x for x in cats if x != c];
        } else {
            cats = cats + [c];
        }
    }

    # Factory: binds `c` as a parameter so each chip's handler toggles its OWN
    # category. A bare lambda over the loop var captures the wrong one.
    def make_cat_toggle(c: str) -> any {
        def handler() -> None {
            toggle_cat(c);
        }
        return handler;
    }

    async def on_files(files: any) -> None {
        new_imgs = images;
        for f in files {
            try {
                r = await window.__readFileB64(f);
                new_imgs = new_imgs + [{"name": str(r.name), "b64": str(r.b64)}];
            } except Exception {
                _ignore = None;
            }
        }
        images = new_imgs;
    }

    def remove_image(name: str) -> None {
        images = [im for im in images if im["name"] != name];
    }

    def insert_image(name: str) -> None {
        s = slug or "your-slug";
        snippet = f"\n![{name}](/assets/{s}/{safe_filename(name)})\n";
        body = body + snippet;
    }

    # Live preview: re-render whenever the body changes (or on entering the
    # write tab). ensure_marked() early-returns once the CDN script is loaded.
    async can with [body, tab] entry {
        if tab == "write" {
            await ensure_marked();
            try {
                if window.marked {
                    preview_html = str(window.marked.parse(body or ""));
                }
            } except Exception {
                _ignore = None;
            }
        }
    }

    async def do_submit() -> None {
        submit_error = "";
        result = None;
        if not title.strip() {
            submit_error = "Title is required.";
            return;
        }
        if not slug.strip() {
            submit_error = "Slug is required.";
            return;
        }
        if not cats {
            submit_error = "Pick at least one category.";
            return;
        }
        if len(body.strip()) < 50 {
            submit_error = "Post body is too short.";
            return;
        }
        submitting = True;
        try {
            # Declared here so both branches assign the SAME binding — assigning
            # only inside the if/else block-scopes `res` and it's undefined below.
            res: any = None;
            if edit_pr > 0 {
                res = root spawn UpdatePost(
                    session=token, pr_number=edit_pr, title=title, slug=slug,
                    categories=cats, description=description, body_md=body, images=images,
                );
            } else {
                res = root spawn SubmitPost(
                    session=token, title=title, slug=slug, categories=cats,
                    description=description, body_md=body, author_bio=bio, images=images,
                );
            }
            if res and res.reports {
                data = res.reports[0];
                if data["ok"] {
                    result = {**data, "edited": edit_pr > 0};
                } else {
                    submit_error = str(data["error"]);
                }
            } else {
                submit_error = "No response from server.";
            }
        } except Exception {
            submit_error = "Network error while saving.";
        }
        submitting = False;
    }

    def reset_form() -> None {
        result = None; edit_pr = 0; title = ""; slug = ""; slug_touched = False;
        description = ""; body = ""; bio = ""; cats = []; images = [];
        preview_html = ""; submit_error = "";
    }

    async def start_edit(pr: int) -> None {
        subs_busy = f"edit-{pr}";
        try {
            res = root spawn GetSubmissionForEdit(session=token, pr_number=pr);
            if res.reports and len(res.reports) > 0 {
                data = res.reports[0];
                if data["ok"] {
                    reset_form();
                    edit_pr = pr;
                    title = str(data["title"]);
                    slug = str(data["slug"]);
                    slug_touched = True;
                    cats = data["categories"];
                    description = str(data["description"]);
                    body = str(data["body_md"]);
                    tab = "write";
                    window.scrollTo(0, 0);
                } else {
                    subs_error = str(data["error"]);
                }
            }
        } except Exception {
            subs_error = "Could not load that submission for editing.";
        }
        subs_busy = "";
    }

    async def open_preview(pr: int) -> None {
        subs_busy = f"prev-{pr}";
        try {
            res = root spawn CreatePreview(session=token, pr_number=pr, origin=site_origin());
            if res.reports and len(res.reports) > 0 {
                data = res.reports[0];
                if data["ok"] {
                    try {
                        window.open(str(data["url"]), "_blank");
                    } except Exception {
                        _ignore = None;
                    }
                } else {
                    subs_error = str(data["error"]);
                }
            }
        } except Exception {
            subs_error = "Could not create preview.";
        }
        subs_busy = "";
    }

    def make_edit(pr: int) -> any {
        def h() -> None {
            start_edit(pr);
        }
        return h;
    }

    def make_preview(pr: int) -> any {
        def h() -> None {
            open_preview(pr);
        }
        return h;
    }

    async def load_subs() -> None {
        subs_loading = True;
        subs_error = "";
        try {
            res = root spawn MySubmissions(session=token);
            if res.reports and len(res.reports) > 0 {
                data = res.reports[0];
                if data["ok"] {
                    subs = data["submissions"];
                } else {
                    subs_error = str(data["error"]);
                }
            }
        } except Exception {
            subs_error = "Could not load submissions.";
        }
        subs_loading = False;
    }

    async can with [tab] entry {
        if tab == "mine" and signed_in {
            await load_subs();
        }
    }

    if booting {
        return <section className="container narrow" style={{"padding": "4rem 0"}}>
            <p className="muted">Loading…</p>
        </section>;
    }

    if not signed_in {
        return <section className="container narrow" style={{"padding": "4rem 0", "maxWidth": "640px"}}>
            <p className="eyebrow">Contribute</p>
            <h1 className="display">Submit a blog post</h1>
            <p className="post-deck">
                Share something insightful with the Jac & Jaseci community. Sign in with
                GitHub to write a post.
            </p>
            {auth_error and <p style={{"color": "var(--danger, #c0392b)", "marginTop": "1rem"}}>{auth_error}</p>}
            <button
                type="button"
                className="cta-pill"
                style={{"marginTop": "2rem", "display": "inline-flex", "alignItems": "center", "gap": "0.5rem"}}
                onClick={lambda -> None { begin_signin(); }}
            >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23A11.509 11.509 0 0112 5.803c1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222 0 1.606-.014 2.898-.014 3.293 0 .322.216.694.825.576C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>
                Sign in with GitHub
            </button>
        </section>;
    }

    return <section className="container app" style={{"padding": "2.5rem 0"}}>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "center", "gap": "1rem", "flexWrap": "wrap"}}>
            <div style={{"display": "flex", "alignItems": "center", "gap": "0.6rem"}}>
                {profile and profile["avatar"] and (
                    <img src={profile["avatar"]} alt="" width={32} height={32} style={{"borderRadius": "50%"}} />
                )}
                <span className="muted small">
                    Signed in as <strong>{profile and profile["name"]}</strong>
                </span>
            </div>
            <div style={{"display": "flex", "alignItems": "center", "gap": "0.75rem"}}>
                {is_editor and <Link to="/editor" className="tag">Editor dashboard →</Link>}
                <button type="button" className="runnable-copy" onClick={lambda -> None { sign_out(); }}>Sign out</button>
            </div>
        </div>

        <div className="tag-row" style={{"marginTop": "1.5rem", "borderBottom": "1px solid var(--rule)", "paddingBottom": "0.75rem"}}>
            <button
                type="button"
                className={tab == "write" and "tag is-active" or "tag"}
                onClick={lambda -> None { tab = "write"; }}
            >Write a post</button>
            <button
                type="button"
                className={tab == "mine" and "tag is-active" or "tag"}
                onClick={lambda -> None { tab = "mine"; }}
            >My submissions</button>
        </div>

        {tab == "write" and result and (
            <div style={{"padding": "2rem 0"}}>
                <p className="eyebrow">{result["edited"] and "Saved ✓" or "Submitted ✓"}</p>
                <h2 className="display" style={{"fontSize": "1.8rem"}}>
                    {result["edited"] and "Your changes were saved" or "Your post is in review"}
                </h2>
                <p className="post-deck">
                    {result["edited"] and "The pull request was updated with your changes." or "A draft pull request was opened. An editor will review and schedule it."}
                </p>
                <p style={{"marginTop": "1.5rem", "display": "flex", "gap": "0.75rem"}}>
                    <a className="cta-pill" href={result["pr_url"]} target="_blank" rel="noopener">View pull request →</a>
                    <button type="button" className="runnable-copy" onClick={lambda -> None { reset_form(); }}>Write another</button>
                </p>
            </div>
        )}

        {tab == "write" and not result and (
            <div style={{"paddingTop": "1.5rem"}}>
                {edit_pr > 0 and (
                    <p className="muted small" style={{"display": "flex", "gap": "0.75rem", "alignItems": "center", "marginBottom": "1rem"}}>
                        ✏️ Editing submission #{edit_pr}. Saving adds a commit to the existing PR.
                        <button type="button" className="runnable-copy" onClick={lambda -> None { reset_form(); }}>Cancel edit</button>
                    </p>
                )}
                <label className="eyebrow">Title</label>
                <input
                    type="text"
                    className="search-input"
                    placeholder="A clear, compelling title"
                    value={title}
                    onChange={lambda e: ChangeEvent { on_title(e.target.value); }}
                />

                <label className="eyebrow" style={{"marginTop": "1rem", "display": "block"}}>Slug</label>
                <input
                    type="text"
                    className="search-input"
                    placeholder="kebab-case-url"
                    value={slug}
                    readOnly={edit_pr > 0}
                    style={edit_pr > 0 and {"opacity": "0.6", "cursor": "not-allowed"} or {}}
                    onChange={lambda e: ChangeEvent { slug_touched = True; slug = e.target.value; }}
                />
                <p className="muted small">
                    {edit_pr > 0 and "Slug can't change when editing: " or "Your post will live at "}/blog/posts/{slug or "your-slug"}
                </p>

                <label className="eyebrow" style={{"marginTop": "1rem", "display": "block"}}>Categories</label>
                <div className="tag-row">
                    {[
                        <button
                            key={c}
                            type="button"
                            className={cat_selected(c) and "tag is-active" or "tag"}
                            onClick={make_cat_toggle(c)}
                        >{c}</button>
                        for c in SUBMIT_CATEGORIES
                    ]}
                </div>

                <label className="eyebrow" style={{"marginTop": "1rem", "display": "block"}}>Short description (optional)</label>
                <input
                    type="text"
                    className="search-input"
                    placeholder="One-line summary for cards & social previews"
                    value={description}
                    onChange={lambda e: ChangeEvent { description = e.target.value; }}
                />

                <label className="eyebrow" style={{"marginTop": "1rem", "display": "block"}}>Images (optional, ≤100KB each)</label>
                <input
                    type="file"
                    multiple
                    accept="image/png,image/jpeg,image/gif,image/webp,image/svg+xml"
                    onChange={lambda e: ChangeEvent { on_files(e.target.files); }}
                />
                {len(images) > 0 and (
                    <ul style={{"listStyle": "none", "padding": "0", "marginTop": "0.5rem"}}>
                        {[
                            <li key={im["name"]} style={{"display": "flex", "alignItems": "center", "gap": "0.5rem", "padding": "0.25rem 0"}}>
                                <span className="muted small" style={{"flex": "1"}}>{im["name"]}</span>
                                <button type="button" className="runnable-copy" onClick={lambda -> None { insert_image(im["name"]); }}>Insert</button>
                                <button type="button" className="runnable-copy" onClick={lambda -> None { remove_image(im["name"]); }}>Remove</button>
                            </li>
                            for im in images
                        ]}
                    </ul>
                )}

                <div style={{"display": "flex", "justifyContent": "space-between", "marginTop": "1rem"}}>
                    <label className="eyebrow">Body (Markdown)</label>
                    <span className="eyebrow" style={{"opacity": "0.6"}}>Live preview →</span>
                </div>
                <div className="submit-editor-grid">
                    <textarea
                        className="search-input"
                        style={{"minHeight": "420px", "fontFamily": "var(--mono, monospace)", "lineHeight": "1.6", "resize": "vertical"}}
                        placeholder="Write your post in Markdown. Use ```jac fences for code, ```mermaid for diagrams."
                        value={body}
                        onChange={lambda e: ChangeEvent { body = e.target.value; }}
                    />
                    <div
                        className="prose"
                        style={{"minHeight": "420px", "maxHeight": "640px", "overflow": "auto", "border": "1px solid var(--rule)", "borderRadius": "8px", "padding": "0.75rem 1.1rem", "background": "var(--bg-elev)", "color": "var(--text)"}}
                        dangerouslySetInnerHTML={{"__html": preview_html or "<p class='muted'>Preview appears here as you type…</p>"}}
                    />
                </div>

                {edit_pr == 0 and (
                    <>
                        <label className="eyebrow" style={{"marginTop": "1rem", "display": "block"}}>Your bio (optional, used if you're a new author)</label>
                        <input
                            type="text"
                            className="search-input"
                            placeholder="One sentence about you"
                            value={bio}
                            onChange={lambda e: ChangeEvent { bio = e.target.value; }}
                        />
                    </>
                )}

                {submit_error and <p style={{"color": "var(--danger, #c0392b)", "marginTop": "1rem"}}>{submit_error}</p>}

                <div style={{"display": "flex", "gap": "0.75rem", "marginTop": "1.5rem", "flexWrap": "wrap"}}>
                    <button type="button" className="cta-pill" disabled={submitting} onClick={lambda -> None { do_submit(); }}>
                        {submitting and "Saving…" or (edit_pr > 0 and "Save changes" or "Submit for review")}
                    </button>
                </div>
            </div>
        )}

        {tab == "mine" and (
            <div style={{"paddingTop": "1.5rem"}}>
                {subs_loading and <p className="muted">Loading your submissions…</p>}
                {subs_error and <p style={{"color": "var(--danger, #c0392b)"}}>{subs_error}</p>}
                {not subs_loading and not subs_error and len(subs) == 0 and (
                    <p className="muted">No submissions yet. Write your first post!</p>
                )}
                <ul className="search-results">
                    {[
                        <li key={s["pr_number"]} className="search-result">
                            <p className="search-result-title">{s["title"]}</p>
                            <p className="muted small" style={{"marginTop": "0.25rem", "display": "flex", "gap": "0.75rem", "flexWrap": "wrap", "alignItems": "center"}}>
                                <span>{status_label(str(s["status"]))}</span>
                                {s["schedule_at"] and <span>· {s["schedule_at"]}</span>}
                                <a href={s["pr_url"]} target="_blank" rel="noopener">PR #{s["pr_number"]}</a>
                                {s["published_url"] and <a href={s["published_url"]} target="_blank" rel="noopener">Read live →</a>}
                                <button type="button" className="runnable-copy" disabled={subs_busy == f"prev-{s['pr_number']}"} onClick={make_preview(int(s["pr_number"]))}>
                                    {subs_busy == f"prev-{s['pr_number']}" and "Opening…" or "Preview ↗"}
                                </button>
                                {s["status"] == "in_review" and (
                                    <button type="button" className="runnable-copy" disabled={subs_busy == f"edit-{s['pr_number']}"} onClick={make_edit(int(s["pr_number"]))}>
                                        {subs_busy == f"edit-{s['pr_number']}" and "Loading…" or "Edit"}
                                    </button>
                                )}
                            </p>
                        </li>
                        for s in subs
                    ]}
                </ul>
            </div>
        )}
    </section>;
}
