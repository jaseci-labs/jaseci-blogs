sv import from ...main { GetPosts }

cl import from "@jac/runtime" { useParams, Link }


cl {
    def:pub page() -> JsxElement {
        params = useParams();
        category = params["name"];

        has loading: bool = True;
        has posts: any = [];

        async can with [category] entry {
            window.scrollTo(0, 0);
            loading = True;
            posts = [];
            start: int = int(Date.now());
            try {
                result = root spawn GetPosts(page=1, per_page=50, category=str(category));
                if result.reports and len(result.reports) > 0 {
                    data = result.reports[0];
                    if data["ok"] {
                        posts = data["posts"];
                        document.title = f"{category} · Jaseci Blogs";
                    }
                }
            } except Exception {
                _ignore = None;
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
                <section className="container narrow">
                    <header style={{"padding": "3rem 0 2rem"}}>
                        <span className="skeleton skeleton-line short" />
                        <span className="skeleton skeleton-title" style={{"height": "3rem"}} />
                        <span className="skeleton skeleton-line medium" />
                    </header>
                    {[
                        <div key={i} className="stream-skeleton-item">
                            <span className="skeleton skeleton-title" />
                            <span className="skeleton skeleton-line long" />
                            <span className="skeleton skeleton-line medium" />
                        </div>
                        for i in range(3)
                    ]}
                </section>
            </>;
        }

        return <article>
            <header className="container narrow" style={{"padding": "3rem 0 2rem"}}>
                <p className="eyebrow"><Link to="/blog/categories">← All categories</Link></p>
                <h1 className="display">{category}</h1>
                <p className="post-deck">Posts tagged {category}.</p>
            </header>
            <section className="post-stream">
                <div className="container narrow">
                    {posts and (
                        <ul className="stream-list">
                            {[
                                <li key={p["slug"]} className="stream-item">
                                    <article className="stream-article">
                                        <div className="stream-body">
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
                    ) or <p className="muted">No posts in this category yet.</p>}
                </div>
            </section>
        </article>;
    }
}
