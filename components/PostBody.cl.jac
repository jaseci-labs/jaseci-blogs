"""PostBody — renders post HTML and progressively enhances code blocks.

The server emits HTML via python-markdown. After mount we walk the DOM and:
  - Add a copy button + language label to <pre><code class="language-x"> blocks
  - Add a collapse toggle for code blocks > 14 lines
  - Render Mermaid diagrams in code blocks tagged .language-mermaid
  - Upgrade <div class="code-block"> wrappers into <RunnableJacBlock> via dynamic mount

External libraries (Mermaid, Monaco, Pyodide) are loaded lazily — only when
the page actually contains a block that needs them.
"""

import from react { useRef }
import from "./RunnableJacBlock.cl.jac" { register_upgrade_hook }


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

            try {
                await mount_runnable_blocks(container);
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


    def enhance_code_blocks(container: any) -> None {
        # Add copy button + language tag + collapse toggle to every <pre><code>.
        blocks = container.querySelectorAll("pre > code");
        for code_el in blocks {
            pre = code_el.parentElement;
            if pre.dataset.enhanced {
                continue;
            }
            pre.dataset.enhanced = "true";

            # Extract language from class="language-foo" or class="highlight foo"
            lang = "";
            classes = code_el.className.split(" ");
            for cls in classes {
                if cls.startswith("language-") {
                    lang = cls[len("language-"):];
                    break;
                }
            }
            if lang == "mermaid" {
                # Skip — handled by render_mermaid_blocks.
                continue;
            }

            # Wrap pre in a figure-like shell to host chrome.
            shell = document.createElement("div");
            shell.className = "code-shell";
            pre.parentNode.insertBefore(shell, pre);
            shell.appendChild(pre);

            # Header row: language label + copy button.
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

            # Collapse if > 14 lines.
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
        targets = container.querySelectorAll("code.language-mermaid");
        has_any = False;
        for _t in targets {
            has_any = True;
            break;
        }
        if not has_any {
            return;
        }
        # Lazy-load mermaid.
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
        for (i, code_el) in enumerate(targets) {
            pre = code_el.parentElement;
            wrapper = document.createElement("div");
            wrapper.className = "mermaid-block";
            wrapper.id = f"mermaid-{Date.now()}-{i}";
            wrapper.textContent = code_el.textContent;
            pre.parentNode.replaceChild(wrapper, pre);
        }
        try {
            await window.mermaid.run({"querySelector": ".mermaid-block"});
        } except Exception {
            _ignore = None;
        }
    }


    async def mount_runnable_blocks(container: any) -> None {
        # Ensure the upgrade hook is registered before we look for blocks.
        register_upgrade_hook();
        blocks = container.querySelectorAll("div.code-block");
        has_blocks = False;
        for _b in blocks {
            has_blocks = True;
            break;
        }
        if not has_blocks {
            return;
        }
        # Lazy-load the runnable bundle.
        if not window.__jac_runnable_loaded {
            await Promise.all([
                load_script("https://cdn.jsdelivr.net/pyodide/v0.27.0/full/pyodide.js"),
                load_script("https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs/loader.min.js"),
            ]);
            window.__jac_runnable_loaded = True;
        }
        # The actual upgrade is handled by the imperative JS exposed at
        # window.__jac_runnable_upgrade — wired up by RunnableJacBlock module.
        if window.__jac_runnable_upgrade {
            window.__jac_runnable_upgrade(blocks);
        }
    }


    async def load_script(src: str) -> None {
        existing = document.querySelector(f"script[src='{src}']");
        if existing {
            return;
        }
        promise = Promise(lambda resolve, reject -> None {
            script = document.createElement("script");
            script.src = src;
            script.onload = lambda -> None { resolve(None); };
            script.onerror = lambda -> None { reject(None); };
            document.head.appendChild(script);
        });
        await promise;
    }
