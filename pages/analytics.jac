"""Reading-analytics dashboard (/analytics).

For repo-write users only. Surfaces the anonymous reading metrics collected by
the RecordView / RecordEngagement walkers (opens, unique readers, average active
read time, scroll depth) per post.

Gating mirrors /reviewer: the same GitHub session minted on /submit, and the
GetAnalytics walker additionally re-verifies repo write access server-side — so
the numbers are never returned to a non-reviewer even if they reach the page.
"""

sv import from .main { GetAnalytics, ResetAnalytics }

to cl:

import from "@jac/runtime" { Link }


glob SESSION_KEY = "blog_submit_session";
glob CARD_STYLE = {"border": "1px solid var(--rule)", "borderRadius": "12px", "padding": "1.1rem 1.3rem", "background": "var(--bg-subtle)"};


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


def fmt_duration(seconds: float) -> str {
    # Human-friendly active read time, e.g. "0s", "45s", "3m 20s".
    s = int(seconds);
    if s < 60 {
        return str(s) + "s";
    }
    m = s // 60;
    rem = s % 60;
    return str(m) + "m " + str(rem) + "s";
}


def scroll_bar(buckets: list) -> JsxElement {
    # Tiny stacked bar of the scroll-depth distribution (4 buckets).
    total = 0;
    for b in buckets {
        total += int(b);
    }
    labels = ["0–25%", "25–50%", "50–75%", "75–100%"];
    colors = ["#d8d8d8", "#9ec6e0", "#5b9bd5", "#2f6fb0"];
    if total == 0 {
        return <span className="muted small">—</span>;
    }
    return <span style={{"display": "inline-flex", "width": "120px", "height": "10px", "borderRadius": "5px", "overflow": "hidden", "border": "1px solid var(--rule)"}} title={f"{total} reading samples"}>
        {[
            <span
                key={labels[i]}
                title={f"{labels[i]}: {buckets[i]}"}
                style={{"width": f"{(int(buckets[i]) / total) * 100.0}%", "background": colors[i]}}
            />
            for i in range(4)
        ]}
    </span>;
}


def:pub page() -> JsxElement {
    has booting: bool = True;
    has signed_in: bool = False;
    has is_reviewer: bool = False;
    has gh_enc: str = "";

    has loading: bool = False;
    has error: str = "";
    has rows: list = [];
    has totals: any = None;
    has expanded: str = "";  # slug whose link-click breakdown is open

    def make_toggle_links(slug: str) -> any {
        def handler() -> None {
            expanded = "" if expanded == slug else slug;
        }
        return handler;
    }

    can with entry {
        existing = read_session();
        if existing {
            gh_enc = str(existing["gh_enc"]);
            signed_in = True;
            is_reviewer = bool(existing["is_reviewer"]);
        }
        booting = False;
    }

    async def load_analytics() -> None {
        loading = True;
        error = "";
        try {
            res = root spawn GetAnalytics(gh_enc=gh_enc);
            if res.reports and len(res.reports) > 0 {
                data = res.reports[0];
                if data["ok"] {
                    rows = data["posts"];
                    totals = data["totals"];
                } else {
                    error = str(data["error"]);
                }
            } else {
                error = "No response from server.";
            }
        } except Exception {
            error = "Could not load analytics.";
        }
        loading = False;
    }

    async def reset_analytics() -> None {
        ok_to = False;
        try {
            ok_to = bool(window.confirm("Delete ALL reading analytics and start fresh? This can't be undone."));
        } except Exception {
            ok_to = False;
        }
        if not ok_to {
            return;
        }
        try {
            res = root spawn ResetAnalytics(gh_enc=gh_enc);
            if res.reports and len(res.reports) > 0 and res.reports[0]["ok"] {
                rows = [];
                totals = None;
                await load_analytics();
            } else {
                error = "Could not reset analytics.";
            }
        } except Exception {
            error = "Could not reset analytics.";
        }
    }

    async can with [signed_in] entry {
        if signed_in and is_reviewer {
            await load_analytics();
        }
    }

    if booting {
        return <section className="container narrow" style={{"padding": "4rem 0"}}>
            <p className="muted">Loading…</p>
        </section>;
    }

    if not signed_in {
        return <section className="container narrow" style={{"padding": "4rem 0"}}>
            <p className="eyebrow">Analytics</p>
            <h1 className="display">Sign in required</h1>
            <p className="post-deck">Sign in with GitHub to access reading analytics.</p>
            <p style={{"marginTop": "1.5rem"}}><Link className="cta-pill" to="/submit">Go to sign in →</Link></p>
        </section>;
    }

    if not is_reviewer {
        return <section className="container narrow" style={{"padding": "4rem 0"}}>
            <p className="eyebrow">Analytics</p>
            <h1 className="display">Not authorized</h1>
            <p className="post-deck">This area is for reviewers with write access to the repository.</p>
            <p style={{"marginTop": "1.5rem"}}><Link className="cta-pill" to="/blog">← Back to the blog</Link></p>
        </section>;
    }

    return <section className="container app" style={{"padding": "2rem 0"}}>
        <div style={{"display": "flex", "justifyContent": "space-between", "alignItems": "baseline", "gap": "1rem", "flexWrap": "wrap"}}>
            <div>
                <p className="eyebrow">Reviewer dashboard</p>
                <h1 className="display" style={{"fontSize": "2rem"}}>Reading analytics</h1>
                <p className="muted small" style={{"marginTop": "0.25rem"}}>Anonymous, aggregate metrics — opens, unique readers, active read time and scroll depth.</p>
            </div>
            <div style={{"display": "flex", "gap": "0.5rem"}}>
                <button type="button" className="runnable-copy" onClick={lambda -> None { load_analytics(); }}>Refresh</button>
                <button type="button" className="tag" onClick={lambda -> None { reset_analytics(); }}>Reset data</button>
            </div>
        </div>

        {totals and (
            <div style={{"display": "flex", "gap": "1rem", "flexWrap": "wrap", "marginTop": "1.25rem"}}>
                <div style={CARD_STYLE}>
                    <p className="muted small" style={{"margin": "0"}}>Total opens</p>
                    <p style={{"fontSize": "1.8rem", "fontWeight": "700", "margin": "0.2rem 0 0"}}>{totals["views"]}</p>
                </div>
                <div style={CARD_STYLE}>
                    <p className="muted small" style={{"margin": "0"}}>Unique readers</p>
                    <p style={{"fontSize": "1.8rem", "fontWeight": "700", "margin": "0.2rem 0 0"}}>{totals["uniques"]}</p>
                </div>
                <div style={CARD_STYLE}>
                    <p className="muted small" style={{"margin": "0"}}>Posts tracked</p>
                    <p style={{"fontSize": "1.8rem", "fontWeight": "700", "margin": "0.2rem 0 0"}}>{len(rows)}</p>
                </div>
            </div>
        )}

        {loading and <p className="muted" style={{"marginTop": "1.5rem"}}>Loading…</p>}
        {error and <p style={{"color": "var(--danger, #c0392b)", "marginTop": "1.5rem"}}>{error}</p>}
        {not loading and not error and len(rows) == 0 and (
            <p className="muted" style={{"marginTop": "1.5rem"}}>No reading data yet. Numbers will appear here as readers open posts.</p>
        )}

        {len(rows) > 0 and (
            <div style={{"marginTop": "1.5rem", "overflowX": "auto"}}>
                <table style={{"width": "100%", "borderCollapse": "collapse", "fontSize": "0.95rem"}}>
                    <thead>
                        <tr style={{"textAlign": "left", "borderBottom": "2px solid var(--rule)"}}>
                            <th style={{"padding": "0.6rem 0.5rem"}}>Post</th>
                            <th style={{"padding": "0.6rem 0.5rem", "textAlign": "right"}}>Opens</th>
                            <th style={{"padding": "0.6rem 0.5rem", "textAlign": "right"}}>Unique</th>
                            <th style={{"padding": "0.6rem 0.5rem", "textAlign": "right"}}>Avg read</th>
                            <th style={{"padding": "0.6rem 0.5rem", "textAlign": "right"}}>Avg scroll</th>
                            <th style={{"padding": "0.6rem 0.5rem"}}>Scroll depth</th>
                            <th style={{"padding": "0.6rem 0.5rem", "textAlign": "right"}}>Link clicks</th>
                        </tr>
                    </thead>
                    <tbody>
                        {[
                            <>
                                <tr key={r["slug"]} style={{"borderBottom": (expanded == r["slug"]) and "none" or "1px solid var(--rule)"}}>
                                    <td style={{"padding": "0.6rem 0.5rem"}}>
                                        <a href={f"/blog/posts/{r['slug']}"} target="_blank" rel="noopener">{r["slug"]}</a>
                                    </td>
                                    <td style={{"padding": "0.6rem 0.5rem", "textAlign": "right", "fontVariantNumeric": "tabular-nums"}}>{r["views"]}</td>
                                    <td style={{"padding": "0.6rem 0.5rem", "textAlign": "right", "fontVariantNumeric": "tabular-nums"}}>{r["uniques"]}</td>
                                    <td style={{"padding": "0.6rem 0.5rem", "textAlign": "right", "fontVariantNumeric": "tabular-nums"}}>{fmt_duration(float(r["avg_read_sec"]))}</td>
                                    <td style={{"padding": "0.6rem 0.5rem", "textAlign": "right", "fontVariantNumeric": "tabular-nums"}}>{r["avg_scroll"]}%</td>
                                    <td style={{"padding": "0.6rem 0.5rem"}}>{scroll_bar(r["scroll_buckets"])}</td>
                                    <td style={{"padding": "0.6rem 0.5rem", "textAlign": "right", "fontVariantNumeric": "tabular-nums"}}>
                                        {(len(r["links"]) > 0) and (
                                            <button type="button" className={(expanded == r["slug"]) and "tag is-active" or "tag"} onClick={make_toggle_links(str(r["slug"]))}>
                                                {r["link_clicks"]} {(expanded == r["slug"]) and "▲" or "▾"}
                                            </button>
                                        ) or <span className="muted">0</span>}
                                    </td>
                                </tr>
                                {(expanded == r["slug"]) and (
                                    <tr key={f"{r['slug']}-links"} style={{"borderBottom": "1px solid var(--rule)"}}>
                                        <td colSpan={7} style={{"padding": "0 0.5rem 0.8rem"}}>
                                            <ul style={{"listStyle": "none", "margin": "0", "padding": "0", "display": "flex", "flexDirection": "column", "gap": "0.3rem"}}>
                                                {[
                                                    <li key={lk["href"]} style={{"display": "flex", "justifyContent": "space-between", "gap": "1rem", "fontSize": "0.85rem"}}>
                                                        <a href={str(lk["href"])} target="_blank" rel="noopener" style={{"overflow": "hidden", "textOverflow": "ellipsis", "whiteSpace": "nowrap"}}>{lk["href"]}</a>
                                                        <span className="muted" style={{"fontVariantNumeric": "tabular-nums"}}>{lk["clicks"]}</span>
                                                    </li>
                                                    for lk in r["links"]
                                                ]}
                                            </ul>
                                        </td>
                                    </tr>
                                )}
                            </>
                            for r in rows
                        ]}
                    </tbody>
                </table>
                <p className="muted small" style={{"marginTop": "0.75rem"}}>
                    “Avg read” is active time on the page (paused while the tab is hidden). “Avg scroll” is the average of each reader’s deepest point reached. “Link clicks” counts clicks on links inside the article body — expand to see which. Counts are anonymous and best-effort.
                </p>
            </div>
        )}
    </section>;
}
