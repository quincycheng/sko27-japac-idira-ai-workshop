# Run of show

**Slot:** 90 minutes. **Planned:** 70 minutes. **Buffer:** 20 minutes.

The buffer is not padding — it is the thing that makes a room of sixty non-developers
survivable. Expect to spend it on Module 1 and on questions.

**Audience:** Idira **Domain Consultants**. They are not just learning to use an agent; they
will be asked to demo this to customers. That changes the emphasis in two places — Module 2
(name the Idira product for each fix) and Module 5 (the Identity Broker, which is the part
clients ask to see).

| # | Module | Min | Cumulative | Who leads |
| --- | --- | --- | --- | --- |
| 0 | Presentation | 12 | 12 | Trainer A |
| 1 | Prework check — Lesson 1 | 5 | 17 | Trainer B + all helpers |
| 2 | Find the secrets — Lesson 2 | 13 | 30 | Trainer A |
| 3 | Zero standing privileges — Lesson 3 | 10 | 40 | Trainer B |
| 4 | Delete the key — Lesson 4 | 8 | 48 | Trainer A |
| 5 | The Identity Broker — Lesson 5 | 12 | 60 | Trainer B |
| 6 | Wrap and Q&A | 10 | 70 | Both |

Modules 1–5 are **mandatory**. Lessons 6, 7 and 8 are **optional**, each a self-contained
page, and exist to occupy fast finishers so they do not derail the room.

---

## Module 0 · Presentation (12 min)

See [presentation-outline.md](presentation-outline.md). Twelve minutes, hard stop. The
lab teaches the content; the presentation only has to make people want to do the lab.

Close with the one instruction that matters: **open `lab/index.html` by double-clicking it.**
Put that on a slide and leave it up.

Tell them there is a **page selector at the top of every lab page** — the dropdown between the
Back and Next buttons. Nobody gets lost, and nobody has to go back to the index to move on.

---

## Module 1 · Prework check (5 min)

**Goal:** every laptop in the room has an agent that answers a question.

Attendees work through [Lesson 1](../lab/0001-setup.html). This is the highest-risk five
minutes of the session — it is where people who skipped the prework are discovered.

**All helpers are on the floor for this module.** Nobody sits down.

Trainer B narrates the steps from the front at the pace of the slowest third, while helpers
work the room. The two most common failures are a new terminal window with no environment
variables, and a virtual environment that is not switched on (no `(.venv)` in the prompt) —
both in [helper-runbook.md](helper-runbook.md).

Say the `(.venv)` thing out loud as you narrate step 5. It is one sentence and it prevents a
dozen hands going up later:

> If your prompt does not start with `(.venv)`, Python cannot see `boto3`. Every window,
> every time.

**Gate:** do not start Module 2 until you have visually confirmed the room. Ask for hands
*down* if the agent answered — hands still up are your work list. If more than about five
people are stuck, pair them with a neighbour rather than holding sixty people.

Say out loud, because it is the free teaching beat of the day:

> The credentials you just pasted were themselves short-lived. Nobody gave you a permanent AWS
> key — before you clicked, your standing access to that account was zero. That is the whole
> idea of Module 3. Hold that thought for twenty minutes.

---

## Module 2 · Find the secrets (13 min)

**Goal:** everyone has an agent-produced table of four secrets, and can name the difference
between eliminating one and vaulting one — **with the Idira product name attached to each**.

Attendees work [Lesson 2](../lab/0002-find-the-secrets.html). Mostly self-paced; Trainer A
punctuates it with three interventions:

1. **After the app fails** (~3 min in) — read the error aloud. "It does not say *no
   credentials*. It says the credentials were *rejected*. So it has credentials. Where?"
2. **After the review returns** (~8 min in) — take three answers from the room on what was
   found. Do not accept "an AWS key" — push for all four.
3. **The two-fixes table** (~11 min in) — do this from the front, on the slide. It is the
   conceptual centre of the workshop and it must not be skimmed as reading.

On intervention 3, land the product names, because this room will be asked for them by name:

> Eliminate → **Idira Secure Cloud Access**. Vault → **Idira Secrets Manager**. Say both
> halves to a client. "Eliminate what you can, vault the rest."

The lesson also asks them to run the built-in `/security-review`. On a fresh clone there may
be no *pending changes* for it to look at, in which case the lesson tells them to ask for the
whole project instead. **Know which behaviour your repo produces** — it is a dry-run capture
item in [owner-prep.md](owner-prep.md) — and say it from the front so sixty people do not
each discover it separately.

The honest claim about AI-generated credentials belongs here, worded as in the lesson:
models *frequently* inline credentials when prompted casually, not always. Do not overstate
it — this room will catch you.

---

## Module 3 · Zero standing privileges (10 min)

**Goal:** every attendee has run `get_caller_identity()` and seen an elevated role ARN with
their own name in it.

Attendees work [Lesson 3](../lab/0003-zsp-access.html). Trainer B demos steps 1–4 from the
front first, at full size, then releases the room. Do not let sixty people discover
`list-targets` output formatting simultaneously without having seen it once.

Three beats to call out — the third is twenty seconds, not a section:

- **The skill is one page of English.** Have people actually open `SKILL.md`. This is the
  moment the phrase "AI harness" becomes concrete rather than a slide.
- **The ARN carries their name.** A shared access key can never tell you who used it.
- **Name Idira EPM, once, out loud.** It is in the lesson as a callout under step 2, and it answers
  the question this room will ask on a customer site: *what stops anyone downloading this CLI and
  requesting access?* One sentence:

  > `idsec` is itself a privileged tool. **Idira EPM** decides which executables may run on the
  > endpoint and by whom — application control, an approval flow when it blocks something, and an
  > audit trail. **EPM** governs which tool may run; **Secure Cloud Access** governs what access
  > that tool can obtain; **Secrets Manager** holds what you cannot eliminate.

  Do not open the EPM console and do not demo it — it is not in the lab and there is no time. This is
  a naming beat that makes the story complete, nothing more.

**Watch for:** the credential hand-off in step 5 requires leaving the agent (`/exit`) to set
environment variables. People will try to get the agent to do it and it cannot.

⚠️ **On the projector, do not run `elevate` live without checking first.** Depending on the CLI
build, its JSON response can contain the short-lived credentials themselves in an
`accessCredentials` field, and the agent shows you command output verbatim. Confirm what your
build prints during the dry run (G7). If it prints credentials, demo steps 1–3 from the front and
let attendees run `elevate` at their own desks. Attendees' own credentials on their own screens
are fine — they are short-lived and scoped to a sandbox account.

---

## Module 4 · Delete the key (8 min)

**Goal:** `python summarize.py` works, and `grep AKIA` finds nothing.

Attendees work [Lesson 4](../lab/0004-fix-the-app.html). Fast module — the agent does the
work. Trainer A's job is to slow people down at two points:

1. **Before approving the change.** They are the review step. Make them read the diff.
2. **After it works.** Land the distinction explicitly: not hidden, not moved, not rotated —
   *eliminated*. Seven lines removed, nothing added, no vault to run, no rotation schedule.

Then close the honesty loop: **three of the four secrets are still there.** Say the number.
It is the line that makes the whole session credible to a security audience.

**The DC-specific beat**, which is in the lesson as a stop callout — read it from the front,
because it is the question a customer asks thirty seconds after this demo:

> Deleting the constants is the right answer *for the AWS key*. It is not a general answer to
> secrets. In production, everything you cannot eliminate goes into **Idira Secrets Manager** —
> vaulted, rotated, audited, fetched at run time. Never a long-lived secret in an environment
> variable. That is a config file wearing a disguise.

---

## Module 5 · The Identity Broker (12 min) 🛡️

**Goal:** every attendee has an MCP server connected through the Broker, has authenticated as
their own numbered user, has called a tool while holding **no credential for that system**, and
has watched the room lose access when the trainer clicks Disable.

This module is mandatory because it is the part Domain Consultants get asked to demo. Treat it
as a rehearsal for that demo, not as an exercise.

Attendees work [Lesson 5](../lab/0005-identity-broker.html). Trainer B drives it from the
front, at the pace of the room, in three parts:

**Part 1 — connect (≈5 min).** `claude mcp add …` outside the agent, then `/mcp` inside it,
then the browser sign-in. Have the Gateway URL and the Client ID **on a slide, large**, and
leave them up for the whole module. The Client Secret is the only thing that needs care —
`--client-secret` takes no value and prompts, so it never reaches shell history.

Two failure modes, both expected: a server listed as *needs authentication* (they have not run
`/mcp` yet) and a browser callback page that does not load (the callback is
`http://localhost:<port>` — a VPN or proxy can eat it). Both are in the helper runbook.

**Part 2 — the audit log, on the projector (≈3 min).** Do this *live*, big, in the console. Ask
someone to shout their attendee number and find their call. What the room needs to see, in one
sentence:

> The log names the human, the agent, the tool and the server — and it does that for every
> call, successful or refused.

Then the sentence that makes it matter to a security person:

> The agent never held a credential for that system. The Broker holds it. That is why there is
> nothing to leak and nothing to rotate.

**Part 3 — the kill switch (≈4 min).** The moment of the session. With everyone connected and
working, set the MCP server to **Disabled** in the console. Wait. Let attendees discover their
next tool call fails.

Say it while they are watching:

> One click. Every agent, every attendee, immediately. No credential to hunt down, no key to
> rotate, no application to redeploy.

Then **Enable it again** and confirm the room recovers. Do not leave it disabled — the optional
lessons do not need it, but a room that thinks it broke something is a distracted room.

Also cover, briefly and from the front, the two enforcement facts the lesson states, because
they are the ones a customer pushes on:

- Access is **deny by default**. A policy allows a call only when it matches *both* the
  principal (user or role **and** the AI agent) and the resource (the tool on that server).
  Console path: **Manage > Policies > AI agents access**.
- **Both** the agent and the server must be enabled for any policy to apply.

Point at the last section of the lesson — *Your five-minute client demo* — and tell them
plainly: that is the script, it works, use it.

---

## Module 6 · Wrap and Q&A (10 min)

- 3 min — recap using the table at the bottom of Lesson 4, plus the one Broker sentence
- 2 min — what we deliberately did *not* cover: vaulting the other three secrets in **Idira
  Secrets Manager**, and writing access policies (they consumed one today; they did not author
  one). Both are follow-up sessions.
- 5 min — questions

Point at the three optional lessons as the take-home, by name, so people know what they are
choosing between:

- [Lesson 6 · Build something from nothing with a simple prompt](../lab/0006-build-from-nothing.html) — ~10 min
- [Lesson 7 · Write your own skill](../lab/0007-write-a-skill.html) — ~15 min
- [Lesson 8 · Build something AFK](../lab/0008-afk-harness.html) — ~20 min, the full harness

And at the [cheat sheet](../lab/reference/cheatsheet.html). Tell people the folder is theirs to
keep, and that the lab pages work on a phone too — they are responsive, so the guide is
readable on the train home.

---

## If you are running late

Cut in this order:

1. **Module 2, intervention 2** — take one answer from the room instead of three. Saves 3 min.
2. **Module 3's front-of-room demo** — release the room straight into the lesson. Saves 4 min,
   costs you helper load.
3. **Module 4, step 4** ("find what you did not fix") — but then you *must* state the
   three-of-four number from the front. Saves 3 min. Never cut the honesty, only the exercise.
4. **Module 5, the policy explanation** — reduce it to the two enforcement facts and point at
   the lesson for the rest. Saves 2 min.

Do not cut Module 1. Do not cut Module 5, and in particular **do not cut the kill switch** —
it is the single most memorable thirty seconds of the session and the thing attendees will
reuse in front of customers. Do not cut the Q&A; this audience will have good questions and
cutting them is how a workshop gets remembered badly.

If you are so far behind that Module 5 will not fit, cut Module 4 to a front-of-room demo
instead and let attendees do Lesson 4 afterwards. Lesson 5 does not depend on Lesson 4 having
been completed.

## If you are running early

Release the room into Lessons 6–8 and let helpers float. Say which one suits whom: 6 if you
want to play, 7 if you want something reusable at work, 8 if you want to see the whole harness.
Do not add material from the front — the fast finishers are already occupied and the rest need
the air.
