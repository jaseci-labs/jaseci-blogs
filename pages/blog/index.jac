sv import from ..main { GetPosts }

to cl:

import from "@jac/runtime" { Link, useLocation }


glob PER_PAGE = 5;


def read_page_from_search(search: str) -> int {
    # Parse ?page=N by hand — the JS URLSearchParams constructor needs `new`,
    # which the Jac→JS compiler doesn't emit.
    try {
        if "page=" in search {
            after = search.split("page=", 1)[1];
            num = after.split("&", 1)[0];
            return max(1, int(num));
        }
    } except Exception {
        return 1;
    }
    return 1;
}


def page_href(n: int) -> str {
    return "/blog" if n == 1 else f"/blog?page={n}";
}


def build_page_tokens(current: int, total_pages: int) -> list {
    # Returns a windowed list of token dicts. kind "page" carries a number;
    # kind "gap" is an ellipsis. Always shows first, last, current ± 1.
    nums: list = [];
    if total_pages <= 7 {
        nums = [n for n in range(1, total_pages + 1)];
    } else {
        nums = [1];
        lo = max(2, current - 1);
        hi = min(total_pages - 1, current + 1);
        if lo > 2 {
            nums.append(-1);
        }
        for n in range(lo, hi + 1) {
            nums.append(n);
        }
        if hi < total_pages - 1 {
            nums.append(-1);
        }
        nums.append(total_pages);
    }
    tokens: list = [];
    # NOTE: avoid `for (i, n) in enumerate(...)` here — jac-client's browser
    # codegen mishandles the tuple-unpack (emits an undefined `n`, crashing the
    # page). A plain loop + counter compiles correctly across versions.
    idx: int = 0;
    for n in nums {
        if n == -1 {
            tokens.append({"kind": "gap", "n": 0, "key": f"gap{idx}"});
        } else {
            tokens.append({"kind": "page", "n": n, "key": f"page{n}"});
        }
        idx = idx + 1;
    }
    return tokens;
}


def:pub page() -> JsxElement {
    loc: any = useLocation();
    current_page: int = read_page_from_search(str(loc["search"]));

    has loading: bool = True;
    has posts: any = [];
    has total: int = 0;
    has has_next: bool = False;
    has error: str = "";

    async can with [current_page] entry {
        window.scrollTo(0, 0);
        loading = True;
        error = "";
        start: int = int(Date.now());
        try {
            result = root spawn GetPosts(page=current_page, per_page=PER_PAGE);
            if result.reports and len(result.reports) > 0 {
                data = result.reports[0];
                if data["ok"] {
                    posts = data["posts"];
                    total = int(data["total"]);
                    has_next = bool(data["has_next"]);
                } else {
                    error = "Could not load posts.";
                }
            }
        } except Exception {
            error = "Network error.";
        }
        min_ms: int = 750;
        try {
            min_ms = int(window.__BLOG_CONFIG["minLoadingMs"]);
        } except Exception {
            _ignore = None;
        }
        remaining: int = min_ms - (int(Date.now()) - start);
        if remaining > 0 {
            setTimeout(lambda -> None { loading = False; }, remaining);
        } else {
            loading = False;
        }
    }

    if loading {
        return <>
            <div className="route-progress" />
            <section className="post-stream stream-top">
                <div className="container narrow">
                    <span className="skeleton skeleton-line short" style={{"margin": "0 0 1.5rem"}} />
                    {[
                        <div key={i} className="stream-skeleton-item">
                            <span className="skeleton skeleton-line short" />
                            <span className="skeleton skeleton-title" />
                            <div className="stream-skeleton-byline">
                                <span className="skeleton skeleton-avatar round" />
                                <span className="skeleton skeleton-line short" />
                            </div>
                            <span className="skeleton skeleton-line full" />
                            <span className="skeleton skeleton-line long" />
                            <span className="skeleton skeleton-line medium" />
                        </div>
                        for i in range(3)
                    ]}
                </div>
            </section>
        </>;
    }
    if error {
        return <section className="container"><p>{error}</p></section>;
    }

    total_pages: int = max(1, (total + PER_PAGE - 1) // PER_PAGE);
    page_tokens: list = build_page_tokens(current_page, total_pages);

    return <>
        <section className="post-stream stream-top">
            <div className="container narrow">
                <p className="eyebrow stream-section-label">Latest posts</p>
                <ul className="stream-list">
                {[
                    <li key={p["slug"]} className="stream-item">
                        <article className="stream-article">
                            <div className="stream-body">
                                {(p["categories"] or p["is_repost"]) and (
                                    <p className="eyebrow stream-eyebrow">
                                        {p["categories"] and (
                                            <Link to={f"/blog/categories/{p['categories'][0]}"}>{p["categories"][0]}</Link>
                                        )}
                                        {p["is_repost"] and (
                                            <span className="repost-badge">↗ Repost</span>
                                        )}
                                    </p>
                                )}
                                <h2 className="stream-title">
                                    <Link to={f"/blog/posts/{p['slug']}"}>{p["title"]}</Link>
                                </h2>
                                <div className="stream-byline">
                                    {p["authors"] and (
                                        <Link
                                            to={f"/blog/authors/{p['authors'][0]['id']}"}
                                            className="byline-author small"
                                        >
                                            {p["authors"][0]["avatar"] and (
                                                <img
                                                    src={p["authors"][0]["avatar"]}
                                                    alt=""
                                                    width={22}
                                                    height={22}
                                                    className="byline-avatar"
                                                />
                                            )}
                                            <span>{p["authors"][0]["name"]}</span>
                                        </Link>
                                    )}
                                    <span className="muted small">{p["date_long"]} · {p["reading_minutes"]} min read</span>
                                </div>
                                <div className="stream-excerpt">
                                    <div
                                        className="excerpt-content"
                                        dangerouslySetInnerHTML={{"__html": p["excerpt_html"] or f"<p>{p['description']}</p>"}}
                                    />
                                    {p["peek_html"] and (
                                        <div
                                            className="post-peek"
                                            aria-hidden="true"
                                            dangerouslySetInnerHTML={{"__html": f'<div class="peek-content">{p["peek_html"]}</div>'}}
                                        />
                                    )}
                                    <nav className="post-action">
                                        <Link to={f"/blog/posts/{p['slug']}"}>Show more ▸</Link>
                                    </nav>
                                </div>
                            </div>
                            {p["cover"] and (
                                <Link to={f"/blog/posts/{p['slug']}"} className="stream-cover">
                                    <img src={p["cover"]} alt="" />
                                </Link>
                            )}
                        </article>
                    </li>
                    for p in posts
                ]}
                </ul>

                {total_pages > 1 and (
                    <nav className="pagination">
                        {current_page > 1 and (
                            <Link className="page-btn page-arrow" to={page_href(current_page - 1)}>←</Link>
                        ) or (
                            <span className="page-btn page-arrow page-disabled">←</span>
                        )}
                        {[
                            <Link
                                key={tok["key"]}
                                to={page_href(int(tok["n"]))}
                                className={("page-btn page-current" if int(tok["n"]) == current_page else "page-btn")}
                            >{tok["n"]}</Link>
                            for tok in page_tokens if tok["kind"] == "page"
                        ]}
                        {has_next and (
                            <Link className="page-btn page-arrow" to={page_href(current_page + 1)}>→</Link>
                        ) or (
                            <span className="page-btn page-arrow page-disabled">→</span>
                        )}
                    </nav>
                )}
            </div>
        </section>
    </>;
}
