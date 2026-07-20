cl import from "@jac/runtime" { Link }


cl {
    def:pub page() -> JsxElement {
        can with entry {
            document.title = "Not found · Jaseci Blogs";
        }
        return <section className="container narrow" style={{"padding": "6rem 0"}}>
            <p className="eyebrow">404</p>
            <h1 className="display">Lost your way?</h1>
            <p className="post-deck">The page you're looking for doesn't exist. It may have been retired, renamed, or never published.</p>
            <p style={{"marginTop": "2rem"}}>
                <Link className="cta-pill" to="/blog">← Back to latest</Link>
            </p>
        </section>;
    }
}
