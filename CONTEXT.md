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

### Prework

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
the guide, grouped by whether it is prework, mandatory, optional or reference. The lesson
sequence has exactly one definition; the selector and the page-to-page links are both generated
from it.

### Knowledge check

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

### Harness

An ordered set of skills that carries a piece of work from an idea to reviewed code, rather than
a single prompt that attempts all of it. The workshop's reference harness runs
interview → spec → tickets → implement → review.

### Context engineering

Deciding what an agent has in front of it at the moment it works, treated as a design activity
rather than a side effect. The workshop teaches exactly one technique under this name: sizing a
unit of work so it fits **one fresh context window**, so that no unit inherits another's
confusion.

### AFK (away from keyboard)

The property a well-engineered harness has: every decision requiring a human is front-loaded
into the interview and specification stages, so the implementation stage needs nobody present.
A measure of how well the work was specified, not a claim that review can be skipped — the
review stage still requires a human.

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

Attendees reach AWS through SSO at `https://ngid.cyberark.cloud/` → CYBR User Portal →
the **AWS** icon. This is the path to the credentials Claude Code uses for Bedrock.

### Bedrock

The AWS service hosting the Claude models attendees use. Claude Code is pointed at it
rather than at the Anthropic API directly.
