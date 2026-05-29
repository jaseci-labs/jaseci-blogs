"""Single post page.

Renders the post HTML emitted by GetPost, then progressively enhances code
blocks (copy button + collapse for long blocks) and Mermaid diagrams. The
runnable Jac editor is loaded lazily via the global hook installed below;
the actual Monaco + Pyodide bundle is wired up in main.jac's app() entry.

NOTE on file shape: PostBody started as a separate .cl.jac component, but
the current Jac compiler emits literal source paths into JS imports, which
vite can't resolve. Inlining the enhancements keeps the build green.
"""

sv import from ...main { GetPost, GetRuntimeZip }

to cl:

import from "@jac/runtime" { useParams, Link }
import from react { useRef }


def copy_text(text: str) -> None {
    # navigator.clipboard only exists in secure contexts (HTTPS / localhost).
    # Over plain HTTP on a LAN IP it's undefined, so fall back to a hidden
    # textarea + execCommand("copy").
    try {
        if navigator.clipboard {
            navigator.clipboard.writeText(text);
            return;
        }
    } except Exception {
        _ignore = None;
    }
    try {
        ta = document.createElement("textarea");
        ta.value = text;
        ta.setAttribute("readonly", "");
        ta.style.position = "fixed";
        ta.style.opacity = "0";
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        document.body.removeChild(ta);
    } except Exception {
        _ignore = None;
    }
}


def upsert_meta(attr: str, key: str, content: str) -> None {
    # Find or create a <meta {attr}="{key}"> and set its content.
    try {
        selector = f"meta[{attr}='{key}']";
        el = document.querySelector(selector);
        if not el {
            el = document.createElement("meta");
            el.setAttribute(attr, key);
            document.head.appendChild(el);
        }
        el.setAttribute("content", content);
    } except Exception {
        _ignore = None;
    }
}


def set_social_meta(title: str, description: str, url: str, image: str) -> None {
    # Open Graph + Twitter Card tags so pasted links expand into rich cards.
    upsert_meta("property", "og:type", "article");
    upsert_meta("property", "og:site_name", "Jaseci Blogs");
    upsert_meta("property", "og:title", title);
    upsert_meta("property", "og:description", description);
    upsert_meta("property", "og:url", url);
    upsert_meta("name", "description", description);
    upsert_meta("name", "twitter:card", "summary_large_image" if image else "summary");
    upsert_meta("name", "twitter:title", title);
    upsert_meta("name", "twitter:description", description);
    if image {
        upsert_meta("property", "og:image", image);
        upsert_meta("name", "twitter:image", image);
    }
}


def install_load_helper() -> None {
    # Jac compiles `Promise(...)` without `new`, which JS rejects. So we inject
    # a raw-JS helper (evaluated by the browser, not the Jac compiler) that
    # owns the `new Promise` and returns a promise we can await from Jac.
    # Guard on the LAST-defined helper so a stale partial helper from a prior
    # HMR build (which preserves window) gets re-injected with all three.
    if window.__loadMermaid {
        return;
    }
    s = document.createElement("script");
    s.textContent = "window.__loadScript=function(src){return new Promise(function(res,rej){var f=document.querySelector('script[data-ls=\"'+src+'\"]');if(f){res();return;}var el=document.createElement('script');el.src=src;el.setAttribute('data-ls',src);el.onload=function(){res();};el.onerror=function(){rej(new Error('failed to load '+src));};document.head.appendChild(el);});};window.__loadCss=function(href){return new Promise(function(res){if(document.querySelector('link[data-lc=\"'+href+'\"]')){res();return;}var l=document.createElement('link');l.rel='stylesheet';l.href=href;l.setAttribute('data-lc',href);l.onload=function(){res();};l.onerror=function(){res();};document.head.appendChild(l);});};window.__loadMermaid=function(){if(window.mermaid){return Promise.resolve(window.mermaid);}return import('https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs').then(function(m){window.mermaid=m.default;return m.default;});};";
    document.head.appendChild(s);
}


async def ensure_codemirror() -> None {
    if window.CodeMirror {
        return;
    }
    install_load_helper();
    await window.__loadCss("https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.css");
    await window.__loadCss("https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/theme/material-darker.min.css");
    await window.__loadScript("https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.js");
    await window.__loadScript("https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/python/python.min.js");
    define_jac_mode();
}


def define_jac_mode() -> None {
    # Register a Jac syntax mode via defineSimpleMode. The definition is
    # base64-encoded JS (decoded with atob) to avoid escaping all the regex
    # backslashes through a Jac string literal.
    try {
        if window.CodeMirror and window.CodeMirror.__jacDefined {
            return;
        }
        b64 = "KGZ1bmN0aW9uKCl7aWYoIXdpbmRvdy5Db2RlTWlycm9yfHxDb2RlTWlycm9yLl9famFjRGVmaW5lZCl7cmV0dXJuO312YXIgS1c9e307Im5vZGUgZWRnZSB3YWxrZXIgb2JqIGNsYXNzIGVudW0gaW1wbCBzZW0gaGFzIGNhbiBkZWYgd2l0aCBlbnRyeSBleGl0IHZpc2l0IHNwYXduIHJlcG9ydCBkaXNlbmdhZ2UgaWdub3JlIGhlcmUgdmlzaXRvciByb290IHNlbGYgc3VwZXIgaW5pdCBwb3N0aW5pdCBpbXBvcnQgaW5jbHVkZSBmcm9tIGFzIGdsb2IgbGV0IGlmIGVsaWYgZWxzZSBmb3Igd2hpbGUgcmV0dXJuIGluIHRvIGJ5IHRlc3QgY2hlY2sgYXNzZXJ0IHRyeSBleGNlcHQgZmluYWxseSByYWlzZSBkZWwgYW5kIG9yIG5vdCBpcyBhc3luYyBhd2FpdCBsYW1iZGEgeWllbGQgbWF0Y2ggY2FzZSBwcmludCBjbCBzdiIuc3BsaXQoIiAiKS5mb3JFYWNoKGZ1bmN0aW9uKGspe0tXW2tdPTE7fSk7dmFyIEFUT009eyJUcnVlIjoxLCJGYWxzZSI6MSwiTm9uZSI6MX07Q29kZU1pcnJvci5kZWZpbmVNb2RlKCJqYWMiLGZ1bmN0aW9uKCl7cmV0dXJue2xpbmVDb21tZW50OiIjIix0b2tlbjpmdW5jdGlvbihzdHJlYW0pe2lmKHN0cmVhbS5lYXRTcGFjZSgpKXtyZXR1cm4gbnVsbDt9dmFyIGNoPXN0cmVhbS5wZWVrKCk7aWYoY2g9PT0iIyIpe3N0cmVhbS5za2lwVG9FbmQoKTtyZXR1cm4gImNvbW1lbnQiO31pZihjaD09PSciJ3x8Y2g9PT0iJyIpe3ZhciBxPXN0cmVhbS5uZXh0KCk7dmFyIGVzYz1mYWxzZSxjO3doaWxlKChjPXN0cmVhbS5uZXh0KCkpIT1udWxsKXtpZihjPT09cSYmIWVzYyl7YnJlYWs7fWVzYz0oIWVzYyYmYz09PSJcXCIpO31yZXR1cm4gInN0cmluZyI7fWlmKC9bMC05XS8udGVzdChjaCkpe3N0cmVhbS5tYXRjaCgvXlxkKyg/OlwuXGQrKT8vKTtyZXR1cm4gIm51bWJlciI7fWlmKC9bQS1aYS16X10vLnRlc3QoY2gpKXt2YXIgbT1zdHJlYW0ubWF0Y2goL15bQS1aYS16X11bQS1aYS16MC05X10qLyk7dmFyIHdvcmQ9bVswXTtpZihLV1t3b3JkXSl7cmV0dXJuICJrZXl3b3JkIjt9aWYoQVRPTVt3b3JkXSl7cmV0dXJuICJhdG9tIjt9aWYoL15bQS1aXS8udGVzdCh3b3JkKSl7cmV0dXJuICJ2YXJpYWJsZS0yIjt9cmV0dXJuIG51bGw7fXN0cmVhbS5uZXh0KCk7cmV0dXJuIG51bGw7fX07fSk7Q29kZU1pcnJvci5fX2phY0RlZmluZWQ9dHJ1ZTt9KSgpOwo=";
        s = document.createElement("script");
        s.textContent = window.atob(b64);
        document.head.appendChild(s);
    } except Exception {
        _ignore = None;
    }
}


async def load_script(src: str) -> None {
    install_load_helper();
    await window.__loadScript(src);
}


def display_lang(lang: str) -> str {
    low = lang.lower();
    if low == "jac" {
        return "Jac";
    }
    if low == "python" or low == "py" {
        return "Python";
    }
    if not lang {
        return "Code";
    }
    return lang[0:1].upper() + lang[1:];
}


async def enhance_code_blocks(container: any) -> None {
    # Render every static code block through CodeMirror too (read-only), so
    # colors, line numbers, and chrome match the runnable editor exactly.
    pres = container.querySelectorAll("pre");
    targets = [];
    for pre in pres {
        if pre.dataset.enhanced {
            continue;
        }
        if pre.closest("div.runnable-jac") or pre.closest("div.code-block") {
            continue;
        }
        code_el = pre.querySelector("code") or pre;
        cls_str = str(code_el.className) + " " + str(pre.className);
        if "language-mermaid" in cls_str or "mermaid" in cls_str {
            continue;
        }
        targets.append(pre);
    }
    has_any = False;
    for _t in targets {
        has_any = True;
        break;
    }
    if not has_any {
        return;
    }
    await ensure_codemirror();
    if not window.CodeMirror {
        return;
    }

    for pre in targets {
        pre.dataset.enhanced = "true";
        code_el = pre.querySelector("code") or pre;
        source = str(code_el.textContent).rstrip("\n");

        lang = "";
        classes = (str(code_el.className) + " " + str(pre.className)).split(" ");
        for raw_cls in classes {
            cls: str = str(raw_cls);
            if cls.startswith("language-") {
                lang = cls[len("language-"):];
                break;
            }
        }

        shell = document.createElement("div");
        shell.className = "runnable-jac code-static";

        header = document.createElement("div");
        header.className = "runnable-header";
        tag = document.createElement("span");
        tag.className = "code-lang";
        tag.textContent = display_lang(lang);
        header.appendChild(tag);
        copy_btn = document.createElement("button");
        copy_btn.type = "button";
        copy_btn.className = "runnable-copy";
        copy_btn.textContent = "Copy";
        header.appendChild(copy_btn);
        shell.appendChild(header);

        host = document.createElement("div");
        host.className = "runnable-editor-host";
        shell.appendChild(host);

        # Replace the whole codehilite wrapper (<div class="highlight">) if
        # present — otherwise just the <pre> — so we don't nest the editor
        # inside the wrapper's own border/background (the "double box").
        outer = pre.closest("div.highlight") or pre;
        outer.parentNode.insertBefore(shell, outer);
        outer.parentNode.removeChild(outer);

        has_jac = False;
        try {
            has_jac = bool(window.CodeMirror.modes["jac"]);
        } except Exception {
            _ignore = None;
        }
        cm_mode = "jac" if (lang.lower() == "jac" or not lang) and has_jac else ("python" if lang.lower() in ["python", "py", "jac", ""] else lang);
        cm = window.CodeMirror(host, {
            "value": source,
            "mode": cm_mode,
            "theme": "default",
            "lineNumbers": True,
            "readOnly": True,
            "viewportMargin": 100000,
        });
        copy_btn.addEventListener("click", make_copier(cm, copy_btn));
        setTimeout(lambda -> None { cm.refresh(); }, 60);
    }
}


async def render_mermaid_blocks(container: any) -> None {
    # Server emits <div class="mermaid-block">SOURCE</div> for each ```mermaid
    # fence. We render each diagram in BOTH palettes up front and keep both SVGs
    # in the DOM; CSS reveals the one matching the active theme. This makes the
    # light/dark switch instant (no re-render, no flash) when a reader toggles
    # themes. data-processed guards re-mounts.
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
        install_load_helper();
        try {
            await window.__loadMermaid();
        } except Exception {
            _ignore = None;
        }
    }
    if not window.mermaid {
        return;
    }
    i = 0;
    for el in targets {
        if el.getAttribute("data-processed") {
            continue;
        }
        i = i + 1;
        el.setAttribute("data-processed", "true");
        source = str(el.textContent).strip();
        try {
            # Light pass, then dark pass. initialize() sets the palette globally,
            # so we re-init between renders. Distinct render ids keep the two
            # SVGs' internal element ids from colliding in the DOM.
            window.mermaid.initialize({
                "startOnLoad": False,
                "theme": "default",
                "securityLevel": "loose",
                "fontFamily": "Inter, system-ui, sans-serif",
            });
            light_res = await window.mermaid.render(f"mmd-l-{Date.now()}-{i}", source);

            window.mermaid.initialize({
                "startOnLoad": False,
                "theme": "dark",
                "securityLevel": "loose",
                "fontFamily": "Inter, system-ui, sans-serif",
            });
            dark_res = await window.mermaid.render(f"mmd-d-{Date.now()}-{i}", source);

            el.innerHTML = f'<div class="mermaid-variant mermaid-variant-light">{light_res.svg}</div><div class="mermaid-variant mermaid-variant-dark">{dark_res.svg}</div>';
            el.classList.add("mermaid-rendered");
        } except Exception as e {
            el.classList.add("mermaid-error");
            el.textContent = f"[mermaid error] {e}";
        }
    }
}


async def ensure_pyodide() -> any {
    # Main-thread Pyodide (no worker / no SharedArrayBuffer, so no COOP/COEP
    # headers needed). Cached on window so it boots once per page session.
    if window.__pyodide {
        return window.__pyodide;
    }
    if not window.__pyodide_loading {
        async def boot() -> any {
            await load_script("https://cdn.jsdelivr.net/pyodide/v0.27.0/full/pyodide.js");
            py = await window.loadPyodide({"indexURL": "https://cdn.jsdelivr.net/pyodide/v0.27.0/full/"});
            await py.loadPackage(["micropip"]);
            return py;
        }
        window.__pyodide_loading = boot();
    }
    py = await window.__pyodide_loading;
    window.__pyodide = py;
    return py;
}


async def ensure_jaclang(py: any) -> None {
    # jaclang is NOT pip-installable into Pyodide. Mirror the original mkdocs
    # playground: extract the prebuilt jaclang.zip onto sys.path and pull its
    # runtime deps (pluggy + sqlite3). The zip arrives via the GetRuntimeZip
    # walker as base64 (static serving can't deliver it reliably).
    if window.__jaclang_ready {
        return;
    }
    await py.loadPackage(["micropip", "sqlite3"]);
    await py.runPythonAsync("""
import micropip
await micropip.install("pluggy")
""");

    zip_result = root spawn GetRuntimeZip();
    b64 = "";
    if zip_result.reports and len(zip_result.reports) > 0 {
        data = zip_result.reports[0];
        if data["ok"] {
            b64 = str(data["b64"]);
        }
    }
    if not b64 {
        raise ValueError("could not load Jac runtime bundle");
    }

    py.globals.set("__zip_b64", b64);
    await py.runPythonAsync("""
import base64, io, zipfile, sys, os
if not os.path.exists("/jaclang"):
    _raw = base64.b64decode(__zip_b64)
    with zipfile.ZipFile(io.BytesIO(_raw), "r") as _z:
        _z.extractall("/jaclang")
if "/jaclang" not in sys.path:
    sys.path.insert(0, "/jaclang")
from jaclang.cli.commands import execution
""");
    window.__jaclang_ready = True;
}


async def run_snippet(code: str, lang: str) -> dict {
    try {
        py = await ensure_pyodide();
        py.globals.set("__src", code);

        if lang == "jac" {
            await ensure_jaclang(py);
            await py.runPythonAsync("""
import sys, io, os, traceback
# Monotonic, never-repeating module name. jaclang derives the module name from
# the file stem and caches it in sys.modules; a repeated stem (NamedTemporaryFile
# can recycle names in Pyodide's in-memory FS) makes it serve the FIRST program
# for every later run. A fresh stem each run guarantees the edited source runs.
_n = getattr(sys, "_jac_run_n", 0) + 1
sys._jac_run_n = _n
_mod = "jac_run_%d" % _n
_dir = "/jac_runs"
os.makedirs(_dir, exist_ok=True)
_path = os.path.join(_dir, _mod + ".jac")
with open(_path, "w") as _f:
    _f.write(__src)
sys.modules.pop(_mod, None)
# jaclang's program is a singleton; its errors_had/warnings_had lists persist
# across runs, so each run would re-print every earlier run's errors. Clear them.
try:
    from jaclang.jac0core.runtime import JacRuntime as _Jac
    _prog = _Jac.get_program()
    _prog.errors_had.clear()
    _prog.warnings_had.clear()
except Exception:
    pass
_out = io.StringIO()
_orig_out, _orig_err = sys.stdout, sys.stderr
sys.stdout = _out
sys.stderr = _out
try:
    from jaclang.cli.commands import execution
    execution.run(_path, main=True, cache=False)
except SystemExit:
    pass
except Exception:
    traceback.print_exc()
finally:
    sys.stdout = _orig_out
    sys.stderr = _orig_err
""");
        } else {
            py.runPython("""
import sys, io, traceback
_out = io.StringIO()
_orig_out, _orig_err = sys.stdout, sys.stderr
sys.stdout = _out
sys.stderr = _out
try:
    exec(__src, {"__name__": "__main__"})
except Exception:
    traceback.print_exc()
finally:
    sys.stdout = _orig_out
    sys.stderr = _orig_err
""");
        }
        out = py.runPython("_out.getvalue()");
        return {"ok": True, "output": str(out)};
    } except Exception as e {
        return {"ok": False, "output": str(e)};
    }
}


async def mount_runnable_blocks(container: any) -> None {
    blocks = container.querySelectorAll("div.code-block:not([data-runnable])");
    has_any = False;
    for _b in blocks {
        has_any = True;
        break;
    }
    if not has_any {
        return;
    }
    await ensure_codemirror();
    if not window.CodeMirror {
        return;
    }
    for block in blocks {
        # Re-check the flag at processing time: the effect can run twice
        # (React StrictMode in dev), and both invocations capture the same
        # NodeList before the flag is set. Without this, the second pass reads
        # the CodeMirror measure text ("xxxx") the first pass created.
        if block.dataset.runnable {
            continue;
        }
        block.dataset.runnable = "true";
        lang = block.getAttribute("data-lang") or "jac";
        # codehilite sometimes emits <pre>…code…</pre> with no <code> child, so
        # fall back through code → pre → the block itself.
        src_el = block.querySelector("pre code") or block.querySelector("code") or block.querySelector("pre");
        source = str(src_el.textContent) if src_el else str(block.textContent);
        source = source.rstrip("\n");

        # Replace the static highlighted markup with an editor + chrome.
        block.innerHTML = "";
        block.className = "runnable-jac";

        header = document.createElement("div");
        header.className = "runnable-header";
        lang_el = document.createElement("span");
        lang_el.className = "code-lang";
        lang_el.textContent = display_lang(str(lang));
        header.appendChild(lang_el);

        actions = document.createElement("div");
        actions.className = "runnable-actions";
        copy_btn = document.createElement("button");
        copy_btn.type = "button";
        copy_btn.className = "runnable-copy";
        copy_btn.textContent = "Copy";
        actions.appendChild(copy_btn);
        run_btn = document.createElement("button");
        run_btn.type = "button";
        run_btn.className = "runnable-run";
        run_btn.textContent = "▶ Run";
        actions.appendChild(run_btn);
        header.appendChild(actions);
        block.appendChild(header);

        host = document.createElement("div");
        host.className = "runnable-editor-host";
        block.appendChild(host);

        # Prefer the registered Jac mode; fall back to python so colors always
        # show even if the jac mode failed to register.
        has_jac = False;
        try {
            has_jac = bool(window.CodeMirror.modes["jac"]);
        } except Exception {
            _ignore = None;
        }
        cm_mode = "jac" if (lang == "jac" and has_jac) else "python";
        cm = window.CodeMirror(host, {
            "value": source,
            "mode": cm_mode,
            "theme": "default",
            "lineNumbers": True,
            "indentUnit": 4,
            "viewportMargin": 100000,
        });
        # CM measures char width with a hidden "xxx" element; if it renders
        # before layout settles, that text leaks. A refresh after paint fixes it.
        setTimeout(lambda -> None { cm.refresh(); }, 60);

        output = document.createElement("pre");
        output.className = "runnable-output";
        block.appendChild(output);

        copy_btn.addEventListener("click", make_copier(cm, copy_btn));
        run_btn.addEventListener("click", make_runner(cm, output, run_btn, str(lang)));
    }
}


def make_copier(cm: any, copy_btn: any) -> any {
    def handler() -> None {
        try {
            copy_text(str(cm.getValue()));
            copy_btn.textContent = "Copied ✓";
            setTimeout(lambda -> None { copy_btn.textContent = "Copy"; }, 1500);
        } except Exception {
            _ignore = None;
        }
    }
    return handler;
}


def make_runner(cm: any, output: any, run_btn: any, lang: str) -> any {
    async def handler() -> None {
        run_btn.disabled = True;
        run_btn.textContent = "Running…";
        output.dataset.kind = "running";
        output.textContent = "Loading runtime…";
        try {
            code = str(cm.getValue());
            result = await run_snippet(code, lang);
            output.textContent = result["output"] or "(no output)";
            output.dataset.kind = "ok" if result["ok"] else "error";
        } except Exception as e {
            output.textContent = str(e);
            output.dataset.kind = "error";
        }
        run_btn.disabled = False;
        run_btn.textContent = "▶ Run";
    }
    return handler;
}


def build_toc(container: any) -> list {
    # Collect h2/h3 headings (the markdown `toc` extension already gave them ids
    # + a .headerlink anchor) into a flat list the sidebar renders as jump links.
    items = [];
    heads = container.querySelectorAll("h2[id], h3[id]");
    for h in heads {
        raw = str(h.textContent or "");
        link_el = h.querySelector(".headerlink");
        if link_el {
            # Drop the trailing ¶ permalink glyph from the visible label.
            raw = raw.replace(str(link_el.textContent or ""), "");
        }
        text = raw.strip();
        if not text {
            continue;
        }
        level = 2 if str(h.tagName) == "H2" else 3;
        items.append({"id": str(h.getAttribute("id")), "text": text, "level": level});
    }
    return items;
}


def setup_toc_scrollspy() -> None {
    # Highlight the section currently in view. We toggle classes directly on the
    # DOM (not React state) so scrolling never triggers re-renders, and keep a
    # single handler on window so SPA re-navigations don't stack listeners. The
    # handler queries .post-toc live, so it's a harmless no-op on non-post pages.
    if window.__tocScroll {
        window.removeEventListener("scroll", window.__tocScroll);
    }
    def on_scroll() -> None {
        toc_el = document.querySelector(".post-toc");
        if not toc_el {
            return;
        }
        links = toc_el.querySelectorAll("a[data-toc-id]");
        current = "";
        for ln in links {
            target = document.getElementById(str(ln.getAttribute("data-toc-id")));
            if target and target.getBoundingClientRect().top <= 140 {
                current = str(ln.getAttribute("data-toc-id"));
            }
        }
        for ln in links {
            if current and str(ln.getAttribute("data-toc-id")) == current {
                ln.classList.add("is-active");
            } else {
                ln.classList.remove("is-active");
            }
        }
    }
    window.__tocScroll = on_scroll;
    window.addEventListener("scroll", on_scroll, {"passive": True});
    # Run once after the nav has painted so the first section highlights on load.
    setTimeout(on_scroll, 60);
}


def:pub PostBody(html: str) -> JsxElement {
    ref = useRef(None);
    has html_version: int = 0;
    has toc: list = [];

    can with [html] entry {
        html_version = html_version + 1;
    }

    async can with [html_version] entry {
        if not ref.current {
            return;
        }
        container = ref.current;
        try {
            await mount_runnable_blocks(container);
        } except Exception {
            _ignore = None;
        }
        try {
            await enhance_code_blocks(container);
        } except Exception {
            _ignore = None;
        }
        try {
            await render_mermaid_blocks(container);
        } except Exception {
            _ignore = None;
        }
        try {
            toc = build_toc(container);
            setup_toc_scrollspy();
        } except Exception {
            _ignore = None;
        }
    }

    return <>
        {len(toc) > 1 and (
            <nav className="post-toc" aria-label="On this page">
                <p className="post-toc-title">On this page</p>
                <ul className="post-toc-list">
                    {[
                        <li key={item["id"]} className={f"post-toc-item post-toc-l{item['level']}"}>
                            <a href={f"#{item['id']}"} data-toc-id={item["id"]} className="post-toc-link">
                                {item["text"]}
                            </a>
                        </li>
                        for item in toc
                    ]}
                </ul>
            </nav>
        )}
        <div
            ref={ref}
            className="prose"
            dangerouslySetInnerHTML={{"__html": html}}
        />
    </>;
}


def:pub page() -> JsxElement {
    params = useParams();
    slug = params["slug"];

    has loading: bool = True;
    has post: any = None;
    has error: str = "";
    has share_copied: bool = False;
    has share_open: bool = False;

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
                    meta_desc = str(data["description"]) or f"{data['reading_minutes']} min read on Jaseci Blogs.";
                    meta_url = "";
                    try {
                        meta_url = str(window.location.href);
                    } except Exception {
                        _ignore = None;
                    }
                    set_social_meta(str(data["title"]), meta_desc, meta_url, str(data["cover"]));
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
                <p><Link className="cta-pill" to="/blog">← Back to latest</Link></p>
            </div>
        </article>;
    }

    cats: any = post["categories"] or [];
    primary_category: any = cats[0] if cats else "";
    related: any = post["related"] or [];

    share_url: str = "";
    try {
        share_url = str(window.location.href);
    } except Exception {
        _ignore = None;
    }
    enc_url = encodeURIComponent(share_url);
    enc_title = encodeURIComponent(str(post["title"]));
    x_url = f"https://twitter.com/intent/tweet?url={enc_url}&text={enc_title}";
    fb_url = f"https://www.facebook.com/sharer/sharer.php?u={enc_url}";
    li_url = f"https://www.linkedin.com/sharing/share-offsite/?url={enc_url}";
    share_text = f"{post['title']} — {share_url}";

    return <article className="post-shell">
        <header className="post-header">
            <div className="container narrow">
                {primary_category and (
                    <p className="eyebrow">
                        <Link to={f"/blog/categories/{primary_category}"}>{primary_category}</Link>
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
                                to={f"/blog/authors/{author['id']}"}
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
                    <button
                        type="button"
                        className="share-trigger"
                        onClick={lambda -> None {
                            share_open = True;
                            try {
                                copy_text(share_text);
                                share_copied = True;
                                setTimeout(lambda -> None { share_copied = False; }, 2200);
                            } except Exception {
                                _ignore = None;
                            }
                        }}
                        aria-label="Share this post"
                    >
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <circle cx="18" cy="5" r="3" />
                            <circle cx="6" cy="12" r="3" />
                            <circle cx="18" cy="19" r="3" />
                            <line x1="8.59" y1="13.51" x2="15.42" y2="17.49" />
                            <line x1="15.41" y1="6.51" x2="8.59" y2="10.49" />
                        </svg>
                        <span>Share</span>
                    </button>
                </div>
            </div>
        </header>

        {share_open and (
            <div
                className="share-modal-overlay"
                onClick={lambda -> None { share_open = False; }}
            >
                <div
                    className="share-modal-card"
                    onClick={lambda e: MouseEvent { e.stopPropagation(); }}
                >
                    <button
                        type="button"
                        className="share-modal-close"
                        onClick={lambda -> None { share_open = False; }}
                        aria-label="Close"
                    >×</button>
                    <p className="eyebrow">Share this post</p>
                    <h3 className="share-modal-title">{post["title"]}</h3>
                    <div className="share-preview">
                        <p className="share-preview-text">{share_text}</p>
                        <span className="share-preview-badge">
                            {share_copied and "Copied to clipboard ✓" or "Ready to paste"}
                        </span>
                    </div>
                    <div className="share-buttons">
                        <a className="share-btn" href={x_url} target="_blank" rel="noopener" aria-label="Share on X" title="X">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
                        </a>
                        <a className="share-btn" href={fb_url} target="_blank" rel="noopener" aria-label="Share on Facebook" title="Facebook">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>
                        </a>
                        <a className="share-btn" href={li_url} target="_blank" rel="noopener" aria-label="Share on LinkedIn" title="LinkedIn">
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>
                        </a>
                        <button
                            type="button"
                            className="share-btn"
                            aria-label="Copy link for Instagram"
                            title="Instagram (copies link)"
                            onClick={lambda -> None {
                                try {
                                    copy_text(share_url);
                                    share_copied = True;
                                    setTimeout(lambda -> None { share_copied = False; }, 1800);
                                } except Exception {
                                    _ignore = None;
                                }
                            }}
                        >
                            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"/></svg>
                        </button>
                    </div>
                    <div className="share-link-row">
                        <input
                            type="text"
                            className="share-link-input"
                            readOnly
                            value={share_url}
                            onClick={lambda e: MouseEvent {
                                tgt: any = e.target;
                                tgt.select();
                            }}
                        />
                        <button
                            type="button"
                            className="share-link-copy"
                            onClick={lambda -> None {
                                try {
                                    copy_text(share_url);
                                    share_copied = True;
                                    setTimeout(lambda -> None { share_copied = False; }, 1800);
                                } except Exception {
                                    _ignore = None;
                                }
                            }}
                        >
                            {share_copied and "Copied ✓" or "Copy"}
                        </button>
                    </div>
                    <button
                        type="button"
                        className="share-copy-link"
                        onClick={lambda -> None {
                            try {
                                copy_text(share_text);
                                share_copied = True;
                                setTimeout(lambda -> None { share_copied = False; }, 1800);
                            } except Exception {
                                _ignore = None;
                            }
                        }}
                    >
                        {share_copied and "Copied ✓" or "Copy title + link"}
                    </button>
                </div>
            </div>
        )}

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
                            <Link to={f"/blog/categories/{cat}"} className="tag">{cat}</Link>
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
                    <Link to={f"/blog/posts/{post['prev']['slug']}"} className="post-nav-link prev">
                        <span className="eyebrow">← Previous</span>
                        <span className="post-nav-title">{post["prev"]["title"]}</span>
                    </Link>
                ) or <span />}
                {post["next"] and (
                    <Link to={f"/blog/posts/{post['next']['slug']}"} className="post-nav-link next">
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
                                <Link to={f"/blog/posts/{rel['slug']}"}>
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
