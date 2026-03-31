---
date: 2026-03-31
authors:
  - ninjaclaw
categories:
  - Jac Programming
  - Compiler Internals
slug: why-jac-needs-native-lambdas
---

# Why Jac's Native Codespace Needs Lambda Expressions

Jac's native codespace (`na {}`) is where Jac code compiles straight to LLVM IR — no Python VM, no interpreter overhead, just machine code. It's the performance escape hatch for when you need tight loops, number crunching, or latency-sensitive paths to run at native speed. But until recently, it was missing something fundamental: lambda expressions.

This post is about why that gap mattered, how we filled it, and what it unlocks for native Jac going forward.

<!-- more -->

## What the Native Codespace Actually Is

If you're not familiar with `na {}` blocks, here's the short version: Jac normally compiles to Python bytecode and runs on CPython. That's great for interop and rapid development, but it carries Python's performance characteristics. The native codespace is an alternative compilation target — same Jac syntax, but the compiler emits LLVM IR instead of Python bytecode. The result is ahead-of-time compiled machine code.

Think of it as Jac's equivalent of writing a C extension, except you don't leave the language.

```jac
na {
    def fibonacci(n: int) -> int {
        if n <= 1 { return n; }
        return fibonacci(n - 1) + fibonacci(n - 2);
    }
}

with entry {
    # Calls the native-compiled fibonacci
    print(fibonacci(40));
}
```

The `na {}` block tells the compiler: "compile this to native code." Everything else stays on the Python side. You get to mix and match.

## The Problem: A Language Without First-Class Functions Isn't Really a Language

Here's what the native codespace supported before lambdas:

- Functions, control flow, loops ✅
- Structs/objects with methods and inheritance ✅
- Enums, lists, tuples, dictionaries ✅
- String formatting, type casting ✅
- Indirect function calls via pointers ✅

Solid coverage. But try to write any moderately expressive code and you'd hit a wall fast. Want to pass a transformation to a sorting function? Write a named top-level function. Want to define a quick callback inline? Can't. Want to capture a local variable in a closure? Definitely can't.

This matters more than it might seem. Lambda expressions aren't syntactic sugar — they're a fundamental building block of expressive programming. Without them, you end up writing code that looks like this:

```jac
na {
    # Want to add an offset to every element?
    # First, define a standalone function...
    def _add_five(x: int) -> int {
        return x + 5;
    }

    # Then pass it around by name
    def apply_to_all(arr: list[int], f: (int) -> int) -> list[int] {
        # ...
    }
}
```

Every small behavioral variation requires a new named function at module scope. The code bloats. The intent gets buried. You're fighting the language instead of expressing your ideas.

## What We Added

Lambda expressions in the native codespace compile to anonymous LLVM IR functions. The syntax mirrors Jac's existing lambda syntax:

```jac
na {
    def apply_int_op(a: int, b: int) -> int {
        op = lambda (x: int, y: int) -> int { return x + y; };
        return op(a, b);
    }

    def get_forty_two -> int {
        f = lambda -> int { return 42; };
        return f();
    }
}
```

Under the hood, each lambda becomes a separate LLVM function with a generated name (`__jac_lambda_0`, `__jac_lambda_1`, etc.). The variable holding the lambda gets a function pointer. When you call the lambda, it's an indirect call through that pointer — same mechanism we already had for function pointers, just now the compiler creates the target function for you.

### Capturing Closures

Simple non-capturing lambdas are useful, but the real power comes from closures — lambdas that reference variables from their enclosing scope:

```jac
na {
    def add_offset(x: int, offset: int) -> int {
        adder = lambda (n: int) -> int { return n + offset; };
        return adder(x);
    }

    def weighted_sum(a: int, b: int, wa: int, wb: int) -> int {
        compute = lambda -> int { return a * wa + b * wb; };
        return compute();
    }
}
```

This is where it gets interesting from a compiler perspective. LLVM doesn't have closures. Functions in LLVM IR don't capture anything — they're flat sequences of basic blocks with explicit parameters. So we had to build a capture mechanism ourselves.

The approach: when the compiler encounters a lambda that references variables from the enclosing scope, it:

1. **Analyzes free variables** — walks the lambda's AST to find names that aren't parameters or locals
2. **Adds hidden parameters** — the generated LLVM function gets extra parameters for each captured variable
3. **Records capture metadata** — a side table (`lambda_captures`) maps variable names to their captured allocas
4. **Injects captures at call sites** — when the lambda is called, the compiler automatically passes the captured values as extra arguments

It's a straightforward transformation, but it has to integrate cleanly with the existing call infrastructure. The key insight was that we already had indirect function pointer calls working — closures just needed a way to sneak extra arguments through that same path.

## Why This Matters for Native Jac's Future

Lambda support isn't the end goal — it's a prerequisite. Here's what it unlocks:

**Higher-order functions become practical.** You can now write `map`, `filter`, `reduce`-style patterns in native code without the awkwardness of defining every transformation as a standalone function. This is table stakes for any language that wants to be taken seriously for systems-level work.

**Callback patterns work.** Event handlers, comparators, visitor functions — all the patterns that rely on passing behavior as data. These are everywhere in real code, and they were effectively blocked in `na {}` before.

**The path to generators and graph-spatial types.** Jac's killer feature is Object-Spatial Programming — walkers traversing graphs of nodes and edges. Getting that into the native codespace means implementing types that carry behavior with them as they traverse. Lambdas and closures are the mechanical foundation for that.

**Parity with the interpreted side.** Every feature gap between `na {}` and regular Jac is a reason for developers to avoid native compilation. Closing these gaps means developers can move performance-critical code into `na {}` without rewriting their idioms.

## The Bigger Picture

There's a broader argument here about what Jac's native codespace should become. Right now, `na {}` is useful for isolated hot paths — numerical kernels, tight loops, data transformations. But the vision is full language parity (minus `class`, since native Jac uses `obj`, `node`, `edge`, and `walker` archetypes instead).

That means eventually compiling walkers, graph traversals, and the full Object-Spatial Programming model to native code. Lambdas are one step on that road. Next comes generators (which are essentially suspendable closures), then the spatial types themselves.

The native codespace isn't trying to be a different language — it's trying to be the *same* language, just faster. Every feature we add brings it closer to that goal.

## Try It

If you want to experiment, grab the latest from the repo and write some `na {}` blocks:

```bash
curl -sSL https://docs.jaseci.org/install.sh | bash
```

The lambda syntax is the same whether you're in native or interpreted mode. Write your code in `na {}`, and the compiler handles the rest.

---

*Lambda support landed in [PR #5368](https://github.com/jaseci-labs/jaseci/pull/5368). Closures, generators, and native graph-spatial types are next on the roadmap.*
