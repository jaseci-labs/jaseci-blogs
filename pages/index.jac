sv import from ..main { GetPosts }

to cl:

import from "@jac/runtime" { Link }


def:pub page() -> JsxElement {
    has loading: bool = True;
    has posts: any = [];
    has has_next: bool = False;
    has error: str = "";

    async can with entry {
        window.scrollTo(0, 0);
        start: int = int(Date.now());
        try {
            result = root spawn GetPosts(page=1, per_page=12);
            if result.reports and len(result.reports) > 0 {
                data = result.reports[0];
                if data["ok"] {
                    posts = data["posts"];
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
            <section className="landing-hero">
                <div className="container narrow">
                    <p className="eyebrow">Jaseci Blogs</p>
                    <h1 className="display">Engineering writing<br />from the Jaseci ecosystem.</h1>
                    <p className="post-deck">
                        Deep dives, language design notes, and field reports from the people
                        building Jac and Jaseci.
                    </p>
                </div>
            </section>
            <section className="post-stream">
                <div className="container narrow">
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

    featured: any = posts[0] if posts else None;
    rest: any = posts[1:] if posts else [];

    return <>
        {featured and (
            <section className="featured-block">
                <div className="container narrow">
                    <div className="featured-tag-row">
                        <span className="featured-pill">★ Featured</span>
                        {featured["categories"] and (
                            <span className="featured-category">
                                <Link to={f"/categories/{featured['categories'][0]}"}>{featured["categories"][0]}</Link>
                            </span>
                        )}
                    </div>
                    {featured["cover"] and (
                        <Link to={f"/posts/{featured['slug']}"} className="featured-cover-banner">
                            <img src={featured["cover"]} alt="" />
                        </Link>
                    )}
                    <h1 className="featured-title">
                        <Link to={f"/posts/{featured['slug']}"}>{featured["title"]}</Link>
                    </h1>
                    {featured["description"] and (
                        <p className="featured-deck">{featured["description"]}</p>
                    )}
                    <div className="stream-byline featured-byline">
                        {featured["authors"] and (
                            <Link
                                to={f"/authors/{featured['authors'][0]['id']}"}
                                className="byline-author"
                            >
                                {featured["authors"][0]["avatar"] and (
                                    <img
                                        src={featured["authors"][0]["avatar"]}
                                        alt=""
                                        width={28}
                                        height={28}
                                        className="byline-avatar"
                                    />
                                )}
                                <span>{featured["authors"][0]["name"]}</span>
                            </Link>
                        )}
                        <span className="muted small">{featured["date_long"]} · {featured["reading_minutes"]} min read</span>
                    </div>
                    <div className="stream-excerpt">
                        <div
                            className="excerpt-content"
                            dangerouslySetInnerHTML={{"__html": featured["excerpt_html"] or f"<p>{featured['description']}</p>"}}
                        />
                        {featured["peek_html"] and (
                            <div
                                className="post-peek"
                                aria-hidden="true"
                                dangerouslySetInnerHTML={{"__html": f'<div class="peek-content">{featured["peek_html"]}</div>'}}
                            />
                        )}
                        <nav className="post-action">
                            <Link to={f"/posts/{featured['slug']}"}>Show more ▸</Link>
                        </nav>
                    </div>
                </div>
            </section>
        )}

        {rest and (
            <section className="post-stream">
                <div className="container narrow">
                    <p className="eyebrow stream-section-label">More posts</p>
                    <ul className="stream-list">
                    {[
                        <li key={p["slug"]} className="stream-item">
                            <article className="stream-article">
                                <div className="stream-body">
                                    {p["categories"] and (
                                        <p className="eyebrow">
                                            <Link to={f"/categories/{p['categories'][0]}"}>{p["categories"][0]}</Link>
                                        </p>
                                    )}
                                    <h2 className="stream-title">
                                        <Link to={f"/posts/{p['slug']}"}>{p["title"]}</Link>
                                    </h2>
                                    <div className="stream-byline">
                                        {p["authors"] and (
                                            <Link
                                                to={f"/authors/{p['authors'][0]['id']}"}
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
                                            <Link to={f"/posts/{p['slug']}"}>Show more ▸</Link>
                                        </nav>
                                    </div>
                                </div>
                                {p["cover"] and (
                                    <Link to={f"/posts/{p['slug']}"} className="stream-cover">
                                        <img src={p["cover"]} alt="" />
                                    </Link>
                                )}
                            </article>
                        </li>
                        for p in rest
                    ]}
                </ul>

                {has_next and (
                    <p className="stream-more">
                        <Link to="/archive" className="cta-pill">See the archive →</Link>
                    </p>
                )}
                </div>
            </section>
        )}
    </>;
}
