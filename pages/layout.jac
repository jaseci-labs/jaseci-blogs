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

            # Resolve the effective theme: saved → light. Light is the default
            # (more readable); system dark-mode preference is intentionally not
            # honored, so readers only get dark if they explicitly toggle it.
            resolved: str = "light";
            try {
                saved = window.localStorage.getItem("jaseci-blog-theme");
                if saved == "dark" or saved == "light" {
                    resolved = str(saved);
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
                    <Link to="/blog" className="brand">
                        <img src="https://www.jaseci.org/images/logo.png" alt="Jaseci" width={32} height={32} className="brand-logo" />
                        <span className="brand-text">
                            <span className="brand-mark">Jaseci</span>
                            <span className="brand-sub">Blogs</span>
                        </span>
                    </Link>

                    <nav className="primary-nav" aria-label="Primary">
                        <Link to="/blog">Latest</Link>
                        <Link to="/blog/archive">Archive</Link>
                        <Link to="/blog/categories">Categories</Link>
                        <a href="https://newsletter.jaseci.org" target="_blank" rel="noopener">Newsletter</a>
                        <a href="https://www.jaseci.org" target="_blank" rel="noopener" className="nav-jaseci">Jaseci.org</a>
                    </nav>

                    <div className="header-actions">
                        <Link to="/blog/search" className="icon-btn" aria-label="Search">
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
                        <img src="https://www.jaseci.org/images/logo.png" alt="" width={40} height={40} />
                        <div>
                            <p className="footer-title">
                                <span className="brand-mark">Jaseci</span>
                                <span className="brand-sub">Blogs</span>
                            </p>
                            <p className="footer-tagline muted">Engineering writing from the Jaseci & Jac open-source ecosystem.</p>
                        </div>
                    </div>
                    <nav className="footer-nav" aria-label="Footer">
                        <div>
                            <p className="eyebrow">Read</p>
                            <Link to="/blog">Latest posts</Link>
                            <Link to="/blog/archive">Archive</Link>
                            <Link to="/blog/categories">Categories</Link>
                        </div>
                        <div>
                            <p className="eyebrow">Jaseci</p>
                            <a href="https://www.jaseci.org" target="_blank" rel="noopener">Jaseci.org</a>
                            <a href="https://newsletter.jaseci.org" target="_blank" rel="noopener">Newsletter</a>
                            <a className="footer-social" href="https://github.com/jaseci-labs/jaseci" target="_blank" rel="noopener">
                                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23A11.509 11.509 0 0112 5.803c1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222 0 1.606-.014 2.898-.014 3.293 0 .322.216.694.825.576C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>
                                <span>GitHub</span>
                            </a>
                            <a className="footer-social" href="https://x.com/Jaseci_Labs" target="_blank" rel="noopener">
                                <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
                                <span>X</span>
                            </a>
                            <a className="footer-social" href="https://discord.com/invite/6j3QNdtcN6" target="_blank" rel="noopener">
                                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M20.317 4.3698a19.7913 19.7913 0 00-4.8851-1.5152.0741.0741 0 00-.0785.0371c-.211.3753-.4447.8648-.6083 1.2495-1.8447-.2762-3.68-.2762-5.4868 0-.1636-.3933-.4058-.8742-.6177-1.2495a.077.077 0 00-.0785-.037 19.7363 19.7363 0 00-4.8852 1.515.0699.0699 0 00-.0321.0277C.5334 9.0458-.319 13.5799.0992 18.0578a.0824.0824 0 00.0312.0561c2.0528 1.5076 4.0413 2.4228 5.9929 3.0294a.0777.0777 0 00.0842-.0276c.4616-.6304.8731-1.2952 1.226-1.9942a.076.076 0 00-.0416-.1057c-.6528-.2476-1.2743-.5495-1.8722-.8923a.077.077 0 01-.0076-.1277c.1258-.0943.2517-.1923.3718-.2914a.0743.0743 0 01.0776-.0105c3.9278 1.7933 8.18 1.7933 12.0614 0a.0739.0739 0 01.0785.0095c.1202.099.246.1981.3728.2924a.077.077 0 01-.0066.1276 12.2986 12.2986 0 01-1.873.8914.0766.0766 0 00-.0407.1067c.3604.698.7719 1.3628 1.225 1.9932a.076.076 0 00.0842.0286c1.961-.6067 3.9495-1.5219 6.0023-3.0294a.077.077 0 00.0313-.0552c.5004-5.177-.8382-9.6739-3.5485-13.6604a.061.061 0 00-.0312-.0286zM8.02 15.3312c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9555-2.4189 2.157-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.9555 2.4189-2.1569 2.4189zm7.9748 0c-1.1825 0-2.1569-1.0857-2.1569-2.419 0-1.3332.9554-2.4189 2.1569-2.4189 1.2108 0 2.1757 1.0952 2.1568 2.419 0 1.3332-.946 2.4189-2.1568 2.4189Z"/></svg>
                                <span>Discord</span>
                            </a>
                        </div>
                    </nav>
                </div>
                <div className="container footer-bottom">
                    <p className="muted small">© 2026 Jaseci Labs. Part of the Jaseci open-source ecosystem.</p>
                    <a
                        className="built-with-jaseci"
                        href="https://www.jaseci.org"
                        target="_blank"
                        rel="noopener noreferrer"
                    >
                        <span>Built with</span>
                        <img
                            src="https://www.jaseci.org/images/logo.png"
                            alt="Jaseci logo"
                            className="built-with-jaseci-logo"
                        />
                        <span className="built-with-jaseci-wordmark">JASECI</span>
                    </a>
                </div>
            </footer>
        </>;
    }
}
