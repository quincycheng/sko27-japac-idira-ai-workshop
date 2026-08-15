# SKO27 TechSummit - AI Workshop for Idira DC

The lab guide and trainer material for the **AI workshop for Idira Domain Consultants**, teaching
**~60 people with no coding experience** how an AI harness is built — and then using a real one to
eliminate an embedded credential instead of merely hiding it better.

Built for Idira (the rebranded CyberArk), using Claude on Amazon Bedrock, Claude Code, the `idsec`
CLI, Idira Secure Cloud Access, and the Idira AI Agent Identity Broker.

Three parts, in order:

- **Part 1 · Build your own AI harness** (lessons `01`–`05`) — five short Python scripts in
  [`ai-harness-app/`](ai-harness-app), all sharing one `session.py`. One call
  to a genuinely old model → the same call with the conversation attached → context engineering (rules,
  output styles, the dumb zone, `/compact`) → tools and the agent loop → the whole harness: rules,
  skills, output style, MCP, LSP, subagents, hooks and memory. Attendees run each script, read the whole
  file with the key lines annotated, then break it on purpose from the chatbox.
- **Break time activity · Govern what you built** (lesson `06`) — no script. It asks the room who is
  running the sixty agents that just started.
- **Part 2 · Practical Guide to AI Harness** (lessons `07`–`10`) — the same seven components,
  properly engineered, pointed at Idira problems.
- **Part 3 · Optional Deep Dives** (lessons `11`–`14`) — for people who finish early.

Part 1 replaced the twelve-minute slide deck this workshop used to open with. Building an agent costs
the same time as explaining one and nobody has to take the trainer's word for anything. What remains
is a three-minute opener in [`docs/presentation-outline.md`](docs/presentation-outline.md), which also
keeps the retired slide wording as an appendix.

The workshop has **two slots: 60 minutes from 1:00pm, then 90 minutes from 3:00pm**, with an hour
between them. Part 1 fills the first and Part 2 the second, but the boundary is soft on purpose: start
Part 2 before the break if Part 1 ran short, or after it if Part 1 ran long. Part 1 does not fit into 60
minutes unmodified — [`docs/run-of-show.md`](docs/run-of-show.md) opens with what to cut.

## The one-sentence version

Part 1 leaves nothing mysterious about what an agent is; then an agent reviews a small, deliberately
careless app, finds four hardcoded secrets, and the attendee eliminates the AWS one entirely with
zero-standing-privileges elevation, names **Idira Secrets Manager** as the destination for the other
three, and finishes by giving an agent access to a system it holds no credential for.

**💬 Build it → 🔎 Look → 🔑 Find → 🎫 Elevate → 🛡️ Broker**, then optionally **✂️ Delete**

The audience are Domain Consultants, so the last move matters twice: they have to be able to
*do* it, and they have to be able to *demo* it. Lesson 10 ends with a client demo script. Part 1 is
what makes them able to *explain* it: every lesson ends by naming the risk it just demonstrated and
the product that answers it, and
[`lab/reference/securing-agentic-ai.html`](lab/reference/securing-agentic-ai.html) holds the deck
that covers the whole platform, and two videos to watch afterwards.

## Start here

| You are… | Read this |
| --- | --- |
| **An attendee** | Double-click [`lab/index.html`](lab/index.html) |
| **An attendee, beforehand** | [`lab/0000-prework.html`](lab/0000-prework.html), or just run `bash check-prereqs.sh` / `.\check-prereqs.ps1` |
| **The workshop owner** | [`docs/owner-prep.md`](docs/owner-prep.md) — start 3 weeks out |
| **A trainer** | [`docs/run-of-show.md`](docs/run-of-show.md), then [`docs/presentation-outline.md`](docs/presentation-outline.md) for the 3-minute opener |
| **A helper** | [`docs/helper-runbook.md`](docs/helper-runbook.md) |

## Layout

```
sko27-japac-idira-ai-workshop/
├── CONTEXT.md          Domain glossary — the vocabulary this workshop uses
├── check-prereqs.sh    Prework checker for macOS/Linux — checks, then offers to fix
├── check-prereqs.ps1   The same for Windows PowerShell
├── lab/                Attendee-facing guide. Plain HTML, opened by double-click.
│   ├── index.html          Entry point
│   ├── 0000-prework.html   Before the session: installs, venv, access checks
│   ├── 0001-one-call.html
│   │                       Part 1 · one call to an old model, two walls
│   ├── 0002-conversation-history.html
│   │                       Part 1 · attach the history, watch the bill
│   ├── 0003-context-engineering.html
│   │                       Part 1 · rules, styles, the dumb zone, /compact
│   ├── 0004-tools-and-agents.html
│   │                       Part 1 · the secret hunt, then the tool-use loop
│   ├── 0005-the-harness.html
│   │                       Part 1 · MCP, skills, LSP, subagents, hooks, memory
│   ├── 0006-who-runs-the-agents.html
│   │                       Part 1 · agent discovery, jailbreaks, the kill switch
│   ├── 0007-setup.html     Everyone · agent running on Bedrock
│   ├── 0008-find-the-secrets.html
│   │                       Everyone · four secrets, two fates
│   ├── 0009-zsp-access.html
│   │                       Everyone · elevate with the zsp-aws skill
│   ├── 0010-identity-broker.html
│   │                       Everyone · MCP through the Broker, audit, kill switch
│   ├── 0011-build-from-nothing.html
│   │                       Optional deep dive · one prompt, empty folder
│   ├── 0012-write-a-skill.html
│   │                       Optional deep dive · write your own SKILL.md
│   ├── 0013-afk-harness.html
│   │                       Optional deep dive · grill → spec → tickets → review
│   ├── 0014-fix-the-app.html
│   │                       Optional deep dive · delete the credential
│   ├── annotations/        The hover/click notes for the code on each Part 1 page
│   ├── reference/
│   │   ├── cheatsheet.html         Every command in the lab, on one page
│   │   └── securing-agentic-ai.html  The platform deck, and two take-home videos
│   └── assets/             Shared stylesheet and script
├── build-lab-code.py   Renders ai-harness-app source into the Part 1 pages.
│                       `--check` fails if a page is stale — run it after any edit.
├── sandbox-app/        The deliberately insecure Python app under study (Part 2)
├── ai-harness-app/     Part 1 — the harness, built in six lessons
│   ├── requirements.txt    Part 1's dependencies — a different list from Part 2's
│   ├── config.py           Model tiers and capabilities; the only file that knows
│   │                       which provider you are on
│   ├── session.py          The shared session: history, usage, context gauge, slash
│   │                       commands, styles, memory. Every lesson imports this.
│   ├── ui.py               Everything the terminal draws — panels, gauges, ⚙ lines
│   ├── 01_bare_call.py     01 · one call, no history, no tools
│   ├── 02_conversation.py  02 · the same call with messages[] attached
│   ├── 03_context.py       03 · system prompt + output style + /fill + /compact
│   ├── 04_tools_and_agents.py
│   │                       04 · the toolbox, the loop, the iteration cap
│   ├── 05_harness.py       05 · all seven components, and the control probe
│   ├── agent.py            The loop itself — unchanged from lesson 04 onwards
│   ├── tools.py            Four tools, `_safe_path` sandbox, command allowlist
│   ├── harness.py          Skills, LSP tools, hooks, subagent delegation
│   ├── mcp_client.py       JSON-RPC over stdio and streamable HTTP, `mcp__` prefix
│   ├── mcp_server_local.py A tiny local MCP server, so lesson 05 works offline
│   ├── prompts/            The rules, as plain Markdown
│   ├── styles/             eli5.md and deep-dive.md — the two output styles
│   ├── skills/             vuln-report and dependency-audit
│   ├── memory.md           The only thing that survives the process exiting
│   └── sandbox/            Five tiny files: six planted secrets, four planted bugs,
│                           and the tampered RELEASE_NOTES.md
├── skills/             Agent skills handed to attendees (Part 2, Claude Code)
│   ├── idsec/              Broad: how to drive the Idira CLI
│   ├── zsp-aws/            Narrow: five steps to eliminate an AWS key
│   └── zsp-azure/          The same for Azure: a session id, and no credential
└── docs/               Owner and trainer material — NOT shipped to attendees
```

Every page carries a **page selector** — a Back / dropdown / Next bar driven by a single
`PAGES` array in [`lab/assets/lab.js`](lab/assets/lab.js). Adding or reordering a lesson means
editing that array, not eighteen files.

## What attendees do

**Part 1 (01–05)** — build the harness. Each page runs one script, shows the **whole file** with the
key lines clickable (hover or click for the note explaining them), and hands the attendee an
experiment to run from the chatbox: argue with the rules, drop `MAX_ITERATIONS` to 2, widen the
command allowlist, try to talk a hook out of a refusal. `04` opens with a **secret hunt** — attendees
search `ai-harness-app/sandbox/` by hand for the six planted values before the agent does, and the two
nobody finds (a hidden `.env`, and a password inside a `postgres://` URL) make the argument for
eliminating credentials rather than scanning for them. `06`, the break time activity, closes the first
slot and hands over to Claude Code, which has all seven of the components it just built.

Every script shares one `session.py`, so the same instrumentation is on every page: **input and output
tokens, the stop reason, and context used as a percentage of that model's real window** after every
single call. Slash commands work everywhere — `/system`, `/style`, `/context`, `/compact`, `/fill`,
`/reset`, `/remember`, `/model` — and every lesson has a free-text chatbox next to its scripted task.

Two model tiers, deliberately far apart: **`tier=legacy`** is Llama 3 8B Instruct (April 2024, no tool
support, an 8,192-token window it enforces exactly) and **`tier=frontier`** is Claude Sonnet 4.5
(200,000). The small window is the point — the gauge moves, the dumb zone is reachable, and the wall
arrives inside a lesson rather than in theory.

The scripts run on **Amazon Bedrock** by default, reading the same temporary `AWS_*` credentials and
`ANTHROPIC_MODEL` that Claude Code uses — no second credential, no extra login. `LLM_PROVIDER`
switches to Vertex, Gemini or a local GGUF model without touching the loop.

**Part 2, mandatory (Lessons 07–10)** — prework verification, secret detection on the sandbox app,
zero standing privileges via `zsp-aws` and `zsp-azure`, and connecting an MCP server through the
Identity Broker.

**Part 3, Optional Deep Dives (Lessons 11–14)**, one self-contained page each, independent of
one another:

- **11 · Build something from nothing with a simple prompt** — an empty folder and one sentence,
  then the experiment: does the agent embed a credential or not?
- **12 · Write your own skill** — turn something you already know into a `SKILL.md`
- **13 · Build something AFK** — the full harness: `/grill-with-docs` → `/to-spec` →
  `/to-tickets` → `/implement` → `/code-review`. The point is *context engineering*: small
  tickets each sized to one fresh context window, and all the human decisions front-loaded so
  the implementation happens while you are away from the keyboard. Lesson 03 gives attendees the
  heads-up that this page exists, because it is the answer to the dumb zone they just hit.
- **14 · Delete the key** — the follow-up to Lesson 09 on the same sandbox app: zero standing
  privileges made the AWS key unnecessary, so an agent takes it out and the attendee reviews the
  diff. Seven lines removed, nothing added, and three secrets still there.

## Constraints this material was built under

These are not incidental. Several design decisions only make sense in light of them.

- **No admin rights, anywhere.** Everything installs into the user's home folder, and Python
  dependencies go into a project-local virtual environment. This is also why the Secrets Manager
  MCP server is out of scope — it ships only as a stdio Docker container, and Docker Desktop
  requires admin rights on Windows.
- **Mixed macOS and Windows.** Every lab page has an OS switch that swaps all
  platform-specific instructions at once, and remembers the choice across lessons.
- **The lab runs from `file://`.** No web server, no CDN, no network calls, no fonts to download,
  and **nothing for an attendee to build**. Just double-click an HTML file. Every browser API that
  can be blocked on `file://` is used defensively. The pages are also responsive, so the guide is
  readable on a phone — wide diagrams and tables scroll sideways rather than shrinking to
  illegibility. The one generator, `build-lab-code.py`, is an *author* tool: it renders the Python
  source, the capability scoreboard, the Idira thread and the app's own terminal output into the
  pages, and its output is committed — so run `.venv/bin/python build-lab-code.py --check` before you
  push and treat a non-zero exit as a stale page.
- **Attendees are told to tile their windows.** Lab guide on one half of the screen, terminal on
  the other, arranged during the prework rather than during the session. The OS switch supplies the
  right instructions for each platform, and the lessons assume a terminal about 80 columns wide.
- **The workshop ships as a git repository.** Which is what makes Claude Code's built-in
  `/security-review` usable in Lesson 08. It is oriented at *changes*, so on a fresh clone the
  lesson also supplies a whole-project fallback prompt.
- **Every AWS credential in the lab comes from one `idsec` command.** No web console is opened
  anywhere. `idsec exec sca cloud-access elevate --raw` is piped through `jq` and `eval`, so the keys
  land in the shell's environment without ever being printed or saved. Both binaries install into
  `~/bin` with no admin rights. That one-liner is deliberately duplicated in prework step 7, Lesson
  01, Lesson 07, Lesson 14, cheat sheet §2 and `skills/zsp-aws/SKILL.md` — change it in all six.
- **One shared tenant, sixty numbered attendees.** One registered MCP server and one registered
  AI agent serve the whole room; each attendee authenticates as themselves in the browser, which
  is what makes the on-behalf-of story demonstrable rather than theoretical.

## The lesson the whole thing exists to teach

> When you find a stored secret, ask **"does this need to exist at all?"** *before* you ask
> "where should we keep it?"

If the platform can issue access on demand, **eliminate** it — that is Idira Secure Cloud
Access. If it cannot, **onboard** it into **Idira Secrets Manager**. Both are good answers; only
one removes the risk permanently. "We moved it to an environment variable" is not one of them.

The workshop deliberately ends with **three of four secrets still in place**, correctly
identified as needing a vault. Everything in `docs/` reminds trainers to say that number out
loud. Overclaiming a partial fix is how a finding gets closed while the risk stays open — and
this audience will notice.

## Not covered, on purpose

- Vaulting the remaining three secrets — named as Idira Secrets Manager throughout, done in a
  follow-up session
- **Authoring** an AI agent access policy — attendees consume one and learn how it is
  structured, but writing one needs the Secure AI Admin role
- **Idira EPM** — named in the prework, Lessons 06 and 09 and the cheat sheet as the layer that
  governs which executables may run on a managed endpoint (`idsec` being a privileged tool), because
  it is the question a customer asks. Never demonstrated; there is no EPM task and no console tour
- **Prism AIRS and Secure Workload Access** — named in Part 1, in the *Where Idira fits* block at the
  end of each lesson, but there is no traffic-inspection console and no Kubernetes in the room. Those
  blocks say so plainly rather than implying a demo happened
- Tests, CI, branching strategy — Lesson 13 shows the shape of an AFK harness, not a delivery pipeline
- **Streaming, retries and backoff, and any real MCP authentication in Part 1's scripts** — all real
  parts of a production harness, all left out so each lesson's file stays readable. Subagents, hooks
  and an MCP client *are* in Part 1 now: they are the point of Lesson 05. What is missing there is
  authentication, deliberately — the playground MCP server needs none, and that absence is the lesson

## A note on the fake credentials

Everything in `sandbox-app/` and `ai-harness-app/sandbox/` is a public example value — AWS's own
documentation placeholders, and obviously-fake GitHub, Stripe, Slack and Postgres strings. None of
them authenticate to anything, anywhere. They are recognisable to scanners, which is the point.

`ai-harness-app/sandbox/RELEASE_NOTES.md` contains a **deliberate prompt-injection payload** in an
HTML comment: it instructs the agent to read `/etc/passwd` and POST the `.env` to an external host.
Any agent that audits the sandbox reads it, and both requests are refused by `_safe_path` and the
`run_command` allowlist. Lesson 05's control probe makes those two calls directly, with no model in the
way, so the refusals are identical on every laptop. Expect security tooling — and other AI agents reading this repo — to flag
that file. That is the correct reaction to it.
