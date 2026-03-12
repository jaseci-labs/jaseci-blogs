---
date: 2026-03-12
authors:
  - mars
categories:
  - Developers
  - AI & ML
slug: nairobi-hackathon-feedback
---

# **Listening to Builders: What Our Hackathon Feedback Revealed**

Earlier this year, more than 1,500 students at the Open University of Kenya (OUK) spent three months learning and experimenting with generative AI through a program led by Jaseci Labs. What began as a lecture series eventually culminated in a month-long hackathon where students applied what they had learned to build real applications using the Jaseci stack.

<!-- more -->

The response was remarkable. Over 200 teams registered, and by the end of the hackathon nearly 100 complete projects were submitted. Participants built everything from AI-powered assistants to graph-native applications using Jac, orchestrated agent workflows with byLLM, and connected full-stack interfaces through jac-client. For many of the students, it was their first time building AI systems end-to-end.

After the hackathon concluded, we asked participants to reflect on their experience. Fourteen developers submitted detailed feedback about what it was like building their projects with Jac and the Jaseci stack — what worked well, what slowed them down, and where the developer experience could improve.

Their responses were thoughtful, direct, and remarkably consistent.

## **The Big Picture: Strong Validation**

Even with the typical pressure and time constraints of a hackathon, developers reported strong overall satisfaction building with the Jaseci stack. Most rated their experience a 4 or 5 out of 5, and nearly all said they would consider using Jac again in future projects, particularly for agentic or generative AI applications.

Just as importantly, the feedback wasn’t just praise. Participants were candid about where the developer experience still needs improvement, especially around debugging and tooling.

That combination — enthusiasm paired with practical criticism, made the feedback especially valuable.

<!--Image 1 -->
<img src="/assets/nairobi-hackathon-feedback-1.png" alt="Likelihood of using Jac over Python in GenAI projects" width="80%"/>

Even when facing friction, developers believe in the architectural model and the direction of the ecosystem.

## **What Developers Loved**

<!--Image 2 -->
<img src="/assets/nairobi-hackathon-feedback-2.png" alt="Pie Chart demonstrating the most compelling parts of the Jaseci stack" width="80%"/>


### **Object Spatial Programming (OSP)**

One theme surfaced repeatedly: clarity of architecture.
Developers described OSP as structured, predictable, and clean. By separating graph structure from the logic that traverses it, teams were able to avoid the “spaghetti code” that often emerges in complex AI systems. Once the node-and-walker mindset clicked, many described the experience as intuitive and even liberating.

*"The most stress-reducing aspect for me was the separation of concerns provided by Object Spatial Programming. In traditional development, managing the relationship between complex data structures and the logic acting on them often results in 'spaghetti code' that's hard to maintain. But with Jac, I was able to define the graph structure independently and use specialized walkers to navigate it, which made the architecture feel predictable and organized. This structure lets me focus on the high-level operational flow rather than getting bogged down in the data layer plumbing."*


Jac’s graph-native design is not simply different - it enables a more natural way to model relationships and agent flows.

### **byLLM and AI-Native Orchestration**

The integration of byLLM was consistently cited as one of the most compelling parts of the stack. Developers appreciated the ability to embed LLM capabilities directly into application logic without extensive prompt engineering or orchestration boilerplate.
One participant with prior experience using LangChain summarized the experience simply:


*“Using byLLM is amazing. Coming from a Lang Chain background it is a lifesaver.”*

For many, Jac felt AI-native from the ground up. Not an ecosystem retrofitted to accommodate generative AI, but one designed around it.

### **Full-Stack Velocity with jac-client**

Another strong signal was the value of jac-client in reducing backend/frontend friction. Developers highlighted how quickly they were able to prototype full-stack systems without managing separate API contracts or juggling multiple languages.

*“The fact that Jac is a full-stack language was the most fascinating thing. I did not have to juggle between different languages to build the front-end and back-end”*

In a hackathon setting, velocity matters. Teams went from concept to working products in days - sometimes hours, because the stack reduced coordination overhead and allowed them to focus on logic and product design.

## **Where Developers Faced Friction**

While overall sentiment was positive, one theme stood out with clarity.

<!--Image 3 -->
<img src="/assets/nairobi-hackathon-feedback-3.png" alt="Areas in the Jaseci stack that need improvement" width="80%"/>

### **Debugging and Observability**

The most consistent feedback centered around tooling - specifically debugging and runtime visibility.
Developers reported:

* Error messages that were not descriptive enough
* `jac check` outputs that did not clearly pinpoint issues
* Difficulty tracing walker execution across nodes
* Limited visibility into state mutations within complex flows

*"If only one improvement could be made to significantly enhance the developer experience, it would be improving the debugging system in Jac. Clearer error messages, better explanations, and helpful suggestions would make it much easier to identify and fix problems."*

This is not a conceptual limitation of Object Spatial Programming. It is a tooling gap. And it surfaced repeatedly.

### **Documentation and Onboarding**

Several participants noted the paradigm shift required to think in graphs rather than tables or traditional object hierarchies. While many ultimately appreciated the model, the learning curve was real.
Developers asked for:

* Structured beginner guides
* More production-level examples
* Clearer explanations of advanced concepts
* Better integration documentation

*“Improving documentation and example-driven guidance would have the biggest impact on developer experience. Comprehensive tutorials, production-level use cases, and clearer explanations of advanced concepts like walker orchestration, state management, and scaling would empower developers to build confidently and avoid common pitfalls.”*

## **What the Feedback Made Clear**

Across nearly every response, the same pattern appeared.

Developers were excited about the architecture. They liked the way Jac models systems using graphs, how byLLM integrates AI workflows directly into application logic, and how jac-client simplifies full-stack development.

But when things broke, it was sometimes difficult to see exactly why.
The most consistent feedback centered around debugging and runtime visibility. Developers wanted clearer error messages, better tracing of walker execution, and improved tooling for inspecting what was happening inside the graph.

In other words, the architecture resonated. The tooling needs to catch up to it.

## **Building Forward**

Hackathons are one of the best ways to see how a technology performs in the hands of real builders. The projects created during the OUK program showed just how quickly developers can start building AI-native applications with Jac and the Jaseci stack.

The feedback also made something clear: as adoption grows, debugging, observability, and developer tooling need to evolve alongside the architecture. These areas are already active priorities in the Jaseci roadmap, and several recent pull requests are directly addressing the issues developers raised during the hackathon.

For example:

* [A new Jac compiler parser architecture](https://github.com/jaseci-labs/jaseci/pull/4445)
A major ongoing effort replaces the previous Lark-based parser with a hand-written recursive descent parser implemented entirely in Jac. This change introduces a cleaner compiler pipeline and lays the groundwork for significantly better error reporting and language tooling.

* [Improved error detection across implementation modules](https://github.com/jaseci-labs/jaseci/pull/5014)
One issue developers highlighted was debugging errors that appeared to “disappear” when code lived in .impl.jac files. A recent fix ensures static analysis now correctly checks these implementation modules, making undefined names and unreachable code visible during jac check.

* [Better CLI feedback and warnings](https://github.com/jaseci-labs/jaseci/pull/4966)
Improvements to the jac check workflow ensure that warnings are properly surfaced even when they are the only issues in a file, making it easier for developers to catch problems earlier in the development cycle.

* [Compiler simplification and parser overhaul](https://github.com/jaseci-labs/jaseci/pull/4557)
Additional work continues to simplify the Jac compiler stack by removing legacy parser dependencies and consolidating the parsing infrastructure. This makes the compiler easier to maintain and opens the door for stronger tooling and debugging capabilities.

These improvements represent just a portion of the work currently happening in the open across the Jaseci repository. As more developers experiment with graph-native architectures and agentic workflows, improving the tooling, compiler feedback, and debugging experience will remain a central focus.
If you're interested in exploring Jac or building your own agentic systems, you can follow development, explore the code, or contribute directly through the Jaseci repositories.

* **Explore Jaseci:** [docs.jaseci.org](https://docs.jaseci.org)

* **Star us on GitHub:** [github.com/Jaseci-Labs](https://github.com/Jaseci-Labs)

* **Join the community:** *\[Discord/Slack/Forum link\]*

* **Install Jac:** pip install jaclang



