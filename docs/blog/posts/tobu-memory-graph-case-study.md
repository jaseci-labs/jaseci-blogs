---
date: '2026-06-06'
authors:
- savini
categories:
- Community
slug: tobu-memory-graph-case-study
---

# How Tobu Used Jaseci to Build an AI-Powered Memory Graph

<p class="lead" markdown="1">Built with [Jaseci](https://www.jaseci.org/), **[Tobu](https://tobu.life/)** turned its AI-powered personal memory platform from concept to production-ready system, fast enough to support the company's early traction and **$1.5M raise**.</p>

<!-- more -->

<div class="stat-grid" markdown="1">
<div class="stat-card" markdown="1"><span class="stat-num">2 weeks</span><span class="stat-label">to a working demo</span></div>
<div class="stat-card" markdown="1"><span class="stat-num">6 weeks</span><span class="stat-label">to production-ready</span></div>
<div class="stat-card" markdown="1"><span class="stat-num">0</span><span class="stat-label">prompt engineering pipelines</span></div>
<div class="stat-card" markdown="1"><span class="stat-num">92.84%</span><span class="stat-label">retrieval accuracy on real Tobu user data</span></div>
<div class="stat-card" markdown="1"><span class="stat-num">2.2×</span><span class="stat-label">fewer missed memories than traditional RAG</span></div>
<div class="stat-card" markdown="1"><span class="stat-num">$1.5M</span><span class="stat-label">raised so far</span></div>
</div>

<figure class="phone-row" markdown="1">
<img src="/assets/tobu-4.jpg" alt="The Tobu app inviting a user to capture their first memory" />
<img src="/assets/tobu-1.jpg" alt="The Tobu memory wall showing photo memories with AI-generated descriptions, dates, and locations" />
<figcaption>From a first photo to a wall of memories: every photo becomes a memory with its own story, date, and place.</figcaption>
</figure>

Tobu is rethinking how people preserve digital memories. Its AI-powered memory app helps users capture not just photos and videos, but the stories, people, places, emotions, and context behind them.

That vision created a backend challenge. Tobu was not building a simple photo-storage app. It needed to manage a connected system of memories, users, relationships, places, privacy rules, sharing actions, comments, notifications, and AI-assisted storytelling.

## Tobu's Backend Challenge: Memories Are Connected, Not Isolated

Most photo apps are designed around storage. A user uploads an image, the system saves the file, stores basic metadata such as time and location, and makes the image available later.

Tobu needed to go further. For Tobu, a photo is only the beginning of a memory. The real value comes from the context around that photo: who was there, where it happened, what the moment was about, how the user felt, and who should be able to access it.

Those details are connected. A memory may involve multiple people. A person may be connected to many memories. A place may link different moments together. A shared memory may need different access rules depending on the relationship between users. AI-generated descriptions also need to connect back to the right memory in a reliable way.

<figure class="phone" markdown="1">
<img src="/assets/tobu-3.jpg" alt="Tobu's Shared Memories screen, a collage of memories shared between people" />
<figcaption>Shared memories: a single moment can connect several people, each with their own access.</figcaption>
</figure>

> For Tobu, a photo is only the beginning of a memory. The real value comes from the context around it: who was there, where it happened, what the moment was about, and who should be able to see it.

## Why Tobu Needed More Than a Conventional Backend

In a conventional backend, this kind of logic can quickly become scattered. The database stores users, photos, comments, permissions, and metadata. API endpoints handle actions such as creating memories, sharing content, or viewing a memory. Permission checks are repeated across different routes. AI calls require prompt handling, response parsing, and validation.

Each layer may work on its own, but the overall system becomes harder to evolve as the product grows. Tobu needed a backend model that matched the shape of its product, not one that forced connected memories into disconnected pieces.

## Where Jac Fit: Modeling Tobu's Product as a Graph

Jaseci gave Tobu a way to model the application in the same shape as the user experience. With Jac, based on [Object-Spatial Programming](https://docs.jaseci.org/reference/language/osp/), developers can represent applications as graphs of connected objects. Nodes represent entities, edges represent relationships, and walkers represent actions that move through the graph.

This model fit Tobu naturally. Users, memories, people, places, comments, permissions, and shared access could all be represented as connected parts of one system.

Instead of spreading the memory model across separate backend layers, Jac made it possible to keep the structure of the product closer to the structure of the code. A memory could be treated not as an isolated record, but as part of a larger network of people, places, stories, and relationships.

That architectural fit helped the team move quickly from idea to implementation. Tobu was able to build an initial demo in approximately **2 weeks** and reach a production-ready release within approximately **6 weeks**.

> With Jac, the structure of the product stayed close to the structure of the code. A memory was treated not as an isolated record, but as part of a larger network of people, places, stories, and relationships.

## How Jac's `by llm` Supported AI-Assisted Storytelling

Tobu also needed AI to support storytelling. Capturing the meaning behind a memory often requires more than storing user-entered text. The product needed LLM-powered behavior to help collect, organize, and preserve the details that make a memory meaningful.

<figure class="phone" markdown="1">
<img src="/assets/tobu-2.jpg" alt="Tobu generating an AI summary of a memory and asking a follow-up question to capture its story" />
<figcaption>Tobu uses <code>by llm</code> behavior to summarize a memory and ask follow-up questions that draw out its story.</figcaption>
</figure>

In many AI applications, developers have to manually manage prompt templates, model calls, response parsing, validation, and glue code between the AI layer and the backend. This creates extra engineering work and makes the system harder to maintain as features evolve.

Jac's [`by llm`](https://byllm.jaseci.org/) feature helped remove that burden. Instead of treating AI as a separate layer of prompt engineering and response handling, developers could describe LLM-powered behavior directly in code, closer to typed application logic.

> For Tobu, this meant AI features could be added without building and maintaining extensive prompt-engineering pipelines. Using Jac's `by llm` capabilities, the team integrated LLM-powered functionality directly into the application logic, making it easier to enable AI-assisted experiences.

## Graph-Based Retrieval for Better Memory Search

Tobu's memory experience also depended on retrieval quality. Users do not always search for memories with exact keywords. They may ask about people, places, events, emotions, or relationships that connect across many memories.

Traditional RAG systems often depend on chunking and text similarity. That works well when the answer is contained in a specific piece of text, but it can miss relevant memories when the connection depends on relationships between people, places, events, or other memories rather than shared keywords.

Because Tobu's memories were already modeled as a graph in Jac, graph-based retrieval was built directly into the application architecture. When a user searched for a memory, the system could identify related people, places, events, or moments, then follow the graph connections around them to find the most relevant context. Instead of relying only on text similarity, Tobu retrieved memories through the relationships that made those memories meaningful.

> In evaluation on real Tobu user data, this graph-based retrieval achieved **92.84% retrieval accuracy** and found **2.2× fewer missed memories** than traditional RAG systems.

## The Outcome: A Backend That Matched the Product

Jaseci helped Tobu move from idea to production faster while simplifying both AI development and memory retrieval.

Using Jac's graph-native programming model, Tobu built an initial demo in approximately **2 weeks** and reached a production-ready release within approximately **6 weeks**. Jac's native LLM capabilities eliminated the need for manual prompt engineering, allowing AI-powered memory features to be integrated directly into the application logic.

The impact extended beyond simplifying the architecture. By retrieving memories through their connections to people, places, events, and other moments, Tobu achieved **92.84% retrieval accuracy** and **2.2× fewer missed memories** than traditional RAG systems on real Tobu user data.

Tobu demonstrates how Jaseci can accelerate development for AI-native applications by combining graph-native architecture, built-in AI capabilities, and high-quality retrieval in a single programming model.

---

The retrieval system behind Tobu is detailed in our EMNLP 2025 paper:

<div class="citation" markdown="1">
Savini Kashmira, Jayanaka L. Dantanarayana, Joshua Brodsky, Ashish Mahendra, Yiping Kang, Krisztian Flautner, Lingjia Tang, and Jason Mars. 2025. [TOBUGraph: Knowledge Graph-Based Retrieval for Enhanced LLM Performance Beyond RAG](https://aclanthology.org/2025.emnlp-industry.93/). In *Proceedings of the 2025 Conference on Empirical Methods in Natural Language Processing: Industry Track*, pages 1349–1356, Suzhou, China. Association for Computational Linguistics.
</div>

<div class="cta" markdown="1">
Curious what graph-native memory feels like? Tobu turns your photos into a living web of the people, places, and stories behind them, all powered by [Jaseci](https://www.jaseci.org/).

[Explore Tobu](https://tobu.life/){ .cta-button }
</div>
