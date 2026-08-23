# Workshop owner preparation

Everything here is the **owner's** job, not the attendees'. Nothing on this list can be done
from a seat during the session.

Seven items are hard gates. If any one of them is not done, the corresponding module does not
work at all — it does not degrade gracefully.

| Gate | What | Lead time |
| --- | --- | --- |
| 🚩 G1 | Session duration set to **4 hours** on the workshop permission set | 30 seconds, do it 2 weeks out |
| 🚩 G2 | ZSP elevation policy onto the sandbox AWS account, **including `bedrock:InvokeModel`** — plus Bedrock **model access** for both tiers, Sonnet 4.5 **and Llama 3 8B** (G2b) | 1 week out |
| 🚩 G3 | Zip on an internal share, with `idsec` binaries for macOS and Windows | 2 weeks out |
| 🚩 G4 | Every attendee has a **CYBRWorld account** (`demo.cyberark.cloud`, `@cyberarklab.com`) with an AWS entitlement, and the `idsec configure` values emailed in advance | 1 week out |
| 🚩 G5 | **Secure AI ready**: MCP server registered *and enabled*, AI agent registered, access policy created, tools discovered | 1 week out |
| 🚩 G6 | The workshop folder is a **git repository** attendees clone, so `/security-review` works | 2 weeks out |
| 🚩 G7 | Full dry run on a clean macOS **and** a clean Windows laptop | 1 week out |

---

## T-3 weeks

### Confirm the room and the network

- Sixty people all elevating through `idsec` at once. Confirm guest Wi-Fi can take it, and that
  `demo.cyberark.cloud`, `*.my.idaptive.app`, `*.data.aigw.cyberark.cloud`, `github.com` and your
  tenant API endpoint are not blocked by the venue.
- **Check `http://localhost` callbacks survive the venue network.** The Broker sign-in in
  Lesson 10 completes by redirecting the browser to `http://localhost:<port>/callback`. Some
  corporate proxies and VPN clients intercept this. Test it on the guest Wi-Fi, on a laptop
  configured the way attendees' laptops are.
- **Find out whether the venue inspects HTTPS — for Part 2's sake, not Part 1's.** From the guest
  Wi-Fi, on a laptop configured the way attendees' laptops are:

  ```
  curl -sS -o /dev/null -w "http %{http_code}\n" https://bedrock-runtime.us-east-1.amazonaws.com
  ```

  `http 404` is the pass — the endpoint was reached and the certificate verified.

  **What changed, and why this is no longer a room-wide blocker for Part 1.** The Part 1 scripts
  make every HTTPS call with **certificate verification switched off** — one function in
  `ai-harness-app/config.py`, documented there at length and disclosed to attendees on the banner
  line (`tls=unverified`) and in the cheat sheet. So an inspecting proxy can no longer end anyone's
  lesson 01, which is the entire reason for the shortcut. If you are uncomfortable with it, that is
  a reasonable position: flip `_VERIFY_TLS` in `config.py` and this bullet goes back to being a
  gate.

  **Part 2 still verifies.** Claude Code is Node, and Node does not read `AWS_CA_BUNDLE`. On an
  inspecting network Lesson 07 fails with `self signed certificate in certificate chain`. Two
  answers, in order of preference:
  - have the corporate root CA path on the cards → `NODE_EXTRA_CA_CERTS=/path/to/corp-root.pem`;
  - no path, and the room is moving → `NODE_TLS_REJECT_UNAUTHORIZED=0`, for today only. Say out
    loud that it is the same shortcut Part 1 takes and the same one you would refuse at a client.

  Managed laptops often have CA bundle variables set by policy; they no longer affect Part 1, but
  check for them anyway before you debug something else: `env | grep CA_BUNDLE` on macOS,
  `Get-ChildItem env: | Where-Object Name -like '*CA_BUNDLE*'` on Windows.

  ℹ️ **The setup script reports this as information, not a gate** — step 9, *"How this network
  treats HTTPS"*. It never fails the run. It is worth reading the replies anyway: a venue that
  re-signs certificates is something you want to know about **before** Part 2, and one corporate
  root CA path collected in advance saves ten minutes of the second session. It is *not* one of the
  two lead-time items in [prework-email.md](prework-email.md) any more — those are the AWS
  entitlement and EPM blocking.
- Confirm the projector resolution and rehearse your terminal at a font size readable from the
  back row. This sounds trivial. It is not — the whole session is terminal output.

### 🖥️ Check the endpoint policy lets `idsec` and `claude` run

Attendees are on **corporate-managed laptops running our own products**, so assume **Idira EPM**
is on them and that its application control policies apply to freshly downloaded, unsigned
executables — which is exactly what `idsec` and the Claude Code installer produce.

This is a room-wide blocker with a **days-long lead time**, because the fix is an endpoint policy
change and neither you nor any attendee has the rights to make it. Nobody can work around it at a
desk, and nobody should try.

Do this now, not in the dry run:

1. Ask the team that owns the EPM sets which policy applies to the attendees' laptop fleet.
2. Get `idsec` / `idsec.exe` and the Claude Code binary **allowed ahead of the session** for that
   set, or confirm that the prevailing policy already permits user-installed executables under the
   home folder.
3. Confirm what an attendee sees if it *is* blocked — a plain failure, or a **Request for
   authorization** prompt they can use themselves. Tell the helpers which one, because "blocked"
   and "not on `PATH`" look nothing alike but get reported identically.

The setup page asks attendees to reply on the day they hit this, so watch for those replies — one is a
laptop, five is the fleet.

**And treat it as content, not just logistics.** EPM is the answer to the question this audience
will be asked on a customer site — *what stops anyone downloading the CLI and requesting access?* —
so it is named in setup step 5, in [Lesson 09](../lab/0009-zsp-access.html) step 3, on the cheat
sheet, and once from the front in Module 4. The wording is in the appendix of
[presentation-outline.md](presentation-outline.md). Not demoed: it is not in the lab and there is no
time for a second console.

### Recruit helpers

Two trainers plus **5–6 helpers**, so roughly one helper per ten attendees. Send them
[helper-runbook.md](helper-runbook.md) and ask them to do the attendee setup themselves,
on their own laptop, before the session. A helper who has not hit the failure modes is not
a helper.

Helpers must also have completed **Lesson 10 at least once**, including the browser sign-in.
It is the only module with an authentication flow, and a helper who has never seen it cannot
tell "not signed in yet" from "no policy allows this".

---

## T-2 weeks

### 🚩 G1 · Session duration — 4 hours

This is the single cheapest risk reduction available and it takes half a minute.

In IAM Identity Center, on the permission set the attendees use, set **session duration to at least
4 hours**, and 6 if you can — the two slots span 1:00pm to 4:30pm. The default is 1 hour, and the
maximum is 12.

With 1 hour, credentials expire mid-session for people who did their setup early, and you spend
Module 4 re-issuing credentials to a confused room.

Do the arithmetic for *your* schedule before you pick a number. The workshop runs **1:00–2:00pm and
3:00–4:30pm**, so credentials minted just before slot 1 have to survive until 4:30pm — a **3.5-hour**
span, and closer to 4 once you allow for people who paste their keys early. 4 hours covers that with
very little to spare, so prefer **6 hours** if your security review allows it. Otherwise **tell the room
at the start of slot 2 to re-copy the three `AWS_*` lines**, and say why. Expired credentials are a
teaching beat when you announce them and a shambles when you do not.

Attendees need working AWS credentials from **Lesson 01**, about three minutes into slot 1, rather than
at the setup check. A room whose credentials expire takes the whole session down, not the second half
of it.

Use a **dedicated workshop permission set** rather than editing something shared.

### 🚩 G6 · Ship it as a git repository

Lesson 08 uses Claude Code's built-in `/security-review`, which is designed to review a
project under version control. So the workshop folder must arrive as a **repo**, not a bare
directory.

⚠️ **First: make the initial commit.** The folder is a git repository, but as shipped to you it has
**no commits on `main`** — only untracked files. Nothing downstream works without a first commit:
`/security-review` has no history to compare against, and Lesson 13's `/code-review` asks for a base
commit or branch and cannot be given one. From the workshop root:

```
git add -A
git commit -m "Workshop material"
```

Check `git status` afterwards — `.venv/`, `__pycache__/` and any downloaded `idsec` binary should be
absent from the commit, because `.gitignore` excludes them, while
`sandbox-app/config/settings.py` and `sandbox-app/config/integrations.json` **must be present**.
That is the point of Lesson 08.

Then, two ways to distribute, in order of preference:

1. **A GitHub repository attendees clone.** Best, if every attendee can reach it from the venue
   network and has `git` installed. Add the clone command to the setup page.
2. **A zip that contains `.git/`.** No `git` binary needed on the attendee's laptop for the zip
   itself, and `/security-review` still has a repository to look at. Make sure your zip tool
   does not silently drop dot-directories — check by unzipping into a clean folder and looking
   for `.git`.

Either way, commit the sandbox app **with its fake secrets already in history**. That is
deliberate: the point of Lesson 08 is that the secrets are sitting in the codebase, not in a
pending change.

⚠️ **Know what `/security-review` does on a fresh clone.** It is oriented at *changes*, and on
a clean checkout there may be nothing pending for it to review. The lesson handles this by
telling attendees to ask for the whole project instead — but you must find out which behaviour
your repo produces, in the dry run (G7), and say it from the front. Sixty people each
discovering this independently is four wasted minutes and a dent in your credibility.

### 🚩 G3 · Build the distribution

The distribution contains:

```
sko27-japac-idira-ai-workshop/
├── .git/              ← keep this (see G6)
├── lab/               ← everything attendee-facing; the entry point is lab/index.html
├── ai-harness-app/    ← Part 1: the six lesson scripts, the shared session, prompts/,
│                        styles/, skills/, memory.md, and their own sandbox
├── sandbox-app/       ← Part 2: the deliberately leaky app
├── skills/            ← idsec and zsp-aws
├── check-prereqs.sh   ← the setup script, macOS and Linux
├── check-prereqs.ps1  ← the setup script, Windows
├── README.md
├── CONTEXT.md
└── idsec/             ← you add this: the platform binaries (see below)
```

⚠️ **`ai-harness-app/` is not optional.** Part 1 is lessons 01 to 05, and with the break time activity
in lesson 06 it is the whole first slot.
If it is missing from the distribution, the workshop does not start. Four things inside it are easy
to lose in transit:

- **`ai-harness-app/sandbox/.env`** is a dotfile, and both zip tools and file copies are prone to
  dropping dotfiles. It is one of the six planted secrets in Lesson 04, and it is deliberately the
  one nobody finds by eye. `.gitignore` has an explicit negation to keep it tracked, at the very
  end of the file. **Do not tidy that block up.**
- **`ai-harness-app/sandbox/RELEASE_NOTES.md`** contains a prompt-injection payload in an HTML comment.
  It is inert text. Lesson 05's repository audit reads it, and the two calls it asks for are the two
  that `prove_the_controls()` makes deterministically. If a scanner in your pipeline strips or
  quarantines the file, you lose the realistic version of that beat.
- **`ai-harness-app/memory.md`** is what Lesson 05's `/remember` writes to, and it ships with three
  lines already in it. An empty file is a weaker lesson; a missing one is an error.
- **`ai-harness-app/prompts/`, `styles/` and `skills/`** are read at run time. Lesson 03 cannot swap
  an output style it cannot find, and Lesson 05's skills catalogue comes out empty.

Verify by unzipping into a clean folder and running:

```
ls -a ai-harness-app/sandbox/
grep -c "CHANGELOG BUILD NOTE" ai-harness-app/sandbox/RELEASE_NOTES.md
ls ai-harness-app/prompts ai-harness-app/styles ai-harness-app/skills/*
wc -l ai-harness-app/memory.md
```

You want `.env` in the first listing, `1` from the second, two prompts, two styles, two `SKILL.md`
files, and a `memory.md` that is not empty.

Do **not** ship `docs/` to attendees. It contains the run of show and this file. If you are
distributing by clone, put `docs/` in a separate private repo or strip it from the branch
attendees clone.

**`idsec` binaries.** Point attendees at the official releases page —
`github.com/cyberark/idsec-cli-golang/releases` — which is what
[`lab/0000-setup.html`](../lab/0000-setup.html) step 5 links to. Also mirror both archives
on the internal share, in case the venue or a proxy blocks GitHub releases.

Check the archive filenames match what the setup page tells people to type, and edit the lesson if
they do not. The lesson maps machine → filename substrings (`darwin`+`arm64`, `darwin`+`amd64`,
`windows`+`amd64`), which survives version bumps, but the `tar -xzf` example uses a literal
name. Attendees typing a filename that does not exist is an entirely avoidable ten minutes.

**Host it somewhere with no login.** A share that prompts for authentication is a support
queue you have created for yourself.

---

## T-1 week

### 🚩 G2 · Cloud access policy

On a **read-only sandbox AWS account** — not production, not shared:

1. Create the elevatable role attendees will assume. Nobody holds it standing — that is the point.
2. Create the SCA cloud-access policy that grants all sixty attendees the right to elevate
   into it.
3. **The role must allow `bedrock:InvokeModel` on *both* models Part 1 uses.** ⚠️

That third point is easy to miss and breaks the rest of slot 2 completely. Here is why: in Lesson 09
step 6 attendees run the elevate command themselves, over the top of the credentials they got in
Lesson 07. From that point, both Claude Code and `summarize.py` authenticate to Bedrock as the
elevated role. If the role cannot invoke the model, the agent stops working and the app never
succeeds.

Minimum policy on the elevated role:

```
bedrock:InvokeModel        on the Sonnet 4.5 inference profile / model ARN
bedrock:InvokeModel        on meta.llama3-8b-instruct-v1:0   ← Part 1's legacy tier
sts:GetCallerIdentity      (implicitly allowed; used by the Lesson 09 verification)
```

Read-only on everything else is correct and desirable. `bedrock:InvokeModel` is not
destructive.

### 🚩 G2b · Bedrock **model access** for the legacy tier

Separate from IAM, and separate from the elevated role: Bedrock will not serve a model your account has
not been granted **model access** to. Part 1 uses two.

In the Bedrock console for **the region attendees use** (`us-east-1` unless you change it), under
**Model access**, confirm both are `Access granted`:

- **Anthropic Claude Sonnet 4.5** — the frontier tier, used from Lesson 04 onwards and by Claude Code
- **Meta Llama 3 8B Instruct** (`meta.llama3-8b-instruct-v1:0`) — the legacy tier, used by Lessons 01
  to 03

Without the second one, **Lesson 01 fails on the first command of the session** with an
`AccessDeniedException`, which is the worst possible place for a room-wide blocker. It is a deliberately
old, cheap model with an 8,192-token window, chosen because the small window is what makes the context
gauge and the "dumb zone" visible inside a lesson — so do not substitute something bigger to avoid the
approval step.

Verify from a laptop, with a test attendee's credentials rather than your own admin role:

```
python ai-harness-app/01_bare_call.py
```

If your tenant genuinely cannot get Llama 3 approved, `LEGACY_MODEL` and `LEGACY_WINDOW` override the
tier from the environment — but pick something with a window of 8k or so, and re-run lesson 03's `/fill`
to check the wall still arrives. A 32k window costs that lesson its point.

**Verify by elevating as a real test attendee**, not as yourself with an admin role. Then run
Lesson 14 end to end with those credentials.

### 🚩 G5 · Secure AI — the AI Agent Identity Broker

Lesson 10 is now **mandatory**, so this is a gate rather than a nice-to-have. Everything below
is done once, tenant-side, and shared by all sixty attendees. You need the **Secure AI Admin**
role to do the policy step.

**The tenant for this gate is `demo.cyberark.cloud`,** the same CYBRWorld tenant the rest of the day
runs on. There is no tenant to switch and no second account to create. Attendees do need **read**
access to **Manage > Inventory > AI**, **Manage > Policies > AI agents access** and **Audit and
Reports**, because lesson 10 steps 6 to 9 have them read those screens themselves. Every attendee
account should already have it. Verify with a real test attendee account, not with your own admin role,
and remind new hires in the setup email.

**Six things, in this order:**

1. **Register the MCP server** and confirm it is **Enabled**. A server's connection details and
   Gateway URL only exist while it is enabled. Note the Gateway URL — it has the shape
   `https://<region>.data.aigw.cyberark.cloud/mcp/<server-name>`. Pick a server whose tools are
   read-only and safe for sixty people to hammer at once.
2. **Register an AI agent** as a **public client**, so it issues an **OAuth 2.1 Client ID** and no
   secret. That is what lets the Client ID sit in the lesson text. Registering the agent is what makes
   the audit trail name the agent rather than degrading to pass-through.
3. **Create the access policy.** **Manage > Policies > AI agents access** → **Create policy**:
   - *Step 1 — General details*: name it after the server it covers, e.g. `EntraSonar MCP - Allow`,
     so the lesson can tell attendees which policy to open.
   - *Step 2 — MCP servers and tools*: **+ Add MCP servers**, pick the server, then
     **Select specific tools** and pick `analyze_domain` **only**. Leaving `beta_features` out is
     deliberate: step 5 of the lesson has every attendee call it and be refused. **Allow all current
     and future tools** breaks the lesson.
   - *Step 3 — AI agents*: **+ Add AI agents**, pick the agent you registered. **Allow all
     current and future AI agents** is also defensible in a disposable lab tenant.
   - *Step 4 — Users and roles*: **+ Add users and roles**. The **Everyone** role covers all
     users in one entry, which is what you want for sixty accounts.
   - **Done.**
4. **Connect once yourself, before the day.** Tool availability shows **Not discovered yet**
   until an agent connects for the first time. Do that connection now, so the policy is
   selecting real tools and the console looks right when you project it.
5. **Confirm the denial, then confirm the success.** Call `beta_features` yourself and check the
   refusal text still reads `Access denied by access policy`. Then call `analyze_domain` and check it
   returns. Both are load-bearing: the lesson quotes the refusal verbatim in step 5, and steps 8 and 9
   explain it. Also rehearse the kill switch for yourself only: set the server to **Disabled**, confirm
   a call fails, then **Enable** it again. You will **not** do that during the session, because nothing
   in the tenant is changed while sixty people are working in it.
6. **Put the six literals into the lesson.** `lab/0010-identity-broker.html` names the Gateway URL, the
   Client ID, the registered agent (`JAPAC-SKO27`), the MCP server (`EntraSonar MCP`), the policy
   (`EntraSonar MCP - Allow`) and both tools verbatim, so attendees copy rather than type. **If you
   re-register the server or the agent, or rename the policy, those values in the lesson are stale.**
   The cheat sheet carries the same command, so update `lab/reference/cheatsheet.html` with it.

**There is no Client Secret to distribute.** The agent is a public client, the Client ID is printed in
the lesson, and the browser sign-in is what authenticates the person. Nothing goes in the Slack channel
and nothing goes on a card. If you register the agent as a confidential client by mistake, you are back
to handing a secret to sixty people, and the lesson text is then wrong.

**Review the agent registration after the session.** Sixty people have its Client ID. That is an
identity, not a key, but it is still worth deleting a registration nobody needs any more.

**The apj-secrets variant.** `lab/0016-identity-broker-apj-secrets.html` is the same lesson against
`apj-secrets.cyberark.cloud`, where the agent uses a Client Secret. It is an optional Part 3 page.
Nothing in the session depends on it, and nobody should be sent to it on the day.

**Remember for the front of the room:** access is deny-by-default, and a request is permitted
only where a policy matches *both* the principal (user/role **and** agent) and the resource
(tool on a server). Both the agent and the server must be enabled. Every tool run is audited,
success or failure.

### 🚩 G4 · Attendee accounts and entitlements

Nobody is issued a workshop login. Every attendee signs in with **their own CYBRWorld account**,
the one ending in `@cyberarklab.com`, against `demo.cyberark.cloud`. So G4 is not a printing job.
It is three checks:

- Every attendee **has** a CYBRWorld account. Get the list, compare it against the invite list.
- Every one of those accounts has an **AWS entitlement** in Secure Cloud Access, so
  `idsec exec sca cloud-access list-targets --csp aws` returns at least one account and role.
- Every attendee can **sign in to `demo.cyberark.cloud` in a browser**, which Lesson 10 needs. Same
  account, no `idsec` involved. They also need read access to **Inventory > AI**, **Policies > AI agent
  access** and **Audit and Reports**, which a standard account already has. Treat it as a reminder
  rather than a task, and aim the reminder at new hires. G5 owns the detail.

**Email these three values a week ahead**, because `idsec configure` asks for them:

| | |
| --- | --- |
| Identity Tenant Subdomain | `demo` |
| Identity URL | `https://aam4614.my.idaptive.app/` |
| Username | their own, ending in `@cyberarklab.com` |

Run `idsec configure` yourself first. The command is interactive, its prompts vary between
releases, and you want to be able to say what the prompts actually look like. Also tell people
about `--profile-name`: anyone already using `idsec` against another tenant needs a second
profile rather than an overwritten one.

The numbered cards are still worth printing, but only as the **help signal**. They carry a number
and nothing else, plus optionally the Broker **Gateway URL** and **Client ID** from G5. There is no
Client Secret to print, and G5 says why.

### Send the setup email

Use [prework-email.md](prework-email.md). Send it a week out, and chase non-responders three
days before. A reply saying "list-targets comes back empty" three days early is a success; the same
sentence on the day is a person who does not get to do the workshop.

---

## 🚩 G7 · Dry run

Do this on a **clean laptop of each OS** — one macOS, one Windows — logged in as a normal
user with no admin rights. Not your own machine, which has years of accumulated setup.

Work through, in order, exactly what an attendee does:

1. `lab/0000-setup.html` — all seven steps, including the virtual environment and the `PATH`
   edits. Run `check-prereqs.sh` (or `.ps1`) and read what it prints, rather than assuming it
   passed.
2. `lab/0001-one-call.html` — `python 01_bare_call.py`. This is the first thing that needs
   credentials and a working virtual environment, so it is where environment problems will surface
   on the day. It is also the first call to the **legacy** model, so it is where a missing Bedrock
   model access grant shows up (G2b).
3. `lab/0002-conversation-history.html` — `python 02_conversation.py`. Ask the follow-up question and
   confirm it is answered, then look at the footer and confirm the token count went up.
4. `lab/0003-context-engineering.html` — `python 03_context.py`. Run the whole sequence, including
   `/style eli5` **after** three long answers, then `/reset` and the same style again. Then `/fill 90`
   and `/compact`. Time this lesson; it is the longest in Part 1 and the easiest to overrun.
5. `lab/0004-tools-and-agents.html` — do the manual secret hunt yourself first and count what you
   find, so you know what the room will report. Then `python 04_tools_and_agents.py`, and confirm the
   legacy tier really does refuse the toolbox before the script switches models.
6. `lab/0005-the-harness.html` — `python 05_harness.py`, then again with `--remote`. The `--remote` run
   is not on the attendee page any more; it is a projector demo, and you still need to know what it does
   on your network. Walk all six tasks. Both outcomes of the remote run are acceptable and you need to know which one your network
   gives you (see the capture list). Also `cat ai-harness-app/audit.log` and use `/remember` once. Run
   the script **twice**: the model's response is not deterministic, and what has to be consistent is the
   `prove_the_controls()` panel, which must show three attempts and three refusals on every run. It
   prints when you quit the chatbox, not at startup, so do not go looking for it before then.
7. `lab/0006-who-runs-the-agents.html` — no script. Read it end to end and decide how you will put the
   three questions to the room, which the page asks each attendee to answer for themselves. Check the photo loads. The two Google embeds are optional and need sharing
   set to anyone-with-the-link before the day.
8. `lab/0007-setup.html` — through to the agent answering
9. `lab/0008-find-the-secrets.html`
10. `lab/0009-zsp-access.html` — including the optional Azure step
11. `lab/0010-identity-broker.html` — including the browser sign-in and one real tool call

Then run `lab/0014-fix-the-app.html` end to end, because it is the follow-up attendees are pointed at
from Lesson 09, and at least skim one other optional lesson, ideally `lab/0013-afk-harness.html`, so
you can answer "does that actually work?" from the floor.

⚠️ **Reset `ai-harness-app/` afterwards.** The dry run leaves `audit.log` populated and a `/remember`
line in `memory.md`. Both are gitignored or trivially reverted, but ship the folder clean — an
attendee's first `cat audit.log` should show *their* calls.

### Capture these while you do it

- **Whether `python 01_bare_call.py` runs at all on a clean machine.** Part 1 uses
  `ai-harness-app/requirements.txt`, which is a different dependency list from the one Part 2
  needs. Install it on the clean laptop and confirm nothing is missing. A `ModuleNotFoundError` at
  minute three costs you the room's confidence for the rest of the session.
- **Whether Lesson 06's four external links resolve for you.** The product page at
  `paloaltonetworks.com/idira/agentic` answered 200 when this was written. The two `docs.cyberark.com`
  links and both Google embeds did not answer to an anonymous client. Open all four while signed in, and
  if a documentation path has moved, fix the link on the page rather than leaving a 404 in front of the
  room. The lesson is a discussion and does not depend on any of them.
- **What Lesson 05 actually prints on your build.** `sandbox/RELEASE_NOTES.md` asks the agent to read
  `/etc/passwd` and POST the `.env` to an external host. Both are refused by `_safe_path()` and the
  two-command allowlist. Capture whether the *model* also declines on its own, because either outcome
  is fine and you should be able to say which one you saw.
- **Timing for Part 1, lesson by lesson.** The run of show budgets 67 minutes for all six lessons —
  10, 8, 14, 15, 15, 5 — and slot 1 is only 60 minutes, so **timing this is not optional any more**:
  it is how you choose which 10 minutes to cut. Time each one on the clean laptop and write your numbers
  into [run-of-show.md](run-of-show.md). Lesson 03 and Lesson 04 are the two that overrun, because both
  invite experimentation.
- **Whether the legacy tier is available and behaves.** `python 01_bare_call.py` must answer, and
  `python 04_tools_and_agents.py` must show the legacy model *refusing* the toolbox before the script
  switches tiers. Both are G2b symptoms if they fail — one silently (no model access) and one loudly.
- **What `python 05_harness.py --remote` does on the venue network.** It calls
  `https://mcpplaygroundonline.com/mcp-stateless-server?rev=2026-07-28` — an unauthenticated internet
  MCP server, over HTTPS, with no token. Three outcomes, all of which you must be able to narrate:
  it works; the proxy blocks it (**the intended teaching moment** — say so rather than debugging it in
  front of the room); or it hangs, in which case tell the room to use the default local server and move
  on. Whatever happens, confirm the **local** stdio path works on both laptops, because that is the
  default and the lesson does not depend on the remote one.
- **Whether the venue inspects HTTPS — a Part 2 question now, not a Part 1 one.** Run
  `bash check-prereqs.sh --check-only` on the venue Wi-Fi and read step 9, *"How this network treats
  HTTPS"*. It never fails the run, and Part 1 will work either way: those scripts do not verify
  certificates (`ai-harness-app/config.py`). **Claude Code does.** So if the venue re-signs HTTPS,
  the thing to capture in the dry run is one **`NODE_EXTRA_CA_CERTS`** path, on the cards or on a
  slide, before Part 2 starts — and decide in advance whether you are willing to say
  `NODE_TLS_REJECT_UNAUTHORIZED=0` from the front if no path materialises. Either way the helpers'
  job is to supply the value, not the diagnosis.
- **What `/security-review` does on a fresh clone.** Does it find the committed secrets, or does
  it report that there are no changes to review? The lesson supplies a fallback prompt either
  way, but you must know which one the room will see. (G6.)
- **The real output of `idsec exec sca cloud-access elevate --raw`.** 🚩 This is the single most
  important thing to confirm, because every AWS credential in the lab now comes from it. The
  response carries the short-lived credentials in an `accessCredentials` field, as a JSON-encoded
  string nested inside the JSON response — which is why the lab pipes it through `jq` with
  `fromjson`. Run the exact one-liner from `lab/0000-setup.html` step 7 on your build and check
  three things: that `--raw` gives clean JSON with nothing decorative in it, that the field names are
  still `aws_access_key` / `aws_secret_access_key` / `aws_session_token`, and that the
  `eval` (macOS) and `Invoke-Expression` (PowerShell) wrappers print nothing at all. If any of the
  three is wrong, fix the one-liner in setup step 7, Lesson 01 step 1, Lesson 07 step 2, cheat
  sheet §2 and `skills/zsp-aws/SKILL.md` — they carry the same command deliberately.
- **The exact `idsec configure` *and* `idsec login` prompts** → onto the cards (G4). The lab now
  says sign-in normally happens in the terminal — password, then MFA if your tenant requires it —
  and mentions a browser only as the alternative. Check which one your tenant does, and if it is
  the browser, say so from the front in Module 4.
- **Whether an agent added *without* `--client-id` is audited as pass-through.** The lab teaches
  that supplying the registered agent's Client ID is what makes the audit name the agent. Try it
  both ways and look at the log, so you can demonstrate the difference rather than assert it.
- **Whether endpoint application control blocks `idsec` or the Claude Code installer.** 🖥️ Do the
  dry run on a laptop with the **same EPM set as the attendees'**, otherwise this test proves
  nothing. If something is blocked, capture the exact wording of the message and whether a
  **Request authorization** option appears — helpers need both. See the T-3 check above; it is a
  policy change with a lead time, not a day-of fix.
- **The `.venv` activation on Windows.** Confirm whether the clean laptop needs
  `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` before `Activate.ps1` runs. If it
  does, warn the room at the start of **Module 1** rather than letting thirty Windows users find
  out one at a time. Part 1 moved this earlier: Lesson 01 is now the first thing that needs the
  virtual environment, so a `.venv` problem surfaces three minutes into the session rather than
  seventeen.
- **Whether `list-targets` returns one target or several.** If several, Lesson 09 needs to tell
  attendees which one to choose, by name. Lessons 01 and 07 hardcode one workspace ID and one role
  ARN in the pasteable command, so check that those two values are right for your build.
- **The Azure role's display name.** `skills/zsp-azure/SKILL.md` and Lesson 09's optional step say
  only "an Azure role you are entitled to", because the name that `list-targets --csp azure` prints
  for role `e3973bdf-4987-49ae-837a-ba8e231c7286` has never been confirmed. Read it off your own
  output and put it on both pages.
- **Whether the whole room is entitled to that Azure role.** The optional step assumes every
  attendee can elevate into `e3973bdf-4987-49ae-837a-ba8e231c7286` in workspace
  `032734d4-b0fe-4736-92df-d923b68c0316`. Confirm it for a test attendee, not for yourself. If only
  some of the room has it, say so on the page rather than letting people think they broke something.
- **How long the Broker sign-in takes**, from `/mcp` to the tool being callable. This sets the
  pace of Module 5 part 1.
- **Timings.** Compare against [run-of-show.md](run-of-show.md) and adjust that file, not
  your expectations on the day.

---

## Day of

### 60 minutes before

- Load `lab/index.html` on the projector machine and leave it up
- **Tile the projector machine the way you are about to tell the room to tile theirs**: lab guide on
  one half, terminal on the other, terminal font large enough for the back row. You are modelling the
  arrangement, not just recommending it.
- Run `python 01_bare_call.py` on the projector machine. It is the first command of the session and it
  exercises credentials, the virtual environment, TLS and the legacy model in one go.
- Run through Lesson 07 yourself on the projector machine, so you know the room's network works
- **Connect the Broker MCP server on the projector machine and call one tool**, so Module 5 is
  warm and you are not authenticating live for the first time
- Open **Audit and Reports** in a browser tab and leave it there. You will be projecting it.
- Open **Manage > Policies > AI agents access** in another tab. You point at that screen in Module 5;
  you do not change anything on it.
- **Call `beta_features` once and confirm it is still refused.** Step 5 of the lesson depends on it
- Confirm the share link or clone URL works from the guest Wi-Fi, on a device that has never
  used it
- Lay out the numbered cards by the door. They are the help signal, not a login

### 10 minutes before

- Brief the helpers: the top failures are new-terminal-lost-variables, no `(.venv)`, `PATH`,
  and expired credentials. All are in [helper-runbook.md](helper-runbook.md).
- Tell helpers explicitly: **any Broker tool call that is refused is escalated, not debugged.**
  It means the server is disabled or no policy matches — both tenant-side, neither fixable at
  the desk.
- Agree the escalation signal: card held up, helper goes.
- Agree who owns the front of the room during each module so two trainers are never both
  talking.
- Agree that **nobody changes the Secure AI configuration during the session**. No server is disabled,
  no policy is edited. Sixty people are working in that tenant at the same time, and editing the policy
  would make step 5 stop failing.

### Spares

- 2–3 pre-configured loaner laptops. There will be at least one machine that cannot be fixed
  in the time available, and moving that person to a working laptop is far better than losing
  them for the session.
- A printed copy of the [cheat sheet](../lab/reference/cheatsheet.html) per table.

### Afterwards

- **Confirm the MCP server is still Enabled.** Nothing should have changed it, so this is a check.
- **Review the registered AI agent.** Sixty people have its Client ID. It is an identity rather than a
  key, and a registration nobody needs is still worth deleting.
- **Review the `EntraSonar MCP - Allow` policy**, especially the **Everyone** role. Leave the tool list
  alone if the workshop runs again: `beta_features` has to stay out of it.
- Disable the sixty attendee accounts, or reset their passwords.

---

## If you edit the material 🛠️

One rule, and it is enforceable rather than advisory:

```
.venv/bin/python build-lab-code.py --check
```

The Part 1 lesson pages contain the **whole** Python file for each lesson, with the key lines clickable.
They also contain the capability scoreboard, the Idira block and the app's own terminal output. All of it
is *generated* — from `ai-harness-app/`, the notes in `lab/annotations/` and `lab/idira-thread.md` — and
the generated output is committed. So editing a script without re-running the generator ships a page that
disagrees with the code the attendee is running — the one failure mode this material cannot survive,
because the whole point is that nothing is hidden.

- `.venv/bin/python build-lab-code.py` — rewrite the pages
- `.venv/bin/python build-lab-code.py --check` — exit 0 if every page is current, **1 if any page is
  stale**, 2 if an annotation anchor no longer matches a line in the source

Use the workshop's own interpreter, not the system `python3`. The terminal blocks are printed by the real
`ui.py`, so the generator imports the app and `rich` to produce them. It never calls a model, and it needs
no credentials and no network.

Run the `--check` before every commit and before building the distribution (G3). If an anchor stops
matching because you edited the line it points at, fix the anchor in `lab/annotations/NNNN.md` — do not
delete the annotation, because it is the explanation of the thing you just changed.

The same applies to renaming or reordering lessons: the page order lives in the `PAGES` array in
[`lab/assets/lab.js`](../lab/assets/lab.js), and the numbers in prose do not update themselves.

---

## Deliberately out of scope

Say this from the front so nobody spends the session wondering:

- **Vaulting the GitHub, Slack and database secrets** in **Idira Secrets Manager**. The product
  is named repeatedly in the lab as the correct destination, and Lesson 09 tells attendees to say
  so to clients — but nobody vaults anything today. The Secrets Manager MCP server ships only as
  a stdio Docker container, and Docker Desktop needs admin rights on Windows, so it cannot be
  used in this room. Follow-up session.
- **Demonstrating Idira EPM.** It is *named* — setup step 5, Lesson 09 step 3, the cheat sheet,
  Module 4 — because it answers "what stops anyone running the CLI?", which is a customer
  question. There is no EPM exercise, no console tour and no screenshot. If you promise one you will
  owe the room ten minutes you do not have.
- **Authoring an AI agent access policy.** Attendees *consume* the policy you created in G5 and
  the lab explains how it is structured, but they never write one — that needs the Secure AI
  Admin role, which they do not have.
- **Tests, CI, branching strategy.** The optional Lesson 13 walks the
  spec → tickets → implement → review harness, but only far enough to see the shape of it. The
  AI-harness workshop covers the rest.

The content will later be extended to cover the previous AI-harness workshop. Not now.
