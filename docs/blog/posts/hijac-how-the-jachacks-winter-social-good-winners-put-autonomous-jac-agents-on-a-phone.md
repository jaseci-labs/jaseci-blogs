---
date: 2026-07-20
authors:
  - jaseci-team
categories:
  - Community
  - Built with Jac
slug: hijac-how-the-jachacks-winter-social-good-winners-put-autonomous-jac-agents-on-a-phone
repost: true
repost_url: "https://dev.to/chess10kp/my-experience-with-jachacks-winter-5g43"
draft: true
---

# Hijac: how the JacHacks Winter Social Good winners put autonomous Jac agents on a phone

Nitin Shankar Madhu, together with teammates Chuka Ezeoke and Meron, took first place in the Social Good track at JacHacks Winter with **Hijac**, a pipeline that compiles Jac apps straight into installable native mobile apps. Their demo: an agent that watches a phone's sensors, notices when its owner has fallen, and calls an emergency contact on its own if they don't respond within 30 seconds.

<--more-->

## From full-stack web to a phone in your pocket

Jac already lets a team build the interface, the logic, the data, and the AI in one language and one codebase. The team pushed that further: take the same Jac app and put it on a phone, running as a real agent that senses the world and acts in it, not just another web UI.

## Built with Jac's Object-Spatial Programming

The fall-detection agent from the demo runs on Jac's Object-Spatial Programming model. Sensor readings live in a node. A walker reacts to them, judging whether a spike looks like a fall. When it does, the walker calls an LLM directly through Jac's `by llm()`, a typed call with no JSON-parsing boilerplate, and starts a 30-second countdown before calling for help.

## Same Jac, now native

To get Hijac onto a phone, the team wrapped their Jac app with Capacitor, which turns web apps into native ones, and hijacked Jac's existing Vite pipeline to feed it: Vite bundles the Jac-generated React output as usual, then `cap sync` turns that straight into a real installable app. No rewrite, no second backend, just the same Jac codebase shipping as a native mobile agent that senses, decides, and calls for help entirely on its own.

Read the full write-up, with the code and the build story, [on dev.to](https://dev.to/chess10kp/my-experience-with-jachacks-winter-5g43).
