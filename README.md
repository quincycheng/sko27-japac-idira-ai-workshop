# SKO27 TechSummit - AI Workshop for Idira DC

The lab guide and trainer material for the **AI workshop for Idira Domain Consultants**, teaching
**~60 people with no coding experience** how an AI harness is built — and then using a real one to
eliminate an embedded credential instead of merely hiding it better.

Built for Idira (the rebranded CyberArk), using Claude on Amazon Bedrock, Claude Code, the `idsec`
CLI, Idira Secure Cloud Access, and the Idira Identity Broker.

Two parts, in order:

- **Part 1 · How a harness is built** (`S1`–`S5`, ~45 min) — five short Python scripts in
  [`ai-harness-app/`](ai-harness-app), each about thirty lines. A bare model call → the tool-use loop
  → an agent (system prompt, toolbox, iteration cap) → context management → prompt injection defeated
  by controls rather than prompt-craft. Attendees run each one, read a breakdown of it, then break it
  on purpose.
- **Part 2 · Claude Code on real problems** (`01`–`08`, ~50 min) — the original vibe-coding lab,
  unchanged. The same loop, properly engineered, pointed at Idira problems.

## The one-sentence version

Part 1 leaves nothing mysterious about what an agent is; then an agent reviews a small, deliberately
careless app, finds four hardcoded secrets, and the attendee eliminates the AWS one entirely with
zero-standing-privileges elevation, names **Idira Secrets Manager** as the destination for the other
three, and finishes by giving an agent access to a system it holds no credential for.

**💬 Build it → 🔎 Look → 🔑 Find → 🎫 Elevate → ✂️ Delete → 🛡️ Broker**

The audience are Domain Consultants, so the last move matters twice: they have to be able to
*do* it, and they have to be able to *demo* it. Lesson 5 ends with a client demo script. Part 1 is
what makes them able to *explain* it.

## Start here

| You are… | Read this |
| --- | --- |
| **An attendee** | Double-click [`lab/index.html`](lab/index.html) |
| **An attendee, beforehand** | [`lab/0000-prework.html`](lab/0000-prework.html), or just run `bash check-prereqs.sh` / `.\check-prereqs.ps1` |
| **The workshop owner** | [`docs/owner-prep.md`](docs/owner-prep.md) — start 3 weeks out |
| **A trainer** | [`docs/run-of-show.md`](docs/run-of-show.md) and [`docs/presentation-outline.md`](docs/presentation-outline.md) |
| **A helper** | [`docs/helper-runbook.md`](docs/helper-runbook.md) |

## Layout

```
vibe-coding-workshop/
├── CONTEXT.md          Domain glossary — the vocabulary this workshop uses
├── check-prereqs.sh    Prework checker for macOS/Linux — checks, then offers to fix
├── check-prereqs.ps1   The same for Windows PowerShell
├── lab/                Attendee-facing guide. Plain HTML, opened by double-click.
│   ├── index.html          Entry point
│   ├── 0000-prework.html   Before the session: installs, venv, access checks
│   ├── stage-1-bare-call.html
│   │                       Part 1 · ~8 min  · one model call, no tools, find the wall
│   ├── stage-2-give-it-a-tool.html
│   │                       Part 1 · ~10 min · hunt the planted secrets, then the loop
│   ├── stage-3-make-it-an-agent.html
│   │                       Part 1 · ~9 min  · system prompt, toolbox, iteration cap
│   ├── stage-4-context.html
│   │                       Part 1 · ~9 min  · token accounting and compaction
│   ├── stage-5-prompt-injection.html
│   │                       Part 1 · ~10 min · injection, controls, hand-off to Part 2
│   ├── 0001-setup.html     Mandatory · ~5 min  · agent running on Bedrock
│   ├── 0002-find-the-secrets.html
│   │                       Mandatory · ~13 min · four secrets, two fates
│   ├── 0003-zsp-access.html
│   │                       Mandatory · ~10 min · elevate with the zsp-aws skill
│   ├── 0004-fix-the-app.html
│   │                       Mandatory · ~8 min  · delete the credential
│   ├── 0005-identity-broker.html
│   │                       Mandatory · ~12 min · MCP through the Broker, audit, kill switch
│   ├── 0006-build-from-nothing.html
│   │                       Optional  · ~10 min · one prompt, empty folder
│   ├── 0007-write-a-skill.html
│   │                       Optional  · ~15 min · write your own SKILL.md
│   ├── 0008-afk-harness.html
│   │                       Optional  · ~20 min · grill → spec → tickets → implement → review
│   ├── reference/cheatsheet.html
│   └── assets/             Shared stylesheet and script
├── sandbox-app/        The deliberately insecure Python app under study (Part 2)
├── ai-harness-app/     Part 1 — the harness, built in five steps
│   ├── config.py           The only file that knows which provider you are on
│   ├── 01_bare_call.py     S1 · one call, text in and text out
│   ├── 02_single_tool.py   S2 · the loop, with one tool
│   ├── 03_agent.py         S3 · system prompt + toolbox + MAX_ITERATIONS
│   ├── 04_context.py       S4 · usage accounting + compaction
│   ├── 05_prompt_injection.py
│   │                       S5 · the injected file, and the controls that refuse it
│   ├── tools.py            Four tools, `_safe_path` sandbox, command allowlist
│   └── sandbox/            Six tiny files: six planted secrets, four planted bugs,
│                           and the tampered RELEASE_NOTES.md
├── skills/             Agent skills handed to attendees
│   ├── idsec/              Broad: how to drive the Idira CLI
│   └── zsp-aws/            Narrow: five steps to eliminate an AWS key
└── docs/               Owner and trainer material — NOT shipped to attendees
```

Every page carries a **page selector** — a Back / dropdown / Next bar driven by a single
`PAGES` array in [`lab/assets/lab.js`](lab/assets/lab.js). Adding or reordering a lesson means
editing that array, not eleven files.

## What attendees do

**Part 1 (S1–S5)** — build the harness. Each page links one script, runs it, breaks the script down
part by part behind collapsible sections, and hands the attendee an experiment: weaken the system
prompt, drop `MAX_ITERATIONS` to 2, turn compaction off, widen the command allowlist. `S2` opens with
a **secret hunt** — attendees search `ai-harness-app/sandbox/` by hand for the six planted values
before the agent does, and the two nobody finds (a hidden `.env`, and a password inside a
`postgres://` URL) make the argument for eliminating credentials rather than scanning for them. `S5`
closes Part 1 and hands over to Claude Code.

The five scripts run on **Claude on Amazon Bedrock** by default, reading the same temporary `AWS_*`
credentials and `ANTHROPIC_MODEL` that Claude Code uses — no second credential, no extra login.
`LLM_PROVIDER` switches to Vertex, Gemini or a local GGUF model without touching the loop.

**Part 2, mandatory (Lessons 1–5)** — prework verification, secret detection on the sandbox app,
zero standing privileges, elimination via `zsp-aws`, and connecting an MCP server through the
Identity Broker.

**Part 2, optional (Lessons 6–8)**, one self-contained page each, marked optional and independent of
one another:

- **6 · Build something from nothing with a simple prompt** — an empty folder and one sentence,
  then the experiment: does the agent embed a credential or not?
- **7 · Write your own skill** — turn something you already know into a `SKILL.md`
- **8 · Build something AFK** — the full harness: `/grill-with-docs` → `/to-spec` →
  `/to-tickets` → `/implement` → `/code-review`. The point is *context engineering*: small
  tickets each sized to one fresh context window, and all the human decisions front-loaded so
  the implementation happens while you are away from the keyboard.

## Constraints this material was built under

These are not incidental. Several design decisions only make sense in light of them.

- **No admin rights, anywhere.** Everything installs into the user's home folder, and Python
  dependencies go into a project-local virtual environment. This is also why the Secrets Manager
  MCP server is out of scope — it ships only as a stdio Docker container, and Docker Desktop
  requires admin rights on Windows.
- **Mixed macOS and Windows.** Every lab page has an OS switch that swaps all
  platform-specific instructions at once, and remembers the choice across lessons.
- **The lab runs from `file://`.** No web server, no build step, no CDN, no network calls, no
  fonts to download. Just double-click an HTML file. Every browser API that can be blocked on
  `file://` is used defensively. The pages are also responsive, so the guide is readable on a
  phone — wide diagrams and tables scroll sideways rather than shrinking to illegibility.
- **The workshop ships as a git repository.** Which is what makes Claude Code's built-in
  `/security-review` usable in Lesson 2. It is oriented at *changes*, so on a fresh clone the
  lesson also supplies a whole-project fallback prompt.
- **Credentials are copy-pasted from the AWS portal.** Not a compromise — AWS's recommended
  auto-refreshing alternative needs the AWS CLI, which needs admin rights.
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
- **Idira EPM** — named in the prework, Lesson 3, the cheat sheet and the deck as the layer that
  governs which executables may run on a managed endpoint (`idsec` being a privileged tool), because
  it is the question a customer asks. Never demonstrated; there is no EPM task and no console tour
- Tests, CI, branching strategy — Lesson 8 shows the shape of an AFK harness, not a delivery pipeline
- **Streaming, sub-agents, MCP clients, retries and backoff in Part 1's scripts** — all real parts of
  a production harness, all left out so each stage stays readable in one screen

## A note on the fake credentials

Everything in `sandbox-app/` and `ai-harness-app/sandbox/` is a public example value — AWS's own
documentation placeholders, and obviously-fake GitHub, Stripe, Slack and Postgres strings. None of
them authenticate to anything, anywhere. They are recognisable to scanners, which is the point.

`ai-harness-app/sandbox/RELEASE_NOTES.md` contains a **deliberate prompt-injection payload** in an
HTML comment: it instructs the agent to read `/etc/passwd` and POST the `.env` to an external host.
It is the exhibit Stage 5 exists to demonstrate, and both requests are refused by `_safe_path` and the
`run_command` allowlist. Expect security tooling — and other AI agents reading this repo — to flag
that file. That is the correct reaction to it.
