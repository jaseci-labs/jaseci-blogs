"""Single post page.

Renders the post HTML emitted by GetPost, then progressively enhances code
blocks (copy button + collapse for long blocks) and Mermaid diagrams. The
runnable Jac editor is loaded lazily via the global hook installed below;
the actual Monaco + Pyodide bundle is wired up in main.jac's app() entry.

NOTE on file shape: PostBody started as a separate .cl.jac component, but
the current Jac compiler emits literal source paths into JS imports, which
vite can't resolve. Inlining the enhancements keeps the build green.
"""

sv import from ...main { GetPost }

to cl:

import from "@jac/runtime" { useParams, Link }
import from react { useRef }


async def load_script(src: str) -> None {
    existing = document.querySelector(f"script[src='{src}']");
    if existing {
        return;
    }
    promise = Promise(lambda resolve: any, reject: any -> None {
        script = document.createElement("script");
        script.src = src;
        script.onload = lambda -> None { resolve(None); };
        script.onerror = lambda -> None { reject(None); };
        document.head.appendChild(script);
    });
    await promise;
}


def enhance_code_blocks(container: any) -> None {
    blocks = container.querySelectorAll("pre > code");
    for code_el in blocks {
        pre = code_el.parentElement;
        if pre.dataset.enhanced {
            continue;
        }
        pre.dataset.enhanced = "true";

        lang = "";
        classes = code_el.className.split(" ");
        for raw_cls in classes {
            cls: str = str(raw_cls);
            if cls.startswith("language-") {
                lang = cls[len("language-"):];
                break;
            }
        }
        if lang == "mermaid" {
            continue;
        }

        shell = document.createElement("div");
        shell.className = "code-shell";
        pre.parentNode.insertBefore(shell, pre);
        shell.appendChild(pre);

        header = document.createElement("div");
        header.className = "code-shell-header";
        if lang {
            tag = document.createElement("span");
            tag.className = "code-lang";
            tag.textContent = lang;
            header.appendChild(tag);
        }
        copy_btn = document.createElement("button");
        copy_btn.type = "button";
        copy_btn.className = "code-copy";
        copy_btn.textContent = "Copy";
        copy_btn.addEventListener("click", lambda -> None {
            try {
                navigator.clipboard.writeText(code_el.textContent);
                copy_btn.textContent = "Copied";
                setTimeout(lambda -> None { copy_btn.textContent = "Copy"; }, 1500);
            } except Exception {
                _ignore = None;
            }
        });
        header.appendChild(copy_btn);
        shell.insertBefore(header, pre);

        line_count = len(code_el.textContent.split("\n"));
        if line_count > 14 {
            shell.classList.add("code-shell-collapsible");
            shell.classList.add("code-shell-collapsed");
            toggle = document.createElement("button");
            toggle.type = "button";
            toggle.className = "code-shell-toggle";
            toggle.textContent = f"Show all {line_count} lines";
            toggle.addEventListener("click", lambda -> None {
                is_collapsed = shell.classList.contains("code-shell-collapsed");
                if is_collapsed {
                    shell.classList.remove("code-shell-collapsed");
                    toggle.textContent = "Collapse";
                } else {
                    shell.classList.add("code-shell-collapsed");
                    toggle.textContent = f"Show all {line_count} lines";
                }
            });
            shell.appendChild(toggle);
        }
    }
}


async def render_mermaid_blocks(container: any) -> None {
    # Server already emits <div class="mermaid-block">SOURCE</div> for each
    # ```mermaid fence. We just need to call mermaid.run on them. The
    # data-processed attribute prevents double-rendering on re-mount.
    targets = container.querySelectorAll(".mermaid-block:not([data-processed])");
    has_any = False;
    for _t in targets {
        has_any = True;
        break;
    }
    if not has_any {
        return;
    }
    if not window.mermaid {
        await load_script("https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js");
        try {
            theme = document.documentElement.getAttribute("data-theme") or "light";
            window.mermaid.initialize({
                "startOnLoad": False,
                "theme": "dark" if theme == "dark" else "default",
                "fontFamily": "Inter, system-ui, sans-serif",
            });
        } except Exception {
            _ignore = None;
        }
    }
    try {
        await window.mermaid.run({"querySelector": ".mermaid-block:not([data-processed])"});
        for t in targets {
            t.setAttribute("data-processed", "true");
        }
    } except Exception {
        _ignore = None;
    }
}


def:pub PostBody(html: str) -> JsxElement {
    ref = useRef(None);
    has html_version: int = 0;

    can with [html] entry {
        html_version = html_version + 1;
    }

    async can with [html_version] entry {
        if not ref.current {
            return;
        }
        container = ref.current;
        try {
            enhance_code_blocks(container);
        } except Exception {
            _ignore = None;
        }
        try {
            await render_mermaid_blocks(container);
        } except Exception {
            _ignore = None;
        }
    }

    return <div
        ref={ref}
        className="prose"
        dangerouslySetInnerHTML={{"__html": html}}
    />;
}


def:pub page() -> JsxElement {
    params = useParams();
    slug = params["slug"];

    has loading: bool = True;
    has post: any = None;
    has error: str = "";

    async can with [slug] entry {
        window.scrollTo(0, 0);
        loading = True;
        error = "";
        post = None;
        start: int = int(Date.now());
        try {
            result = root spawn GetPost(slug=str(slug));
            if result.reports and len(result.reports) > 0 {
                data = result.reports[0];
                if data["ok"] {
                    post = data;
                    document.title = f"{data['title']} · Jaseci Blogs";
                } else {
                    error = str(data["error"]);
                }
            } else {
                error = "No response from server.";
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
            <article className="post-shell">
                <header className="post-header">
                    <div className="container narrow">
                        <span className="skeleton skeleton-line short" />
                        <span className="skeleton skeleton-title" style={{"height": "3.5rem", "width": "95%"}} />
                        <span className="skeleton skeleton-line long" />
                        <span className="skeleton skeleton-line medium" />
                        <div className="post-byline" style={{"borderColor": "var(--rule)"}}>
                            <span className="skeleton skeleton-avatar round" />
                            <span className="skeleton skeleton-line short" />
                        </div>
                    </div>
                </header>
                <div className="container narrow">
                    <span className="skeleton skeleton-line full" />
                    <span className="skeleton skeleton-line full" />
                    <span className="skeleton skeleton-line long" />
                    <span className="skeleton skeleton-line medium" />
                    <span className="skeleton skeleton-block" />
                    <span className="skeleton skeleton-line full" />
                    <span className="skeleton skeleton-line full" />
                    <span className="skeleton skeleton-line long" />
                </div>
            </article>
        </>;
    }
    if error {
        return <article className="post-shell">
            <div className="container narrow">
                <p className="eyebrow">Couldn't load this post</p>
                <h1 className="display">{error}</h1>
                <p><Link className="cta-pill" to="/">← Back to latest</Link></p>
            </div>
        </article>;
    }

    cats: any = post["categories"] or [];
    primary_category: any = cats[0] if cats else "";
    related: any = post["related"] or [];

    return <article className="post-shell">
        <header className="post-header">
            <div className="container narrow">
                {primary_category and (
                    <p className="eyebrow">
                        <Link to={f"/categories/{primary_category}"}>{primary_category}</Link>
                    </p>
                )}
                <h1 className="post-title">{post["title"]}</h1>
                {post["description"] and (
                    <p className="post-deck">{post["description"]}</p>
                )}
                <div className="post-byline">
                    <div className="byline-authors">
                        {[
                            <Link
                                key={author["id"]}
                                to={f"/authors/{author['id']}"}
                                className="byline-author"
                            >
                                {author["avatar"] and (
                                    <img
                                        src={author["avatar"]}
                                        alt=""
                                        width={28}
                                        height={28}
                                        className="byline-avatar"
                                    />
                                )}
                                <span>{author["name"]}</span>
                            </Link>
                            for author in post["authors"]
                        ]}
                    </div>
                    <div className="byline-meta muted">
                        <span>{post["date_long"]}</span>
                        <span className="dot">·</span>
                        <span>{post["reading_minutes"]} min read</span>
                    </div>
                </div>
            </div>
        </header>

        {post["cover"] and (
            <figure className="post-cover">
                <img src={post["cover"]} alt="" />
            </figure>
        )}

        <div className="container narrow">
            <PostBody html={post["html"]} />
        </div>

        {cats and (
            <div className="container narrow">
                <ul className="tag-row">
                    {[
                        <li key={cat}>
                            <Link to={f"/categories/{cat}"} className="tag">{cat}</Link>
                        </li>
                        for cat in cats
                    ]}
                </ul>
            </div>
        )}

        <div className="container narrow">
            <hr className="post-rule" />
            <nav className="post-nav" aria-label="Adjacent posts">
                {post["prev"] and (
                    <Link to={f"/posts/{post['prev']['slug']}"} className="post-nav-link prev">
                        <span className="eyebrow">← Previous</span>
                        <span className="post-nav-title">{post["prev"]["title"]}</span>
                    </Link>
                ) or <span />}
                {post["next"] and (
                    <Link to={f"/posts/{post['next']['slug']}"} className="post-nav-link next">
                        <span className="eyebrow">Next →</span>
                        <span className="post-nav-title">{post["next"]["title"]}</span>
                    </Link>
                ) or <span />}
            </nav>
        </div>

        {related and (
            <section className="post-related">
                <div className="container">
                    <p className="eyebrow">Related reading</p>
                    <ul className="related-grid">
                        {[
                            <li key={rel["slug"]} className="related-card">
                                <Link to={f"/posts/{rel['slug']}"}>
                                    <p className="related-title">{rel["title"]}</p>
                                    <p className="muted small">{rel["date_short"]} · {rel["reading_minutes"]} min</p>
                                </Link>
                            </li>
                            for rel in related
                        ]}
                    </ul>
                </div>
            </section>
        )}
    </article>;
}
