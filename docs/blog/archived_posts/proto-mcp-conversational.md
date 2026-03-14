---
date: 2026-03-16
authors:
  - nimesh
categories:
  - Developers
  - Jac Programming
  - AI & ML
slug: proto-mcp-conversational
---
# **Hey Folks, I Built an MCP Playground and You Should Try It**

Hey folks — been working with MCP lately and hit a wall with the tooling.

The protocol itself is great, honestly. But when it came time to actually *test* an MCP server, I felt like I was spending more time debugging JSON-RPC than building anything useful.

<!-- more -->

Kept wondering if it was just me, or if others were dealing with this too.

## The Problem with MCP Inspector

So here's where I got stuck. I'd connect to a server, inspect the schema, hand-craft a JSON-RPC request, send it... and get an error.

Then I'd tweak the JSON, try again — another error.

At some point I realized the workflow was basically:

1. Connect to server
2. Inspect tool schema
3. Manually construct JSON-RPC request
4. Send it
5. Get an error
6. Guess what went wrong

And the debugging wasn't much better:
- Add logs
- Restart the server
- Retry the request
- Repeat until it works (or you give up)

MCP Inspector exists and technically works, but it felt like trying to debug a distributed system through a keyhole.

## So I Threw Together ProtoMCP

I needed something that felt more like Postman for MCP — you know, connect to a server, see what's there, run tools without writing raw JSON, inspect what actually happened.

[ProtoMCP](https://jac-mcp-playground.jaseci.org/) is what came out the other side.

It's a browser-based playground where you can:
- Connect to any MCP server
- See all the tools, prompts, and resources it exposes
- Run tools through auto-generated forms (no JSON required)
- Inspect every request and response

The request logging is the part that actually saves you time — you can see the exact JSON-RPC that went out, what came back, whether streaming broke, and how long it took. No more guessing what went wrong.

## Built It in Jac (and It Was Surprisingly Fast)

Here's the part that might interest you — ProtoMCP is written entirely in Jac.

Same language for the frontend UI, backend logic, and MCP transport handling. No separate React app, no Python backend, no API glue layer. UI components are in Jac, proxy walkers handle CORS and sessions, and the MCP transport runs directly in the runtime.

It honestly made building the whole thing faster than I expected.

## Try It Out and Let Me Know What You Think

Would love to hear if this matches y'all's experience with MCP tooling, or if I'm missing something obvious.

**[Live playground](https://jac-mcp-playground.jaseci.org/)**

Everything's open source, so if you want to run your own instance or poke around the internals:

**[GitHub repository](https://github.com/jaseci-labs/jac-mcp-playground)**

Drop a star if it helps, or open an issue if you've got ideas for making it better.

