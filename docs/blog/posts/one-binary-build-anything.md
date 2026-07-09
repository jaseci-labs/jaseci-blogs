---
date: 2026-07-09
authors:
  - mars
categories:
  - Tutorials
slug: one-binary-build-anything
draft: true
---

# One Binary, Build Anything

Jac ships as a single native binary. One download gives you a complete polyglot development environment — no system Python, no Node.js, no C toolchain, no package manager to install first. Everything is bundled.

```bash
c*rl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

That's it. You now have a compiler, a runtime, a package manager, a server, a build system, and a native linker — all behind one command.

## What's Inside the Binary

| Capability | What it replaces | How you use it |
|---|---|---|
| **CPython 3.14** | System Python, pyenv, venvs | Bundled — runs your `.jac` files and PyPI imports |
| **Bun** | Node.js, npm, npx | Bundled — compiles `.cl.jac` to JS, manages npm deps |
| **LLVM + Zig linker** | gcc, clang, make, cmake | Bundled — `jac nacompile` produces native binaries |
| **Package manager** | pip, npm, pipx | `jac install` / `jac add` for PyPI and npm |
| **REST server** | Flask, FastAPI, Express | `jac start` — walkers become API endpoints |
| **Kubernetes deployer** | Docker + kubectl + Helm | `jac start --scale` — one-command K8s deployment |
| **AI integration** | LangChain, prompt libraries | `by llm()` — built into the language |
| **MCP server** | Separate MCP package | `jac mcp` — built in, no install needed |
| **Type checker** | mypy, pyright, tsc | `jac check` — built into the compiler |
| **Formatter & linter** | black, ruff, eslint | `jac fmt`, `jac check --lint` |
| **Test runner** | pytest, jest | `jac test` |
| **Language server** | Separate LSP packages | `jac lsp` — IDE support built in |

## Two Scopes for Dependencies

Jac has exactly two places dependencies can live. No more "is this in my venv or system Python?" confusion.

### Project scope (default)

Dependencies declared in `jac.toml` and installed into the project's `.jac/venv/`:

```bash
# Add a dependency to your project
jac add numpy

# Or declare it in jac.toml and install
jac install
```

```toml
# jac.toml
[dependencies]
numpy = ">=1.26"

[dependencies.npm]
react = "^18.2.0"
```

Both PyPI and npm packages live in the same config file, managed by the same tool.

### Global scope

Tools you want available everywhere — not tied to any project:

```bash
jac install --global huggingface
```

Global packages are accessible from any directory on your machine.

## `jac x` — The Universal Tool Runner

`jac x` runs any CLI tool installed via `jac install`, whether it came from PyPI or npm. Think of it as `npx` but for both ecosystems:

```bash
# Install and run Python CLI tools
jac install --global huggingface
jac x hf              # runs the Hugging Face CLI

# Install and run npm CLI tools
jac install --global agent-browser
jac x agent-browser   # runs the agent-browser CLI

# Project-scoped tools work too
jac install ruff       # installed into .jac/venv
jac x ruff check .     # runs ruff within the project
```

The tool runs with the correct environment automatically — no `source .venv/bin/activate`, no `npx`, no `pipx`.

## What You Can Uninstall

With Jac installed, you no longer need these on your development machine:

| Tool | Why it's replaced |
|---|---|
| Python / pyenv / conda | Jac bundles CPython 3.14 |
| pip / pipx / uv / poetry | `jac install` / `jac add` manage Python deps |
| Node.js / npm / npx / yarn | Jac bundles Bun; `jac install` manages JS deps |
| venv / virtualenv | `.jac/venv` is automatic and project-scoped |
| gcc / clang / make / cmake | Jac bundles LLVM + Zig for native compilation |
| Flask / FastAPI / Express | `jac start` generates a server from your code |

!!! note
    You only need these replacements if you're building with Jac. If you have other Python or Node projects, keep those toolchains installed for them.

## How It Works

The Jac binary is a self-contained native executable that embeds:

- A **CPython 3.14 runtime** (stripped of unnecessary components)
- A **Bun runtime** for JavaScript/TypeScript compilation
- An **LLVM backend** for native code generation
- A **Zig-based linker** for producing native binaries and shared libraries
- The **Jac compiler**, type checker, formatter, and all language tooling
- Built-in subsystems: **byLLM** (AI), **Scale** (deployment), **Client** (full-stack), **MCP** (AI assistant integration)

When you run `jac install`, dependencies are resolved from PyPI or npm into an isolated environment (`.jac/venv` for projects, a global directory for `--global`). The Jac binary provides the runtime; dependencies provide the libraries.

## Quick Start

```bash
# Install Jac (one binary, ~100MB)
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash

# Verify
jac --version

# Create a project
jac create my-app --use web-app
cd my-app
jac install
jac start

# Open http://localhost:8000
```

From zero to a running full-stack app with AI integration, graph persistence, and auto-generated API docs — using one tool.
