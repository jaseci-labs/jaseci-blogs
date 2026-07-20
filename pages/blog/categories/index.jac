sv import from ...main { GetCategories }

cl import from "@jac/runtime" { Link }


cl {
    def:pub page() -> JsxElement {
        has loading: bool = True;
        has categories: any = [];

        can with entry {
            document.title = "Categories · Jaseci Blogs";
        }

        async can with entry {
            window.scrollTo(0, 0);
            start: int = int(Date.now());
            try {
                result = root spawn GetCategories();
                if result.reports and len(result.reports) > 0 {
                    data = result.reports[0];
                    if data["ok"] {
                        categories = data["categories"];
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
                <section className="container">
                    <header style={{"padding": "3rem 0 1rem"}}>
                        <span className="skeleton skeleton-line short" />
                        <span className="skeleton skeleton-title" />
                    </header>
                    <ul className="category-grid">
                        {[
                            <li key={i}><span className="skeleton" style={{"display": "block", "height": "5rem", "borderRadius": "10px"}} /></li>
                            for i in range(6)
                        ]}
                    </ul>
                </section>
            </>;
        }

        return <section className="container">
            <header style={{"padding": "3rem 0 1rem"}}>
                <p className="eyebrow">Browse</p>
                <h1 className="display">Categories</h1>
            </header>
            <ul className="category-grid">
                {[
                    <li key={c["name"]}>
                        <Link to={f"/blog/categories/{c['name']}"} className="category-tile">
                            <p className="category-name">{c["name"]}</p>
                            <p className="category-count">{c["count"]} post{c["count"] == 1 and "" or "s"}</p>
                        </Link>
                    </li>
                    for c in categories
                ]}
            </ul>
        </section>;
    }
}
