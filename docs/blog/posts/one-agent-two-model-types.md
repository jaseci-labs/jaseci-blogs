---
date: 2026-10-08
authors:
  - jayanaka
categories:
  - Engineering
slug: one-agent-two-model-types
draft: true
---

# How Jac Runs the Same AI Agent with Claude and Jev

An agent is walking through a graph. At every step, it needs to decide where to go next and whether it has found the answer. We can ask a chat model to make those decisions. We can also ask a model built specifically to choose between known answers. In Jac, both can run the same agent code.

<!-- more -->

<!-- Post-specific reading style. Keep this below the excerpt marker. -->
<style id="jac-model-reading-style">
.prose:has(#jac-model-reading-style) p {
  text-align: left;
  hyphens: none;
}
</style>

[PR #9656](https://github.com/jaseci-labs/jac/pull/9656) adds System One model support to byLLM. This post walks through a graph navigation demo using Claude Haiku 4.5 and TypeSafe's Jev, then looks at how Meaning-Typed Programming makes that switch possible.

## The task

Here is the first question in the demo:

> How do doctors see soft tissue inside the body using powerful magnets?

The answer is Magnetic Resonance Imaging. But the agent starts at **Jazz**.

The graph connects topics through broader fields. The agent has to follow those connections until it reaches a topic that answers the question. At a field node, it chooses the next neighbor. At a topic node, it first checks whether that topic answers the question. If it does, the walk stops. Otherwise, it chooses another neighbor and continues.

We run two walkers on the same graph, with the same question and starting point. One uses `openrouter/anthropic/claude-haiku-4.5`. The other uses `systemone:typesafe/jev-latest`.

<div style="position:relative;width:100%;padding-top:56.25%;">
  <iframe
    src="https://www.linkedin.com/embed/feed/update/urn:li:activity:7513623565024342016?compact=true"
    title="The same Jac agent with Claude and Jev"
    style="position:absolute;inset:0;width:100%;height:100%;border:0;"
    loading="lazy"
    allowfullscreen>
  </iframe>
</div>

[Watch the demo on LinkedIn](https://lnkd.in/p/d3X_tcvS)

In the first race, both take the same four-hop route:

**Jazz → Arts → Knowledge → Medicine → Magnetic Resonance Imaging**

The chat model finishes in **8.33 seconds**. Jev finishes in **1.02 seconds**. The dashboard reports **8.2× faster** and **30× cheaper** for that run.

<figure markdown="span">

![The first race ends at Magnetic Resonance Imaging for both walkers, with the same four-hop path and different recorded times and costs.](/assets/one-agent-two-model-types/mri-race.webp)

<figcaption>Same question, starting point, graph, and walker code. The model binding is different.</figcaption>
</figure>

## The same code makes both decisions

This is the decision and traversal core shown in the demo:

```jac
walker Navigator {
    def answers_here(topic: str, about: str) -> bool by self._brain();

    can route with Field entry {
        visit [-->] by self._brain(select=1);
    }

    can check with Topic entry {
        if self.answers_here(here.label, here.blurb) { disengage; }
        visit [-->] by self._brain(select=1);
    }
}
```

This is a fragment of the demo, with the graph setup, question context, model field, and UI omitted.

**The stop decision is a Boolean function.** `answers_here` takes the current topic's label and description and returns a `bool`. The walker carries the question being answered. The `if` and `disengage` are ordinary Jac control flow: the model supplies a decision, and the program acts on it.

**The next step is a choice among actual neighbors.** `[-->]` supplies the outgoing neighbors of the current node. `select=1` asks byLLM to choose one. Jac then visits the selected node. The model does not have to invent a node name for the application to look up later.

Neither operation requires an open-ended answer. One has two possible values. The other has a finite set of candidates that changes as the walker moves.

The two model bindings are:

```jac
Model(model_name="openrouter/anthropic/claude-haiku-4.5")
Model(model_name="systemone:typesafe/jev-latest")
```

Bind either one to the walker's `_brain`, and the decision and traversal code above stays the same.

## What Meaning-Typed Programming gives us

In [Building Agentic AI with Jac](https://github.com/jaseci-labs/jaseci-blogs/blob/main/docs/blog/posts/building_agentic_ai_with_jac.md), we looked at how Meaning-Typed Programming lets a function describe model work through its name, parameters, return type, and semantic annotations. byLLM uses that information to build the model request.

That becomes particularly useful when the return type describes a finite answer space.

A `bool` already tells us the possible answers. An enum already names the choices. A graph visit already has a collection of candidate nodes. The function's meaning describes the decision to make, and the input values describe the situation in which to make it.

**The program already contains the decision specification.** We do not need to maintain a second version of it in a separate provider schema.

For a chat model, byLLM uses this information to construct the prompt and output contract. For a System One model, it can use the same information to construct a decision request.

## What changes underneath

A chat model receives messages and generates a response. byLLM interprets that response against the expected return type and gives the Jac program a typed value. A chat provider may support structured output, but the operation is still response generation.

A System One model receives **state and questions with defined possible answers**. Jev returns probabilities over those answers without generating a free-form answer. byLLM uses the returned scores to select the value and reconstruct the type the caller expects.

<figure markdown="span">

![A shared Jac decision contract branches into a chat request that generates a response and a System One request that scores predefined answers. Both paths return the typed value expected by the same walker.](/assets/one-agent-two-model-types/model-paths_2.svg)

<figcaption>The application describes the decision once. The selected backend determines how that decision is answered. The diagram shows the normal successful paths; fallback is discussed below.</figcaption>
</figure>

At the **Knowledge** node in our example, the decision is which current neighbor to visit next. On the chat path, the request asks the model to choose using the question and candidate descriptions. On the System One path, those candidates become the allowed answers to a choice question. The selected answer maps back to an existing Jac node.

At **Magnetic Resonance Imaging**, the decision changes. Now `answers_here` asks whether the current topic answers the user's question. The System One request has a Boolean answer space, and the result comes back to the walker as `true` or `false`.

The agent does not need a different loop for either backend. It still chooses, visits, checks, and stops.

This is the high-level change in the runtime: **byLLM can now execute a typed call as a decision request as well as a generation request.** The model name selects the backend, and the call's types determine whether it fits the decision model.

## What the races show

All nine races in the recording reach the expected target with both models. Here are three that show different parts of the behavior. Times, costs, and hop counts are copied from the demo's display.

| Target | Chat time | Jev time | Chat cost | Jev cost | Hops, chat / Jev |
|---|---:|---:|---:|---:|---:|
| Magnetic Resonance Imaging | 8.33 s | 1.02 s | $0.00537 | $0.00018 | 4 / 4 |
| Video Games | 9.54 s | 0.95 s | $0.00699 | $0.00018 | 5 / 4 |
| Batteries | 6.04 s | 1.57 s | $0.00541 | $0.00028 | 4 / 6 |

Across the recording, the dashboard reports **3.9–10× faster** and **19–39× cheaper** for Jev. These are observations from this demo, not a benchmark establishing a general speed or accuracy guarantee. They include the particular models, providers, prices, and routes used in these runs.

**Same code does not mean identical decisions.** In the Video Games race, Jev takes a shorter route. In the Batteries race, it takes six hops while the chat model takes four. Both still find the expected topic, and Jev finishes sooner in both runs.

The stable part is the contract. Each backend returns the kind of decision the program asked for. Which valid choice is best remains a model quality question. A typed answer can still be the wrong answer.

## Using it in your own code

The latest Jac binary includes System One support in byLLM. The backend is present in [Jac v0.37.25](https://github.com/jaseci-labs/jac/releases/tag/v0.37.25), so you can use Jev now with a TypeSafe API key. With Jac installed, set the key:

```bash
export TYPESAFE_API_KEY="your-api-key"
```

For a project using the built-in `llm`, select Jev in `jac.toml`:

```toml
[byllm.model]
default_model = "systemone:typesafe/jev-latest"
```

Or bind a model explicitly with `Model`, as in the demo. Here is a complete, smaller example of the same stop decision. It passes the question directly rather than carrying it on a walker:

```jac
import from jaclang.byllm.lib { Model }

glob brain = Model(model_name="systemone:typesafe/jev-latest");

def answers_here(question: str, topic: str, about: str) -> bool by brain();
sem answers_here = "Decide whether this topic answers the question.";

with entry {
    print(answers_here(
        "How do doctors see soft tissue inside the body using powerful magnets?",
        "Magnetic Resonance Imaging",
        "A medical imaging technique that uses magnetic fields and radio waves."
    ));
}
```

Save it as `decision-check.jac` and run `jac run decision-check.jac`. Change only the model name to the chat model's identifier, configure that provider's credentials, and the same function works through the chat path.

`sem` is useful here: it states what the decision means. For enum results, semantic annotations on individual members also describe what each choice represents. Smaller decision models benefit from explicit descriptions, especially for ambiguous labels such as `OTHER`.

The integration supports Boolean results, enums, lists of enum members, and objects whose fields are enums or Booleans. Graph routing works because the current candidate nodes form a finite answer set. A function returning free text needs a generation model.

## Keep generation where you need it

An application can need both kinds of work. It might choose a route with Jev, then ask a chat model to explain what it found.

Configure a fallback to handle calls that the decision backend cannot serve:

```jac
glob brain = Model(
    model_name="systemone:typesafe/jev-latest",
    config={"fallback": "gpt-4o-mini", "min_confidence": 0.7}
);
```

With both providers' credentials configured, supported decisions go to Jev. Calls requiring free text, tools, or streaming go to the fallback. A supported decision whose confidence falls below the configured threshold is also re-asked of the fallback. Without a fallback, unsupported calls raise a configuration error.

If the application needs to inspect the decision itself, `Decision[T]` exposes the value, confidence, probabilities, and which backend answered. Confidence summarizes how concentrated the decision model's probabilities are. A threshold of `0.7` does not mean the answer has a measured 70% chance of being correct.

The [Decision Models guide](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/cli/docs/tutorials/ai/decision-models.md) covers these options, and the [byLLM reference](https://jaclang.org/docs/latest/reference/plugins/byllm) documents the broader model interface. The new [System One reference section](https://github.com/jaseci-labs/jac/blob/main/jac/jaclang/cli/docs/reference/plugins/byllm.md#system-one-models) contains the provider and return-type details.

## What this opens up

In the earlier agent programming post, the language owned the workflow while the model supplied the intelligence inside a step. This demo takes that separation further. The language also knows enough about the step to describe it to two different kinds of models.

The graph defines where the agent can move. The walker defines when it moves and when it stops. The types define what the model must return. That leaves the model free to change without rewriting the agent around a different API.

The design discussion is in [issue #9655](https://github.com/jaseci-labs/jac/issues/9655), and the integration is in [PR #9656](https://github.com/jaseci-labs/jac/pull/9656). The useful result is visible in the demo: one agent, one set of decisions, and two ways to answer them.
