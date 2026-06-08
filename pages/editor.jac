"""Editor dashboard (/editor).

For repo-write users only. Lists open blog submissions, renders each for review
using the same server pipeline the live post page uses, and exposes the editor
actions — all backed by GitHub (no DB):

  • Approve & merge       -> PUT /pulls/{n}/merge
  • Schedule / hold / ... -> dispatches the existing "Schedule a post" workflow
  • Take down a live post -> dispatches the existing "Take down a post" workflow

Editor identity + gating is the same GitHub session minted on /submit; this page
just additionally requires is_editor (server-verified repo write access).
"""

sv import from .main { ListSubmissions, PreviewSubmission, CreatePreview }

to cl:

import from "@jac/runtime" { Link }


glob SESSION_KEY = "blog_submit_session";
glob ROW_STYLE = {"display": "flex", "alignItems": "center", "gap": "0.5rem", "justifyContent": "space-between"};
glob CODE_STYLE = {"fontFamily": "var(--mono, monospace)", "fontSize": "0.9rem", "padding": "0.6rem 0.8rem", "background": "var(--bg-subtle)", "color": "var(--text)", "border": "1px solid var(--rule)", "borderRadius": "6px", "flex": "1", "overflowX": "auto", "whiteSpace": "nowrap"};
glob EDITOR_ACTIONS = [
    {"key": "schedule", "label": "Schedule"},
    {"key": "publish-now", "label": "Publish now"},
    {"key": "hold", "label": "Hold"},
    {"key": "cancel", "label": "Cancel"},
    {"key": "takedown", "label": "Take down"},
];


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


def:pub page() -> JsxElement {
    has booting: bool = True;
    has signed_in: bool = False;
    has is_editor: bool = False;
    has token: str = "";

    has queue: list = [];
    has queue_loading: bool = False;
    has queue_error: str = "";

    has selected: int = 0;
    has preview: any = None;
    has preview_loading: bool = False;
    has preview_error: str = "";

    has copied: bool = False;
    has preview_link: str = "";
    has preview_busy: bool = False;
    has action: str = "schedule";
    has sched_date: str = "";
    has sched_time: str = "14:00";
    has notes: str = "";
    has td_dest: str = "draft";
    has td_reason: str = "";

    can with entry {
        existing = read_session();
        if existing {
            token = str(existing["token"]);
            signed_in = True;
            is_editor = bool(existing["is_editor"]);
        }
        booting = False;
    }

    async def load_queue() -> None {
        queue_loading = True;
        queue_error = "";
        try {
            res = root spawn ListSubmissions(session=token);
            if res.reports and len(res.reports) > 0 {
                data = res.reports[0];
                if data["ok"] {
                    queue = data["submissions"];
                } else {
                    queue_error = str(data["error"]);
                }
            }
        } except Exception {
            queue_error = "Could not load the review queue.";
        }
        queue_loading = False;
    }

    async can with [signed_in] entry {
        if signed_in and is_editor {
            await load_queue();
        }
    }

    async def select_pr(n: int) -> None {
        selected = n;
        preview = None;
        preview_error = "";
        copied = False;
        preview_link = "";
        preview_loading = True;
        try {
            res = root spawn PreviewSubmission(session=token, pr_number=n);
            if res.reports and len(res.reports) > 0 {
                data = res.reports[0];
                if data["ok"] {
                    preview = data;
                } else {
                    preview_error = str(data["error"]);
                }
            }
        } except Exception {
            preview_error = "Could not load the preview.";
        }
        preview_loading = False;
    }

    # Editor actions run with the editor's OWN GitHub access: merge happens on
    # the PR page, and scheduling/take-down are slash-commands the editor pastes
    # as a PR comment (their write access authorizes the slash-command workflow).
    # So the app needs no privileged merge/dispatch credential.
    def make_set_action(k: str) -> any {
        def handler() -> None {
            action = k;
            copied = False;
        }
        return handler;
    }

    # Build the single slash-command for the currently selected action.
    def generated_command() -> str {
        if action == "publish-now" {
            return "/publish-now";
        }
        if action == "hold" {
            return "/hold";
        }
        if action == "cancel" {
            return "/cancel";
        }
        if action == "takedown" {
            verb = "/hide";
            if td_dest == "unlist" {
                verb = "/unlist";
            } elif td_dest == "archive" {
                verb = "/archive";
            }
            return (verb + " " + td_reason) if td_reason else verb;
        }
        # schedule
        when = f"{sched_date}T{sched_time or '00:00'}:00Z" if sched_date else "YYYY-MM-DDTHH:MM:SSZ";
        cmd = "/schedule " + when;
        return (cmd + " " + notes) if notes else cmd;
    }

    def do_copy(text: str) -> None {
        try {
            if navigator.clipboard {
                navigator.clipboard.writeText(text);
            } else {
                ta = document.createElement("textarea");
                ta.value = text;
                document.body.appendChild(ta);
                ta.select();
                document.execCommand("copy");
                document.body.removeChild(ta);
            }
            copied = True;
            setTimeout(lambda -> None { copied = False; }, 1500);
        } except Exception {
            _ignore = None;
        }
    }

    def copy_command() -> None {
        do_copy(generated_command());
    }

    def copy_link() -> None {
        do_copy(preview_link);
    }

    async def create_preview() -> None {
        preview_busy = True;
        try {
            res = root spawn CreatePreview(session=token, pr_number=selected);
            if res.reports and len(res.reports) > 0 {
                data = res.reports[0];
                if data["ok"] {
                    preview_link = str(data["url"]);
                    try {
                        window.open(preview_link, "_blank");
                    } except Exception {
                        _ignore = None;
                    }
                } else {
                    preview_link = "";
                    preview_error = str(data["error"]);
                }
            }
        } except Exception {
            preview_error = "Could not create preview link.";
        }
        preview_busy = False;
    }

    if booting {
        return <section className="container narrow" style={{"padding": "4rem 0"}}>
            <p className="muted">Loading…</p>
        </section>;
    }

    if not signed_in {
        return <section className="container narrow" style={{"padding": "4rem 0"}}>
            <p className="eyebrow">Editor dashboard</p>
            <h1 className="display">Sign in required</h1>
            <p className="post-deck">Sign in with GitHub to access the editor tools.</p>
            <p style={{"marginTop": "1.5rem"}}><Link className="cta-pill" to="/submit">Go to sign in →</Link></p>
        </section>;
    }

    if not is_editor {
        return <section className="container narrow" style={{"padding": "4rem 0"}}>
            <p className="eyebrow">Editor dashboard</p>
            <h1 className="display">Not authorized</h1>
            <p className="post-deck">This area is for editors with write access to the repository.</p>
            <p style={{"marginTop": "1.5rem"}}><Link className="cta-pill" to="/blog">← Back to the blog</Link></p>
        </section>;
    }

    return <section className="container app" style={{"padding": "2rem 0"}}>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "baseline", "gap": "1rem", "flexWrap": "wrap"}}>
            <div>
                <p className="eyebrow">Editor dashboard</p>
                <h1 className="display" style={{"fontSize": "2rem"}}>Review queue</h1>
            </div>
            <button type="button" className="runnable-copy" onClick={lambda -> None { load_queue(); }}>Refresh</button>
        </div>

        <div style={{"display": "grid", "gridTemplateColumns": "minmax(240px, 320px) 1fr", "gap": "2rem", "marginTop": "1.5rem", "alignItems": "start"}}>
            <aside>
                {queue_loading and <p className="muted">Loading…</p>}
                {queue_error and <p style={{"color": "var(--danger, #c0392b)"}}>{queue_error}</p>}
                {not queue_loading and len(queue) == 0 and <p className="muted">No open submissions 🎉</p>}
                <ul style={{"listStyle": "none", "padding": "0", "margin": "0", "display": "flex", "flexDirection": "column", "gap": "0.5rem"}}>
                    {[
                        <li key={item["pr_number"]}>
                            <button
                                type="button"
                                className={selected == item["pr_number"] and "tag is-active" or "tag"}
                                style={{"width": "100%", "textAlign": "left", "display": "block"}}
                                onClick={lambda -> None { select_pr(int(item["pr_number"])); }}
                            >
                                <span style={{"display": "block", "fontWeight": "600"}}>{item["title"]}</span>
                                <span className="muted small">@{item["author"]} · PR #{item["pr_number"]}</span>
                            </button>
                        </li>
                        for item in queue
                    ]}
                </ul>
            </aside>

            <div>
                {not preview and not preview_loading and <p className="muted">Select a submission to review.</p>}
                {preview_loading and <p className="muted">Rendering preview…</p>}
                {preview_error and <p style={{"color": "var(--danger, #c0392b)"}}>{preview_error}</p>}

                {preview and (
                    <div>
                        <div>
                            <h2 style={{"margin": "0"}}>{preview["title"]}</h2>
                            <p className="muted small" style={{"marginTop": "0.25rem"}}>
                                /blog/posts/{preview["slug"]} · {preview["reading_minutes"]} min read
                                {preview["mergeable"] == False and " · ⚠ not mergeable (conflicts/checks)"}
                            </p>
                        </div>

                        <div className="tag-row" style={{"marginTop": "0.75rem"}}>
                            <a className="tag" href={preview["pr_url"]} target="_blank" rel="noopener">Pull request ↗</a>
                            {preview["issue_url"] and (
                                <a className="tag" href={preview["issue_url"]} target="_blank" rel="noopener">Tracker issue ↗</a>
                            )}
                            <button type="button" className="tag" disabled={preview_busy} onClick={lambda -> None { create_preview(); }}>
                                {preview_busy and "Creating…" or "Create shareable preview →"}
                            </button>
                        </div>
                        {preview_link and (
                            <div style={{"marginTop": "0.6rem", "display": "flex", "gap": "0.5rem", "alignItems": "center"}}>
                                <code style={CODE_STYLE}>{preview_link}</code>
                                <button type="button" className="runnable-copy" onClick={lambda -> None { copy_link(); }}>{copied and "Copied ✓" or "Copy"}</button>
                            </div>
                        )}

                        <div style={{"marginTop": "1rem", "padding": "1rem", "border": "1px solid var(--rule)", "borderRadius": "10px"}}>
                            <p className="muted small" style={{"marginTop": "0"}}>
                                Pick an action and it builds one slash-command. Copy it and paste it as a
                                comment on the PR (your write access authorizes it). To merge, open the PR.
                            </p>

                            <div className="tag-row" style={{"marginBottom": "1rem"}}>
                                {[
                                    <button
                                        key={a["key"]}
                                        type="button"
                                        className={action == a["key"] and "tag is-active" or "tag"}
                                        onClick={make_set_action(str(a["key"]))}
                                    >{a["label"]}</button>
                                    for a in EDITOR_ACTIONS
                                ]}
                            </div>

                            {action == "schedule" and (
                                <div style={{"display": "flex", "gap": "0.5rem", "flexWrap": "wrap", "marginBottom": "0.75rem"}}>
                                    <label className="muted small" style={{"display": "flex", "flexDirection": "column", "gap": "0.2rem"}}>
                                        Date (UTC)
                                        <input type="date" className="search-input" value={sched_date}
                                            onChange={lambda e: ChangeEvent { sched_date = e.target.value; }} style={{"maxWidth": "180px"}} />
                                    </label>
                                    <label className="muted small" style={{"display": "flex", "flexDirection": "column", "gap": "0.2rem"}}>
                                        Time (UTC)
                                        <input type="time" className="search-input" value={sched_time}
                                            onChange={lambda e: ChangeEvent { sched_time = e.target.value; }} style={{"maxWidth": "140px"}} />
                                    </label>
                                    <label className="muted small" style={{"display": "flex", "flexDirection": "column", "gap": "0.2rem", "flex": "1", "minWidth": "180px"}}>
                                        Notes (optional)
                                        <input type="text" className="search-input" placeholder="e.g. waiting on marketing" value={notes}
                                            onChange={lambda e: ChangeEvent { notes = e.target.value; }} />
                                    </label>
                                </div>
                            )}

                            {action == "takedown" and (
                                <div style={{"display": "flex", "gap": "0.5rem", "flexWrap": "wrap", "marginBottom": "0.75rem"}}>
                                    <label className="muted small" style={{"display": "flex", "flexDirection": "column", "gap": "0.2rem"}}>
                                        Destination
                                        <select className="search-input" value={td_dest} onChange={lambda e: ChangeEvent { td_dest = e.target.value; }} style={{"maxWidth": "200px"}}>
                                            <option value="draft">hide (reversible draft)</option>
                                            <option value="unlist">unlist</option>
                                            <option value="archive">archive</option>
                                        </select>
                                    </label>
                                    <label className="muted small" style={{"display": "flex", "flexDirection": "column", "gap": "0.2rem", "flex": "1", "minWidth": "180px"}}>
                                        Reason
                                        <input type="text" className="search-input" placeholder="why it's coming down" value={td_reason}
                                            onChange={lambda e: ChangeEvent { td_reason = e.target.value; }} />
                                    </label>
                                </div>
                            )}

                            {(action == "publish-now" or action == "hold" or action == "cancel") and (
                                <p className="muted small" style={{"marginBottom": "0.75rem"}}>No extra input needed for this action.</p>
                            )}

                            <p className="eyebrow">Comment to paste</p>
                            <div style={ROW_STYLE}>
                                <code style={CODE_STYLE}>{generated_command()}</code>
                                <button type="button" className="cta-pill" onClick={lambda -> None { copy_command(); }}>{copied and "Copied ✓" or "Copy"}</button>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    </section>;
}
