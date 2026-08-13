# Run of show

**Slot:** 90 minutes. **Planned:** 87 minutes. **Buffer:** 3 minutes.

⚠️ **Read that buffer number before you plan anything else.** The earlier version of this workshop
planned 70 minutes and kept 20 in reserve, and that reserve was the thing that made a room of sixty
non-developers survivable. Part 1 has since been added, and it is worth the time, but it has eaten
almost all of the slack. Two consequences, both of which you have to accept up front:

1. **You will need to cut something on the day.** Read *If you are running late* now, not at minute
   sixty. The first cut is chosen for you.
2. **Lessons 03 and 04 are self-paced and are not run live.** That is not a time-saving fudge, it is
   how those two pages are written. Say so from the front or twenty people will quietly start
   working through them while you talk about lesson 05.

If your slot is genuinely 90 minutes and the room is new to terminals, consider making **lesson 05
self-paced as well** before you start. That returns the buffer to about 13 minutes and costs you the
prompt-injection beat, which is the most quotable part of Part 1. It is a real trade and it is yours
to make, but make it in advance rather than at minute seventy.

**Audience:** Idira **Domain Consultants**. They are not just learning to use an agent; they
will be asked to demo this to customers. That changes the emphasis in three places: Part 1 (they
have to be able to *explain* an agent, not only drive one), Module 3 (name the Idira product for
each fix) and Module 6 (the Identity Broker, which is the part clients ask to see).

| # | Module | Min | Cumulative | Who leads |
| --- | --- | --- | --- | --- |
| 0 | Welcome and ground rules | 3 | 3 | Trainer A |
| 1 | Part 1 live — Lessons 01, 02, 05 | 28 | 31 | Trainer A |
| 2 | Prework check — Lesson 06 | 5 | 36 | Trainer B + all helpers |
| 3 | Find the secrets — Lesson 07 | 13 | 49 | Trainer A |
| 4 | Zero standing privileges — Lesson 08 | 10 | 59 | Trainer B |
| 5 | Delete the key — Lesson 09 | 8 | 67 | Trainer A |
| 6 | The Identity Broker — Lesson 10 | 12 | 79 | Trainer B |
| 7 | Wrap and Q&A | 8 | 87 | Both |

**There is no slide deck any more.** Part 1 replaced it. The old twelve-minute presentation
explained what an agent is; attendees now build one instead, which lands harder and takes the same
time. What survives is a three-minute opener, in
[presentation-outline.md](presentation-outline.md).

Modules 1 to 6 are **mandatory**. **Lessons 03 and 04** are mandatory reading but self-paced.
**Lessons 11, 12 and 13** are **optional advanced courses**, each a self-contained page, and exist
to occupy fast finishers so they do not derail the room.

---

## Module 0 · Welcome and ground rules (3 min)

See [presentation-outline.md](presentation-outline.md). Three minutes, hard stop. You are not
teaching anything here, you are getting sixty people pointed at the same file.

Close with the one instruction that matters: **open `lab/index.html` by double-clicking it.**
Put that on a slide and leave it up.

Three things to say and then stop:

- There is a **page selector at the top of every lab page**, the dropdown between Back and Next.
  Nobody gets lost and nobody has to return to the index to move on.
- **Thirteen lessons, numbered in the order you do them.** 01 to 05 build an agent, 06 to 10 use a
  real one, 11 to 13 are optional advanced courses for people who finish early.
- **Raise your numbered card** rather than waiting politely. Helpers are watching for cards, not
  for confused faces.

---

## Module 1 · Part 1 live (28 min)

**Goal:** every attendee can say what an AI agent actually is, out loud, without using the word
"magic", because they built one and then broke it.

This is the module that makes the room able to *explain* Claude Code to a customer rather than only
demo it. Trainer A leads all three lessons from the front, with attendees running the same commands
at their own machines.

**Lesson 01 · One call to a model (~8 min).** [Page](../lab/0001-one-call.html) ·
`python 01_bare_call.py`. Credentials and the virtual environment get set up here, which is why this
lesson comes before the prework check rather than after it. Expect the environment problems to
surface now. That is deliberate and it is why all helpers are on the floor.

The beat to land, in one sentence:

> That is a model. It talked, it could not act, and it forgot you the moment it answered. Everything
> else today is code we wrap around it.

**Lesson 02 · Give it a tool (~10 min).** [Page](../lab/0002-give-it-a-tool.html) ·
`python 02_single_tool.py`. The best twelve minutes of the session for audience participation,
because it opens with a **secret hunt**: attendees grep `ai-harness-app/sandbox/` by hand and count
what they find, before any agent runs.

Run the hunt as a room. Ask for numbers out loud. Most people find four of the six. The two nobody
finds are a hidden `.env` and a password buried inside a `postgres://` URL, and that miss is the
whole argument for eliminating credentials instead of scanning for them. Do not give the answer
early; let them be wrong first.

> You just did what a scanner does, and you missed two. This is why "we grep for secrets" is not a
> security control.

**Lesson 05 · When the data lies (~10 min).** [Page](../lab/0005-when-data-lies.html) ·
`python 05_prompt_injection.py`. A file in the repo gives the agent instructions and the agent
refuses, not because it was asked nicely but because `_safe_path()` and a two-command allowlist
would not carry out the request.

This is the beat this audience will reuse in front of customers:

> The model was talked into it. The controls refused anyway. When a vendor tells you their agent is
> safe because of its system prompt, that is the wrong answer.

⚠️ **The model's refusal is not deterministic.** Sometimes it declines the injected instructions on
its own, sometimes it tries and the tool layer blocks it. Both outcomes prove the point, and the
page says so. Do not promise the room a specific output.

**Point at lessons 03 and 04 and move on.** They cover the system prompt plus the iteration cap, and
token accounting plus compaction. Say plainly: "these two are yours to read, they are written for
that, and 04 is where `/compact` comes from." Do not summarise them from the front. If you start,
you will spend nine minutes you do not have.

**Gate:** do not start Module 2 until the room has seen a refusal in lesson 05. If you are already
behind, see *If you are running late*.

---

## Module 2 · Prework check (5 min)

**Goal:** every laptop in the room has an agent that answers a question.

Attendees work through [Lesson 06](../lab/0006-setup.html). This used to be the highest-risk five
minutes of the session. It is less risky now, because Part 1 already required the credentials and
the virtual environment, so most of the breakage has surfaced during Module 1.

**All helpers are on the floor for this module.** Nobody sits down.

Trainer B narrates the steps from the front at the pace of the slowest third, while helpers
work the room. The two most common failures are a new terminal window with no environment
variables, and a virtual environment that is not switched on (no `(.venv)` in the prompt).
Both are in [helper-runbook.md](helper-runbook.md).

Say the `(.venv)` thing out loud as you narrate step 5. It is one sentence and it prevents a
dozen hands going up later:

> If your prompt does not start with `(.venv)`, Python cannot see `boto3`. Every window,
> every time.

**Gate:** do not start Module 3 until you have visually confirmed the room. Ask for hands
*down* if the agent answered; hands still up are your work list. If more than about five
people are stuck, pair them with a neighbour rather than holding sixty people.

Say out loud, because it is the free teaching beat of the day:

> The credentials you pasted were themselves short-lived. Nobody gave you a permanent AWS
> key. Before you clicked, your standing access to that account was zero. That is the whole
> idea of Module 4. Hold that thought for twenty minutes.

---

## Module 3 · Find the secrets (13 min)

**Goal:** everyone has an agent-produced table of four secrets, and can name the difference
between eliminating one and vaulting one, **with the Idira product name attached to each**.

Attendees work [Lesson 07](../lab/0007-find-the-secrets.html). Mostly self-paced; Trainer A
punctuates it with three interventions:

1. **After the app fails** (~3 min in). Read the error aloud. "It does not say *no
   credentials*. It says the credentials were *rejected*. So it has credentials. Where?"
2. **After the review returns** (~8 min in). Take three answers from the room on what was
   found. Do not accept "an AWS key"; push for all four.
3. **The two-fixes table** (~11 min in). Do this from the front, on the slide. It is the
   conceptual centre of the workshop and it must not be skimmed as reading.

Callback to Part 1 that costs you ten seconds and is worth it:

> In lesson 02 you hunted six of these by hand and found four. The agent found them in one pass.
> That is a better scanner, and it is still not a fix.

On intervention 3, land the product names, because this room will be asked for them by name:

> Eliminate → **Idira Secure Cloud Access**. Vault → **Idira Secrets Manager**. Say both
> halves to a client. "Eliminate what you can, vault the rest."

The lesson also asks them to run the built-in `/security-review`. On a fresh clone there may
be no *pending changes* for it to look at, in which case the lesson tells them to ask for the
whole project instead. **Know which behaviour your repo produces.** It is a dry-run capture
item in [owner-prep.md](owner-prep.md). Say it from the front so sixty people do not
each discover it separately.

The honest claim about AI-generated credentials belongs here, worded as in the lesson:
models *frequently* inline credentials when prompted casually, not always. Do not overstate
it; this room will catch you.

---

## Module 4 · Zero standing privileges (10 min)

**Goal:** every attendee has run `get_caller_identity()` and seen an elevated role ARN with
their own name in it.

Attendees work [Lesson 08](../lab/0008-zsp-access.html). Trainer B demos steps 1 to 4 from the
front first, at full size, then releases the room. Do not let sixty people discover
`list-targets` output formatting simultaneously without having seen it once.

Four beats to call out. The last two are twenty seconds each, not sections:

- **The skill is one page of English.** Have people actually open `SKILL.md`. This is the
  moment the phrase "AI harness" becomes concrete rather than a slide, and Part 1 has already
  primed them for it.
- **The ARN carries their name.** A shared access key can never tell you who used it.
- **Nothing was pre-wired for this.** No OIDC provider, no IAM trust policy, no per-person role,
  no CloudFormation. It is in the lesson as a callout under *The idea*, and it answers the first
  question a customer asks about effort. One sentence:

  > Nobody set up federation in that AWS account for you. There is no identity provider to
  > configure, no trust relationship to write and no role per person to maintain. Secure Cloud
  > Access brokers the request, so the setup cost you are looking at is the login you already did.

- **Name Idira EPM, once, out loud.** It is in the lesson as a callout under step 2, and it answers
  the question this room will ask on a customer site: *what stops anyone downloading this CLI and
  requesting access?* One sentence:

  > `idsec` is itself a privileged tool. **Idira EPM** decides which executables may run on the
  > endpoint and by whom: application control, an approval flow when it blocks something, and an
  > audit trail. **EPM** governs which tool may run; **Secure Cloud Access** governs what access
  > that tool can obtain; **Secrets Manager** holds what you cannot eliminate.

  Do not open the EPM console and do not demo it. It is not in the lab and there is no time. This is
  a naming beat that makes the story complete, nothing more.

**Watch for:** the credential hand-off in step 5 requires leaving the agent (`/exit`) to set
environment variables. People will try to get the agent to do it and it cannot.

**Close the module by promising the kill switch.** One sentence, because the old deck used to do
this and Module 6 lands measurably harder when it was foreshadowed:

> In about twenty minutes you are all going to connect an agent through the Broker and call a tool.
> Then I am going to click one button up here, and all sixty of you will lose access at the same
> instant. Watch for that.

⚠️ **On the projector, do not run `elevate` live without checking first.** Depending on the CLI
build, its JSON response can contain the short-lived credentials themselves in an
`accessCredentials` field, and the agent shows you command output verbatim. Confirm what your
build prints during the dry run (G7). If it prints credentials, demo steps 1 to 3 from the front and
let attendees run `elevate` at their own desks. Attendees' own credentials on their own screens
are fine; they are short-lived and scoped to a sandbox account.

---

## Module 5 · Delete the key (8 min)

**Goal:** `python summarize.py` works, and `grep AKIA` finds nothing.

Attendees work [Lesson 09](../lab/0009-fix-the-app.html). Fast module, because the agent does the
work. Trainer A's job is to slow people down at two points:

1. **Before approving the change.** They are the review step. Make them read the diff.
2. **After it works.** Land the distinction explicitly: not hidden, not moved, not rotated,
   *eliminated*. Seven lines removed, nothing added, no vault to run, no rotation schedule.

Then close the honesty loop: **three of the four secrets are still there.** Say the number.
It is the line that makes the whole session credible to a security audience.

**The DC-specific beat**, which is in the lesson as a stop callout. Read it from the front,
because it is the question a customer asks thirty seconds after this demo:

> Deleting the constants is the right answer *for the AWS key*. It is not a general answer to
> secrets. In production, everything you cannot eliminate goes into **Idira Secrets Manager**:
> vaulted, rotated, audited, fetched at run time. Never a long-lived secret in an environment
> variable. That is a config file wearing a disguise.

---

## Module 6 · The Identity Broker (12 min) 🛡️

**Goal:** every attendee has an MCP server connected through the Broker, has authenticated as
their own numbered user, has called a tool while holding **no credential for that system**, and
has watched the room lose access when the trainer clicks Disable.

This module is mandatory because it is the part Domain Consultants get asked to demo. Treat it
as a rehearsal for that demo, not as an exercise.

Attendees work [Lesson 10](../lab/0010-identity-broker.html). Trainer B drives it from the
front, at the pace of the room, in three parts:

**Part 1, connect (≈5 min).** `claude mcp add …` outside the agent, then `/mcp` inside it,
then the browser sign-in. Have the Gateway URL and the Client ID **on a slide, large**, and
leave them up for the whole module. The Client Secret is the only thing that needs care:
`--client-secret` takes no value and prompts, so it never reaches shell history.

Two failure modes, both expected: a server listed as *needs authentication* (they have not run
`/mcp` yet) and a browser callback page that does not load (the callback is
`http://localhost:<port>`, and a VPN or proxy can eat it). Both are in the helper runbook.

**Part 2, the audit log, on the projector (≈3 min).** Do this *live*, big, in the console. Ask
someone to shout their attendee number and find their call. What the room needs to see, in one
sentence:

> The log names the human, the agent, the tool and the server, and it does that for every
> call, successful or refused.

Then the sentence that makes it matter to a security person:

> The agent never held a credential for that system. The Broker holds it. That is why there is
> nothing to leak and nothing to rotate.

**Part 3, the kill switch (≈4 min).** The moment of the session. With everyone connected and
working, set the MCP server to **Disabled** in the console. Wait. Let attendees discover their
next tool call fails.

Say it while they are watching:

> One click. Every agent, every attendee, immediately. No credential to hunt down, no key to
> rotate, no application to redeploy.

Then **Enable it again** and confirm the room recovers. Do not leave it disabled. The optional
advanced courses do not need it, but a room that thinks it broke something is a distracted room.

Also cover, briefly and from the front, the two enforcement facts the lesson states, because
they are the ones a customer pushes on:

- Access is **deny by default**. A policy allows a call only when it matches *both* the
  principal (user or role **and** the AI agent) and the resource (the tool on that server).
  Console path: **Manage > Policies > AI agents access**.
- **Both** the agent and the server must be enabled for any policy to apply.

Point at the last section of the lesson, *Your five-minute client demo*, and tell them
plainly: that is the script, it works, use it.

---

## Module 7 · Wrap and Q&A (8 min)

- 2 min: recap using the table at the bottom of Lesson 09, plus the one Broker sentence
- 2 min: what we deliberately did *not* cover. Vaulting the other three secrets in **Idira
  Secrets Manager**, and writing access policies (they consumed one today; they did not author
  one). Both are follow-up sessions.
- 4 min: questions

Two take-home pointers. First, **lessons 03 and 04**, which nobody ran live:

> 03 is the system prompt and the iteration cap. 04 is why your agent does not fall over on a long
> task, and it is where `/compact` comes from. Twenty minutes, on the train, and you will be able
> to answer the context-window question a customer asks.

Then the three optional advanced courses, by name, so people know what they are choosing between:

- [Lesson 11 · Build something from nothing with a simple prompt](../lab/0011-build-from-nothing.html) · ~10 min
- [Lesson 12 · Write your own skill](../lab/0012-write-a-skill.html) · ~15 min
- [Lesson 13 · Build something AFK](../lab/0013-afk-harness.html) · ~20 min, the full harness

And at the [cheat sheet](../lab/reference/cheatsheet.html). Tell people the folder is theirs to
keep, and that the lab pages work on a phone too. They are responsive, so the guide is
readable on the train home.

---

## If you are running late

With a 3 minute buffer you should assume you will be. Cut in this order:

1. **Lesson 05's second run** (the "run it again and watch it differ" step). Demo the
   non-determinism from the front instead of having sixty people re-run it. Saves 3 min.
2. **Module 3, intervention 2.** Take one answer from the room instead of three. Saves 3 min.
3. **Module 4's front-of-room demo.** Release the room straight into the lesson. Saves 4 min,
   costs you helper load.
4. **Lesson 02's secret hunt, as a room.** Give them the answer table after two minutes rather than
   letting them search for five. Saves 3 min and costs you the best participation beat of the day,
   which is why it is fourth and not first.
5. **Module 5, step 4** ("find what you did not fix"), but then you *must* state the
   three-of-four number from the front. Saves 3 min. Never cut the honesty, only the exercise.
6. **Module 6, the policy explanation.** Reduce it to the two enforcement facts and point at
   the lesson for the rest. Saves 2 min.

That is 18 minutes of cuts available before you have to touch anything structural.

Do not cut Module 2. Do not cut Module 6, and in particular **do not cut the kill switch**.
It is the single most memorable thirty seconds of the session and the thing attendees will
reuse in front of customers. Do not cut the Q&A; this audience will have good questions and
cutting them is how a workshop gets remembered badly.

**If you are more than ten minutes down by the end of Module 1**, drop lesson 05 to a two-minute
front-of-room demo and tell the room to read the page later. That recovers 8 minutes in one move.
Lessons 06 to 10 do not depend on lesson 05 having been run.

If you are so far behind that Module 6 will not fit, cut Module 5 to a front-of-room demo
instead and let attendees do Lesson 09 afterwards. Lesson 10 does not depend on Lesson 09 having
been completed.

## If you are running early

You will not be, but if you are: release the room into Lessons 11 to 13 and let helpers float. Say
which one suits whom. 11 if you want to play, 12 if you want something reusable at work, 13 if you
want to see the whole harness. Or point people at lessons 03 and 04, which they have not done.

Do not add material from the front. The fast finishers are already occupied and the rest need
the air.
