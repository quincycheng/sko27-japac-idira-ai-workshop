# Run of show

**Slots:** 60 minutes at 1:00–2:00pm, then 90 minutes at 3:00–4:30pm, with an hour between them.
**Planned:** 70 minutes of Part 1 into a 60-minute slot 1, 60 minutes of Part 2 into a 90-minute
slot 2. **Buffer:** **minus 10 minutes** in slot 1, about 30 in slot 2.

🚨 **Slot 1 is over budget by design of the schedule, not of the material.** Part 1 as written is 70
minutes and you have 60. You are not deciding *whether* to cut, only *which* cuts — and the six
listed under *If you are running late* total 18 minutes, so 10 is reachable without touching anything
structural. Choose them before the day and write them down; do not improvise at minute forty.

⚠️ **Read the buffer numbers before you plan anything else.** They are lopsided on purpose. Part 1 is
six lessons run live and it is the half that overruns, because it is the half where sixty
non-developers meet a terminal. Part 2 is the half where the agent does the work. Three consequences,
all of which you have to accept up front:

1. **Slot 1 does not fit.** Read *If you are running late* now, before the day, not at minute sixty.
   The first cut is chosen for you, and you need roughly the first four of the six.
2. **Every Part 1 lesson runs live.** There is no self-paced Part 1 material any more. If you cut, you
   cut a *step* inside a lesson, not a lesson — the numbering and the callbacks assume all six
   happened.
3. **Slot 2 has genuine slack, and it is not spare time.** It absorbs slot 1's overrun, and whatever
   is left goes into the optional deep dives with helpers floating. Plan that, do not improvise
   it.

### Where the break goes

The break is the full hour from 2:00 to 3:00pm, and the boundary is deliberately soft:

- **Part 1 finished with 5+ minutes left in slot 1?** Run Module 2 (Lesson 07, the setup check,
  5 min) *before* the break. It is the module that surfaces environment breakage, and an hour of break
  is enough for helpers to fix every broken laptop in the room. This is the preferred shape, and the
  long gap is what makes it worth protecting.
- **Part 1 ran long?** Stop at 2:00pm, mid-Part-1 if you have to, and pick up at 3:00pm where you
  stopped — slot 2's 34 minutes of slack is there for exactly this. Never skip lesson 05 to protect the
  break; it is the lesson the whole of Part 2 is a callback to.

Announce which shape you are in *before* the break, not after.

### Versions, and the one rule for the owner

Attendees run `update.sh` / `update.ps1` twice: at the top of slot 1 (Module 0) and again before
Lesson 07 (Module 2). Between those two moments the room is on one version, which is what makes "what
does your screen say" a question a helper can act on.

🚫 **Do not push to `main` while a slot is running.** A push mid-slot puts the room on two versions with
no announcement, and the version an attendee holds is the one their `.py` files came from. Push during
the break, then call the Module 2 update. If you have to fix something mid-slot, tell both trainers and
have them announce the update to the whole room at once.

The updater reports a version like `0.4`, or `0.4-3-g1a2b3c4` for a copy taken after that tag. Tag
`main` whenever you push during the week, so the number an attendee reads back to you is short.

**Audience:** Idira **Domain Consultants**. They are not just learning to use an agent; they will be
asked to demo this to customers. That changes the emphasis in four places: Part 1 (they have to be able
to *explain* an agent, not only drive one), Lesson 06 (the governance questions they will reuse in
every customer conversation), Module 3 (name the Idira product for each fix) and Module 5 (the Identity
Broker, which is the part clients ask to see).

## Slot 1 · Build your own AI harness

| # | Module | Min | Cumulative | Who leads |
| --- | --- | --- | --- | --- |
| 0 | Welcome and ground rules | 3 | 3 | Trainer A |
| 1a | One call to a model — Lesson 01 | 10 | 13 | Trainer A |
| 1b | Conversation history — Lesson 02 | 8 | 21 | Trainer A |
| 1c | Context engineering — Lesson 03 | 14 | 35 | Trainer B |
| 1d | Tools and agents — Lesson 04 | 15 | 50 | Trainer A |
| 1e | The harness — Lesson 05 | 15 | 65 | Trainer B |
| 1f | Who runs the agents? — Lesson 06 | 5 | 70 | Trainer A |

**— break —** (run Module 2 before it if you are ahead)

## Slot 2 · Practical Guide to AI Harness

| # | Module | Min | Cumulative | Who leads |
| --- | --- | --- | --- | --- |
| 2 | Setup check — Lesson 07 | 5 | 5 | Trainer B + all helpers |
| 3 | Vibe coding: Find the secrets — Lesson 08 | 13 | 18 | Trainer A |
| 4 | Skills: ZSP by Idsec CLI — Lesson 09 | 12 | 30 | Trainer B |
| 5 | MCP: AI Agent Identity Broker — Lesson 10 | 20 | 50 | Trainer B |
| 6 | Wrap and Q&A | 8 | 58 | Both |
| 7 | Buffer, or release the room early | 2 | 60 | Both |
| 8 | Optional deep dives, helpers floating — Lessons 11–14 | rest | — | All |

**There is no slide deck any more.** Part 1 replaced it. The old twelve-minute presentation explained
what an agent is; attendees now build one instead, which lands harder. What survives is a three-minute
opener, in [presentation-outline.md](presentation-outline.md).

Modules 0 to 6 are **mandatory**. **Lessons 11, 12, 13 and 14** are **Part 3, the optional deep dives**, each a
self-contained page, and exist to occupy fast finishers so they do not derail the room. Delete the key
moved into that set: zero standing privileges is the beat that has to land in the room, and deleting the
key it replaced is the follow-up an attendee can do alone.

---

## Module 0 · Welcome and ground rules (3 min)

See [presentation-outline.md](presentation-outline.md). Three minutes, hard stop. You are not teaching
anything here, you are getting sixty people pointed at the same file.

Close with the one instruction that matters: **open `lab/index.html` by double-clicking it.** Put that
on a slide and leave it up.

Five things to say and then stop:

- **Everyone run the updater now.** The guide moves during the week, and this is the only moment the
  whole room lands on the same version. Put it on the slide next to the `lab/index.html` instruction:

  ```
  # macOS                          # Windows PowerShell
  bash update.sh                   .\update.ps1
  ```

  Say what it prints, so nobody reads a normal result as a problem:

  > It says either "you are on the current version" or how many changes you are behind. If it offers,
  > say yes. If it prints a web address instead, use that address for the guide and tell a helper.

  Do not wait for the room. It is a few seconds for most people, and the ones it fails for are a
  helper's job, not a reason to hold sixty people.
- **Arrange your screen now: lab guide on one half, terminal on the other.** The setup page told them to
  do this, so it is a ten-second reminder rather than an exercise — but do it, because the alternative
  is sixty people alt-tabbing for three hours. The instruction is at the top of `lab/index.html` and it
  follows the OS switch.
- There is a **page selector at the top of every lab page**, the dropdown between Back and Next. Nobody
  gets lost and nobody has to return to the index to move on.
- **Fourteen lessons, numbered in the order you do them.** 01 to 05 build an agent, 06 is the break time
  activity, 07 to 10 use a real one, 11 to 14 are optional deep dives for people who finish early.
- **Raise your numbered card** rather than waiting politely. Helpers are watching for cards, not for
  confused faces.

---

## Module 1 · Part 1, live (74 min)

**Goal:** every attendee can say what an AI agent actually is, out loud, without using the word
"magic", because they built one and then broke it.

This is the half that makes the room able to *explain* Claude Code to a customer rather than only demo
it. Trainers lead from the front, with attendees running the same commands at their own machines. Every
lesson ends in a chatbox, so the room can experiment at each step — which is also the main way this
half overruns. Watch the clock, not the enthusiasm.

Say once, at the start, and then never again: **the numbers on your screen will not match mine.** Token
counts and percentages differ per run. The *shape* is the lesson.

### 1a · Lesson 01 · One call to a model (~10 min)

[Page](../lab/0001-one-call.html) · `python 01_bare_call.py`

Credentials and the virtual environment get set up here, which is why this lesson comes before the
setup check rather than after it. Expect the environment problems to surface now. That is deliberate
and it is why all helpers are on the floor.

Two walls, in order: the model **forgets** (ask a follow-up and watch it fail), and the model **cannot
act**. Then have them look at the footer: tiny input, tiny output, a stop reason, and a context gauge
barely off zero.

> That is a model. It talked, it could not act, and it forgot you the moment it answered. Everything
> else today is code we wrap around it.

Also worth ten seconds, because it defuses a question that otherwise recurs all day: the model here is
**deliberately old** — April 2024, no tool support, an 8,192-token window. We are not being unfair to
it; we need a window small enough that you can fill it in a lesson.

### 1b · Lesson 02 · Conversation history (~8 min)

[Page](../lab/0002-conversation-history.html) · `python 02_conversation.py`

The same call, with the conversation attached. Ask the follow-up that failed in lesson 01 and watch it
succeed. Then point at the footer twice: input tokens are up, and the gauge moved.

> Nothing gained a memory. We are re-sending the whole conversation every turn, and paying for it every
> turn. "The model remembers" is a user-interface illusion, and it is the first cost line in every
> agent bill.

The security beat, in one sentence, because this room will use it: everything in that transcript is
re-sent to a model provider on every turn — which is what **Prism AIRS** inspects.

### 1c · Lesson 03 · Context engineering (~14 min)

[Page](../lab/0003-context-engineering.html) · `python 03_context.py`

The longest Part 1 lesson and the one with the most quotable beats. Four things happen: rules go in,
an output style goes in, `/fill` takes the window to the dumb zone, and `/compact` buys some of it
back.

Do not skip `/style eli5` **after** three long answers. The model keeps answering long, because the
history outweighs the instruction — and then `/reset` and the same style produces a third of the
tokens. That is the whole of context engineering in two commands.

> The instruction did not lose to a bug. It lost to three previous answers. Whatever is in the window
> in bulk beats whatever is in the window in principle.

Then the dumb zone and the wall. Land both names, and land what `/compact` actually is: a summary
written by the model, of the conversation, replacing the middle of it. Lossy on purpose.

**Give the heads-up about Lesson 13 here**, in one sentence, because it is the answer to the problem
they just felt:

> There is an optional lesson at the end where you break a whole project into tickets small enough that
> each one fits in a fresh window. That is what people mean by context engineering when they say it in
> a job interview.

### 1d · Lesson 04 · Tools and agents (~15 min)

[Page](../lab/0004-tools-and-agents.html) · `python 04_tools_and_agents.py`

The best fifteen minutes of the session for audience participation, because it opens with a **secret
hunt**: attendees search `ai-harness-app/sandbox/` by hand and count what they find, before any agent
runs.

Run the hunt as a room. Ask for numbers out loud. Most people find four of the six. The two nobody
finds are a hidden `.env` and a password buried inside a `postgres://` URL, and that miss is the whole
argument for eliminating credentials instead of scanning for them. Do not give the answer early; let
them be wrong first.

> You just did what a scanner does, and you missed two. This is why "we grep for secrets" is not a
> security control.

Then the toolbox — and the old model **refuses it outright** (`This model doesn't support tool use`),
which is why the lesson switches tiers in front of the room. Read the `⚙`/`↳` transcript together, stop
on the approval prompt, and finish on `/context`: four tool schemas, sent on every single turn whether
used or not.

> The loop is nine lines. That is the entire difference between a chatbot and an agent.

### 1e · Lesson 05 · The harness (~15 min)

[Page](../lab/0005-the-harness.html) · `python 05_harness.py`

Everything at once: rules, skills, output style, MCP, LSP, subagents, hooks and memory. One task per
component, all six inside the one session. No new loop — `agent.py` has not changed since lesson 04,
and saying that out loud is the point.

The script sends nothing on start. It prints the component panel and the six tasks, then waits. Every
prompt in this lesson is one an attendee pastes, including task 4's delegated audit.

Four beats that matter more than completeness:

- **Five of the seven are text.** Rules, skills, style, memory and tool descriptions are all things the
  model reads. One is a control: the hook. Task 5 has them argue with `deny_secret_reads` in the chatbox
  and watch it refuse without consulting anybody.
- **`prove_the_controls()`.** The script prints it when you quit the chatbox: three attacks, three
  refusals, no model in the loop, identical on every laptop in the room. ⚠️ **The model's behaviour is
  not deterministic.** Sometimes it declines on its own, sometimes it tries and the tool layer blocks
  it. Demo from *that* panel and treat the model's behaviour as the anecdote.
- **`audit.log`.** Have them `cat` it. The model has no way to know it exists. That is the difference
  between "the agent did something" and "we can prove what the agent did".
- **MCP, and where the tools came from.** The lesson uses a local stdio server, and the page stops there.
  `python 05_harness.py --remote` points at an unauthenticated internet playground; it is a projector
  demo now, not an attendee step, so run it once from the front if you have the minute. If the proxy
  blocks it, **the block is the finding**. Say that sentence; do not treat it as a failed demo.

Open on the CTF callback — this room has hands-on jailbreaking experience from last year's mid-year
kick-off, so use it rather than teaching around it.

> The model's judgement was the unreliable control. The path check, the allowlist and the approval gate
> are the reliable ones, and they are twenty lines of Python.

**Gate:** do not start slot 2 until the room has seen a hook refuse something in lesson 05. If you are
already behind, see *If you are running late*.

### 1f · Lesson 06 · Who runs the agents? (~5 min)

[Page](../lab/0006-who-runs-the-agents.html) · no script

You lead this one from the front. Nobody types anything. The page asks each attendee to answer three
questions for themselves, and each of them running out of answer is the content. Give them a few seconds
on each before you land it.

- **Count the agents.** How many agents ran in this venue today, who started them, what did they do,
  when? No answer exists, for their laptop or anyone's, because no control was set before the agents
  started. Say the words **agent discovery**.
- **They already know how to break one.** Half this room did hands-on jailbreaking at last year's APJ SE
  Bootcamp, and more of them at the TechSummit26 AI Agentic workshops and the channel partner events.
  The deck and the recording are linked from the page as an optional step. Do not play them.
- **Could you stop one?** Do we know if any agent here is doing something suspicious, how would we
  prevent it, is there a kill switch? Land the honest answer: nobody can say, because no control was
  enforced before the agents started.

Then name the three things Secure AI Agents does about it: discover and centrally manage agents, control
agent access and enforce least privilege, govern and audit agent actions for compliance. That is the
handover into Part 2.

Close Part 1:

> Claude Code has all seven components you just built. You are not about to learn a new tool, you are
> about to recognise one.

---

## Module 2 · Setup check (5 min)

**Goal:** every laptop in the room has an agent that answers a question.

Attendees work through [Lesson 07](../lab/0007-setup.html). This used to be the highest-risk five
minutes of the session. It is less risky now, because Part 1 already required the credentials and the
virtual environment, so most of the breakage has surfaced during slot 1.

**Run the updater again, first, before Lesson 07.** Same command as Module 0. Anything fixed during the
break reaches the room here, and this is the last chance to get sixty laptops onto one version:

```
# macOS                          # Windows PowerShell
bash update.sh                   .\update.ps1
```

**All helpers are on the floor for this module.** Nobody sits down. If you are running this one *before*
the break — the preferred shape — helpers keep working through the break on whatever is still red.

Trainer B narrates the steps from the front at the pace of the slowest third, while helpers work the
room. The two most common failures are a new terminal window with no environment variables, and a
virtual environment that is not switched on (no `(.venv)` in the prompt). Both are in
[helper-runbook.md](helper-runbook.md).

Say the `(.venv)` thing out loud as you narrate step 4. It is one sentence and it prevents a dozen
hands going up later:

> If your prompt does not start with `(.venv)`, Python cannot see `boto3`. Every window, every time.

Then narrate step 5 slowly, because it sets up the rest of the afternoon: after `claude` starts, the
bottom line should already say **auto**, because the setup script offered to make it the default.
Anyone whose line says something else presses `Shift+Tab` until it does. Say why once, and say it
honestly:

> Auto mode is on so that sixty people move at the same speed. On Monday, in a repo that matters, do
> not use it. You read each command before you approve it.

Every lesson from here on assumes auto mode, so a room that misses this will be stopped at an approval
prompt in Module 3 without knowing why.

**Gate:** do not start Module 3 until you have visually confirmed the room. Ask for hands *down* if the
agent answered; hands still up are your work list. If more than about five people are stuck, pair them
with a neighbour rather than holding sixty people.

Say out loud, because it is the free teaching beat of the day:

> The credentials that command gave you were themselves short-lived. Nobody gave you a permanent AWS
> key. Before you ran it, your standing access to that account was zero. That is the whole idea of
> Module 4. Hold that thought for twenty minutes.

---

## Module 3 · Vibe coding: Find the secrets (13 min)

**Goal:** everyone has an agent-produced table of four secrets, and can name the difference between
eliminating one and vaulting one, **with the Idira product name attached to each**.

Attendees work [Lesson 08](../lab/0008-find-the-secrets.html). Mostly self-paced; Trainer A punctuates
it with three interventions:

1. **After the app fails** (~3 min in). Read the error aloud. "It does not say *no credentials*. It says
   the credentials were *rejected*. So it has credentials. Where?"
2. **After the review returns** (~8 min in). Take three answers from the room on what was found. Do not
   accept "an AWS key"; push for all four.
3. **The two-fixes table** (~11 min in). Do this from the front, on the slide. It is the conceptual
   centre of the workshop and it must not be skimmed as reading.

Callback to Part 1 that costs you ten seconds and is worth it:

> In lesson 04 you hunted six of these by hand and found four. The agent found them in one pass. That
> is a better scanner, and it is still not a fix.

On intervention 3, land the product names, because this room will be asked for them by name:

> Eliminate → **Idira Secure Cloud Access**. Vault → **Idira Secrets Manager**. Say both halves to a
> client. "Eliminate what you can, vault the rest."

The lesson also asks them to run the built-in `/security-review`. On a fresh clone there may be no
*pending changes* for it to look at, in which case the lesson tells them to ask for the whole project
instead. **Know which behaviour your repo produces.** It is a dry-run capture item in
[owner-prep.md](owner-prep.md). Say it from the front so sixty people do not each discover it
separately.

The honest claim about AI-generated credentials belongs here, worded as in the lesson: models
*frequently* inline credentials when prompted casually, not always. Do not overstate it; this room will
catch you.

---

## Module 4 · Skills: ZSP by Idsec CLI (12 min)

**Goal:** every attendee has run `get_caller_identity()` and seen an elevated role ARN with their own
name in it.

Attendees work [Lesson 09](../lab/0009-zsp-access.html). Trainer B demos steps 1 to 4 from the front
first, at full size, then releases the room. Do not let sixty people discover `list-targets` output
formatting simultaneously without having seen it once.

Four beats to call out. The last two are twenty seconds each, not sections:

- **The skill is one page of English.** Step 2 has them page through all three `SKILL.md` files with
  `more`. Part 1 has already primed them for this — lesson 05 loaded a skill the same way, and they
  watched the catalogue cost two lines until it was needed.
- **The ARN carries their name.** A shared access key can never tell you who used it.
- **Nothing was pre-wired for this.** No OIDC provider, no IAM trust policy, no per-person role, no
  CloudFormation. It is in the lesson as a callout under *The idea*, and it answers the first question a
  customer asks about effort. One sentence:

  > Nobody set up federation in that AWS account for you. There is no identity provider to configure, no
  > trust relationship to write and no role per person to maintain. Secure Cloud Access brokers the
  > request, so the setup cost you are looking at is the login you already did.

- **Name Idira EPM, once, out loud.** It is in the lesson as a callout under step 3, and it answers the
  question this room will ask on a customer site: *what stops anyone downloading this CLI and requesting
  access?* One sentence:

  > `idsec` is itself a privileged tool. **Idira EPM** decides which executables may run on the endpoint
  > and by whom: application control, an approval flow when it blocks something, and an audit trail.
  > **EPM** governs the agents and tools that run on the laptop; **Secure Cloud Access** and **Secure
  > Infrastructure Access** govern the access they can obtain; **Secrets Management** governs your
  > machine identities everywhere else.

  Do not open the EPM console and do not demo it. It is not in the lab and there is no time. This is a
  naming beat that makes the story complete, nothing more.

**Watch for:** the agent is told to *print* the elevate command, not run it, and step 6 has the
attendee leave the agent (`/exit`) and run it themselves. People will try to get the agent to do it.
It cannot set an environment variable in their shell, and you do not want the credentials in its
transcript either. Both halves of that are worth saying out loud.

**Close on the honesty number.** One of the four secrets is now gone and three are not, and Lesson 09
says so under *What this fixes, and what it does not*. Say the number from the front. It is the line
that makes the whole session credible to a security audience. Then point at the two optional steps at
the end of the lesson: the same elevation for **Azure**, which returns a session id and no credential at
all, and **Lesson 14**, which deletes the key this lesson made unnecessary. Both are for after the
workshop.

**Then foreshadow Module 5.** One sentence, because the old deck used to do this and Module 5 lands
measurably harder when it was set up:

> In about ten minutes you are all going to connect an agent through the Broker and call a tool you hold
> no credential for. Then you are going to ask it for a second tool and be refused. Both calls end up in
> the audit log with your own name on them.

Do **not** promise a live kill switch: no server is disabled and no policy is edited during the session.
The refused call is the live moment, and every attendee runs it themselves.

⚠️ **On the projector, do not run `elevate` live.** Its JSON response carries the short-lived
credentials in an `accessCredentials` field. The lab's one-liner ends in `eval`, so at a desk it prints
nothing, but anything you type by hand from the front might. Demo steps 1 to 5 on the projector and let
attendees run the elevate command at their own desks. Their own credentials on their own screens are
fine; they are short-lived and scoped to a sandbox account.

---

## Module 5 · MCP: AI Agent Identity Broker (20 min) 🛡️

**Goal:** every attendee has an MCP server connected through the Broker, has authenticated as their own
user, has called a tool while holding **no credential for that system**, has been **refused** a second
tool, and has then read both calls back out of the console.

This module is mandatory because it is the part Domain Consultants get asked to demo. Treat it as a
rehearsal for that demo, not as an exercise.

Attendees work [Lesson 10](../lab/0010-identity-broker.html), which is in three acts: five steps as a
user, three as a security professional, one as an auditor. It all runs on CYBRWorld,
`demo.cyberark.cloud`, so there is no tenant to switch and no secret to fetch. Trainer B drives it from
the front at the pace of the room.

**Nothing in the tenant is changed during the session.** No server is disabled, no policy is edited. Say
so, so nobody waits for a demo that is not coming.

**Part 1, connect and call two tools (≈8 min).** `/mcp` inside the agent to see it is empty, `/exit`,
then `claude mcp add …` in the terminal, then `/mcp` again, arrow keys, **Authenticate**, and the browser
sign-in. The Gateway URL and Client ID are printed in the lesson, so nothing needs to be on a slide.
There is **no Client Secret**: the agent is a public client, and the browser sign-in is what
authenticates the person.

Then three prompts: `What MCP tools are available?`, the `analyze_domain` call on
`paloaltonetworks.com`, and the `beta_features` call that is **refused**. The refusal is the point of the
module. Say out loud that nobody wrote a rule to block them, and that no policy naming the tool is
enough.

Three failure modes, all expected: a server listed as *needs authentication* (they have not run `/mcp`
yet), the sign-in opening in the wrong browser or profile, and a callback page that does not load (the
callback is `http://localhost:<port>`, and a VPN or proxy can eat it). All three are in the helper
runbook.

The callback here is short and worth it:

> In lesson 05 you connected to an MCP server by pasting a URL, with no authentication at all, and some
> of you got blocked by the proxy. This is the same protocol with somebody in charge of it.

**Part 2, the console (≈8 min).** Attendees have read access, so they do this themselves, four screens
at under two minutes each: the agent inventory (`JAPAC-SKO27`) and its **Connected MCP servers** tab,
the `EntraSonar MCP` server and its three tabs, the **EntraSonar MCP - Allow** policy, and the **Audit
and Reports** space filtered to Time range, Service name = Secure AI Agents, and their own Username.

On the policy screen, point at part 2 of the policy: it names `analyze_domain` and not
`beta_features`. That single omission is what refused them a minute earlier. In the audit log they
should find **both** records, the success and the denial.

Sixty people are hitting the same tenant, so expect the console to be slow. That is what the spare time
is for.

Two sentences the room needs while they are on the policy screen:

> Remove the tool, the agent or the role from this policy and the calls stop. Every connected agent, at
> once, from one screen. That is the kill switch, and disabling the MCP server does the same thing.

> The agent never held a credential for that system. The Broker holds it. That is why there is nothing
> to leak and nothing to rotate.

**Part 3, the two enforcement facts (≈3 min).** From the front, because these are what a customer
pushes on:

- Access is **deny by default**. A policy allows a call only when it matches *both* the principal (user
  or role **and** the AI agent) and the resource (the tool on that server). Console path:
  **Manage > Policies > AI agents access**.
- **Both** the agent and the server must be enabled for any policy to apply.

Then a minute of slack, because the browser sign-in is where a room of sixty spreads out.

Point at the last section of the lesson, *Your five-minute demo*, and tell them plainly: that is the
script, it works, use it. Beat 4 is the refused call, which every one of them has now run, so they can
demo it from memory.

---

## Module 6 · Wrap and Q&A (8 min)

- 2 min: recap using *What this fixes, and what it does not* at the bottom of Lesson 09, plus the one
  Broker sentence
- 2 min: what we deliberately did *not* cover. Vaulting the other three secrets in **Idira Secrets
  Manager**, and writing access policies (they consumed one today; they did not author one). Both are
  follow-up sessions.
- 4 min: questions

Two take-home pointers. First, the page that turns today into a customer conversation:

> [Post-Workshop Resources](../lab/reference/securing-agentic-ai.html) has the deck for the whole
> platform, plus two videos. That is the page to open on the train.

Then the four optional deep dives, by name, so people know what they are choosing between:

- [Lesson 11 · Build something from nothing with a simple prompt](../lab/0011-build-from-nothing.html) · ~10 min
- [Lesson 12 · Write your own skill](../lab/0012-write-a-skill.html) · ~15 min
- [Lesson 13 · Build something AFK](../lab/0013-afk-harness.html) · ~20 min, the full harness
- [Lesson 14 · Delete the key](../lab/0014-fix-the-app.html) · ~8 min, the follow-up to Lesson 09

And at the [cheat sheet](../lab/reference/cheatsheet.html). Tell people the folder is theirs to keep,
and that the lab pages work on a phone too. They are responsive, so the guide is readable on the train
home.

---

## Module 7 · Buffer, or release the room early (2 min)

Two minutes of slack, deliberately at the end. If the clock held, hand it to Q&A. If a helper is still
unblocking somebody, this is where that happens instead of eating the wrap.

---

## Module 8 · Optional deep dives, in the room (whatever is left)

Slot 2 should finish with real time left. Do not fill it from the front. Release the room into Lessons
11 to 14 with helpers floating, and say which one suits whom in one sentence each: **11** if you want to
play, **12** if you want something reusable at work on Monday, **13** if you want to see the whole
harness, **14** if you want the sandbox app's key actually deleted. Trainers stay for questions rather
than starting new material.

**Lesson 14 is the one a helper should watch.** The agent does the editing, so the attendee is the
review step. Slow them down twice: before they accept the change, make them read the diff, and after it
works, land the distinction. Not hidden, not moved, not rotated, *eliminated*. Seven lines removed,
nothing added, no vault to run. The page carries the customer-facing version of that as a stop callout:

> Deleting the constants is the right answer *for the AWS key*. It is not a general answer to secrets.
> In production, everything you cannot eliminate goes into **Idira Secrets Manager**: vaulted, rotated,
> audited, fetched at run time. Never a long-lived secret in an environment variable. That is a config
> file wearing a disguise.

---

## If you are running late

Slot 1 is where this happens. Cut in this order:

1. **Lesson 03's second `/fill`.** Take the window to the dumb zone once, from the front, rather than
   having sixty people do it twice. Saves 3 min.
2. **Lesson 05's jailbreak attempts** (task 5, the three prompts they argue with). Demo one from the
   front instead, and keep the `prove_the_controls()` panel, which is the deterministic part. Saves 3 min.
3. **Lesson 04's secret hunt, as a room.** Give them the answer table after two minutes rather than
   letting them search for five. Saves 3 min and costs you the best participation beat of the day, which
   is why it is third and not first.
4. **Module 3, intervention 2.** Take one answer from the room instead of three. Saves 3 min.
5. **Module 4's front-of-room demo.** Release the room straight into the lesson. Saves 4 min, costs you
   helper load.
6. **Module 5, the policy explanation.** Reduce it to the two enforcement facts and point at the lesson
   for the rest. Saves 2 min.

That is 18 minutes of cuts available before you have to touch anything structural — and slot 2's slack
is behind that. Lesson 05's `--remote` demo is not on this list because it is no longer an attendee
step: skipping it costs nothing and saves nothing.

Do not cut Module 2. Do not cut Module 5, and in particular **do not cut the audit search**. Finding
their own name on the call is the thing attendees will reuse in front of customers. Do not cut the Q&A;
this audience will have good questions and cutting them is how a workshop gets remembered badly.

**If you are more than ten minutes down by the end of lesson 04**, cut lesson 05 to tasks 1, 5 and 6
(MCP, hooks, memory) and demo the rest from the front. The `prove_the_controls()` panel prints either
way, on quit. One thing to say if you cut task 4: `audit.log` will hold no subagent calls, because
nobody ran a subagent. Let the room read the page later.

Lesson 06 is already the short one, and it needs no laptops. If the clock has gone, run it as three
questions asked from the front in two minutes and skip the optional media. Do not drop it: it is the
handover into Part 2, and it is the argument this audience takes to customers.

If you are so far behind that lesson 05 will not fit in slot 1, take it into slot 2 *before* Module 2
rather than dropping it. It is fifteen minutes and it is what Part 2 is a callback to. Slot 2 has the
room for it.

If Module 5 is running out of room, take Module 7's two minutes and drop Module 4's front-of-room demo.
Do not cut the Broker itself; it is the part clients ask to see. Nothing in the mandatory path waits on
Lesson 14, because deleting the key is now an optional follow-up.

## If you are running early

In slot 1: let the chatbox do the work. Every Part 1 lesson has an experiment nobody has time for
normally — argue with the hook in lesson 05, widen the allowlist in `tools.py`, `/style eli5`
mid-history in lesson 03. Take one, do it live, take questions.

In slot 2: release the room into Lessons 11 to 14 and let helpers float, as Module 8 describes.

Do not add material from the front. The fast finishers are already occupied and the rest need the air.
