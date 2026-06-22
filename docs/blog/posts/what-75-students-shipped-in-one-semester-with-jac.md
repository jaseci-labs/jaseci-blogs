---
date: 2026-06-22
authors:
  - jayanaka
categories:
  - Community
slug: what-75-students-shipped-in-one-semester-with-jac
draft: true
---

# What 75 students shipped in one semester with Jac

The University of Michigan's CSE division recently published a [story on the final showcase for EECS 449: Conversational AI.](https://cse.engin.umich.edu/stories/students-build-agentic-ai-tools-for-work-travel-wellness) More than 75 students, working in teams, built 17 full-stack AI applications in a single Winter semester, and most of them were built in Jac.

These weren't chatbot demos. They were live products with conversational interfaces, visual reasoning, document analysis, multimodal input, and multi-step agentic workflows, spanning academic advising, health, travel, finance, athletics, software development, and career prep.

## One language for the whole stack

Building a full AI application usually means stitching together separate systems: one framework for the interface, another for the backend, a database layer underneath, and still more tooling to call models and orchestrate AI workflows. Each seam is its own thing to learn, wire up, and keep from breaking, and for a four-person team on a deadline, a lot of the semester can disappear into that glue work instead of the product.

In the U-M write-up, course instructor Jason Mars (CSE) points to the single-language design as a big reason a semester was enough. Jac and the Jaseci runtime let a team handle the interface, the application logic, the data, and the AI itself in one language, instead of context-switching between a frontend framework, a backend, a database access layer, and a separate AI orchestration stack. AI calls are part of the language rather than a bolted-on service, and Jac stays model-agnostic underneath, so teams could reach for whatever model fit, like Gemini in Skooch, without re-architecting anything. That left less time on plumbing and more on the actual problem: what the product should do and how the AI should help.

## Three from the showcase

[Skooch.ai](http://skooch.ai) is an adaptive scheduling assistant that learns how someone works, not just what's on their calendar. It profiles priorities, focus windows, buffer needs, and energy patterns, then scores time slots and places flexible tasks around fixed commitments so demanding work lands in high-energy windows. Users drive it in plain language, like "I have an exam Thursday, build me a study plan." In Jac, the interface, the optimization engine, and the Gemini-powered assistant were one application instead of three separate services to wire together.

[MaizeMind.com](http://maizemind.com) turns messy, half-formed notes into an interactive argument map, surfacing claims, evidence, weak support, and unaddressed contradictions. It deliberately doesn't ghostwrite; it keeps writers in control of their own reasoning. Jac's graph-based data model maps directly onto that argument structure, so the visual interface and the reasoning behind it shared one representation rather than a database and a separate graph layer.

[EdgeCastApp.com](http://edgecastapp.com) is a research terminal for prediction-market traders. It aggregates live Kalshi markets, links a real-time newsfeed to each one, and embeds an agent that already knows which market you're viewing, along with its prices, history, and related news. Pulling external data, application logic, and the contextual agent into a single workflow took one language instead of a stack of integrations.

## A semester of working AI products

These are a few of the applications presented at the showcase. You can explore the full lineup, with every team, demo videos, live apps, and GitHub repositories, on the [EECS 449 projects showcase](https://jaseci-labs.github.io/eecs-449-projects/).

For more on the course and the students, read the U-M story: [Students build agentic AI tools for work, travel, wellness](https://cse.engin.umich.edu/stories/students-build-agentic-ai-tools-for-work-travel-wellness).

## Try it yourself

Want to build something full-stack in a single language? You can install Jac and scaffold a project in a few minutes. The [getting started guide](https://docs.jaseci.org/learn/getting_started/) walks through setup and your first app, with the backend, the frontend, and the AI in one codebase, the same setup these teams used to ship in a semester.

[Get started with Jac →](https://www.jaseci.org/) · [Documentation](https://docs.jaseci.org/) · [GitHub](https://github.com/jaseci-labs/jaseci)

Jaseci's open-source work at the University of Michigan is supported by the NSF.
