# Opening remarks

**3 minutes. Hard stop.** Three slides.

**There is no deck any more.** This session used to open with twelve minutes of slides explaining
what an AI agent is. Part 1 replaced them: attendees now build one, in five steps, starting from
fifteen lines of Python. It costs the same time and it lands harder, because nobody has to take your
word for anything.

So your job in these three minutes is small and specific: get sixty people pointed at the same file,
and tell them how the room works. You are not teaching yet. Resist the urge.

The material that used to be on slides 4 to 9 has not been thrown away. It is delivered in the
lessons now, and the trainer beats are scripted in [run-of-show.md](run-of-show.md). The exact
wording for the claims this audience will test you on is preserved in the appendix below, because
some of it is worth saying verbatim.

Audience: **Idira Domain Consultants**. Security professionals, not developers. They are sceptical
of AI hype and will catch an overclaim, so lean into that rather than around it. They will also be
asked to *demo* this to customers, which means every product name has to be said correctly.

---

## 1 · Title (45 s)

Event name on the slide furniture, on every slide: **SKO27 TechSummit - Idira AI Workshops**.

Session title, large:

**Vibe coding, for people who audit other people's code**

Plus the one instruction, large, and leave it visible for the rest of the session:

> Double-click `lab/index.html`

Say what vibe coding means here, in two sentences, and then stop:

> You describe the outcome, the agent writes the code, you review it. You are not learning to be a
> developer today, you are learning to be a very fast and very demanding reviewer, which is a job
> you already have.

One line for this specific room:

> You are also learning to demo this. Read every lesson twice. Once as a user, once as the person
> who has to explain it to a customer next month.

## 2 · How the room works (1 min 15 s) 🗺️

Four things. Put them all on one slide so you cannot accidentally talk for four minutes.

**Thirteen lessons, numbered in the order you do them.**

- **01 to 05, Part 1.** You build an AI agent out of parts. Five small Python files, about thirty
  lines each. By the end there is nothing in the box you have not seen.
- **06 to 10, Part 2.** You use a real one, Claude Code, on Idira problems.
- **11 to 13, optional advanced courses.** For people who finish early.

**We are running 01, 02 and 05 together. Lessons 03 and 04 are yours to read.** Say this clearly or
twenty people will quietly work ahead while you are talking:

> Two of the Part 1 lessons are self-paced. They are written for that, and they are marked. Read
> them on the train if you like. Nothing later today depends on you having done them.

**The page selector.** The dropdown at the top of every lab page, between Back and Next. Nobody has
to go back to the index to move on and nobody gets lost.

**The cards.** Hold up your numbered card the moment you are stuck. Do not wait politely. Helpers
are watching for cards, not for confused faces.

Then give people permission not to finish, which costs ten seconds and saves several people's
afternoon:

> Sixty people, mixed comfort with a terminal. Somebody in this room is going to feel behind. That
> is fine and it is expected. Lessons 11 to 13 exist precisely so that finishing early is not the
> goal.

## 3 · Go (1 min) 🚀

Two things you are *not* covering, said from the front so nobody spends the session waiting:

- **Vaulting the other three secrets.** That is **Idira Secrets Manager**, and a follow-up session.
  You will hear it named as the right answer several times today. You will not do it.
- **Writing an access policy.** You will *use* one today. Authoring one needs the Secure AI Admin
  role.

Naming the gaps buys real credibility with this audience and costs nothing.

Then:

- Double-click `lab/index.html`
- Start at **Lesson 01**
- Hold up your numbered card if you are stuck 🙋
- No prior coding experience needed

Go straight into Lesson 01 from the front. Do not pause for questions here; you have a Q&A at the
end and the first question will cost you four minutes.

---

## Notes for the presenter

**Do not demo.** The old deck had a two-minute live demo at this point. Lesson 02 now does that job
better, because attendees run it themselves after failing to find the secrets by hand. If you demo
here you will spoil that, and you will overrun.

**Do not explain what an agent is.** Lessons 01 and 02 do it in code. Anything you say here is
something they will hear again in six minutes, which trains the room to tune you out.

**Terminal font size.** Rehearse it at projector resolution from the back row. Nearly everything in
this session is terminal output, and a demo nobody can read is worse than no demo.

**Timekeeping.** If you are past 3 minutes at the end of slide 2, cut slide 3's "not covering" list
and say it in the wrap instead. Never cut the card instruction or the self-paced warning; those two
are what keep sixty people synchronised.

---

## Appendix · The retired slides, and where each beat now lives

The wording below survived several rehearsals with security audiences. It is here so you can lift
the phrasing verbatim when you reach these moments in the lessons. The scripted trainer beats are in
[run-of-show.md](run-of-show.md); this is the language.

### The uncomfortable part → now Lesson 11, and Module 3

**Word this carefully. It is the claim the room will test you on.**

> Ask an agent to "write a script that uploads a file to S3" without mentioning credentials, and it
> will **frequently** put them straight into the file, because that is what most of the code it
> learned from does.

Then the honest qualifier, out loud:

> Current models are getting better at this and often reach for an environment variable instead. So
> this is not "always". But *frequently* is a bad number when your organisation ships sixty times a
> week. **Speed makes review matter more, not less.**

Do **not** say "AI always generates embedded secrets". Somebody in that room has tried it and seen
it do the right thing, and you will lose them for the whole session.

In **Lesson 11** attendees run this experiment themselves and compare with a neighbour. They will
not all get the same answer, and that is worth more than a slide.

### Four secrets, two fates → now Module 3, intervention 3

The conceptual core of the whole workshop. Draw it as two columns, from the front, on a slide:

| 🔒 Onboard it | ✂️ Eliminate it |
| --- | --- |
| Move the secret into a vault | Delete the secret entirely |
| It still exists, but safer, rotated, audited | It does not exist. Nothing to steal or rotate. |
| GitHub tokens, Slack webhooks, DB passwords | Cloud access, where the platform mints short-lived credentials |
| **Idira Secrets Manager** | **Idira Secure Cloud Access** |
| Named today, not done today | **Today** |

The line to land:

> When you find a stored secret, ask **"does this need to exist at all?"** *before* you ask "where
> should we keep it?"

Almost everyone in the room defaults to the second question. That reflex is the thing this workshop
is trying to change.

Say both product names, and say them together, because that is the sentence a Domain Consultant
needs in front of a customer:

> Eliminate what you can with Secure Cloud Access. Vault the rest in Secrets Manager. An embedded
> secret has two acceptable endings, and "we moved it to an environment variable" is not one of them.

### Zero standing privileges → now Module 4

A long-lived key is a bet: *nobody will ever leak this, for as long as it exists.*

**Zero standing privileges** removes the bet rather than hedging it. Between tasks, the identity
holds nothing at all:

- Access is granted **when you ask**, not in advance
- Only if **policy** says you may
- It **expires by itself**
- Every request is **recorded against your name**, which a shared key can never do

The beat that lands best with this audience:

> You already did this. Earlier you copied credentials out of the portal that started with `ASIA`
> and came with a session token. Those expire. Nobody has ever given you a permanent AWS key for
> this tenant.

The before/after diagram lives in [Lesson 08](../lab/0008-zsp-access.html).

Two twenty-second additions, both now callouts in the lesson itself:

> **On setup cost.** Nobody set up federation in that AWS account for you. No identity provider to
> configure, no trust relationship to write, no role per person to maintain. The setup cost you are
> looking at is the login you already did.

> **On the CLI.** "So anyone who downloads the CLI can request access?" Not on a managed endpoint.
> **Idira EPM** decides which executables may run and by whom, offers an approval flow when it
> blocks one, and audits the decision.

The stack as one line, which is the sentence worth taking away:

> **EPM**, which tool may run here. **Secure Cloud Access**, what access it can obtain and for how
> long. **Secrets Manager**, what happens to the secrets you cannot eliminate.

No EPM demo and no console screenshot. It is not in the lab, and promising a demo you do not give is
worse than not mentioning it.

### The Identity Broker → now Module 6

This is the part that sells the session to this audience, so do not rush it.

An agent needs to reach a system. Two ways to arrange that:

| Without the Broker | With the Idira Identity Broker |
| --- | --- |
| The agent holds a credential | The **Broker** holds the credential |
| The credential is in a config file, an env var, or the model's context | The agent never sees it |
| The log says "this API key was used" | The log names **the human, the agent, the server, the tool** |
| Revoking means finding and rotating the secret | Revoking is **one click**, instantly, for every agent |

The governance sentence, because a customer will ask:

> Access is **deny by default**. A call is allowed only where a policy matches both *who*, the user
> **and** the agent, and *what*, the specific tool on the specific server.

The without/with diagram lives in [Lesson 10](../lab/0010-identity-broker.html).

**The kill switch is still worth foreshadowing.** You no longer have a slide for it, so do it at the
end of Module 4 instead, in one sentence:

> In about twenty minutes you are all going to connect an agent through the Broker and call a tool.
> Then I am going to click one button up here, and all sixty of you will lose access at the same
> instant. Watch for that.

### Three things that were true of the deck and are still true

**The one thing not to say.** Do not imply the exercise makes the app secret-free. It removes one of
four secrets. Three remain, deliberately, and Lesson 09 makes attendees find them again. Overclaim
in Module 3 and Lesson 09 contradicts you in front of the room.

**The one thing to repeat.** *Onboard* versus *eliminate*, with the product name attached to each.
Module 3, again in Module 4, again in the wrap. If people leave with one idea, this is the one worth
having.

**The one thing to promise.** The kill switch. Set the expectation early and pay it off in Module 6.
It is the thirty seconds attendees will reuse in front of customers, and foreshadowing it doubles
the effect.
