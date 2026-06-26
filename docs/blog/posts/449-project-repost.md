---
date: 2026-06-26
authors:
  - jaseci-team
categories:
  - Community
  - Developers
slug: 449-project-repost
repost: true
repost_url: "https://cse.engin.umich.edu/stories/students-build-agentic-ai-tools-for-work-travel-wellness"
repost_source: "Students build agentic AI tools for work, travel, wellness"
draft: true
---

# What 75 students shipped in one semester with Jac

<p class="lead" markdown="1">The University of Michigan's CSE division just published a [story on the final showcase for **EECS 449: Conversational AI**](https://cse.engin.umich.edu/stories/students-build-agentic-ai-tools-for-work-travel-wellness), where **75+ students**, working in teams, built **17 full-stack AI applications** in a single Winter semester, most of them in [Jac](https://www.jaseci.org/).</p>

<!-- more -->

**These weren't chatbot demos.** They were live, full-stack products: conversational interfaces, visual reasoning, document analysis, multimodal input, and multi-step agentic workflows, built for everything from academic advising and health to travel, finance, and career prep.

## One language for the whole stack

Building a full AI application usually means stitching together separate systems: one framework for the interface, another for the backend, a database underneath, and more tooling to call models and orchestrate workflows, with every seam its own thing to learn, wire up, and keep from breaking. **That glue work eats up much of a semester, and it is exactly what Jac removes.** **Jac and the Jaseci runtime let a team handle the interface, the application logic, the data, and the AI itself in one language, with model calls native to the language rather than a bolted-on service and model-agnostic underneath, so teams could reach for whatever model fit without re-architecting anything.** Less time on plumbing, more on the actual problem, which is most of why a single semester was enough.

## A few from the showcase

The range shows what Jaseci made possible. Three very different products, all shipped on a student timeline:

[**Skooch.ai**](http://skooch.ai) is an adaptive scheduling assistant that learns someone's focus windows and energy patterns, then places flexible tasks around fixed commitments from a plain-language prompt like "build me a study plan."

[**MaizeMind.com**](http://maizemind.com) turns half-formed notes into an interactive argument map, surfacing claims, evidence, and contradictions without ghostwriting, with Jac's graph data model mapping directly onto the argument structure.

[**EdgeCastApp.com**](http://edgecastapp.com) is a research terminal for prediction-market traders that links live Kalshi markets to a real-time newsfeed and an agent that already knows which market you're viewing.

The same story sits underneath all three: Jaseci was the common thread that made them feasible on a student timeline, letting each team keep the interface, the logic, the data, and the AI in one application instead of a stack of integrations.

You can explore the full lineup, with every team, demo videos, live apps, and GitHub repos, on the [EECS 449 projects showcase](https://jaseci-labs.github.io/eecs-449-projects/), and read more in the [U-M story](https://cse.engin.umich.edu/stories/students-build-agentic-ai-tools-for-work-travel-wellness).

## Try it yourself

Want to build something full-stack in a single language? You can install Jac and scaffold a project in a few minutes. The [getting started guide](https://docs.jaseci.org/learn/getting_started/) walks through setup and your first app, with the backend, frontend, and AI in one codebase, the same setup these teams used to ship in a semester.

<div class="cta" markdown="1">
Same backend, frontend, and AI, all in one language. The setup behind 17 student apps is a few minutes away.

[Get started with Jac](https://www.jaseci.org/){ .cta-button }

[Documentation](https://docs.jaseci.org/) · [GitHub](https://github.com/jaseci-labs/jaseci)
</div>
