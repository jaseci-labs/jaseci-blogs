"""Shareable draft preview entry (/preview/<token>).

Resolves the random token to its post slug, then redirects to the real post
page with ?preview=<token> — so the snapshot renders through the exact same
article view (runnable code blocks, mermaid, TOC, …) as a published post.
"""

sv import from ..main { GetPreview }

to cl:

import from "@jac/runtime" { useParams, useNavigate, Link }


def:pub page() -> JsxElement {
    params = useParams();
    token = str(params["token"]);
    nav = useNavigate();

    has error: str = "";

    async can with entry {
        window.scrollTo(0, 0);
        try {
            res = root spawn GetPreview(token=token);
            if res.reports and len(res.reports) > 0 {
                data = res.reports[0];
                if data["ok"] {
                    nav(f"/blog/posts/{data['slug']}?preview={token}", {"replace": True});
                    return;
                } else {
                    error = str(data["error"]);
                }
            } else {
                error = "Could not load this preview.";
            }
        } except Exception {
            error = "Could not load this preview.";
        }
    }

    return <section className="container narrow" style={{"padding": "4rem 0"}}>
        <p className="eyebrow">Draft preview</p>
        <h1 className="display">{error or "Loading preview…"}</h1>
        {error and (
            <p style={{"marginTop": "1.5rem"}}>
                <Link className="cta-pill" to="/blog">← Back to the blog</Link>
            </p>
        )}
    </section>;
}
