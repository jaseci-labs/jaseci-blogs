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

[![JacHacks Spring 2026 — where the series went global: 300+ participants, 81 projects, 4 days, 13 winners](../../assets/jachacks-spring-2026-hero.jpg)](https://jachacks.org/spring/)

<!-- more -->

## The Kickoff

Jac creator Jason Mars opened the weekend with the kickoff keynote. If you missed it live, the recording below picks up right where the keynote starts:

<div style="position: relative; width: 100%; padding-bottom: 56.25%; margin: 1.5em 0;">
  <iframe style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;" src="https://www.youtube.com/embed/JHBLmoU7zVk?start=310" title="Opening Ceremony and Keynote Speech | JacHacks Spring" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
</div>

## Real Problems, Real Agents
 
The theme across almost every winning project was the same: builders weren't making chatbots, they were making agents that go out and *do* things. Teams shipped systems that triage medical cases, investigate fraud, negotiate with insurance companies, and coordinate food deliveries, all running autonomously once pointed at a problem.
 
What stood out most this time, though, is how many teams talked about *how fast* they got there, and almost all of them said Jac was a big part of why.
 
## Why Jac Made These Projects Easier to Build
 
Building a full agentic AI application, complete with a frontend, a backend, a database, and a prompt-engineering layer, is a lot to pull off in one weekend, let alone make it good enough to compete. Jac let teams skip most of that glue code and get straight to the idea.
 
Much of that comes down to Jac treating graphs and language models as built-in parts of the language instead of things you bolt on. Agents can be written directly as Jac walkers that move across a graph, so there's no separate agent framework to wire in. On the AI side, meaning-typed programming lets you describe what a function should do through its type signature and a short description, and the compiler builds the prompt from there, no folder of prompt files required. And since Jac compiles down to both backend and frontend, teams could build the whole app in one place instead of hand-coding the plumbing between layers.
 
Put together, that's a lot of the usual hackathon setup tax gone, which is a big part of why 81 projects came out of a single weekend.

Participants didn't have to figure all of that out on their own, either. The Agentic AI workshop from the event walks through building an agentic application with Jac end to end, and the recording works just as well as a self-paced on-ramp today:

<div style="position: relative; width: 100%; padding-bottom: 56.25%; margin: 1.5em 0;">
  <iframe style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;" src="https://www.youtube.com/embed/V4MVTPspMVs" title="Agentic AI workshop | JacHacks Spring" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
</div>

## What Builders Told Us

We didn't just want to guess how the weekend went, so we asked. In the post-event survey (12 responses), one number frames everything else: **10 of the 12 respondents had never touched Jac before the hackathon** — and yet not a single one said they felt *less* productive than in their usual stack.

<div style="display: flex; flex-wrap: wrap; gap: 12px; margin: 1.5em 0;">
  <div style="flex: 1 1 150px; box-sizing: border-box; border: 1px solid rgba(128,128,128,0.35); border-radius: 8px; padding: 14px 18px;"><span style="display: block; font-size: 1.8em; font-weight: 600; line-height: 1.15;">10 of 12</span><span style="display: block; font-size: 0.82em; opacity: 0.75; margin-top: 4px;">were brand new to Jac</span></div>
  <div style="flex: 1 1 150px; box-sizing: border-box; border: 1px solid rgba(128,128,128,0.35); border-radius: 8px; padding: 14px 18px;"><span style="display: block; font-size: 1.8em; font-weight: 600; line-height: 1.15;">8 of 12</span><span style="display: block; font-size: 0.82em; opacity: 0.75; margin-top: 4px;">felt more productive than in their usual stack</span></div>
  <div style="flex: 1 1 150px; box-sizing: border-box; border: 1px solid rgba(128,128,128,0.35); border-radius: 8px; padding: 14px 18px;"><span style="display: block; font-size: 1.8em; font-weight: 600; line-height: 1.15;">8.2 / 10</span><span style="display: block; font-size: 0.82em; opacity: 0.75; margin-top: 4px;">average likelihood to keep using Jac</span></div>
  <div style="flex: 1 1 150px; box-sizing: border-box; border: 1px solid rgba(128,128,128,0.35); border-radius: 8px; padding: 14px 18px;"><span style="display: block; font-size: 1.8em; font-weight: 600; line-height: 1.15;">12 of 12</span><span style="display: block; font-size: 0.82em; opacity: 0.75; margin-top: 4px;">want to join the Jac community</span></div>
</div>

When we asked what the best part of the stack was, the two ideas at the heart of the language came out on top — graph-based programming and writing the whole app, front to back, in one language:

**What builders liked most about the Jaseci stack**

<svg viewBox="0 0 680 252" width="100%" style="max-width: 680px; display: block; margin: 0.5em 0;" role="img" aria-label="Horizontal bar chart: graph-based programming 9, one language for the full stack 8, byLLM for AI features 6, simpler database operations 3, Jac-builder 2, authentication 1">
  <title>What builders liked most about the Jaseci stack</title>
  <g font-size="13.5" fill="currentColor" text-anchor="end">
    <text x="205" y="25">Graph-based programming</text>
    <text x="205" y="65">One language, full stack</text>
    <text x="205" y="105">byLLM for AI features</text>
    <text x="205" y="145">Simpler database operations</text>
    <text x="205" y="185">Jac-builder</text>
    <text x="205" y="225">Authentication</text>
  </g>
  <g fill="#e8622c">
    <path d="M215,10 h374 a4,4 0 0 1 4,4 v14 a4,4 0 0 1 -4,4 h-374 z"/>
    <path d="M215,50 h332 a4,4 0 0 1 4,4 v14 a4,4 0 0 1 -4,4 h-332 z"/>
    <path d="M215,90 h248 a4,4 0 0 1 4,4 v14 a4,4 0 0 1 -4,4 h-248 z"/>
    <path d="M215,130 h122 a4,4 0 0 1 4,4 v14 a4,4 0 0 1 -4,4 h-122 z"/>
    <path d="M215,170 h80 a4,4 0 0 1 4,4 v14 a4,4 0 0 1 -4,4 h-80 z"/>
    <path d="M215,210 h38 a4,4 0 0 1 4,4 v14 a4,4 0 0 1 -4,4 h-38 z"/>
  </g>
  <g font-size="13" font-weight="600" fill="currentColor">
    <text x="602" y="25">9</text>
    <text x="560" y="65">8</text>
    <text x="476" y="105">6</text>
    <text x="350" y="145">3</text>
    <text x="308" y="185">2</text>
    <text x="266" y="225">1</text>
  </g>
  <line x1="214.5" y1="6" x2="214.5" y2="236" stroke="currentColor" stroke-opacity="0.3" stroke-width="1"/>
</svg>

<em style="font-size: 0.8em; opacity: 0.7;">"Which is the best part of the Jaseci stack that you liked?" — post-event survey, 12 respondents, multiple selections allowed.</em>

The productivity question tells the same story from another angle. On a 1–5 scale from "much less productive" to "much more productive" than their usual stack, nobody landed below the midpoint — in a language 10 of them had met four days earlier:

**Compared to their usual stack, how productive did builders feel?**

<svg viewBox="0 0 460 212" width="100%" style="max-width: 460px; display: block; margin: 0.5em 0;" role="img" aria-label="Column chart of productivity ratings on a 1 to 5 scale: no responses at 1 or 2, four responses at 3, five at 4, three at 5">
  <title>Compared to their usual stack, how productive did builders feel?</title>
  <g fill="#e8622c">
    <path d="M218,168 v-100 a4,4 0 0 1 4,-4 h16 a4,4 0 0 1 4,4 v100 z"/>
    <path d="M303,168 v-126 a4,4 0 0 1 4,-4 h16 a4,4 0 0 1 4,4 v126 z"/>
    <path d="M388,168 v-74 a4,4 0 0 1 4,-4 h16 a4,4 0 0 1 4,4 v74 z"/>
  </g>
  <g font-size="13" font-weight="600" fill="currentColor" text-anchor="middle">
    <text x="60" y="160" opacity="0.55" font-weight="400">0</text>
    <text x="145" y="160" opacity="0.55" font-weight="400">0</text>
    <text x="230" y="56">4</text>
    <text x="315" y="30">5</text>
    <text x="400" y="82">3</text>
  </g>
  <line x1="30" y1="168.5" x2="430" y2="168.5" stroke="currentColor" stroke-opacity="0.3" stroke-width="1"/>
  <g font-size="12.5" fill="currentColor" opacity="0.65" text-anchor="middle">
    <text x="60" y="188">1</text>
    <text x="145" y="188">2</text>
    <text x="230" y="188">3</text>
    <text x="315" y="188">4</text>
    <text x="400" y="188">5</text>
  </g>
  <g font-size="11" fill="currentColor" opacity="0.55" text-anchor="middle">
    <text x="70" y="206">much less productive</text>
    <text x="390" y="206">much more productive</text>
  </g>
</svg>

<em style="font-size: 0.8em; opacity: 0.7;">"Compared to your usual programming stack, how productive did you feel?" — post-event survey, 12 respondents.</em>

A couple of answers from the free-text responses sum up the vibe better than the numbers do:

> "My first time working with a new language in a hackathon environment. As a full-time quantum-control software engineer and part-time AI engineer, I loved this."

> "I didn't expect much when I first heard about it, but once I started using it in the project it shocked me how easy it is to implement. Going to use this language for future projects and hackathons."

The feedback wasn't all roses, and that's the useful part: documentation and examples (7 of 12) and CLI error messages (5 of 12) topped the list of things builders want improved. Consider that heard.

## Track Winners
 
**Agentic AI Track** went to [*CivicMesh*](https://devpost.com/software/civicmesh-0ctxl5) by Anbuchelvan Ganesan, a multi-agent navigator that routes people in crisis, like single mothers, undocumented families, or elderly tenants, to the housing, food, healthcare, and legal aid they qualify for, in multiple languages, with every decision showing its full reasoning. Runner-up [*MediGraph*](https://devpost.com/software/medigraph) by Soujanya Chatti used agents that reason through drug interactions biochemically instead of just looking them up, flagging dangerous combinations and suggesting safer alternatives.
 
**Consumer Healthcare Track** was won by [*CONSILIUM*](https://devpost.com/software/consilium-mqu6w3) from Tony Y, a diagnostic system where seven AI specialist agents debate a case and cross-examine the evidence before narrowing it down to the three most likely diagnoses. Second place [*Persist*](https://devpost.com/software/persist-yindp5) by Patrick Wang went a step further than most insurance tools: it doesn't just file prior-authorization claims, it fights back when they're denied, generating ERISA-compliant appeal letters on its own.
 
**Fintech Track** went to [*Sentinel*](https://devpost.com/software/sentinel-multi-agent-fraud-investigation-system) by Yash Patil, where five Jac walkers traverse a Medicare claims knowledge graph together and turn scattered fraud signals into fully cited investigations with 98% precision, flagging an estimated $50.6M in fraud exposure across 200 providers. Runner-up [*Killbill*](https://devpost.com/software/killbill-wam45d) by Ibrahim Pima keeps an eye on your subscriptions, figures out which ones you're not actually using, and drafts the cancellation email for you.
 
**Social Impact Track** was won by [*Nourish*](https://devpost.com/software/demo-wrtjkc) from Viktor Nedev, which matches surplus food in real time with shelters and volunteer drivers so it gets where it's needed before it goes to waste. Second place [*Orion & Diana*](https://devpost.com/software/orion-eua8x9) by Pranav Rajesh Krishnan spots marine oil spills in satellite imagery faster than a human reviewer could, using trained ML models to classify oil slicks as they happen.
 
## Special & Sponsor Awards
 
Five more teams picked up special recognition. [*Ori*](https://devpost.com/software/ori-4mscde) by Ahmed Hammad took home both **Best Use of Jac** and **Best Use of Featherless.AI** for a full-stack Jac template that lets vehicles talk to each other for safer, more fuel-efficient driving. [*FutureOS*](https://devpost.com/software/futureos-f03dgs) by Kshitij Kumrawat also won **Best Use of Jac**, for a graph-native "life OS" where six agents turn long-term goals into daily missions and coaching, with all its data persisted directly in Jac's graph store instead of a separate database. [*PairUp*](https://devpost.com/software/pairup-qmjrke) by Harshith Nair and Anjika Singh won **Best Demo** with a swipe-based way to find technical co-founders and teammates. [*DepGraph*](https://devpost.com/software/depgraph) by Shailesh Hawale won **Best LinkedIn Post** for a security agent that traces dependency graphs, flags CVEs, and writes up remediation plans, using six of Jac's built-in agent primitives to let an LLM decide which package to investigate next without any hardcoded logic. And [*Drowzie*](https://devpost.com/software/drowzie) by Shashank Shekhar won **Best Use of Lovable** for a sleep-tracking app that finds the habits actually correlated with your sleep quality and nudges you to fix them.

## Beyond the Weekend Project

A hackathon project doesn't have to end when the weekend does. Between build sessions, Vatsal Shah sat down to share his journey through Y Combinator and the startup world — well worth a watch if one of these 81 projects (or yours) is secretly a company:

<div style="position: relative; width: 100%; padding-bottom: 56.25%; margin: 1.5em 0;">
  <iframe style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;" src="https://www.youtube.com/embed/E7KaxOKLcWQ" title="My journey through YC and startups" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
</div>

## What's Next
 
Huge congrats to every team that shipped, and a big thanks to Featherless.AI and Lovable for sponsoring. You can browse all the winners, and every project that was submitted, over on the [JacHacks Spring winners page](https://jachacks.org/spring/). If reading about what these teams pulled off in a weekend made you want to try it yourself, the [Jac docs](https://docs.jaseci.org/) are the best place to start, and keep an eye on [jachacks.org](https://jachacks.org/) for the next hackathon.
