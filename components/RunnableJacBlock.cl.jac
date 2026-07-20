"""RunnableJacBlock — interactive Jac code editor + runner.

Exposes window.__jac_runnable_upgrade(blocks) for PostBody to call after
the prose HTML mounts. Each <div class="code-block"> wrapper becomes a
Monaco editor + Run button + output pane.

Jac execution runs in Pyodide: jaclang is installed via micropip once, then
each Run pipes the editor contents through `jac run`-equivalent and captures
stdout/stderr. Loaded lazily — only when a page has a runnable block.
"""

glob:pub __pyodide: any = None;
glob:pub __pyodide_loading: any = None;


    async def boot_pyodide() -> any {
        py = await window.loadPyodide({
            "indexURL": "https://cdn.jsdelivr.net/pyodide/v0.27.0/full/",
        });
        await py.loadPackage(["micropip"]);
        micropip = py.pyimport("micropip");
        await micropip.install(["jaclang"]);
        return py;
    }


    async def ensure_pyodide() -> any {
        if __pyodide {
            return __pyodide;
        }
        if not __pyodide_loading {
            __pyodide_loading = boot_pyodide();
        }
        __pyodide = await __pyodide_loading;
        return __pyodide;
    }


    async def run_jac(code: str) -> dict {
        try {
            py = await ensure_pyodide();
            py.runPython("import sys, io; _stdout = io.StringIO(); _stderr = io.StringIO(); sys.stdout = _stdout; sys.stderr = _stderr;");
            py.globals.set("__jac_source", code);
            py.runPython(
                "from jaclang.runtimelib.machine import JacMachineInterface as Jac\n"
                "import tempfile, os, traceback\n"
                "with tempfile.NamedTemporaryFile(mode='w', suffix='.jac', delete=False) as f:\n"
                "    f.write(__jac_source)\n"
                "    __jac_path = f.name\n"
                "try:\n"
                "    Jac.jac_import(os.path.basename(__jac_path).replace('.jac',''), base_path=os.path.dirname(__jac_path))\n"
                "except Exception:\n"
                "    traceback.print_exc()\n"
            );
            stdout = py.runPython("_stdout.getvalue()");
            stderr = py.runPython("_stderr.getvalue()");
            return {"stdout": str(stdout), "stderr": str(stderr), "ok": True};
        } except Exception as e {
            return {"stdout": "", "stderr": str(e), "ok": False};
        }
    }


    def mount_monaco(host: any, initial: str, on_ready: any) -> None {
        try {
            window.require.config({
                "paths": {"vs": "https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs"},
            });
            window.require(["vs/editor/editor.main"], lambda -> None {
                if not window.__jac_monaco_lang_registered {
                    window.monaco.languages.register({"id": "jac"});
                    window.monaco.languages.setMonarchTokensProvider("jac", {
                        "keywords": [
                            "walker", "node", "edge", "obj", "has", "can", "def", "with",
                            "entry", "exit", "report", "visit", "spawn", "root", "here",
                            "visitor", "if", "elif", "else", "for", "while", "return",
                            "import", "from", "glob", "True", "False", "None", "try",
                            "except", "finally", "raise", "and", "or", "not", "in", "is",
                            "async", "await", "lambda", "class", "self", "super", "pub",
                            "priv", "test",
                        ],
                        "tokenizer": {
                            "root": [
                                [r"[a-zA-Z_]\w*", {"cases": {"@keywords": "keyword", "@default": "identifier"}}],
                                [r"\"([^\"\\]|\\.)*\"", "string"],
                                [r"'([^'\\]|\\.)*'", "string"],
                                [r"#.*$", "comment"],
                                [r"\d+", "number"],
                            ],
                        },
                    });
                    window.__jac_monaco_lang_registered = True;
                }
                theme = document.documentElement.getAttribute("data-theme") or "light";
                editor = window.monaco.editor.create(host, {
                    "value": initial,
                    "language": "jac",
                    "theme": "vs-dark" if theme == "dark" else "vs",
                    "fontSize": 14,
                    "fontFamily": "JetBrains Mono, ui-monospace, monospace",
                    "minimap": {"enabled": False},
                    "scrollBeyondLastLine": False,
                    "automaticLayout": True,
                    "padding": {"top": 12, "bottom": 12},
                });
                line_height = 20;
                lines = max(len(initial.split("\n")), 6);
                host.style.height = f"{lines * line_height + 24}px";
                on_ready(editor);
            });
        } except Exception {
            ta = document.createElement("textarea");
            ta.className = "runnable-fallback";
            ta.value = initial;
            host.appendChild(ta);
            on_ready(ta);
        }
    }


    def make_run_handler(block: any, run_btn: any, output: any, original_code: str) -> any {
        async def handler() -> None {
            run_btn.disabled = True;
            run_btn.textContent = "Running…";
            output.textContent = "";
            output.dataset.kind = "running";
            editor = block.__jac_editor;
            code = original_code;
            if editor {
                try {
                    code = editor.getValue();
                } except Exception {
                    try {
                        code = editor.value;
                    } except Exception {
                        code = original_code;
                    }
                }
            }
            try {
                result = await run_jac(code);
                stdout = str(result["stdout"]);
                stderr = str(result["stderr"]);
                if stdout {
                    output.textContent = stdout;
                }
                if stderr {
                    sep = "\n" if output.textContent else "";
                    output.textContent = output.textContent + sep + stderr;
                    output.dataset.kind = "error";
                } else {
                    output.dataset.kind = "ok";
                }
            } except Exception as e {
                output.textContent = str(e);
                output.dataset.kind = "error";
            }
            run_btn.disabled = False;
            run_btn.textContent = "▶ Run";
        }
        return handler;
    }


    def upgrade_block(block: any) -> None {
        if block.dataset.runnable_mounted {
            return;
        }
        block.dataset.runnable_mounted = "true";

        original_code = "";
        code_el = block.querySelector("pre code") or block.querySelector("code");
        if code_el {
            original_code = code_el.textContent;
        }

        block.innerHTML = "";
        block.className = "runnable-jac";

        header = document.createElement("div");
        header.className = "runnable-header";
        lang_el = document.createElement("span");
        lang_el.className = "code-lang";
        lang_el.textContent = "jac";
        header.appendChild(lang_el);
        run_btn = document.createElement("button");
        run_btn.type = "button";
        run_btn.className = "runnable-run";
        run_btn.textContent = "▶ Run";
        header.appendChild(run_btn);
        block.appendChild(header);

        editor_host = document.createElement("div");
        editor_host.className = "runnable-editor";
        block.appendChild(editor_host);

        output = document.createElement("pre");
        output.className = "runnable-output";
        output.textContent = "";
        block.appendChild(output);

        mount_monaco(editor_host, original_code, lambda editor: any -> None {
            block.__jac_editor = editor;
        });

        run_btn.addEventListener("click", make_run_handler(block, run_btn, output, original_code));
    }


    def:pub register_upgrade_hook() -> None {
        if window.__jac_runnable_upgrade {
            return;
        }
        def upgrade_all(blocks: any) -> None {
            for block in blocks {
                upgrade_block(block);
            }
        }
        window.__jac_runnable_upgrade = upgrade_all;
    }
