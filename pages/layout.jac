cl import "../styles/main.css";
cl import "../styles/typography.css";
cl import "../styles/prose.css";
cl import from "@jac/runtime" { Outlet, Link }


cl {
    def:pub layout() -> JsxElement {
        has theme: str = "light";

        can with entry {
            # Site-wide runtime config. Pages read from here so we have one
            # source of truth for tunables like the skeleton-show floor.
            window.__BLOG_CONFIG = {
                "minLoadingMs": 800,
            };

            # Resolve the effective theme: saved → system pref → light.
            resolved: str = "light";
            try {
                saved = window.localStorage.getItem("jaseci-blog-theme");
                if saved == "dark" or saved == "light" {
                    resolved = str(saved);
                } else {
                    prefers_dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
                    resolved = "dark" if prefers_dark else "light";
                }
            } except Exception {
                _ignore = None;
            }
            # Apply to DOM first (instant visual), then state (for label/icon).
            try {
                document.documentElement.setAttribute("data-theme", resolved);
            } except Exception {
                _ignore = None;
            }
            theme = resolved;
        }

        return <>
            <a className="skip-link" href="#main">Skip to content</a>

            <header className="site-header">
                <div className="container header-inner">
                    <a href="https://www.jaseci.org" className="brand" aria-label="Jaseci.org" rel="noopener">
                        <img src="/logo.png" alt="" width={32} height={32} className="brand-logo" />
                        <span className="brand-text">
                            <span className="brand-mark">Jaseci</span>
                            <span className="brand-sub">Blogs</span>
                        </span>
                    </a>

                    <nav className="primary-nav" aria-label="Primary">
                        <Link to="/">Latest</Link>
                        <Link to="/archive">Archive</Link>
                        <Link to="/categories">Categories</Link>
                        <a href="https://newsletter.jaseci.org" target="_blank" rel="noopener">Newsletter</a>
                    </nav>

                    <div className="header-actions">
                        <Link to="/search" className="icon-btn" aria-label="Search">
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                <circle cx="11" cy="11" r="7" />
                                <line x1="21" y1="21" x2="16.65" y2="16.65" />
                            </svg>
                        </Link>
                        <button
                            type="button"
                            className="icon-btn theme-toggle"
                            onClick={lambda -> None {
                                next_theme = "dark" if theme == "light" else "light";
                                try {
                                    document.documentElement.setAttribute("data-theme", next_theme);
                                    window.localStorage.setItem("jaseci-blog-theme", next_theme);
                                } except Exception {
                                    _ignore = None;
                                }
                                theme = next_theme;
                            }}
                            aria-label={theme == "dark" and "Switch to light theme" or "Switch to dark theme"}
                        >
                            {theme == "dark" and (
                                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <circle cx="12" cy="12" r="5" />
                                    <line x1="12" y1="1" x2="12" y2="3" />
                                    <line x1="12" y1="21" x2="12" y2="23" />
                                    <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
                                    <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
                                    <line x1="1" y1="12" x2="3" y2="12" />
                                    <line x1="21" y1="12" x2="23" y2="12" />
                                    <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
                                    <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
                                </svg>
                            ) or (
                                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                                    <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
                                </svg>
                            )}
                        </button>
                    </div>
                </div>
            </header>

            <main id="main" className="site-main">
                <Outlet />
            </main>

            <footer className="site-footer">
                <div className="container footer-grid">
                    <div className="footer-brand">
                        <img src="/logo.png" alt="" width={40} height={40} />
                        <div>
                            <p className="footer-title">Jaseci Blogs</p>
                            <p className="footer-tagline muted">Engineering writing from the Jaseci & Jac open-source ecosystem.</p>
                        </div>
                    </div>
                    <nav className="footer-nav" aria-label="Footer">
                        <div>
                            <p className="eyebrow">Read</p>
                            <Link to="/">Latest posts</Link>
                            <Link to="/archive">Archive</Link>
                            <Link to="/categories">Categories</Link>
                        </div>
                        <div>
                            <p className="eyebrow">Jaseci</p>
                            <a href="https://www.jaseci.org" target="_blank" rel="noopener">Jaseci.org</a>
                            <a href="https://newsletter.jaseci.org" target="_blank" rel="noopener">Newsletter</a>
                            <a href="https://github.com/jaseci-labs" target="_blank" rel="noopener">GitHub</a>
                            <a href="https://discord.gg/jaseci" target="_blank" rel="noopener">Discord</a>
                        </div>
                    </nav>
                </div>
                <div className="container footer-bottom">
                    <p className="muted small">© 2026 Jaseci Labs. Part of the Jaseci open-source ecosystem.</p>
                </div>
            </footer>
        </>;
    }
}
