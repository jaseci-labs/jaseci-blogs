---
date: 2026-02-20
authors:
  - mars
categories:
  - Jac Programming
  - AI & ML
  - Object-Spatial Programming
slug: agentic-object-spatial-programming
---

# Agents on Graphs: Agentic Object-Spatial Programming with Jaseci

*Four architecture patterns for AI agents that build context over time*

What makes an agent different from a chatbot? Not the model. Not the tools. **The context.**

<!-- more -->

A chatbot responds to what you just said, while an agent builds on everything it has ever seen. This context includes every query, every tool result, and every failure, allowing its understanding to *grow*. Over time, that accumulated context is what makes it intelligent.

But this context has to live somewhere. And where it lives changes everything: how the agent reasons, how it scales, how it recovers from failure.

We started with a single question:

!!! quote ""

    If an agent is a context that builds over time, **what shape does that context take?**

That question led us to **Object-Spatial Programming** and four architecture patterns that answer it in fundamentally different ways.

---

Before diving into these patterns, let's cover the building blocks they all share.

## Object-Spatial Programming

Object-Spatial Programming (OSP) gives context a shape. Instead of flat prompt strings, you get a graph. Instead of function chains, you get spatial relationships. Code and data live *where they belong* in the graph.

Three primitives:

| Primitive | Role | Think of it as... |
|---|---|---|
| **Walkers** | Move through the graph, carry context, trigger actions at every node | Agents with legs - they *travel* |
| **Nodes** | Locations in the graph that hold state and host abilities | Places where work happens |
| **Edges** | Connect nodes, define who can reach whom | The topology of your agent system |

Jac is the language built for OSP. With Jac, this is all it takes:

```jac
node Expert    { has knowledge: list[str] = []; }
walker advisor { has query: str; }

root ++> Expert();                    # connect a node to the graph
advisor(query="recommend a film") spawn root;  # launch a walker
```

Four lines. A graph with an expert node. A walker that traverses it. No framework setup. No routing middleware. The code structure *is* the agent architecture.

---

## `by llm()` - When Functions Think

Any function in Jac can delegate its implementation to an LLM. You write the signature - the LLM fills in the logic:

```jac
def recommend(query: str, preferences: list[str]) -> str by llm();
```

The function name, parameter names, and types *are* the prompt. No templates. No string manipulation. You describe what you want through code, and the LLM delivers.

When you add tools to the function, it becomes a ReAct agent that can reason, call tools, and observe results - all in a single line:

```jac
def research(topic: str) -> str by llm(
    tools=[search_web, fetch_docs]
);
```

This is what we call **Meaning-Typed Programming**. The semantics of your code *are* the instructions to the LLM.

---

## `visit by llm()` - When Navigation Thinks

This is where OSP becomes truly agentic. Instead of writing routing logic with switch statements, enum-based dispatchers, or chain configurations, the walker asks the LLM to choose where to go:

```jac
visit [-->] by llm(incl_info={"User query": self.query});
```

One line. The LLM reads every connected node, understands what each one does, and chooses the right destination. Add a new capability tomorrow? Just connect a new node to the graph. The LLM discovers it automatically.

No routing tables. No orchestration code. The graph *is* the router.

!!! info "Independent of the patterns below"

    `visit by llm()` is syntax sugar that provides agentic decision-making for traversal. It can be combined with **any** of the four architecture patterns.

---

## Four Patterns, One Question

With walkers, nodes, edges, `by llm()`, and `visit by llm()`, four architecture patterns emerge. Each answers the same question differently:

!!! quote ""

    **Where does the agent's context live, and how does it grow?**

!!! note "Reading the diagrams"

    **Circles** represent nodes (stateful locations in the graph). **Teal rounded rectangles** represent walkers (agents that traverse). Dashed arrows show spawning or traversal, and the **amber highlight** marks whichever element is currently active.

---

### 1. Worker Bee { #worker-bee }

!!! abstract ""

    *Walkers spawn walkers. No nodes. Results bubble up.*

To demonstrate this, we built a **trip planner**. Give it a city and it researches food, sights, and transit in parallel, then combines everything into a complete itinerary. The entire pattern lives in walker-space - no graph edges, only spawn relationships.

<figure markdown="span">
  ![Worker Bee Pattern](../../assets/diagrams/worker_bee.gif){ loading=lazy }
  <figcaption>A parent walker spawns child walkers, each carrying its own tools</figcaption>
</figure>

Children work independently, report back, and the parent synthesizes everything into a final result.

??? example "Worker Bee - Code Sketch"

    ```jac
    # Each child walker - does one job, carries its own tools
    walker research_food {
        has city: str, result: str = "";

        def find(city: str) -> str by llm(
            tools=[search_restaurants]
        );
        can start with Root entry {
            self.result = self.find(self.city);
        }
    }

    # same as research_food walker
    walker research_sights { ... }
    walker research_transit { ... }

    # The parent walker - spawns children, merges results
    walker plan_trip {
        has city: str = "Tokyo";

        def build_itinerary(food: str, sights: str, transit: str) -> str by llm();

        can start with Root entry {
            # Spawn three child walkers
            food    = research_food(city=self.city) spawn root;
            sights  = research_sights(city=self.city) spawn root;
            transit = research_transit(city=self.city) spawn root;

            # Merge results into a final itinerary
            plan    = self.build_itinerary(food.result, sights.result, transit.result);
        }
    }
    ```

`plan_trip` is a walker. `research_food` is a walker. Walkers spawning walkers. No graph needed - the hierarchy lives entirely in walker-space.

!!! success "Where context lives"

    **Context builds in walkers**, split and merged across layers. Each child adds its own specialized research. The parent's final context is richer than any individual child's because it synthesizes across all branches.

!!! tip "When to use"

    Tasks that naturally decompose into multiple parts, such as research, analysis, or multi-part generation. Anywhere "divide and conquer" applies.

---

### 2. Traveler { #traveler }

!!! abstract ""

    *One walker carries all context through stateless toolbox nodes.*

To demonstrate this, we built a **developer assistant chatbot**. Ask it a Python question and it routes to the right toolbox - DocSearch for concepts, CodeHelper for running and linting code, or QnA for general conversation. The `chatbot` walker starts at root and the LLM picks which toolbox node to visit next. The walker's context grows at every stop.

<figure markdown="span">
  ![Traveler Pattern](../../assets/diagrams/traveler.gif){ loading=lazy }
  <figcaption>The walker moves through tool-nodes, building context at every stop</figcaption>
</figure>

Each node is a *toolbox* with a focused set of 2–3 related tools. The node does the work when the walker visits, but doesn't store any state between visits. The walker is the agent that remembers everything.

??? example "Traveler - Code Sketch"

    ```jac
    # The walker - carries all context, LLM picks where to go
    walker chatbot {
        has query: str, context: list[str] = [], response: str = "";

        can route with Root entry {
            visit [-->] by llm(incl_info={
                "User query": self.query,
                "Context so far": str(self.context)
            });
        }
    }

    # A toolbox node - stateless, does work when visited
    node DocSearch {
        def respond(query: str, context: list) -> str by llm(
            tools=[search_docs, fetch_example]
        );
        can process with chatbot entry {
            visitor.response = self.respond(visitor.query, visitor.context);
            visitor.context.append(f"[Docs] {visitor.response}");
        }
    }

    node CodeHelper { ... }  # same shape, different tools
    node QnA { ... }
    ```

The walker's journey through the graph *is* the chain-of-thought. The path taken is the reasoning trace.

Why not give one agent all tools in a flat list? Because the graph acts as **guardrails**. Tools are spatially separated into focused toolboxes. The LLM first picks the right toolbox, then the toolbox picks from its small set. Two-level decision making. Fewer wrong tool calls.

!!! success "Where context lives"

    **Context builds in the walker** as it travels. Nodes are stateless - they process what the walker brings and forget. The walker is the memory.

!!! tip "When to use"

    Tool-heavy agents, chatbots with diverse capabilities, any system where spatially organizing tools improves reliability.

---

### 3. Expert { #expert }

!!! abstract ""

    *Domain nodes get smarter with every visit. The walker is just a courier.*

To demonstrate this, we built a **personal movie advisor**. Ask it for film recommendations and it routes to genre-specific experts: an ActionExpert for thrillers and martial arts, a ComedyExpert for rom-coms and satire. Each expert remembers every past recommendation *and* user feedback, so its suggestions genuinely adapt over time.

<figure markdown="span">
  ![Expert Pattern](../../assets/diagrams/expert.gif){ loading=lazy }
  <figcaption>Expert nodes remember every interaction and deepen their knowledge</figcaption>
</figure>

Unlike Traveler where nodes forget, Expert nodes *remember*. Every visit enriches them. The walker brings a query - and optionally a rating of a previous suggestion - so the node reasons using accumulated knowledge that includes real user preferences, not just logged history.

??? example "Expert - Code Sketch"

    ```jac
    # Courier walker - carries query in, response out, optionally a rating
    walker advisor {
        has query: str = "", rating: str = "", response: str = "";

        can route with Root entry {
            visit [-->] by llm(incl_info={"User query": self.query});
        }
    }

    # Expert node - remembers recommendations AND user feedback
    node ActionExpert {
        has knowledge: list[str] = [];

        def recommend(query: str, preferences: list[str]) -> str by llm();

        can advise with advisor entry {
            if visitor.rating {
                self.knowledge.append(f"Feedback: {visitor.rating}");
            }
            response = self.recommend(visitor.query, self.knowledge);
            self.knowledge.append(f"Q: {visitor.query} | Rec: {response}");
            visitor.response = response;
        }
    }

    node ComedyExpert { ... }  # same shape, different domain
    ```

Visit 1: a generic recommendation. Visit 5: the user rates a suggestion ("loved the choreography, hated the gore"), and the node adjusts. Visit 50: deeply personalized, drawing on a rich history of *actual preferences*, not just logged queries. The node *is* the expert. Not the walker. Not the model.

!!! success "Where context lives"

    **Context builds in the nodes.** A node visited fifty times is fundamentally more capable than one visited once. The walker is a courier that triggers and feeds the nodes.

!!! tip "When to use"

    Recommendation systems, personalized assistants, domain-specific advisors - anything that should get better at a domain the more it's used.

---

### 4. Collab { #collab }

!!! abstract ""

    *Peer nodes. No supervisor. Each agent decides locally who else to involve.*

To demonstrate this, we built a **blog post creator**. Drop a topic and the Researcher gathers information, the Writer drafts a post, and the Reviewer evaluates quality. If the draft isn't good enough, the Reviewer sends feedback back to the Writer for revision. There is no supervisor agent - instead, peers make local decisions about who should work next.

<figure markdown="span">
  ![Collab Pattern](../../assets/diagrams/collab.gif){ loading=lazy }
  <figcaption>Peer nodes collaborate without a supervisor - the path emerges from local decisions</figcaption>
</figure>

Every node is an equal. There is no coordinator deciding who talks to whom. Each peer finishes its work, looks at what it produced, and decides which peer should see it next.

??? example "Collab - Code Sketch"

    ```jac
    # Structured review decision - the type system enforces the choice
    enum Decision { APPROVED, NEEDS_REVISION }
    obj ReviewResult { has decision: Decision, feedback: str = ""; }

    # Message walker - traverses between peers
    walker message { has content: str = "", sender: str = ""; }

    # Researcher - researches, then sends walker to Writer
    node Researcher {
        has findings: str = "";
        def research(topic: str) -> str by llm();

        can handle with message entry {
            self.findings = self.research(visitor.content);
            visitor.content = self.findings;
            visitor.sender = "Researcher";
            visit [-->](?:Writer);
        }
    }

    # Writer - writes/revises, tracks revision history
    node Writer {
        has draft: str = "", revision_history: list[str] = [];
        def write(research: str) -> str by llm();
        def revise(draft: str, feedback: str, revision_history: list[str]) -> str by llm();

        can handle with message entry {
            if visitor.sender == "Researcher" {
                self.draft = self.write(visitor.content);
            } elif visitor.sender == "Reviewer" {
                self.draft = self.revise(self.draft, visitor.content, self.revision_history);
                self.revision_history.append(visitor.content);
            }
            visitor.content = self.draft;
            visitor.sender = "Writer";
            visit [-->](?:Reviewer);
        }
    }

    # Reviewer - structured decision, remembers past feedback
    node Reviewer {
        has review_count: int = 0, past_feedback: list[str] = [];
        def review(draft: str, past_feedback: list[str]) -> ReviewResult by llm();

        can handle with message entry {
            self.review_count += 1;
            result = self.review(visitor.content, self.past_feedback);
            self.past_feedback.append(result.feedback);

            if result.decision == Decision.APPROVED or self.review_count >= 3 {
                print(f"=== Final Blog Post ===\n{visitor.content}");
            } else {
                visitor.content = result.feedback;
                visitor.sender = "Reviewer";
                visit [-->](?:Writer);
            }
        }
    }
    ```

Three things to notice. First, each peer decides locally where the walker goes next - `visit [-->](?:Writer)`, `visit [-->](?:Reviewer)` - no central coordinator. Second, the Reviewer's `review` function returns a `ReviewResult` with an explicit `Decision` enum, not free text - the type system enforces the choice. Third, every peer builds its own context: the Writer accumulates `revision_history`, the Reviewer accumulates `past_feedback`. No single peer has the full picture. Together, they do.

!!! success "Where context lives"

    **Context builds distributed across all peers.** No single node has the full picture. Together, they do.

!!! tip "When to use"

    Creative workflows, research teams, any domain where experts need to collaborate flexibly without rigid process.

---

## Where Does Context Live?

Four patterns. One question. Four answers.

| Pattern | Context lives in | How it grows | Shape | Jac feature |
|---|---|---|---|---|
| **Worker Bee** | Multiple walkers | Split and merge across layers | Tree | `spawn` |
| **Traveler** | The walker | Accumulates at each stop | Path | `visit by llm()` |
| **Expert** | The nodes | Deepens with every visit | Depth | node state |
| **Collab** | All peers | Lateral sharing between equals | Mesh | peer-to-peer `visit` |

Each pattern captures a fundamentally different shape of context. Worker Bee builds a tree. Traveler builds a path. Expert builds depth. Collab builds a mesh.

And these patterns compose. A Collab network where each peer is an Expert that remembers. A Worker Bee whose children are Travelers navigating tool graphs. A system that starts as one pattern and evolves into another as requirements grow.

The agent isn't the model. It's the graph the model walks. And the shape of that graph - the shape of the context - is the real design decision.

Object-Spatial Programming gives you the primitives to make that decision explicit, composable, and surprisingly concise. Each pattern above fits in fewer lines of code than most configuration files. No boilerplate. No framework ceremony. Just the architecture, expressed directly.
