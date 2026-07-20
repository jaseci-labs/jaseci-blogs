sv import from ...main { GetAuthor }

cl import from "@jac/runtime" { useParams, Link }


cl {
    def:pub page() -> JsxElement {
        params = useParams();
        author_id = params["id"];

        has loading: bool = True;
        has author: any = None;
        has error: str = "";

        async can with [author_id] entry {
            window.scrollTo(0, 0);
            loading = True;
            error = "";
            author = None;
            start: int = int(Date.now());
            try {
                result = root spawn GetAuthor(id=str(author_id));
                if result.reports and len(result.reports) > 0 {
                    data = result.reports[0];
                    if data["ok"] {
                        author = data;
                        document.title = f"{data['name']} · Jaseci Blogs";
                    } else {
                        error = str(data["error"]);
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
                <section className="container narrow">
                    <div className="author-header">
                        <span className="skeleton round" style={{"width": "80px", "height": "80px"}} />
                        <div style={{"flex": "1"}}>
                            <span className="skeleton skeleton-line short" />
                            <span className="skeleton skeleton-title" style={{"height": "2.5rem"}} />
                            <span className="skeleton skeleton-line long" />
                        </div>
                    </div>
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
        if error {
            return <section className="container">
                <p className="eyebrow">Author not found</p>
                <h1 className="display">{error}</h1>
                <p><Link className="cta-pill" to="/blog">← Back to latest</Link></p>
            </section>;
        }

        posts: any = author["posts"] or [];

        return <article>
            <header className="container narrow">
                <div className="author-header">
                    {author["avatar"] and (
                        <img src={author["avatar"]} alt="" className="author-avatar" />
                    )}
                    <div>
                        <p className="eyebrow">Author</p>
                        <h1 className="author-name">{author["name"]}</h1>
                        {author["description"] and (
                            <p className="author-bio">{author["description"]}</p>
                        )}
                    </div>
                </div>
            </header>

            <section className="post-stream">
                <div className="container narrow">
                    <p className="eyebrow" style={{"marginBottom": "1rem"}}>Posts</p>
                    {posts and (
                        <ul className="stream-list">
                            {[
                                <li key={p["slug"]} className="stream-item">
                                    <article className="stream-article">
                                        <div className="stream-body">
                                            {p["categories"] and (
                                                <p className="eyebrow">
                                                    <Link to={f"/blog/categories/{p['categories'][0]}"}>{p["categories"][0]}</Link>
                                                </p>
                                            )}
                                            <h2 className="stream-title">
                                                <Link to={f"/blog/posts/{p['slug']}"}>{p["title"]}</Link>
                                            </h2>
                                            <div className="stream-byline">
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
                    ) or <p className="muted">No posts yet.</p>}
                </div>
            </section>
        </article>;
    }
}
