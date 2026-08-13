# Presentation outline

**12 minutes. Hard stop.** Around 10 slides.

The lab teaches the content. This deck has exactly one job: make sixty security people want
to open a terminal. Every minute you overrun comes out of hands-on time, and hands-on time is
the entire point.

Audience: **Idira Domain Consultants** — security professionals, not developers. Two things
follow from that. They are sceptical of AI hype and will catch an overclaim, so lean into it.
And they will be asked to *demo* this to customers, so every product name has to be said
correctly and every claim has to survive a customer's follow-up question.

---

## 1 · Title (30 s)

Event name on the slide furniture, on every slide: **SKO27 TechSummit - Idira AI Workshops**.

Session title, large:

**Vibe coding, for people who audit other people's code**

Plus the one instruction, large, and leave it visible for the rest of the session:

> Double-click `lab/index.html`

## 2 · What "vibe coding" means (1 min)

You describe the outcome. The agent writes the code. You review it.

You are not learning to be a developer today. You are learning to be a very fast, very
demanding reviewer — which is a job you already have.

One line for this specific room:

> You are also learning to demo this. Read every lesson twice: once as a user, once as the
> person who has to explain it to a customer next month.

## 3 · The demo (2 min) 🎬

**Live, not screenshots.** Open a terminal in `sandbox-app`, type:

> *In one sentence, what does this app do?*

Then:

> *Review every file in this project for hardcoded secrets.*

Let the room watch it find four secrets in a codebase you never opened. Stop there. Do not
fix anything — that is their job in twenty minutes.

If the venue network is unreliable, have a recording ready. Do not let a failed live demo eat
three minutes; switch to the recording without comment and move on.

## 4 · The uncomfortable part (1.5 min) ⚠️

**Word this carefully. This is the slide the room will test you on.**

> Ask an agent to "write a script that uploads a file to S3" without mentioning credentials,
> and it will **frequently** put them straight into the file — because that is what most of
> the code it learned from does.

Then the honest qualifier, out loud:

> Current models are getting better at this, and often reach for an environment variable
> instead. So this is not "always". But *frequently* is a bad number when your organisation is
> shipping sixty times a week. **Speed makes review matter more, not less.**

Do **not** say "AI always generates embedded secrets". Somebody in that room has tried it and
seen it do the right thing, and you will lose them for the whole session.

Optional, if you want the room fully awake: in Lesson 6 they can run this experiment
themselves and compare with their neighbour. They will not all get the same answer.

## 5 · Four secrets, two fates (2 min) 🔑

The conceptual core. Draw it as two columns:

| 🔒 Onboard it | ✂️ Eliminate it |
| --- | --- |
| Move the secret into a vault | Delete the secret entirely |
| It still exists — safer, rotated, audited | It does not exist. Nothing to steal or rotate. |
| GitHub tokens, Slack webhooks, DB passwords | Cloud access, where the platform mints short-lived credentials |
| **Idira Secrets Manager** | **Idira Secure Cloud Access** |
| Named today, not done today | **Today** |

The line to land:

> When you find a stored secret, ask **"does this need to exist at all?"** *before* you ask
> "where should we keep it?"

Almost everyone in the room defaults to the second question. That reflex is the thing this
workshop is trying to change.

**Say both product names, and say them together**, because that is the sentence a Domain
Consultant needs in front of a customer:

> Eliminate what you can with Secure Cloud Access. Vault the rest in Secrets Manager. An
> embedded secret has exactly two acceptable endings, and "we moved it to an environment
> variable" is not one of them.

## 6 · Zero standing privileges (2 min) 🎫

A long-lived key is a bet: *nobody will ever leak this, for as long as it exists.*

**Zero standing privileges** removes the bet rather than hedging it — between tasks, the identity
holds nothing at all:

- Access is granted **when you ask**, not in advance
- Only if **policy** says you may
- It **expires by itself**
- Every request is **recorded against your name** — which a shared key can never do

Then the beat that lands best with this audience:

> You already did this. Ten minutes ago you copied credentials out of the portal that started
> with `ASIA` and came with a session token. Those expire. Nobody has ever given you a
> permanent AWS key for this tenant.

Reuse the before/after diagram from
[Lesson 3](../lab/0003-zsp-access.html) so the slide and the lab match.

**Then close the obvious gap before someone else does** 🖥️ — twenty seconds, on the same slide, no
extra slide. A DC will be asked this on a customer site, so answer it in two sentences and move on:

> "So anyone who downloads the CLI can request access?" — Not on a managed endpoint. **Idira EPM**
> decides which executables are allowed to run and by whom, offers an approval flow when it blocks
> one, and audits the decision.

The stack, said as one line, which is the sentence worth taking away:

> **EPM** — which tool may run here. **Secure Cloud Access** — what access it can obtain, and for how
> long. **Secrets Manager** — what happens to the secrets you cannot eliminate.

No EPM demo, no console screenshot. It is not in the lab, and promising a demo you do not give is
worse than not mentioning it.

## 7 · The Identity Broker (1.5 min) 🛡️

**This is the slide that sells the session to this audience, so do not rush it.**

An agent needs to reach a system. Two ways to arrange that:

| Without the Broker | With the Idira Identity Broker |
| --- | --- |
| The agent holds a credential | The **Broker** holds the credential |
| The credential is in a config file, an env var, or the model's context | The agent never sees it |
| The log says "this API key was used" | The log names **the human, the agent, the server, the tool** |
| Revoking means finding and rotating the secret | Revoking is **one click**, instantly, for every agent |

Then set up the moment they will get in Module 5, and do not spoil it:

> Later today you are all going to connect an agent through the Broker and call a tool. Then I
> am going to click one button up here, and all sixty of you will lose access at the same
> instant. Watch for that.

And the one governance sentence, because a customer will ask:

> Access is **deny by default**. A call is allowed only where a policy matches both *who* — the
> user **and** the agent — and *what* — the specific tool on the specific server.

Reuse the without/with diagram from
[Lesson 5](../lab/0005-identity-broker.html).

## 8 · What you will actually do (1 min) 🗺️

The five-move arc from `lab/index.html`:

**🔎 Look → 🔑 Find → 🎫 Elevate → ✂️ Delete → 🛡️ Broker**

Say the timings, and say clearly that **Lessons 1–5 are for everyone** and **Lessons 6, 7 and 8
are optional** — nobody is expected to reach them. Explicitly give people permission not to
finish. Sixty people, mixed comfort with terminals — someone will feel behind, and telling them
in advance that it is fine costs you ten seconds.

Mention the **page selector** at the top of every lab page (the dropdown between Back and Next).
Nobody needs to return to the index to move on, and nobody gets lost.

## 9 · What we are not covering (45 s) 🚧

Say this from the front, so nobody spends the session waiting for it:

- **Vaulting the other three secrets.** That is **Idira Secrets Manager**, and a follow-up
  session. We will name it as the right answer several times today; we will not do it.
- **Writing an access policy.** You will *use* one today. Authoring one needs the Secure AI
  Admin role.
- **Tests, CI, branching.** Lesson 8 shows the shape of the full harness; the AI-harness
  workshop covers the rest.

Naming the gaps buys you enormous credibility with this audience, and costs nothing.

## 10 · Go (30 s) 🚀

- Double-click `lab/index.html`
- Start at Lesson 1
- Hold up your numbered card if you are stuck — helpers will come to you 🙋
- No prior coding experience needed. Genuinely.

---

## Notes for the presenter

**The one thing not to say.** Do not imply that today's exercise makes the app secret-free.
It removes one of four secrets. Three remain, deliberately, and Lesson 4 makes attendees find
them again. If you overclaim on slide 5, Lesson 4 contradicts you in front of the room.

**The one thing to repeat.** *Onboard* versus *eliminate*, with the product name attached to
each. Slide 5, again in Module 2, again in Module 4, again in the wrap. If people leave with
only one idea, this is the one worth having.

**The one thing to promise.** The kill switch on slide 7. Set the expectation here and pay it
off in Module 5. It is the thirty seconds attendees will reuse in front of customers, and
foreshadowing it doubles its effect.

**Terminal font size.** Rehearse it at projector resolution from the back row. Everything in
this session is terminal output, and a demo nobody can read is worse than no demo.

**Timekeeping.** Slides 3, 5 and 7 are where you will overrun. If you are past 8 minutes by the
end of slide 7, cut slide 8 to a single sentence and go. Do not cut slide 7 — Module 5 lands
much harder when it was promised.
