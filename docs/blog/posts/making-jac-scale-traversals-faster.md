---
date: 2026-03-24
authors:
  - asim
categories:
  - Jac Programming
slug: making-jac-scale-traversals-faster
---

# How We Made Jac-Scale Graph Traversals 5x Faster

If you've ever worked with a graph database at scale, you've probably hit the N+1 query problem. It's one of those things that doesn't show up in development but absolutely kills you in production. We ran into it with Jac's tiered memory system and spent a week figuring out the right fix. This is the story of what we tried, what failed, and what actually worked.

<!-- more -->

## The Problem

Jac uses a tiered memory hierarchy — L1 is an in-process cache, L2 is Redis, and L3 is your database (MongoDB or SQLite). Graph anchors are stored as serialized blobs keyed by UUID. Simple enough.

The trouble starts when a walker traverses edges. Say you have a node with 100 edges and you do `[-->]`. The runtime iterates through each edge stub, and the first time you touch any property on that stub, it calls `populate()`, which calls `mem.get(id)` — one database round-trip. Then it does the same for the target node on the other end of the edge.

So for 100 edges: 1 fetch for the origin + 100 fetches for edges + 100 fetches for targets = **201 individual database queries**. Each one is 1-10ms against MongoDB over the network. That adds up fast.

At 500 edges you're looking at 1,001 queries and over 1.5 seconds just to traverse from a single node. Not great.

## The First Attempt: Structured Metadata Columns

The initial idea seemed reasonable — surface `anchor_type`, `archetype`, `source`, and `target` as queryable fields alongside the serialized blob. This would let us use MongoDB aggregation pipelines and SQL JOINs to resolve traversals in fewer queries. Filter push-down to the database. Indexed lookups without deserializing blobs. All the good stuff.

We implemented it. Added 4 columns and 3 partial indexes in SQLite, 4 top-level document fields and 3 indexes in MongoDB. Auto-migration from the old schema. All 12 CI checks passed. Felt pretty good about it.

Then we ran the benchmarks.

### SQLite Results

| Metric | Before (ms) | After (ms) | Change |
|--------|:-----------:|:----------:|:------:|
| Build (100 nodes, 1K edges) | 1,240 | 1,188 | ~same |
| Build (500 nodes, 5K edges) | 3,476 | 5,645 | **+62%** |
| `-->` (100 results) | 4.0 | 3.1 | -22% |
| `-->(?:PersonNode)` (50) | 2.6 | 1.2 | -54% |

### MongoDB Results

| Metric | Before (ms) | After (ms) | Change |
|--------|:-----------:|:----------:|:------:|
| Build (100 nodes, 1K edges) | 2,714 | 7,588 | **+180%** |
| Build (500 nodes, 5K edges) | 8,773 | 78,948 | **+800%** |
| `-->` (600 results) | 14.6 | 21.0 | +44% |
| `->:KnowsEdge:->` (10) | 1.1 | 11.8 | **+970%** |

That MongoDB write regression was brutal. Building a graph with 500 nodes went from 8.7 seconds to nearly 79 seconds. An **800% increase**. And traversals actually got *slower* too.

What happened? Every `put()` now had to extract metadata and write 6 fields instead of 2. Larger documents meant more serialization and network overhead. Three indexes needed updating on every single write. And the worst part — the runtime still used the same N+1 `populate()` path for traversals, so none of the query optimizations were actually being used.

We did verify that the approach works at the raw database level. Bypassing the Jac runtime entirely and querying MongoDB directly with pymongo:

| Operation | N+1 (ms) | Aggregation (ms) | Speedup |
|-----------|:--------:|:----------------:|:-------:|
| Traversal (20 edges) | 26.8 | 3.1 | **8.5x** |
| Type-filtered (10 matches) | 29.9 | 5.4 | **5.5x** |
| Archetype lookup (250 matches) | 1,279 | 3.8 | **341x** |

The aggregation pipeline approach is legitimately powerful — 341x faster for archetype lookups. But the problem was wiring it into the runtime. The walker `-->` operators go through `edges_to_nodes()` which calls `populate()` on each stub sequentially. The metadata columns were sitting there in the database, fully indexed, completely unused by the actual code path that walkers take.

**Rejected.** Adding cost where it hurts (writes) without changing anything where it matters (reads).

## The Fix: batch_get()

After staring at this for a while, the answer turned out to be much simpler. Instead of restructuring the storage schema, just change how many things we fetch at once.

We added a `batch_get(ids: list[UUID])` method to the Memory interface. Instead of calling `find_one()` 201 times, call `find({_id: {$in: [...]}})` once and get all 201 anchors back in a single round-trip.

The implementation was 76 lines of code. Zero lines modified. No schema changes. No new indexes. No migration.

The trick is a `_prefetch_edges()` function that runs before the filter loop in `edges_to_nodes()`. It collects all edge stub IDs, batch-fetches them into L1, then collects all target node IDs from those loaded edges and batch-fetches those too. By the time the original filter loop runs, every `populate()` call hits L1. The runtime code doesn't even know anything changed.

## Benchmarking — The Hard Part

Here's something that tripped us up and is worth talking about. Our first benchmark showed **zero improvement**. Absolutely nothing. We spent time debugging before realizing the benchmark itself was the problem.

The standard `jac run benchmark.jac` builds a graph and traverses it in the same process. After `root ++> PersonNode(...)`, that node is sitting right there in L1. When the walker does `[-->]`, every `populate()` hits L1 — zero L3 fetches. `batch_get` is a no-op because all the IDs are already in memory.

The N+1 problem only shows up when:

1. L1 is empty — fresh request, different worker, cold start
2. Edges are stubs — loaded from the database with just a UUID
3. Each `populate()` actually goes to the database

This is a production-only problem. In development with SQLite, everything is sub-millisecond anyway. In a single-process benchmark, L1 has everything cached. You have to deliberately simulate cold-start conditions to see it.

So we built a cold-start benchmark — clear L1, measure individual `find_one()` calls vs `find({$in: [...]})` batch queries directly against MongoDB.

### Cold Start Results — 100 Edges

| Method | DB Queries | Latency | Speedup |
|--------|:----------:|:-------:|:-------:|
| N+1 (`find_one` per anchor) | 201 | 159 ms | baseline |
| `batch_get()` API | 3 | 30.6 ms | **5.2x** |
| Raw pymongo `$in` | 3 | 8.7 ms | **18x** |

### Cold Start Results — 500 Edges

| Method | DB Queries | Latency | Speedup |
|--------|:----------:|:-------:|:-------:|
| N+1 (`find_one` per anchor) | 1,001 | 1,539 ms | baseline |
| `batch_get()` API | 3 | 462 ms | **3.3x** |
| Raw pymongo `$in` | 3 | 65.7 ms | **23x** |

201 queries down to 3. 1,001 queries down to 3. That's the difference between "one indexed `$in` lookup" and "hundreds of individual `find_one` calls."

And zero write overhead — build times were identical before and after.

## The Deserialization Gap

You'll notice there's a gap between the `batch_get()` API results (3-5x) and the raw pymongo `$in` results (18-23x). That gap is deserialization.

Each anchor blob has to be individually parsed by `Serializer.deserialize()`. For a single NodeAnchor with 20 edges, deserialization constructs 1 NodeAnchor + 1 Permission + 1 Access + 1 archetype + 20 EdgeAnchor stubs = 24 Python objects. Scale that to 500 anchors and you're constructing 12,000+ Python objects sequentially. Each anchor's deserialization is independent — there's no shared state to amortize, and the recursive dispatch pattern prevents vectorization.

The raw `$in` result shows us the ceiling — that's what's possible if deserialization cost went to zero. The batch_get API result is what we actually deliver today. Still a solid 3-5x, and the query reduction from hundreds to 3 is the important structural change.

## How This Fits with TopologyIndex

Worth mentioning how `batch_get` relates to the TopologyIndex work (PR #5205). They solve different parts of the same problem:

| | TopologyIndex | batch_get |
|---|:---:|:---:|
| **What it eliminates** | Unnecessary UUIDs (type filter before fetch) | Unnecessary round-trips (batch fetch) |
| **When it helps** | Type-filtered queries like `-->(?:Type)` | All traversals |
| **Write cost** | Re-encoded on every mutation | Zero |

They're complementary. TopologyIndex resolves `-->(?:PersonNode)` to a UUID set — say 50 out of 500. Then `batch_get` fetches those 50 in 1 query instead of 50 queries. Filter first, then batch fetch the filtered set.

## What We Learned

**Benchmark what matters.** Our first benchmarks showed nothing because they weren't testing the actual production scenario. Warm-graph, single-process tests are useful for catching regressions, but they'll never expose a cold-start database problem.

**Don't change writes to fix reads.** The structured metadata approach was elegant on paper but added cost to every single write operation while the read path didn't even use it. Read-path-only changes like `batch_get` have zero write overhead by definition.

**Fix the actual code path.** The Jac runtime's `edges_to_nodes()` function is where traversals happen. Adding query capabilities to the database doesn't help if the runtime never uses them. We had to change the runtime itself — specifically, prefetch into L1 before the filter loop runs.

**Simple beats clever.** 76 lines. No schema changes. No indexes. No migrations. Just "fetch many things at once instead of one at a time." Sometimes the boring solution is the right one.

The PR is [#5270](https://github.com/Jaseci-Labs/jaseci/pull/5270) if you want to look at the code. The full benchmark methodology and results are in `BENCHMARKS_AND_FINDINGS.md` in that PR.
