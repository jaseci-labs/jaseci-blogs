---
date: 2026-03-16
authors:
  - nimesh
categories:
  - Developers
  - Jac Programming
  - AI & ML
slug: proto-mcp
---
# **ProtoMCP: The MCP Tool I Built After Fighting the Inspector for Hours**

The first time I tried testing an MCP server, I thought I was doing something wrong.

I connected to the server.  
Tried running a tool.  
Got an error.

So I tweaked the JSON.

Tried again.

Another error.

At some point I realized I wasn't building anything anymore. I was just debugging JSON-RPC plumbing.

<!-- more -->

If you've worked with the **Model Context Protocol (MCP)** recently, this experience might feel familiar. The protocol itself is elegant. The tooling around it is… still evolving.

And the moment that really pushed me over the edge was using **MCP Inspector**.

Technically it works. But practically, it felt like trying to debug a distributed system through a keyhole.

That frustration is what led to **[ProtoMCP](https://jac-mcp-playground.jaseci.org/)**.


## The Moment Everything Broke

While building MCP integrations, my workflow started looking like this:

1. Connect to a server  
2. Inspect the tool schema  
3. Manually construct a JSON-RPC request  
4. Send it  
5. Get an error  
6. Guess what went wrong  

Typical request:

```json
{
  "method": "tools/call",
  "params": { ... }
}
```

If anything changed — the schema, authentication, headers — the whole request had to be rewritten.

Then debugging started. Was the session header wrong? Did the server expect streaming? Was the schema slightly different? Did the response fail halfway through a stream?

The worst part wasn't the errors.

It was the lack of visibility.

When something failed, I'd add logs, restart the server, retry the request, and repeat. It worked, but it was slow. Painfully slow.

I kept thinking:

*"Why does testing MCP servers feel like writing a debugging tool every time?"*

That was the moment ProtoMCP started.

## What I Wanted Instead

I didn’t want another CLI.

I didn’t want another JSON editor.

What I wanted was something that felt like Postman for MCP — a place where you could connect to a server instantly, see all available tools, run them without writing JSON, inspect requests and responses, and debug everything visually.

Basically:

*A proper developer UI for MCP.*

So we built one.

## Introducing ProtoMCP

After a few late nights of debugging MCP servers, I realized the tool I wanted didn't exist.

So I built ProtoMCP — essentially a playground for connecting to MCP servers and seeing everything they expose without writing JSON.

Once connected, ProtoMCP automatically discovers:
- tools
- prompts
- resources

And instead of writing raw JSON, each tool generates an interactive form from its schema.

That means you can run a tool instantly.

No scripts.
No curl commands.
No guessing the payload format.

## What Using ProtoMCP Actually Feels Like

The workflow becomes dramatically simpler.

1. Connect to a server
2. Explore everything the server exposes
3. Run tools without writing JSON
4. Inspect every request and response

One of the most useful parts of ProtoMCP is something simple:

**transparent request logging.**

Every request the UI sends is visible.

So when something fails, you can instantly see the exact JSON-RPC request, the server response, whether streaming broke, and how long execution took.

That visibility completely changes the debugging process.
Instead of guessing what's wrong, you can actually see it.

## Built Entirely in Jac

Another interesting part of this project is how it was built.

ProtoMCP is written entirely in Jac, the full-stack language from the Jaseci ecosystem.

That means the same language powers the frontend UI, backend logic, and MCP transport handling. In practice this removed an entire layer of complexity — there's no separate React frontend, Python backend, or API glue layer. Everything lives in one coherent system.

For this project, UI components are written in Jac, backend proxy walkers handle CORS and sessions, and MCP transport logic runs directly in the runtime. It made building the whole playground much faster than expected.

## Try It Yourself

You can explore ProtoMCP directly:

**[Live playground](https://jac-mcp-playground.jaseci.org/)**

ProtoMCP is fully open source.

If you want to run your own instance, extend it, or explore how it works internally:

**[GitHub repository](https://github.com/jaseci-labs/jac-mcp-playground)**



