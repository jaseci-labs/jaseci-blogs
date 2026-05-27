sv import from ...main { GetArchive }

cl import from "@jac/runtime" { Link }


cl {
    def:pub page() -> JsxElement {
        has loading: bool = True;
        has years: any = [];
        has total: int = 0;

        can with entry {
            document.title = "Archive · Jaseci Blogs";
        }

        async can with entry {
            window.scrollTo(0, 0);
            start: int = int(Date.now());
            try {
                result = root spawn GetArchive();
                if result.reports and len(result.reports) > 0 {
                    data = result.reports[0];
                    if data["ok"] {
                        years = data["years"];
                        total = int(data["total"]);
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
                    <header style={{"padding": "3rem 0 1rem"}}>
                        <span className="skeleton skeleton-line short" />
                        <span className="skeleton skeleton-title" />
                        <span className="skeleton skeleton-line medium" />
                    </header>
                    <span className="skeleton" style={{"display": "block", "height": "3rem", "margin": "2rem 0 1rem", "width": "20%"}} />
                    {[
                        <div key={i} style={{"padding": "0.875rem 0", "borderBottom": "1px solid var(--rule)"}}>
                            <span className="skeleton skeleton-line long" />
                        </div>
                        for i in range(6)
                    ]}
                </section>
            </>;
        }

        return <section className="container narrow">
            <header style={{"padding": "3rem 0 1rem"}}>
                <p className="eyebrow">Archive</p>
                <h1 className="display">Every post.</h1>
                <p className="post-deck">{total} post{total == 1 and "" or "s"} in chronological order.</p>
            </header>

            <ul className="archive-list">
                {[
                    <li key={group["year"]}>
                        <h2 className="archive-year">{group["year"]}</h2>
                        <ul style={{"listStyle": "none", "padding": "0", "margin": "0"}}>
                            {[
                                <li key={p["slug"]}>
                                    <Link to={f"/posts/{p['slug']}"} className="archive-item">
                                        <span className="archive-date">{p["date_short"]}</span>
                                        <span className="archive-title">{p["title"]}</span>
                                    </Link>
                                </li>
                                for p in group["posts"]
                            ]}
                        </ul>
                    </li>
                    for group in years
                ]}
            </ul>
        </section>;
    }
}
