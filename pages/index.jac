"""Root redirect: / -> /blog. Keeps the canonical app under /blog/."""

to cl:

import from "@jac/runtime" { useNavigate }


def:pub page() -> JsxElement {
    nav = useNavigate();

    can with entry {
        nav("/blog", {"replace": True});
    }

    return <section className="container narrow" style={{"padding": "4rem 0"}}>
        <p className="muted">Redirecting…</p>
    </section>;
}
