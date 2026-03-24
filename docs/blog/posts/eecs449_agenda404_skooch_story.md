---
date: 2026-03-22
authors:
  - zshuai
categories:
  - Developers
  - AI
  - Productivity
slug: eecs449-agenda404-skooch-story
---
# Building Skooch.ai in EECS 449: What Actually Happened Behind the Demo

When people see a class demo, they usually see the polished version: a clean UI, a confident pitch, and a product story that sounds linear.

Our reality was not linear.

I worked on **Agenda 404**, and we built **Skooch.ai** for EECS 449: a conversational scheduling assistant that tries to do more than store tasks. Our goal was to make scheduling feel adaptive, not static. We wanted the system to use priorities, hard constraints, and user patterns to generate a plan that could move with real life.

At first, that sounded straightforward. Then implementation started.

<!-- more -->

## The Product We Thought We Were Building

Our original concept was ambitious:

- Dynamic scheduling based on priority and deadlines
- Hard constraint handling (classes, meetings, fixed events)
- User profile driven planning (focus windows, preferences)
- AI assistant behavior for context ingestion from external sources

In one sentence, the dream was: **an AI secretary that could reason about your week**.

The turning point came after office hours feedback. We were told, correctly, that trying to do everything would likely produce a shallow system.

So we reduced scope to the core engine:

1. Task priority
2. Hard constraints

That single decision made progress possible.

## Week-by-Week Reality: Architecture Refactors, Then Bugs, Then More Refactors

One of our most important moves happened during a full code structure cleanup.

We separated the scheduler logic and API integration concerns out of the main entry flow. In practice, that meant the scheduling algorithm and the client/server integration boundaries became explicit modules instead of one growing file. The code was suddenly easier to reason about, easier to assign across teammates, and less fragile when we changed one feature.

But better structure did not magically remove bugs.

The recurring issues were painfully practical:

- Data did not consistently persist after refresh for events and profile preferences
- Repeating event semantics were partially wrong (for example, multi-day fixed events only remembered the last selected day)
- Calendar interactions felt unstable, especially drag-and-drop behavior
- Login UX had friction (keyboard submit behavior was inconsistent)
- Dashboard and onboarding needed clearer product guidance for first-time users

None of these are glamorous "AI" problems. They are product trust problems. If users cannot trust persistence and interaction consistency, they do not care how smart your model is.

## What We Learned About Building "AI Features" in a Team Project

The hardest lesson was this: AI integration should not come first if your product loop is not stable.

We had explicit plans to connect an LLM API to support conversational assistance and scheduling intelligence. But every time we pushed deeper into AI behavior before stabilizing storage, profile semantics, and event editing, we created more confusion instead of more value.

Eventually, we changed the order of operations:

1. Stabilize data contracts and persistence
2. Improve scheduler determinism on known inputs
3. Clean UI friction points that block usage
4. Layer AI integration where it improves decisions, not where it hides missing logic

That sequence sounds obvious now. It did not feel obvious when deadlines were close.

## Team Workflow That Actually Helped

We split ownership by system boundaries instead of by random features.

- Profile + scheduling logic optimization
- Supabase persistence and event memory behavior
- UI cleanup and usability fixes
- AI integration research and implementation path

This helped because each owner could make local progress without waiting for the entire stack to stabilize every day.

Another practical win was keeping sensitive credentials out of source control and using environment configuration. It is basic engineering hygiene, but in fast-moving class projects, this is easy to skip unless someone is actively enforcing it.

## Where Skooch.ai Felt Most Promising

Even with rough edges, two parts consistently felt strong:

1. **Constraint-aware planning**: the scheduler respected immovable commitments and could reflow around them.
2. **Explainability direction**: we pushed toward outputs that justify placement decisions instead of returning opaque suggestions.

For a scheduling product, explanations matter. Users are far more likely to accept a schedule if the system can say why a task was placed at a specific time.

## What I Would Do Differently If We Restarted

If I had to restart this project tomorrow, I would make three early commitments:

1. Freeze a minimal schema and event semantics contract by week one
2. Build deterministic scheduling tests before UI polish
3. Introduce AI only after persistence and interaction reliability are boringly stable

In student projects, the temptation is to lead with impressive features for demos. In practice, reliability wins trust, and trust is what makes advanced features believable.

## Final Reflection

Skooch.ai taught me that "conversational AI product" work is mostly systems work: data integrity, interface clarity, model boundaries, and careful scope control.

The flashy part is the assistant.

The real part is everything that makes the assistant dependable.

Our team did not build a perfect scheduler. But we did build a clearer understanding of what it takes to move from idea to usable decision engine under real constraints, and that learning was more valuable than any single sprint outcome.
