---
date: 2026-07-12
authors:
  - jaseci-team
categories:
  - Community
  - Built with Jac
slug: jachacks-spring-2026-300-builders-81-projects-one-weekend-of-jac
draft: true
---

# JacHacks Spring 2026: 300+ Builders, 81 Projects, One Weekend of Jac

[**JacHacks Spring**](https://jachacks.org/spring/) ran from May 15 to May 19, 2026, bringing together **300+ builders from around the world** for a global online hackathon. Over four days, teams shipped **81 projects**, most of them built with Jac and the Jaseci stack, competing across four tracks: Agentic AI, Consumer Healthcare, Fintech, and Social Impact. Sponsors Featherless.AI and Lovable also handed out special awards for the best use of their tools.
 
<!-- more -->
 
## Real Problems, Real Agents
 
The theme across almost every winning project was the same: builders weren't making chatbots, they were making agents that go out and *do* things. Teams shipped systems that triage medical cases, investigate fraud, negotiate with insurance companies, and coordinate food deliveries, all running autonomously once pointed at a problem.
 
What stood out most this time, though, is how many teams talked about *how fast* they got there, and almost all of them said Jac was a big part of why.
 
## Why Jac Made These Projects Easier to Build
 
Building a full agentic AI application, complete with a frontend, a backend, a database, and a prompt-engineering layer, is a lot to pull off in one weekend, let alone make it good enough to compete. Jac let teams skip most of that glue code and get straight to the idea.
 
Much of that comes down to Jac treating graphs and language models as built-in parts of the language instead of things you bolt on. Agents can be written directly as Jac walkers that move across a graph, so there's no separate agent framework to wire in. On the AI side, meaning-typed programming lets you describe what a function should do through its type signature and a short description, and the compiler builds the prompt from there, no folder of prompt files required. And since Jac compiles down to both backend and frontend, teams could build the whole app in one place instead of hand-coding the plumbing between layers.
 
Put together, that's a lot of the usual hackathon setup tax gone, which is a big part of why 81 projects came out of a single weekend.
 
## Track Winners
 
**Agentic AI Track** went to [*CivicMesh*](https://devpost.com/software/civicmesh-0ctxl5) by Anbuchelvan Ganesan, a multi-agent navigator that routes people in crisis, like single mothers, undocumented families, or elderly tenants, to the housing, food, healthcare, and legal aid they qualify for, in multiple languages, with every decision showing its full reasoning. Runner-up [*MediGraph*](https://devpost.com/software/medigraph) by Soujanya Chatti used agents that reason through drug interactions biochemically instead of just looking them up, flagging dangerous combinations and suggesting safer alternatives.
 
**Consumer Healthcare Track** was won by [*CONSILIUM*](https://devpost.com/software/consilium-mqu6w3) from Tony Y, a diagnostic system where seven AI specialist agents debate a case and cross-examine the evidence before narrowing it down to the three most likely diagnoses. Second place [*Persist*](https://devpost.com/software/persist-yindp5) by Patrick Wang went a step further than most insurance tools: it doesn't just file prior-authorization claims, it fights back when they're denied, generating ERISA-compliant appeal letters on its own.
 
**Fintech Track** went to [*Sentinel*](https://devpost.com/software/sentinel-multi-agent-fraud-investigation-system) by Yash Patil, where five Jac walkers traverse a Medicare claims knowledge graph together and turn scattered fraud signals into fully cited investigations with 98% precision, flagging an estimated $50.6M in fraud exposure across 200 providers. Runner-up [*Killbill*](https://devpost.com/software/killbill-wam45d) by Ibrahim Pima keeps an eye on your subscriptions, figures out which ones you're not actually using, and drafts the cancellation email for you.
 
**Social Impact Track** was won by [*Nourish*](https://devpost.com/software/demo-wrtjkc) from Viktor Nedev, which matches surplus food in real time with shelters and volunteer drivers so it gets where it's needed before it goes to waste. Second place [*Orion & Diana*](https://devpost.com/software/orion-eua8x9) by Pranav Rajesh Krishnan spots marine oil spills in satellite imagery faster than a human reviewer could, using trained ML models to classify oil slicks as they happen.
 
## Special & Sponsor Awards
 
Five more teams picked up special recognition. [*Ori*](https://devpost.com/software/ori-4mscde) by Ahmed Hammad took home both **Best Use of Jac** and **Best Use of Featherless.AI** for a full-stack Jac template that lets vehicles talk to each other for safer, more fuel-efficient driving. [*FutureOS*](https://devpost.com/software/futureos-f03dgs) by Kshitij Kumrawat also won **Best Use of Jac**, for a graph-native "life OS" where six agents turn long-term goals into daily missions and coaching, with all its data persisted directly in Jac's graph store instead of a separate database. [*PairUp*](https://devpost.com/software/pairup-qmjrke) by Harshith Nair and Anjika Singh won **Best Demo** with a swipe-based way to find technical co-founders and teammates. [*DepGraph*](https://devpost.com/software/depgraph) by Shailesh Hawale won **Best LinkedIn Post** for a security agent that traces dependency graphs, flags CVEs, and writes up remediation plans, using six of Jac's built-in agent primitives to let an LLM decide which package to investigate next without any hardcoded logic. And [*Drowzie*](https://devpost.com/software/drowzie) by Shashank Shekhar won **Best Use of Lovable** for a sleep-tracking app that finds the habits actually correlated with your sleep quality and nudges you to fix them.
 
## What's Next
 
Huge congrats to every team that shipped, and a big thanks to Featherless.AI and Lovable for sponsoring. You can browse all the winners, and every project that was submitted, over on the [JacHacks Spring winners page](https://jachacks.org/spring/). If reading about what these teams pulled off in a weekend made you want to try it yourself, the [Jac docs](https://docs.jaseci.org/) are the best place to start, and keep an eye on [jachacks.org](https://jachacks.org/) for the next hackathon.
