---
date: 2026-06-29
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

**These products aren't chatbot demos.** They are live and full-stack: conversational interfaces, visual reasoning, document analysis, multimodal input, and multi-step agentic workflows, built for everything from academic advising and health to travel, finance, and career prep.

## One language, one semester

Building a full AI application usually means stitching together separate systems: one framework for the interface, another for the backend, a database layer underneath, and more tooling to call models and orchestrate workflows. Each seam is its own thing to learn, wire up, and keep from breaking, and for a four-person team on a deadline, a lot of the semester can disappear into that glue work instead of the product.

That is exactly where Jac came in. Its single-language design is a big reason a semester was enough: Jac and the Jaseci runtime let a team handle the interface, the application logic, the data, and the AI itself in one language. AI calls are part of the language rather than a bolted-on service, and Jac stays model-agnostic underneath, so teams could reach for whatever model fit without re-architecting anything. Less time on plumbing, more on the actual problem.

## From the showcase

The range shows what Jaseci made possible. Here are three standouts:

[**Skooch.ai**](http://skooch.ai) is an adaptive scheduling assistant that learns someone's focus windows and energy patterns, then places flexible tasks around fixed commitments from a plain-language prompt like "build me a study plan."

[**MaizeMind.com**](http://maizemind.com) turns half-formed notes into an interactive argument map, surfacing claims, evidence, and contradictions without ghostwriting, with Jac's graph data model mapping directly onto the argument structure.

[**EdgeCastApp.com**](http://edgecastapp.com) is a research terminal for prediction-market traders that links live Kalshi markets to a real-time newsfeed and an agent that already knows which market you're viewing.

The same story sits underneath all three: Jaseci was the common thread that made them feasible on a student timeline, letting each team keep the interface, the logic, the data, and the AI in one application instead of a stack of integrations.

You can explore the full lineup, with every team, demo videos, live apps, and GitHub repos, on the [EECS 449 projects showcase](https://jaseci-labs.github.io/eecs-449-projects/), and read more in the [U-M story](https://cse.engin.umich.edu/stories/students-build-agentic-ai-tools-for-work-travel-wellness).

<div class="cta cta-rich" markdown="1">
**Want to build something full-stack in a single language?** Install [Jac](https://www.jaseci.org/) and scaffold your first app in a few minutes, with the backend, frontend, and AI in one codebase, the same setup behind these 17 student projects.

[Try it yourself](https://docs.jaseci.org/){ .cta-button }
</div>
