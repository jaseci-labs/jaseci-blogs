---
date: '2026-07-12'
authors:
- jaseci-team
categories:
- Built with Jac
- Community
slug: ghostwatch-how-one-of-the-jachacks-winter-winners-built-an-autonomous-code-guardian-in-jac
repost: true
repost_url: https://dev.to/ayushmk/we-built-an-autonomous-code-guardian-in-a-weekend-heres-what-happened-4982
---

# GhostWatch: how one of the JacHacks Winter winners built an autonomous code guardian in Jac

Two University of Michigan freshmen, Ayush and Aaron, wrote up how they built **GhostWatch** over a single weekend at JacHacks Winter, an autonomous system that watches a repo for malicious dependency changes, tests the threat in a sandbox, writes a fix, and opens the pull request itself. It placed 2nd in the Agentic AI track.
 
<!-- more -->
 
## The problem: reviews miss what graphs would catch
 
Ayush and Aaron started from two gaps in normal code review. Reviewers rarely trace how a change actually propagates through a codebase, which functions depend on it, what tests cover it, what breaks downstream. And compromised packages pushed straight to a registry skip code review entirely, often running install scripts before anyone notices. Neither problem is really about reading a diff line by line. Both are about understanding a graph.
 
## Mapping blast radius as an actual graph
 
That's the piece Jac made easy. The repo is modeled directly as `FileNode` and `ImportEdge` objects, and a `BlastRadiusMapperWalker` walks outward from a changed file up to five hops to find everything it could affect:
 
```
node FileNode { has path, content, language, risk_score, is_test }
edge ImportEdge { has is_direct, import_type }
```
 
Three walkers, one for security, one for compatibility, one for blast radius, run over that same graph and merge into a single risk verdict, which then feeds an autonomous pipeline that sandboxes the dependency, generates a deterministic fix, and files the PR. The authors also pointed to Jac's `by llm` keyword for the parts that needed a model, calling out that it let them make typed LLM calls directly instead of writing JSON-parsing boilerplate.
 
## One language, start to finish
 
The whole thing, graph backend, autonomous pipeline, and a dual frontend for maintainers and contributors, was written in Jac, including a React-backed UI compiled from the same codebase. That's what let two students take it from idea to a working demo with passing tests in a weekend. Asked if they'd reach for Jac again, they said: "For an agentic system over structured data, yeah, and faster next time. The walker over a graph thing fit a code defense problem so well that most of our arguing was about the actual security logic, not plumbing."
 
They're upfront that some pieces are still rough, the sandboxing runs locally rather than in a cloud microVM, and part of the dashboard still leans on demo data, but the core idea holds up: an agent that reasons over a dependency graph as a graph, not as a wall of text.
 
Read the full write-up, with the demo video and source, on [dev.to](https://dev.to/ayushmk/we-built-an-autonomous-code-guardian-in-a-weekend-heres-what-happened-4982).
