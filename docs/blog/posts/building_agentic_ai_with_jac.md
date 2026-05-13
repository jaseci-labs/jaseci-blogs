---
date: 2026-05-12
authors:
  - jayanaka
categories:
  - Jac Programming
  - AI
slug: building-agentic-ai-with-jac
---

# Déjà Vu: Why Every Agent Codebase Rebuilds the Same Seven Wheels

LLMs draft our emails, write our code, and run our businesses. We talk to them like coworkers and hand them our calendars. The moment we sit down to *build* one, the tooling drops back to HTTP requests and string concatenation.

---

## The Problem

<!-- more -->

An agent is a program built around LLM calls. The model does the thinking, and the code around it decides which calls to make, what to do with the results, and what to call next.

Today, most agents are built in Python or TypeScript. These languages were chosen for their ecosystem maturity, not because they were designed for agents. As a result, three problems show up in nearly every agent codebase.

**The same intent gets written twice.** A tool is a function *and* a JSON schema describing it. A structured output is a Pydantic class *and* a `response_format` argument. If we rename the function but forget the JSON spec, the spec still advertises the old name to the model. If we rename a field but forget the prompt that asks for it, the prompt still references the old one. Nothing in the build catches the mismatch, because the link between the code and the string only exists in the developer's head. Drift is silent until the model misbehaves at runtime.

**Control flow lives in prose.** When we want an agent to follow a specified workflow, that workflow ends up inside a system prompt in natural language, like *"First search, then summarize, then if the summary is too long, revise it."* Because the workflow only lives as a string, the code can't enforce or check the steps. There's no way to verify the agent followed the workflow correctly as specified.

**The plumbing is rebuilt every project.** Every agent codebase needs the same supporting machinery: a ReAct loop for tool use, retry logic around validation errors, a router that dispatches on a classifier output, a threadpool that fans work out and merges results. None of this is the agent's logic, but every team builds it themselves. That wastes engineering time, and bugs in the plumbing are hard to tell apart from bugs in the agent.

These three problems share a root cause. The parts that *are* the agent, its tools, its workflow, its retries, its parallelism, live in two places: as strings inside prompts, and as code that every team has to write from scratch. Neither place is something the language understands as an agent. So a question:

!!! quote ""

    *If agents were a feature of the language itself, instead of being built from prompts and code that developers need to write from scratch, what would the language need to provide?*

The answer is already in the [**Jac**](https://docs.jaseci.org/) programming language. Two ideas power it: **Meaning-Typed Programming** ([MTP](https://dl.acm.org/doi/10.1145/3763092)), brought in by the [**byLLM**](https://docs.jaseci.org/) plugin, and **Object-Spatial Programming** (OSP), Jac's native model for organizing computation around a graph. Together they give us **seven primitives** for building agents: three for what an LLM does inside a single call (the **Mind**), and four for how work moves between calls (the **Flow**). Every agent codebase already implements all seven, just by hand. The rest of this post is what those seven look like when the language has words for them.

!!! info "About the code"

    Every Jac snippet below is self-contained and runs with `jac run <file>.jac` against a configured model. Copy any block, save it, and you'll see the agent execute end-to-end.

<!-- ---

## The Gap

Two places agent logic actually ends up today:

**In the prompt.** *"First do X, then if Y do Z, retry up to three times."* Flexible, fast to write, completely unverified. A typo fails silently. A smaller model defects without warning. The prose costs thousands of tokens on every turn because the model has to re-read it to know what comes next.

**In glue code.** A tool dispatcher checks `allowed-tools` before the model gets a turn. A retry runner re-invokes on parse failure. A session store holds memory. Real code, with real types, but every team writes its own, and it's rigid per-capability: a skill is either fully structured or fully prose. There is no in-between.

Either way, the things developers care about are out of reach: type-checked workflows, refactor-safe agents, testable control flow, predictable behavior on smaller models. That's the gap the seven primitives are designed to close. -->

---

## The Mind

Three things any single LLM call usefully does:

1. **Generate**: LLM returns free text from a function signature.
2. **Extract**: LLM returns typed data validated against a schema.
3. **Invoke**: LLM calls tools in a ReAct loop until it has an answer.


### 1. Generate

LLM returns free text. The function signature is the prompt.

<div class="collapse" data-lines="10">

```python
# Python: an LLM call is an HTTP request with a string
from openai import OpenAI
client = OpenAI()

def answer(question: str) -> str:
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You answer questions about any topic."},
            {"role": "user", "content": question},
        ],
    )
    return response.choices[0].message.content
```

</div>

```jac
# Jac: an LLM call is a function
"""Answer a question about any topic."""
def answer(question: str) -> str by llm();

with entry {
    response = answer("What are three interesting facts about computer architecture?");
}
```

The Python version has no information in it that the Jac version doesn't. Model name, system prompt, question, return type, all of it lives in the Jac signature, docstring, and runtime config. To change the agent's behavior in Jac, change the signature. Not a YAML file. Not a prompt template. The semantics of the code *are* the prompt. Jac calls this **Meaning-Typed Programming**.

### 2. Extract

LLM returns typed data. The compiler enforces the schema.

<div class="collapse" data-lines="10">

```python
# Python: schema declared twice, once as a type, once as an API argument
from pydantic import BaseModel
from enum import Enum
from openai import OpenAI

class Topic(str, Enum):
    HARDWARE = "HARDWARE"; SOFTWARE = "SOFTWARE"
    NETWORKS = "NETWORKS"; AI = "AI"; OTHER = "OTHER"

class PaperClassification(BaseModel):
    topic: Topic
    one_line_summary: str
    key_contributions: list[str]

def classify_paper(title: str, abstract: str) -> PaperClassification:
    response = OpenAI().beta.chat.completions.parse(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "Classify a research paper..."},
            {"role": "user", "content": f"Title: {title}\n\nAbstract: {abstract}"},
        ],
        response_format=PaperClassification,
    )
    return response.choices[0].message.parsed   # may be None, must check
```

</div>

In Jac:

```jac
enum Topic { HARDWARE, SOFTWARE, NETWORKS, AI, OTHER }

obj PaperClassification {
    has topic: Topic;
    has one_line_summary: str;
    has key_contributions: list[str];
}

def classify_paper(title: str, abstract: str) -> PaperClassification by llm();
sem classify_paper = "Classify a research paper by its title and abstract.";

with entry {
    result = classify_paper(
        title="Attention Is All You Need",
        abstract="The dominant sequence transduction models are based on..."
    );
    # result.topic is a Topic enum member, result.key_contributions is list[str]
}
```

The return type *is* the schema; the compiler knows about it. If the model produces something malformed, the runtime retries with the validation error in scope, automatically. The `try / json.loads / pydantic.ValidationError` layer that lives in every production agent today doesn't exist here.

### 3. Invoke

LLM calls tools. ReAct in one line.

<div class="collapse" data-lines="10">

```python
# Python: hand-rolled ReAct
TOOLS = [
    {"type": "function", "function": {
        "name": "search_papers",
        "description": "Search for academic papers by query.",
        "parameters": {"type": "object",
            "properties": {"query": {"type": "string"}},
            "required": ["query"]}}},
    # ... two more, declared by hand
]
DISPATCH = {"search_papers": search_papers, ...}

def research(query: str) -> str:
    messages = [{"role": "system", "content": "Research..."},
                {"role": "user",   "content": query}]
    while True:                                          # the loop, by hand
        msg = client.chat.completions.create(...).choices[0].message
        messages.append(msg.model_dump(exclude_none=True))
        if not msg.tool_calls: return msg.content        # the stop, by hand
        for call in msg.tool_calls:                      # the dispatch, by hand
            args = json.loads(call.function.arguments)
            result = DISPATCH[call.function.name](**args)
            messages.append({"role": "tool",
                             "tool_call_id": call.id,
                             "content": str(result)})
```

</div>

The dispatch table re-declares functions that already exist. The tool schema re-declares parameters that are already typed. The while-loop re-implements the ReAct cycle every team in the world is re-implementing this week.

In Jac:

```jac
# Tool stubs (in a real app these'd hit an API)
def search_papers(query: str) -> str { return f"3 papers found for '{query}'"; }
def get_citations(paper_id: str) -> int { return len(paper_id) * 100; }
def summarize_abstract(text: str) -> str { return f"Summary of: {text[:30]}..."; }

def research(query: str) -> str by llm(
    tools=[search_papers, get_citations, summarize_abstract]
);
sem research = "Research a topic by searching papers, checking citations, and summarizing findings.";

with entry {
    findings = research("Recent papers on transformer architectures and their citation impact");
}
```

Tools are just functions. The runtime introspects their signatures, exposes them to the model, runs the ReAct loop, and only returns when the model says it's done.

---

That's the Mind. Three primitives, one per LLM call. With them in hand, you can wire calls together with `for` loops and `if` statements and convince yourself you have an agent. But the moment two calls need to talk, the moment one's output feeds the next, or a retry kicks in, or three workers run in parallel, that wiring is the agent, and your `for` loop is doing the agent's job in plain Python. That work has a different shape. It belongs in the next four primitives.

---

## The Flow

Four kinds of wiring between Mind calls:

1. **Pipe**: sequential composition. One call's output is the next call's input.
2. **Route**: pick which handler runs based on what came in.
3. **Loop**: repeat until a typed quality check passes.
4. **Spawn**: fan out parallel work, fan in the results.


### 1. Pipe

Pipe is a literal chain of nodes wired by edges, with a walker that visits each in turn and carries state forward.

<figure markdown="span">
  ![Pipe Pattern](../../assets/diagrams/pipe.gif){ loading=lazy }
</figure>

```jac
node Draft    { def run(topic: str) -> str by llm(); }
node Examples { def run(draft: str) -> str by llm(); }
node Summary  { def run(detail: str) -> str by llm(); }
node Done     {}

walker Explainer {
    has topic: str;
    has text: str = "";

    can do_draft with Draft entry {
        self.text = here.run(self.topic);
        visit [-->];
    }
    can do_examples with Examples entry {
        self.text = here.run(self.text);
        visit [-->];
    }
    can do_summary with Summary entry {
        self.text = here.run(self.text);
        visit [-->];
    }
}

with entry {
    draft = Draft();  ex = Examples();  summ = Summary();  done = Done();
    root ++> draft;  draft ++> ex;  ex ++> summ;  summ ++> done;
    root spawn Explainer(topic="How cache coherence works in multicore processors");
}
```

Each step is a small, scoped prompt living on its node. None see the others' instructions, only the typed data the walker carries forward. To insert a fact-check stage tomorrow, connect a new node into the chain. The graph *is* the pipeline.

### 2. Route

The LLM reads the graph and picks which node the walker visits.

```jac
node HardwareExpert {
    has description: str = "Expert in CPU, GPU, memory hierarchies, chip fabrication";
    def answer(q: str) -> str by llm();
    can respond with ResearchAssistant entry {
        visitor.response = self.answer(visitor.query);
    }
}
node SoftwareExpert {
    has description: str = "Expert in compilers, operating systems, runtimes";
    def answer(q: str) -> str by llm();
    can respond with ResearchAssistant entry {
        visitor.response = self.answer(visitor.query);
    }
}
node AIExpert {
    has description: str = "Expert in neural networks, LLMs, machine learning systems";
    def answer(q: str) -> str by llm();
    can respond with ResearchAssistant entry {
        visitor.response = self.answer(visitor.query);
    }
}

walker ResearchAssistant {
    has query: str;
    has response: str = "";
    can route with Root entry {
        visit [-->] by llm(incl_info={"User query": self.query});
    }
}

with entry {
    root ++> HardwareExpert();
    root ++> SoftwareExpert();
    root ++> AIExpert();

    q = "How do branch predictors work in modern CPUs?";
    r = root spawn ResearchAssistant(query=q);
}
```

The route is a single line: `visit [-->] by llm(...)`. The LLM reads each connected node's `description` field and picks. To add a new expert, add a `node` with a `description`. No prompt edit, no dispatch-table edit. The graph *is* the routing table.

### 3. Loop

Self-correction expressed as a cycle in the graph: draft, evaluate, and if the verdict isn't good enough, take a typed retry edge back to revise.

<figure markdown="span">
  ![Loop Pattern](../../assets/diagrams/loop.gif){ loading=lazy }
</figure>

```jac
enum Quality { GOOD, NEEDS_IMPROVEMENT }

obj Review {
    has quality: Quality;
    has weaknesses: list[str];
    has suggestion: str;
}

edge RetryEdge {
    has reason: str = "Verdict was NEEDS_IMPROVEMENT";
    has max_retries: int = 3;
}

node Draft    { def run(topic: str) -> str by llm(); }
node Evaluate { def run(draft: str, topic: str) -> Review by llm(); }
node Revise   { def run(draft: str, feedback: str) -> str by llm(); }
node Approved {}

walker TutorialWriter {
    has topic: str;
    has draft: str = "";
    has feedback: str = "";
    has version: int = 1;

    can do_draft with Draft entry {
        self.draft = here.run(self.topic);
        visit [-->];
    }

    can do_evaluate with Evaluate entry {
        review = here.run(self.draft, self.topic);
        if review.quality == Quality.GOOD {
            visit [-->][?:Approved];
        } else {
            self.feedback = f"{review.weaknesses}. {review.suggestion}";
            visit [->:RetryEdge:->];
        }
    }

    can do_revise with Revise entry {
        self.version += 1;
        self.draft = here.run(self.draft, self.feedback);
        visit [-->];
    }
}

with entry {
    draft = Draft();   eval_n = Evaluate();
    revise = Revise(); done   = Approved();

    root ++> draft ++> eval_n;
    eval_n ++> done;
    eval_n +>:RetryEdge:+> revise;
    revise ++> eval_n;

    root spawn TutorialWriter(topic="How cache coherence works in multicore processors");
}
```

`RetryEdge` is a typed edge with a name and its own fields. Scanning the graph, a reader sees `eval_n +>:RetryEdge:+> revise` and knows what kind of loop this is. A `while` in a function body could be anything; a `RetryEdge` is one specific thing. The exit condition rides on a typed `Quality` verdict, not a string-match on the model's reply.

### 4. Spawn

`flow spawn` fans out work; `wait` fans it back in.

<figure markdown="span">
  ![Spawn Pattern](../../assets/diagrams/spawn.gif){ loading=lazy }
  <figcaption>The orchestrator fans out to parallel workers, then synthesizes their merged results</figcaption>
</figure>

```jac
def search_papers(query: str) -> str { return f"papers on '{query}'"; }
def get_citations(paper_id: str) -> int { return 1247; }

walker HardwareResearcher {
    has topic: str;
    has result: str = "";
    def investigate(topic: str) -> str by llm(tools=[search_papers, get_citations]);
    can start with Root entry {
        self.result = self.investigate(self.topic);
    }
}
walker SoftwareResearcher {
    has topic: str;
    has result: str = "";
    def investigate(topic: str) -> str by llm(tools=[search_papers, get_citations]);
    can start with Root entry {
        self.result = self.investigate(self.topic);
    }
}
walker AIResearcher {
    has topic: str;
    has result: str = "";
    def investigate(topic: str) -> str by llm(tools=[search_papers, get_citations]);
    can start with Root entry {
        self.result = self.investigate(self.topic);
    }
}

walker SurveyAgent {
    has topic: str;
    has response: str = "";
    def synthesize(topic: str, hw: str, sw: str, ai: str) -> str by llm();

    can start with Root entry {
        hw_task = flow root spawn HardwareResearcher(topic=self.topic);
        sw_task = flow root spawn SoftwareResearcher(topic=self.topic);
        ai_task = flow root spawn AIResearcher(topic=self.topic);

        hw: any = wait hw_task;
        sw: any = wait sw_task;
        ai: any = wait ai_task;

        self.response = self.synthesize(self.topic, hw.result, sw.result, ai.result);
    }
}

with entry {
    root spawn SurveyAgent(topic="Efficient inference for large language models");
}
```

Each researcher carries its own scoped tool list and its own context. Three focused prompts running concurrently, not one bloated prompt holding nine tools and hoping the model picks correctly.

---

That's the Flow. Four kinds of wiring, each a property of the graph instead of a paragraph in a prompt. Plus the three Mind primitives, that's the whole list. Most of every agent codebase you've ever read is one of these seven, rebuilt by hand because the host language couldn't host it.

---

## The Takeaway

Jac has all seven Mind and Flow primitives directly in the language. A developer expresses an agent as code, with types, instead of as prose in a prompt or glue around an LLM call.

The agents people are actually shipping aren't there yet. The most prominent open-source projects are all in Python or TypeScript:

- [**OpenClaw**](https://github.com/openclaw/openclaw): personal assistant across 20+ chat channels (TypeScript)
- [**Hermes**](https://github.com/NousResearch/hermes-agent) (Nous Research): self-improving agent (Python)
- [**OpenCode**](https://github.com/anomalyco/opencode): open-source coding agent (TypeScript)

Those languages weren't chosen because they're a natural fit for agents. They were chosen for library support and ecosystem maturity, nothing more. It's a reasonable trade, but it has a cost: every team rebuilds the same plumbing from scratch, and the codebase bloats around the missing primitives.

The same handful of subsystems shows up in every codebase. In Jac, each one collapses to a single primitive or a small composition of them:

| What every agent codebase builds by hand | In Jac |
|---|---|
| **Capability loader**: injects rules into the prompt, manages the tool registry | `by llm(tools=[...])` |
| **Subagent spawner**: task queue, context isolation, result merging | `flow spawn` / `wait` |
| **Router**: switch on a classifier, prompt that returns a name, dispatch table | `visit [-->] by llm()` |
| **Loop runner**: while-loop over string verdicts, parse-and-pray exits | a typed edge closing a cycle in the graph |
| **Self-extension**: agent writes more English prose to its own capability file | add a node, add an edge |

!!! quote ""

    **With these primitives in the language, building an agent is just building the agent.**
