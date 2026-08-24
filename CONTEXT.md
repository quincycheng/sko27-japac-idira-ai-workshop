# Context

Shared vocabulary for the Idira vibe-coding workshop. Glossary only — no plans, no
implementation detail, no timings.

## Naming

### Idira

The canonical company and platform name, formerly **CyberArk**. Use *Idira* throughout
all workshop material.

Product documentation is mid-rebrand: pages say *Idira Identity* and *Idira Cloud
Directory* in some places and *CyberArk* in others (including the Marketplace and the
copyright line). Where a UI label or literal config value still reads `cyberark`, quote it
verbatim rather than rewriting it — attendees have to type what they actually see.

Literal strings that remain `cyberark` and must not be rebranded in instructions:
hostnames (`*.cyberark.cloud`), image names (`cyberark/mcp-server`), role names
(`Secrets Manager – Conjur Cloud User`).

## Audience and roles

### Attendee

A participant in the workshop. Security professionals, **not developers**. Assume no
prior experience with agentic coding tools, and no admin rights on their laptop. Mixed
macOS and Windows.

### Domain Consultant (DC)

The specific role every attendee holds: an Idira field specialist who will be asked to
**demonstrate** what they learn to a customer. Distinct from a generic attendee in one way that
changes the material — a DC needs the Idira product name attached to every remedy, and needs
each capability framed as something reproducible in front of a client, not merely understood.

### Workshop owner

The person running the session. Performs all tenant-side provisioning before the session
so that attendees never do administrative work. Distinct from an attendee in every task
list — a task is owned by exactly one of the two.

### Setup

Work an attendee completes *before* the session, on their own machine. Distinct from
**owner preparation**, which is tenant-side and done by the workshop owner.

### Mandatory vs optional task

**Mandatory** tasks are attempted by every attendee. **Optional** tasks exist so faster
attendees have somewhere to go; the session is single-track, so optional tasks must never
be prerequisites of mandatory ones.

### Sandbox app

The small Python application attendees work on. It ships with **dummy** credentials in its
config files — for AWS, GitHub, and other systems — so that detection has something real to
find without any live credential ever reaching an attendee's laptop. Attendees receive it;
they do not write it.

### Lab guide

The attendee-facing walkthrough: self-contained HTML files opened locally from disk, one per
use case, entered through a local `index.html`. It must work offline with no network calls,
no CDN, and no build step, and must be **responsive** — legible on a phone as well as a laptop.

Every page carries a **page selector**: a Back / dropdown / Next control listing every page in
the guide, grouped by whether it is setup, mandatory, optional or reference. The lesson
sequence has exactly one definition; the selector and the page-to-page links are both generated
from it.

### Annotated source

How a lab page shows a lesson's code: the **whole** Python file, with the lines that matter marked
and tappable, each revealing a short explanation of what that line does and why it is there.

Two properties are deliberate. It is the whole file, because an attendee comparing the page to their
editor should find no difference. And it is **generated from the `.py` file** rather than copied into
the page by hand, because the guide has to stay in sync with code that keeps changing, and hand-copied
excerpts in this material have already drifted once.

Tap is the primary interaction and hover is a desktop nicety, because these pages are read on phones.

### Knowledge Check

A short retrieval exercise inside a lab guide page. Its purpose is durability, not
assessment — nothing is scored or collected. Answer options are written to equal length so
that formatting reveals nothing.

## Agentic coding

### Vibe coding

Building software by directing an AI agent in natural language rather than writing code
directly. The workshop's framing: what an attendee can produce this way, and what new
exposure it creates.

### Claude Code

The CLI agent attendees run locally.

### AI agent

Per Idira: an application or service that uses AI to perform tasks and may require access
to MCP servers. Claude Code running on an attendee's laptop is an AI agent.

### Permission mode

How much Claude Code may do before it asks the person at the keyboard. The attendee cycles
the modes with `Shift+Tab`, and the current one is named on the bottom line of the window.

**Auto mode** is the one the workshop assumes: the agent runs commands without asking
first. Every lesson from 08 onward depends on it, and setup makes it the attendee's
default so nobody is stopped at an approval prompt. It is a workshop convenience, named as
such on the pages: the material tells attendees not to use it in a repo that matters.

Distinct from `bypassPermissions`, which is wider still and which the workshop never asks
for.

### MCP server

A service an AI agent connects to using the Model Context Protocol, exposing **tools** the
agent can discover and call.

- **Predefined MCP server** — curated and maintained by Idira, registrable in one click
  from the catalog.
- **Custom MCP server** — registered by your own organisation from a URL. Must pass
  well-known endpoint discovery before registration is permitted.

### Tool

A single named operation an MCP server exposes. The Identity Broker records every tool
discovery and every tool call as an auditable event.

### Skill

A written instruction sheet that teaches an agent how to perform a job properly — plain
prose in a `SKILL.md` file, not code. The agent selects one by matching the task to the
skill's description.

Distinct from a **tool**, and the two must not be conflated: a tool is a capability an MCP
server *provides*; a skill is knowledge the agent *applies* when using capabilities it
already has. Attendees are handed skills; they never write a tool.

A skill is **broad** when it teaches the shape of something and how to discover the rest, or
**narrow** when it prescribes an ordered procedure. Narrow skills are easier to get right,
so they are the recommended starting point for an attendee writing their first one.

### Rules

Standing instructions that apply to *every* task in a project, as opposed to a **skill**, which
applies to one kind of task. In Claude Code they live in a `CLAUDE.md` file; in Part 1's harness
they are `prompts/system.md`. Both are prose in a file, which is the point — the thing governing an
agent's behaviour is a document a security reviewer can read.

### Output style

A separate instruction that shapes *how* an answer is written — its length, register and structure —
without changing *what* the agent is asked to do. Part 1 ships two, deliberately at opposite
extremes: `styles/eli5.md` and `styles/deep-dive.md`.

Workshop-relevant because it is the cheapest demonstration that prose costs tokens: swapping one
style for the other changes the context gauge in a single keystroke, with the task untouched.

### Hook

A command the harness runs automatically at a fixed point in the loop — before a tool call, after
one, at the end of a turn — regardless of what the model wants. Distinct from every other item in
this section in one way that matters: rules, skills and styles are things the model is *asked* to
follow, and a hook is not asked at all. That makes it the only one of them that is a control.

### Subagent

A second agent the main one delegates a bounded piece of work to, with its own fresh context
window. Two reasons it exists, and the workshop names both: parallelism, and keeping a long
investigation's debris out of the main transcript — a subagent returns a conclusion rather than
everything it read. Directly a **context engineering** move.

### LSP (Language Server Protocol)

The protocol editors use to get real answers about code — where a symbol is defined, what its type
is, what broke. A harness wired to a language server stops guessing at code structure and starts
asking. Named in Part 1 as one component of a full harness; not built there.

### Memory (agent)

Anything the harness deliberately persists *between* runs, as opposed to the transcript it holds
*during* one. The distinction is load-bearing in Part 1: a fresh process forgetting everything is
lesson 01's whole point, so persistence is introduced only in the last of the five scripts, as a design
choice with a file behind it.

Not to be confused with **conversation memory**, which is within a single session.

### Conversation memory

Re-sending the previous turns of a conversation with each new message, which is the only reason a
chat appears to remember anything. The model is stateless; memory is a list the harness chooses to
keep, and its cost is visible on the context gauge immediately.

### Harness

**Two senses, and the material uses both.** Say which one you mean.

1. **The machinery sense** — the code around a model: the loop, the tools, the limits, and
   everything else that turns a thing which only produces text into a thing which acts. This is
   what Part 1 builds, one piece per lesson, and what the phrase *AI harness* means on its own.
2. **The workflow sense** — an ordered set of skills that carries a piece of work from an idea to
   reviewed code, rather than a single prompt that attempts all of it. The workshop's reference
   harness runs interview → spec → tickets → implement → review.

The two are not rivals: the workflow sense is something you can only build once the machinery
sense exists. Part 1 ends on the machinery, the optional deep dive on the workflow.

### Context engineering

Deciding what an agent has in front of it at the moment it works, treated as a design activity
rather than a side effect. Everything the model sees is one flat token stream, so this covers
every decision about what goes into it:

- the **system prompt** and the **output style** — instructions the harness prepends
- **conversation memory** — how much of the transcript gets re-sent
- **compaction** — folding old turns into a note so the loop can keep running
- **sizing a unit of work** so it fits one fresh context window, so no unit inherits another's
  confusion

The last of those is the technique the optional AFK course rests on, and for a while it was the
only one this material taught under the name. It is now the *end* of the argument rather than the
whole of it.

### Dumb zone

The region of a filled context window where answer quality falls off — the model is still
answering, and answering worse, with nothing in the output to say so. It is the reason context is
engineered rather than merely monitored, and the reason the harness shows **context used as a
percentage** rather than a raw token count: a number nobody can interpret is not a warning.

Two ways out, and the workshop shows both: **compact** what is already there, or **size the work**
so it never gets there.

### Compact

Folding the middle of a transcript into a short note, keeping the original task and the most
recent turns intact, so a long-running loop stays out of the dumb zone. Named after the thing
Claude Code does under `/compact`, which is the same move at production scale.

The constraint that makes it fiddly is worth stating: a tool call and its result are one unit, and
splitting them makes the next request invalid.

### AFK (away from keyboard)

The property a well-engineered harness has: every decision requiring a human is front-loaded
into the interview and specification stages, so the implementation stage needs nobody present.
A measure of how well the work was specified, not a claim that review can be skipped — the
review stage still requires a human.

## Models and their limits

### Context window

The maximum number of tokens a model can be given in one request. A hard ceiling, and a property of
the model rather than of the harness — which is why the harness has to be the thing that manages
it.

Part 1 deliberately uses two models with windows an order of magnitude apart, because a limit you
can reach in four turns teaches what a limit you cannot reach in a whole session does not.

### Context gauge

The share of the context window a request has consumed, shown as a **percentage**, displayed
continuously rather than on request. Its job is to make the **dumb zone** visible before it is
reached.

A percentage, not a token count, and against the model's *real* window. If a run ever has to gauge
against a working budget the material chose rather than a model limit, the display must say so —
labelling our own number as the model's ceiling would be the one dishonest thing on the screen.

### Token accounting

Reading `input_tokens` and `output_tokens` off every model response. Input tokens are everything
sent this turn, so on a growing conversation they climb whether or not anyone is watching; they are
the number that eventually kills a naive agent, and they are what the gauge is computed from.

### Stop reason

The model's own statement of why it stopped producing text — `end_turn` because it finished,
`tool_use` because it wants something run, `max_tokens` because it ran out of room. Workshop
vocabulary because the change from `end_turn` to `tool_use` *is* the moment a chatbot becomes an
agent, and because a truncated answer is a `max_tokens` away from a complete one with nothing else
to distinguish them.

### Legacy model / frontier model

The two tiers Part 1 runs on, named by **capability** and never by age or marketing tier:

- a **legacy model** — a small context window, no tool support, and no separate system role. Enough
  to hold a conversation, not enough to act.
- a **frontier model** — tools, a large window, and the instruction-following that makes an agent
  worth building.

The switch between them happens at the lesson where tools arrive, and it is motivated by attendees
having already hit the smaller model's wall rather than by assertion.

### Capability record

The short statement — tools yes/no, system role yes/no, window size — that a harness has to keep
about whichever model it is pointed at. It exists because *format* is a replaceable part and
*capability* is not: an adapter can make two models answer the same call, and cannot make an old
one grow tools.

The honest version of "the model is swappable", and the answer to the first question a customer
asks about bringing their own.

## Identity Broker

### Identity Broker

The Idira service that brokers all traffic between AI agents and MCP servers. It
authenticates the agent, validates the session, proxies the call, and returns the
response. Two properties matter for this workshop: **credentials are never exposed to the
agent**, and **every action is audited**.

Prefer *Identity Broker* as the canonical term. *AI Broker* is acceptable in
presentation material but should be introduced as the same thing, since the
documentation uses *Identity Broker*.

### Register (MCP server)

Onboarding an MCP endpoint into the MCP servers inventory, making it a governed target and
preparing the Broker to route to it. Registration alone does not grant access.

### Register (AI agent)

Onboarding an AI agent into the AI agents inventory to give it a unique identity. This is
what issues the OAuth 2.1 client credentials the agent authenticates with, and what makes
the audit trail attributable.

Note the collision with the Secrets Manager sense of *onboard* below — say which one you
mean.

### Gateway URL

The address an AI agent connects to in order to reach a registered MCP server *through* the
Broker, rather than reaching the server directly. Shape:
`https://<region>.data.aigw.cyberark.cloud/mcp/<server-name>`.

It exists only while the server is **Enabled**, and it is what makes the Broker a proxy rather
than a directory: the agent has no route to the underlying server at all.

### Enabled / Disabled

An MCP server's lifecycle state. Connection details and the Gateway URL exist only while
**Enabled**. Disabling one immediately revokes access for every connected agent — the
**kill switch**. Servers registered by an administrator are Enabled by default; servers
registered by an AI builder start Disabled and need an administrator to enable them.

An AI agent has the same two states. **Both** the agent and the server must be Enabled for any
access policy between them to apply.

### AI agent access policy

The rule that permits an agent to use a tool. Access is **deny by default**: a call is allowed
only where some policy matches *both*

- the **principal** — the human user or role **and** the AI agent, and
- the **resource** — a specific tool on a specific MCP server.

Matching one and not the other is a denial, not a partial allow. A policy is composed of four
parts: general details, MCP servers and tools, AI agents, and users and roles. Each of the three
selector parts may name specific items or admit all current and future ones.

Authoring a policy requires the **Secure AI Admin** role. In this workshop the policy is
**owner preparation**, not an attendee task — attendees consume one and learn its shape.

### Tool discovery

The Broker learns a server's tools the first time an agent connects to it. Until then the
server's tool inventory is unknown — reported as *not discovered yet* — which means a policy
written before the first connection cannot name specific tools.

### Pass-through

Traffic from an AI agent that is *not* registered. Still detectable and governable, but
the agent's identity cannot be resolved, so audit data degrades to "this server was
accessed, these tools were used". Contrast with a registered agent, where the audit record
names the initiating human user, the agent identity, the server, and the tools called.

### On-behalf-of (OBO)

An agent acting under the *attendee's own* identity rather than under a static shared
credential, so that authorisation and audit resolve to the human who initiated the
request.

Realised by the agent authenticating **interactively, in a browser**, as the person using it.
One registered agent identity plus sixty humans therefore yields sixty distinguishable
principals — which is why a single shared server record serves the whole room without collapsing
the audit trail. OBO is a mandatory demonstration in this workshop, not an advanced topic.

## Securing Human, Machine & Agentic AI Identities

The set of products the workshop maps onto the parts of a harness. Each lesson in Part 1 exposes one
kind of risk and names the product that answers it, so a Domain Consultant leaves with the mapping
rather than only the mechanics. **One risk, one product, one sentence** — this is a naming exercise,
and only Secure Cloud Access and the Identity Broker are demonstrated.

| The harness part | The exposure | The product |
| --- | --- | --- |
| An agent that needs cloud access | A long-lived key in a config file | **Secure Cloud Access** (ZSP) |
| A skill that drives a CLI | Anyone who can run the binary can request elevation | **Endpoint Privilege Manager** |
| An MCP server the agent calls | An unauthenticated endpoint, no attribution, no kill switch | **Identity Broker** |
| The agent's own identity | An agent nobody can name in an audit log | **Idira Identity** (OIDC / OAuth) |
| An agent running as a workload | A shared credential baked into a container | **Secure Workload Access** (SVID) |
| What the model is told and what it replies | Injection in, sensitive data out | **Prism AIRS** |

### Idira Identity

The Idira service that issues and verifies identity for humans **and** for AI agents, over OIDC and
OAuth 2.1. In this workshop its agent-facing half is what the Identity Broker uses: registering an
AI agent issues OAuth 2.1 client credentials, and those are what make an audit record attributable
to an agent instead of degrading to **pass-through**.

### Secure Workload Access

The Idira service that gives a *workload* — a container, a pod, a service — a verifiable identity of
its own, so it can authenticate without a credential having been placed inside it.

Its workshop-relevant sense is one sentence long: an AI agent that runs on Kubernetes rather than on
a laptop still needs to be *somebody*, and this is how it becomes somebody without a secret in a
manifest. Named as the answer to "what about the agents we run in production", which is the question
that follows every laptop demo. Never demonstrated; there is no cluster in this workshop.

### SVID (SPIFFE Verifiable Identity Document)

The short-lived identity document a workload presents to prove what it is, issued to it
automatically rather than configured into it. The workload equivalent of the elevated, short-lived
credentials **zero standing privileges** produces for a person — same principle, different subject,
and worth saying in exactly those terms because the room will already have seen the human version.

### Prism AIRS

**Palo Alto Networks'** AI runtime security product — guardrails that inspect what goes into a model
and what comes out of it, at runtime, outside the application.

Two points of care. First, **it is not branded Idira**, so introduce it as Palo Alto's, the way the
material already says *Idira by Palo Alto Networks*. Second, it is the answer to a question Part 1
raises and cannot answer on its own: a prompt is not a guardrail, and the controls that saved the
agent in the harness lesson were the tool layer's. Prism AIRS is that layer for the *content* of
the conversation, where the tool sandbox is that layer for the *actions*.

Neither replaces the other, and saying so is the point of naming it at all.

## Secrets

### Embedded secret

A credential written directly into source code. Also *hard-coded secret*, which is the
term the Idira documentation uses. Treat the two as synonyms and pick one per document.

### Secrets Manager

The Idira SaaS secrets product, built on **Conjur Cloud**. Both names appear in the
documentation and in role names.

**The canonical destination for any embedded secret that cannot be eliminated.** Naming it is
part of the vocabulary every attendee leaves with — an embedded secret has two acceptable
endings, elimination via Secure Cloud Access or onboarding into Secrets Manager, and an
environment variable holding a long-lived value is neither.

Distinguish the **product** from its **MCP server**. The product is named throughout the
workshop; the MCP server is **out of scope**, because it ships only as a stdio Docker container
with no URL, so the Identity Broker cannot route to it, and requiring Docker is incompatible
with an audience that has no admin rights. Its internal vocabulary (branches, variables,
workloads) is therefore not workshop vocabulary.

### PCloud Safe

A vaulted container for privileged accounts in the PCloud service. An alternative
destination for an onboarded credential, separate from Secrets Manager.

### Secrets Hub

The Idira service that discovers secrets and syncs them into cloud secret stores (e.g. AWS
Secrets Manager). It *distributes* secrets rather than serving as the original store, so it
is not itself an onboarding destination for a newly discovered embedded secret.

### Onboard (a secret)

Bringing an existing credential under vault management, as opposed to **provisioning** a
new one or **rotating** an existing one. The secret continues to exist; what changes is
where it lives and who controls it.

### Eliminate (a secret)

Removing the need for the credential altogether by replacing it with short-lived access
obtained at the moment of use. The distinction from **onboarding** is the central lesson of
this workshop: onboarding makes an embedded secret *safer*, eliminating it makes the secret
*absent*. An embedded long-lived AWS access key is eliminated, not onboarded, when the
application switches to zero standing privileges.

## Tooling

### Idsec CLI

The official Idira command-line interface (`idsec`), open source and Apache-2.0. Organised
around **profiles** (`idsec configure`, `idsec login`) and then service commands
(`idsec <service> <subcommand>`). Services include `sia`, `sca`, `pcloud`, `identity`,
`policy`, `cmgr`, and `sechub`.

Relevant property for this workshop: it ships as a **single prebuilt binary** for macOS,
Windows and Linux, so it can be extracted and run without an installer and without admin
rights.

### Endpoint Privilege Manager (EPM)

The Idira product that enforces least privilege, **application control** and credential theft
protection on the endpoint itself, through an agent on the machine. Its workshop-relevant sense is
narrow: application control decides **which executables are permitted to run, and by whom**, can
route a blocked one through an approval flow rather than a plain failure, and records each policy
decision as an auditable event.

Its place in the vocabulary is as a distinct **layer**, not a synonym for anything else here: EPM
governs *which tool may run on the endpoint*, **Secure Cloud Access** governs *what access that tool
can obtain*, and **Secrets Manager** governs *what happens to secrets that cannot be eliminated*.
The **Idsec CLI** is the concrete case that makes the layer necessary — it is itself a privileged
tool, since anyone able to run it can request elevation.

Named in the workshop, never demonstrated: it has no lab task and no tenant-side preparation beyond
confirming the attendees' laptops are permitted to run `idsec`.

The layering above is one row of the larger map under **Securing Human, Machine & Agentic AI
Identities**, and EPM's row there is
the same argument arriving from the other direction: a **skill** is prose that tells an agent to run a
privileged binary, so whatever governs that binary governs the skill.

### Virtual environment

A project-local folder holding this project's Python libraries, activated per terminal window.
The workshop's standard way of installing dependencies, for one reason that dominates the
others: it requires no admin rights and touches nothing outside the project folder.

Its per-window nature is workshop vocabulary in its own right, because it produces the same
class of failure as an unset environment variable — a new window is a fresh, unconfigured
window.

### Zero standing privileges (ZSP)

The principle that no identity holds durable entitlements — between tasks it holds nothing, and
access is granted only for the moment it is needed. Contrast with a long-lived credential, which is
what an embedded secret is.

Also the name of the **mechanism** as this workshop uses it: requesting a role at the moment of use
and receiving short-lived credentials. `idsec sca cloud-access` performs this against an AWS or
Azure workspace, and the `zsp-aws` skill is the narrow procedure for doing it.

**One term, deliberately.** *Just-in-time* and *JIT* are not used anywhere in this material, even
though the vendor documentation uses them for the mechanism. Attendees leave with a single phrase,
and it is the one that matches the skill name and the outcome a customer buys. Where prose needs to
describe the credentials rather than the principle, the word is **short-lived** — not *JIT*.

## Cloud

### AWS access

Attendees get AWS credentials from the `idsec` CLI, against their own CYBRWorld tenant
(`demo.cyberark.cloud`): `idsec login`, then `idsec exec sca cloud-access elevate --csp aws`, with
`jq` lifting the credentials out of the JSON and into three environment variables. No web portal is
used anywhere in the lab. This is the path to the credentials Claude Code uses for Bedrock.

### Bedrock

The AWS service hosting the models attendees use. Claude Code is pointed at it rather than at the
Anthropic API directly, and Part 1's scripts reach it with the same temporary credentials.

It hosts more than one vendor's models, which is what makes Part 1's **legacy model / frontier model**
pairing possible on a single login: both tiers are Bedrock model IDs, reached with the credentials
already in the terminal window. Each one an attendee can invoke has to be enabled in the account
*and* permitted by the elevated role — model access and `bedrock:InvokeModel` are two separate
switches, and both are owner preparation.
