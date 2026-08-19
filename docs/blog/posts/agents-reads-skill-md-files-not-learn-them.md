---
date: '2026-08-17'
authors:
- jaseci-team
categories:
- Built with Jac
slug: agents-reads-skill-md-files-not-learn-them
repost: true
repost_url: https://sigilagent.com/blog/agent-skills-should-be-compiled.html
repost_source: Agent skills should be compiled, not just read
---

# Agents Reads SKILL.md files, not learn them

Agent skills such as `SKILL.md` have become a popular way to give AI agents reusable procedures. But there is a fundamental gap between **telling an agent what procedure to follow and actually enforcing that procedure**.

SIGIL explores a different approach. Instead of leaving the entire skill as instructions in the model's context, it compiles the enforceable parts of the skill into a typed, executable agent harness written in Jac.

<!-- more -->

## The problem with skills as instructions

A skill might tell an agent to run a test suite, inspect the result, verify that every test passed, and only then report success. The model can read every one of those instructions and still skip the test, perform the steps out of order, or claim that verification happened when it did not. The problem is not necessarily understanding. The procedure itself is still just text that the model is being asked to follow. For workflows where particular steps **must** happen, instructions alone are a weak execution model.

## From `SKILL.md` to a Jac agent

SIGIL treats the skill more like source code.

It extracts the procedure into a typed intermediate representation called **AG-IR**, separates deterministic operations from steps that genuinely require model reasoning, validates the resulting workflow, and then mechanically lowers it into a runnable Jac agent harness.

That split fits naturally with Jac's programming model. Deterministic work such as running commands, checking exit codes, reading files, or enforcing approval gates becomes explicit program control flow. Tasks that require interpretation or generation remain model operations.

The model still reasons. It just no longer owns the entire procedure. A required test runs because the program executes it. A required approval becomes an actual gate. A required artifact is produced by an explicit operation rather than being something the model is merely reminded to create.

## What changes when the procedure becomes a program

Across 30 agent skills, SIGIL compared normal prose-based skill execution against compiled execution.

With GPT-4o, agents reading the skills as prose completed **56% of applicable required steps on average**. Compiling the same skills with SIGIL increased that to **86%**. With GPT-5, prose execution reached 68%, while compiled execution remained at 86%.

More importantly, the median compliance of the compiled harness was **100% with both models**.

The result points to a broader idea for agentic software. As agents take on longer and more consequential workflows, some parts of their behavior should not depend on whether a model remembers to follow an instruction. Those parts should become part of the program itself.

SIGIL keeps Markdown as the human-readable authoring format, then uses Jac to turn the procedure into executable agent control flow.

*Read the full write-up, including the compiler architecture, AG-IR, evaluation results, and how to try SIGIL, on [sigilagent.com](https://sigilagent.com/blog/agent-skills-should-be-compiled.html).*
