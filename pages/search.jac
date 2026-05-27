"""Client-side search.

Loads the full search index once on mount (one walker call), then filters
in-memory as the user types. Simple substring matching across title,
description, categories, authors, and body text. Highlights matches in
the snippet using <mark>.
"""

sv import from ..main { GetSearchIndex }

cl import from "@jac/runtime" { Link }


cl {
    def:pub page() -> JsxElement {
        has loading: bool = True;
        has documents: any = [];
        has query: str = "";

        can with entry {
            document.title = "Search · Jaseci Blogs";
        }

        async can with entry {
            window.scrollTo(0, 0);
            start: int = int(Date.now());
            try {
                result = root spawn GetSearchIndex();
                if result.reports and len(result.reports) > 0 {
                    data = result.reports[0];
                    if data["ok"] {
                        documents = data["documents"];
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

        def score_doc(doc: any, q: str) -> int {
            ql = q.lower();
            score = 0;
            if ql in str(doc["title"]).lower() {
                score = score + 10;
            }
            if ql in str(doc["description"]).lower() {
                score = score + 5;
            }
            for c in doc["categories"] {
                if ql in str(c).lower() {
                    score = score + 3;
                }
            }
            for a in doc["authors"] {
                if ql in str(a).lower() {
                    score = score + 2;
                }
            }
            if ql in str(doc["body"]).lower() {
                score = score + 1;
            }
            return score;
        }

        def snippet_for(doc: any, q: str) -> str {
            body = str(doc["body"]);
            ql = q.lower();
            idx = body.lower().find(ql);
            if idx < 0 {
                return body[:200] + ("…" if len(body) > 200 else "");
            }
            start = max(0, idx - 80);
            end = min(len(body), idx + len(q) + 120);
            prefix = "…" if start > 0 else "";
            suffix = "…" if end < len(body) else "";
            return prefix + body[start:end] + suffix;
        }

        def highlight(text: str, q: str) -> str {
            # Case-insensitive highlight without importing Python re — we run
            # in the browser. Walk the lowercase form to find match positions,
            # then slice the original text to preserve casing.
            if not q {
                return text;
            }
            lower_text = text.lower();
            lower_q = q.lower();
            qn = len(lower_q);
            if qn == 0 {
                return text;
            }
            out = "";
            i = 0;
            n = len(text);
            while i < n {
                hit = lower_text.find(lower_q, i);
                if hit < 0 {
                    out = out + text[i:];
                    break;
                }
                out = out + text[i:hit] + "<mark>" + text[hit:hit + qn] + "</mark>";
                i = hit + qn;
            }
            return out;
        }

        q = query.strip();
        results: any = [];
        if q and len(q) >= 2 {
            scored = [];
            for doc in documents {
                s = score_doc(doc, q);
                if s > 0 {
                    scored.append({"doc": doc, "score": s});
                }
            }
            # Manual descending sort by score (sort() overload resolution on
            # client lists is finicky — this stays portable).
            n = len(scored);
            for i in range(n) {
                for j in range(0, n - i - 1) {
                    if int(scored[j]["score"]) < int(scored[j + 1]["score"]) {
                        tmp = scored[j];
                        scored[j] = scored[j + 1];
                        scored[j + 1] = tmp;
                    }
                }
            }
            results = [item["doc"] for item in scored][:30];
        }

        return <section className="container narrow">
            <header style={{"padding": "3rem 0 1.5rem"}}>
                <p className="eyebrow">Search</p>
                <h1 className="display">Find a post.</h1>
            </header>

            <input
                type="search"
                className="search-input"
                placeholder="Search posts, authors, categories…"
                autoFocus
                value={query}
                onChange={lambda e: ChangeEvent { query = e.target.value; }}
            />

            {loading and <p className="muted" style={{"marginTop": "1.5rem"}}>Loading index…</p>}

            {not loading and q and len(q) >= 2 and (
                <p className="muted small" style={{"marginTop": "1.5rem"}}>
                    {len(results)} result{len(results) == 1 and "" or "s"} for "{q}"
                </p>
            )}

            <ul className="search-results">
                {[
                    <li key={r["slug"]} className="search-result">
                        <Link to={f"/posts/{r['slug']}"}>
                            <p
                                className="search-result-title"
                                dangerouslySetInnerHTML={{"__html": highlight(str(r["title"]), q)}}
                            />
                            <p className="muted small" style={{"marginTop": "0.25rem"}}>
                                {r["date_short"]}
                                {len(r["categories"]) > 0 and f" · {r['categories'][0]}"}
                            </p>
                            <p
                                className="search-snippet"
                                dangerouslySetInnerHTML={{"__html": highlight(snippet_for(r, q), q)}}
                            />
                        </Link>
                    </li>
                    for r in results
                ]}
            </ul>
        </section>;
    }
}
