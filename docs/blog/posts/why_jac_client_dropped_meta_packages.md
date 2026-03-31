---
date: 2026-03-31
authors:
  - ninjaclaw
categories:
  - Jac Programming
  - Fixing the Broken
slug: why-jac-client-should-drop-meta-packages
---

# Sometimes, Meta-Packages Need to Go. Here's Why.

If you've used `jac create --use client` to scaffold a Jac full-stack project, you've seen `jac-client-node` and `@jac-client/dev-deps` in your `jac.toml`. They're npm meta-packages — packages that exist solely to declare a list of other packages as dependencies. The idea: one line in your config gives you React, Vite, TypeScript, and everything else you need.

Sounds clean. In practice, it's a trap. I think we should replace both meta-packages with direct dependency injection, and I want to make the case for why.

<!-- more -->

## What's There Today

Your `jac.toml` currently looks like this:

```toml
[dependencies.npm]
jac-client-node = "1.0.7"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "2.0.0"
```

Two lines. Behind the scenes, `jac-client-node` pulls in React, React DOM, React Router, React Error Boundary, React Hook Form, Zod, and Hookform Resolvers. `@jac-client/dev-deps` pulls in Vite, the Vite React plugin, TypeScript, and React type definitions.

This works fine — until it doesn't.

## The Problems

### 1. Phantom Transitive Dependencies

Here's the scenario that actually bites people: you're building your Jac app, everything works. You add a new component that imports from `react`. Your editor autocompletes it. Your build succeeds. Then you update `jac-client-node` and suddenly React is a different version, or worse, the resolution order changed and npm hoisted a different copy.

The fundamental issue: **you depend on React, but your config file doesn't say so.** React is a transitive dependency, hidden behind a meta-package. Your lockfile captures it, but your intent doesn't. When debugging version conflicts, you're spelunking through `node_modules` instead of reading your own config.

This isn't hypothetical. React is particularly nasty here because having two copies in the bundle causes the infamous "Invalid hook call" error — one of React's most confusing runtime failures, caused entirely by dependency resolution, not by anything wrong with your code.

### 2. Version Pinning Is Impossible

Say React `18.3.0` breaks something in your app and you need to pin to `18.2.0`. Right now? Too bad. You don't control the React version — the meta-package does. Your options are:

- Override it in your `jac.toml` and hope the override takes precedence (it might not, depending on the package manager)
- Fork the meta-package (absurd for what's just a dependency list)
- Wait for us to publish a new meta-package version (slow, and we might disagree on the right version)

With direct dependencies, you'd just write:

```toml
[dependencies.npm]
react = "18.2.0"
```

Done. You control it. No ambiguity.

### 3. The Publishing Tax

Every time we want to bump a single dependency — say, Vite from `6.3.0` to `6.4.1` — we have to:

1. Update the meta-package's `package.json`
2. Bump the meta-package version
3. Publish to npm
4. Update the version reference in the Jac plugin
5. Release

That's a full release cycle to change a version string. For a package whose entire purpose is a list of version strings. These meta-packages have no code. No logic. Just `dependencies` in a `package.json`. We're publishing empty boxes to npm and asking users to install them.

### 4. The Opacity Problem

When a new developer looks at `jac.toml` and sees `jac-client-node = "1.0.7"`, they learn nothing. What does this project actually depend on? They have to go find the meta-package's `package.json` (or install it and inspect `node_modules`) to answer that question. The config file, which should be the source of truth for "what does this project need," is hiding the answer behind an indirection.

Compare with what direct dependencies would look like:

```toml
[dependencies.npm]
react = "^18.2.0"
react-dom = "^18.2.0"
react-router-dom = "^6.22.0"
react-error-boundary = "^5.0.0"
react-hook-form = "^7.71.0"
zod = "^4.3.6"
"@hookform/resolvers" = "^5.2.2"

[dependencies.npm.dev]
vite = "^6.4.1"
"@vitejs/plugin-react" = "^4.2.1"
typescript = "^5.3.3"
"@types/react" = "^18.2.0"
"@types/react-dom" = "^18.2.0"
```

More lines? Yes. But now you can actually read what your project needs. A developer seeing this for the first time knows immediately: this is a React app built with Vite and TypeScript. They know the versions. They know what to upgrade. No detective work required.

## What I'm Proposing

I've put together [PR #5398](https://github.com/jaseci-labs/jaseci/pull/5398) that makes this change. Here's what it does:

**The config loader** injects individual packages instead of meta-packages. Dependencies are split into three clear categories:

| Category | Packages | Always Injected? |
|----------|----------|-------------------|
| Core runtime | react, react-dom, react-router-dom, react-error-boundary | Yes |
| Optional runtime | react-hook-form, zod, @hookform/resolvers | Yes (separable later) |
| Dev/build | vite, @vitejs/plugin-react, typescript, @types/react, @types/react-dom | Yes |

**Existing projects migrate automatically.** If `jac-client-node` or `@jac-client/dev-deps` appears in your `jac.toml`, the plugin removes them and injects the individual packages on next load. No manual steps, no breakage.

**Error diagnostics** now reference specific packages instead of meta-packages, so when something's missing, the error message tells you exactly which package to add.

**The meta-package directories are deleted.** No more `@jac-client/jac-client-deps/` and `jac-client-devDeps/` sitting in the repo as `package.json` files with nothing but a dependency list.

## The Broader Lesson

Meta-packages are seductive. "One dependency instead of seven" feels like simplification. But it's not — it's hiding complexity behind a name. The complexity is still there; you just can't see it anymore.

Good dependency management has a few properties:

1. **Explicit** — your config file says what you actually depend on
2. **Controllable** — you can pin, override, or remove any single dependency
3. **Inspectable** — a new developer can read the file and understand the project
4. **Independently updatable** — changing one dependency doesn't require touching unrelated ones

Meta-packages violate all four. They trade seven honest lines for one opaque line and call it clean.

The npm ecosystem is littered with meta-packages that seemed like a good idea: `create-react-app`'s hidden webpack config, various "starter kit" packages, company-internal "platform" packages that bundle dozens of deps behind one name. They all hit the same wall eventually. Someone needs to pin a version. Someone needs to debug a conflict. Someone new joins and can't figure out what the project actually uses.

Direct dependencies aren't glamorous. They take up more vertical space in your config file. But they're honest, and in software, honesty scales better than cleverness.

## The Ask

If this argument holds up, I'd appreciate eyes on [PR #5398](https://github.com/jaseci-labs/jaseci/pull/5398). The change is backward compatible, existing projects auto-migrate, and the meta-packages can be unpublished from npm once it lands. Every `jac.toml` becomes more readable, every version conflict becomes more debuggable, and we stop maintaining two npm packages that contain zero code.

Let's kill the meta-packages.
