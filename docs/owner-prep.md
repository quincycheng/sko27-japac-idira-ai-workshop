# Workshop owner preparation

Everything here is the **owner's** job, not the attendees'. Nothing on this list can be done
from a seat during the session.

Seven items are hard gates. If any one of them is not done, the corresponding module does not
work at all — it does not degrade gracefully.

| Gate | What | Lead time |
| --- | --- | --- |
| 🚩 G1 | Session duration set to **4 hours** on the workshop permission set | 30 seconds, do it 2 weeks out |
| 🚩 G2 | ZSP elevation policy onto the sandbox AWS account, **including `bedrock:InvokeModel`** | 1 week out |
| 🚩 G3 | Zip on an internal share, with `idsec` binaries for macOS and Windows | 2 weeks out |
| 🚩 G4 | 60 numbered cards, and the same details emailed in advance | 1 week out |
| 🚩 G5 | **Secure AI ready**: MCP server registered *and enabled*, AI agent registered, access policy created, tools discovered | 1 week out |
| 🚩 G6 | The workshop folder is a **git repository** attendees clone, so `/security-review` works | 2 weeks out |
| 🚩 G7 | Full dry run on a clean macOS **and** a clean Windows laptop | 1 week out |

---

## T-3 weeks

### Confirm the room and the network

- Sixty people all pulling from the AWS portal and `idsec` at once. Confirm guest Wi-Fi can
  take it, and that `*.awsapps.com`, `ngid.cyberark.cloud`, `*.data.aigw.cyberark.cloud` and
  your tenant API endpoint are not blocked by the venue.
- **Check `http://localhost` callbacks survive the venue network.** The Broker sign-in in
  Lesson 5 completes by redirecting the browser to `http://localhost:<port>/callback`. Some
  corporate proxies and VPN clients intercept this. Test it on the guest Wi-Fi, on a laptop
  configured the way attendees' laptops are.
- **Check that TLS to Bedrock actually verifies.** From the guest Wi-Fi, on a laptop configured
  the way attendees' laptops are:

  ```
  curl -sS -o /dev/null -w "http %{http_code}\n" https://bedrock-runtime.us-east-1.amazonaws.com
  ```

  `http 404` is the pass — the endpoint was reached and the certificate verified. A
  `certificate problem` or `SSL certificate verify failed` is a **room-wide blocker**: Claude
  Code cannot reach Bedrock, and Lesson 2 step 1 ends in a raw `SSLError` traceback instead of
  the credential error the lesson describes. Two causes, opposite fixes:
  - the network re-signs HTTPS and the corporate root is not trusted → point `AWS_CA_BUNDLE`
    and `REQUESTS_CA_BUNDLE` at the corporate certificate, or use a network that does not
    inspect;
  - the laptop already has `AWS_CA_BUNDLE` / `REQUESTS_CA_BUNDLE` set for the office proxy and
    you are *not* behind it → unset them for the session.

  Managed laptops often have those variables set by policy, so check for them rather than
  assuming: `env | grep CA_BUNDLE` on macOS, `Get-ChildItem env: | Where-Object Name -like
  '*CA_BUNDLE*'` on Windows.
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

The prework asks attendees to reply on the day they hit this, so watch for those replies — one is a
laptop, five is the fleet.

**And treat it as content, not just logistics.** EPM is the answer to the question this audience
will be asked on a customer site — *what stops anyone downloading the CLI and requesting access?* —
so it is named in prework step 5, in [Lesson 3](../lab/0003-zsp-access.html) step 2, on the cheat
sheet, on slide 6, and once from the front in Module 3. Not demoed: it is not in the lab and there
is no time for a second console.

### Recruit helpers

Two trainers plus **5–6 helpers**, so roughly one helper per ten attendees. Send them
[helper-runbook.md](helper-runbook.md) and ask them to do the attendee prework themselves,
on their own laptop, before the session. A helper who has not hit the failure modes is not
a helper.

Helpers must also have completed **Lesson 5 at least once**, including the browser sign-in.
It is the only module with an authentication flow, and a helper who has never seen it cannot
tell "not signed in yet" from "no policy allows this".

---

## T-2 weeks

### 🚩 G1 · Session duration — 4 hours

This is the single cheapest risk reduction available and it takes half a minute.

In IAM Identity Center, on the permission set the attendees use, set **session duration to
4 hours**. The default is 1 hour, and the maximum is 12.

With 1 hour, credentials expire mid-session for people who did their prework early, and you
spend Module 3 re-issuing credentials to a confused room. With 4 hours, expiry cannot happen
inside the slot.

Use a **dedicated workshop permission set** rather than editing something shared.

### 🚩 G6 · Ship it as a git repository

Lesson 2 uses Claude Code's built-in `/security-review`, which is designed to review a
project under version control. So the workshop folder must arrive as a **repo**, not a bare
directory.

⚠️ **First: make the initial commit.** The folder is a git repository, but as shipped to you it has
**no commits on `main`** — only untracked files. Nothing downstream works without a first commit:
`/security-review` has no history to compare against, and Lesson 8's `/code-review` asks for a base
commit or branch and cannot be given one. From the workshop root:

```
git add -A
git commit -m "Workshop material"
```

Check `git status` afterwards — `.venv/`, `__pycache__/` and any downloaded `idsec` binary should be
absent from the commit, because `.gitignore` excludes them, while
`sandbox-app/config/settings.py` and `sandbox-app/config/integrations.json` **must be present**.
That is the point of Lesson 2.

Then, two ways to distribute, in order of preference:

1. **A GitHub repository attendees clone.** Best, if every attendee can reach it from the venue
   network and has `git` installed. Add the clone command to the prework.
2. **A zip that contains `.git/`.** No `git` binary needed on the attendee's laptop for the zip
   itself, and `/security-review` still has a repository to look at. Make sure your zip tool
   does not silently drop dot-directories — check by unzipping into a clean folder and looking
   for `.git`.

Either way, commit the sandbox app **with its fake secrets already in history**. That is
deliberate: the point of Lesson 2 is that the secrets are sitting in the codebase, not in a
pending change.

⚠️ **Know what `/security-review` does on a fresh clone.** It is oriented at *changes*, and on
a clean checkout there may be nothing pending for it to review. The lesson handles this by
telling attendees to ask for the whole project instead — but you must find out which behaviour
your repo produces, in the dry run (G7), and say it from the front. Sixty people each
discovering this independently is four wasted minutes and a dent in your credibility.

### 🚩 G3 · Build the distribution

The distribution contains:

```
vibe-coding-workshop/
├── .git/           ← keep this (see G6)
├── lab/            ← everything attendee-facing; the entry point is lab/index.html
├── sandbox-app/    ← the deliberately leaky app
├── skills/         ← idsec and zsp-aws
├── README.md
├── CONTEXT.md
└── idsec/          ← you add this: the platform binaries (see below)
```

Do **not** ship `docs/` to attendees. It contains the run of show and this file. If you are
distributing by clone, put `docs/` in a separate private repo or strip it from the branch
attendees clone.

**`idsec` binaries.** Point attendees at the official releases page —
`github.com/cyberark/idsec-cli-golang/releases` — which is what
[`lab/0000-prework.html`](../lab/0000-prework.html) step 5 links to. Also mirror both archives
on the internal share, in case the venue or a proxy blocks GitHub releases.

Check the archive filenames match what the prework tells people to type, and edit the lesson if
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
3. **The role must allow `bedrock:InvokeModel` on the Sonnet model.** ⚠️

That third point is easy to miss and breaks Module 4 completely. Here is why: in Lesson 3
step 5 attendees paste their *elevated* credentials over the portal credentials from Lesson 1.
From that point, both Claude Code and `summarize.py` authenticate to Bedrock as the elevated
role. If the role cannot invoke the model, the agent stops working and the app never
succeeds.

Minimum policy on the elevated role:

```
bedrock:InvokeModel        on the Sonnet 4.5 inference profile / model ARN
sts:GetCallerIdentity      (implicitly allowed; used by the Lesson 3 verification)
```

Read-only on everything else is correct and desirable. `bedrock:InvokeModel` is not
destructive.

**Verify by elevating as a real test attendee**, not as yourself with an admin role. Then run
Lesson 4 end to end with those credentials.

### 🚩 G5 · Secure AI — the Identity Broker

Lesson 5 is now **mandatory**, so this is a gate rather than a nice-to-have. Everything below
is done once, tenant-side, and shared by all sixty attendees. You need the **Secure AI Admin**
role to do the policy step.

**Five things, in this order:**

1. **Register the MCP server** and confirm it is **Enabled**. A server's connection details and
   Gateway URL only exist while it is enabled. Note the Gateway URL — it has the shape
   `https://<region>.data.aigw.cyberark.cloud/mcp/<server-name>`. Pick a server whose tools are
   read-only and safe for sixty people to hammer at once.
2. **Register an AI agent.** This issues the **OAuth 2.1 Client ID and Client Secret** that
   attendees pass to `claude mcp add`. Registering the agent is what makes the audit trail name
   the agent rather than degrading to pass-through.
3. **Create the access policy.** **Manage > Policies > AI agents access** → **Create policy**:
   - *Step 1 — General details*: name it something obviously disposable, e.g.
     `workshop-<date>`, so it is easy to delete afterwards.
   - *Step 2 — MCP servers and tools*: **+ Add MCP servers**, pick the server. For a lab,
     **Allow all current and future tools** saves you a re-edit when you change your mind about
     which tool attendees call.
   - *Step 3 — AI agents*: **+ Add AI agents**, pick the agent you registered. **Allow all
     current and future AI agents** is also defensible in a disposable lab tenant.
   - *Step 4 — Users and roles*: **+ Add users and roles**. The **Everyone** role covers all
     users in one entry, which is what you want for sixty accounts.
   - **Done.**
4. **Connect once yourself, before the day.** Tool availability shows **Not discovered yet**
   until an agent connects for the first time. Do that connection now, so the policy is
   selecting real tools and the console looks right when you project it.
5. **Rehearse the kill switch.** Set the server to **Disabled**, confirm a tool call fails,
   then **Enable** it again and confirm it recovers. Time it. This is the thirty seconds the
   room remembers, and you do not want to be hunting for the toggle on the projector.

**Getting the Client ID and Secret to sixty people.** Two workable options:

- **On the card** alongside the tenant login. Simplest, and the secret is scoped to a
  disposable lab agent in a lab tenant.
- **On a slide**, left up for the whole module. Fewer cards to reprint if you re-register.

Either way, **rotate or delete the agent registration after the session.** It is a client
credential that sixty people have seen.

Also write the **Gateway URL** somewhere large and leave it up. It is long, and one wrong
character produces an error that looks like an authentication problem.

**Remember for the front of the room:** access is deny-by-default, and a request is permitted
only where a policy matches *both* the principal (user/role **and** agent) and the resource
(tool on a server). Both the agent and the server must be enabled. Every tool run is audited,
success or failure.

### 🚩 G4 · Attendee logins

Sixty logins on the shared tenant, numbered 1–60. Numbering avoids the name collisions you
get with sixty accounts created in a hurry, and gives helpers something unambiguous to shout
across a room.

**Each card carries:**

- Attendee number
- Portal URL: `https://ngid.cyberark.cloud/`
- Username and initial password
- The exact answers to give `idsec configure` — tenant subdomain and username
- *Optionally* the Broker **Gateway URL**, **Client ID** and **Client Secret** from G5

That `idsec configure` line matters. The command is interactive, and its prompts vary between
releases. **Run it yourself first**, write down the exact prompts and the exact answers, and
put them on the card. Do not make sixty non-developers guess at an interactive prompt.

**Email the same details a week ahead.** The prework requires `idsec configure` and the AWS
portal check, and neither is possible without a login. The physical card is the in-room copy,
not the first delivery.

### Send the prework

Use [prework-email.md](prework-email.md). Send it a week out, and chase non-responders three
days before. A reply saying "the AWS tile is missing" three days early is a success; the same
sentence on the day is a person who does not get to do the workshop.

---

## 🚩 G7 · Dry run

Do this on a **clean laptop of each OS** — one macOS, one Windows — logged in as a normal
user with no admin rights. Not your own machine, which has years of accumulated setup.

Work through, in order, exactly what an attendee does:

1. `lab/0000-prework.html` — all seven steps, including the virtual environment and the `PATH`
   edits
2. `lab/0001-setup.html` — through to the agent answering
3. `lab/0002-find-the-secrets.html`
4. `lab/0003-zsp-access.html`
5. `lab/0004-fix-the-app.html`
6. `lab/0005-identity-broker.html` — including the browser sign-in and one real tool call

Then at least skim one optional lesson end to end, ideally
`lab/0008-afk-harness.html`, so you can answer "does that actually work?" from the floor.

### Capture these while you do it

- **What `/security-review` does on a fresh clone.** Does it find the committed secrets, or does
  it report that there are no changes to review? The lesson supplies a fallback prompt either
  way, but you must know which one the room will see. (G6.)
- **The real output of `idsec sca cloud-access elevate`.** The CLI documentation says the
  response carries the short-lived credentials in an `accessCredentials` field — as a
  JSON-encoded string nested inside the JSON response, so it is *not* pasteable as environment
  variables. That is why Lesson 3 sends attendees back to the portal. Confirm it on your build,
  and note two things: whether credentials appear on screen at all (see the projector warning in
  [run-of-show.md](run-of-show.md), Module 3), and whether the portal route is still needed.
- **The exact `idsec configure` *and* `idsec login` prompts** → onto the cards (G4). The lab now
  says sign-in normally happens in the terminal — password, then MFA if your tenant requires it —
  and mentions a browser only as the alternative. Check which one your tenant does, and if it is
  the browser, say so from the front in Module 3.
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
  does, warn the room in Module 1 rather than letting thirty Windows users find out one at a
  time.
- **The exact label on the portal button** — "Access keys" or "Get credentials". Both appear
  in the wild; the lesson mentions both, but tell the room which one *they* will see.
- **A screenshot of the credentials dialog** for your slides, with the values blacked out.
- **Whether `list-targets` returns one target or several.** If several, Lesson 3 needs to tell
  attendees which one to choose, by name.
- **How long the Broker sign-in takes**, from `/mcp` to the tool being callable. This sets the
  pace of Module 5 part 1.
- **Timings.** Compare against [run-of-show.md](run-of-show.md) and adjust that file, not
  your expectations on the day.

---

## Day of

### 60 minutes before

- Load `lab/index.html` on the projector machine and leave it up
- Run through Lesson 1 yourself on the projector machine, so you know the room's network works
- **Connect the Broker MCP server on the projector machine and call one tool**, so Module 5 is
  warm and you are not authenticating live for the first time
- Open the **audit log** in a browser tab and leave it there. You will be projecting it.
- Have the **Disable/Enable** toggle for the MCP server open in another tab, ready
- Confirm the share link or clone URL works from the guest Wi-Fi, on a device that has never
  used it
- Lay out the numbered cards by the door

### 10 minutes before

- Brief the helpers: the top failures are new-terminal-lost-variables, no `(.venv)`, `PATH`,
  and expired credentials. All are in [helper-runbook.md](helper-runbook.md).
- Tell helpers explicitly: **any Broker tool call that is refused is escalated, not debugged.**
  It means the server is disabled or no policy matches — both tenant-side, neither fixable at
  the desk.
- Agree the escalation signal: card held up, helper goes.
- Agree who owns the front of the room during each module so two trainers are never both
  talking.
- Agree who clicks **Disable** in Module 5, and when.

### Spares

- 2–3 pre-configured loaner laptops. There will be at least one machine that cannot be fixed
  in the time available, and moving that person to a working laptop is far better than losing
  them for the session.
- A printed copy of the [cheat sheet](../lab/reference/cheatsheet.html) per table.

### Afterwards

- **Enable the MCP server again** if you left it disabled.
- **Delete or rotate the registered AI agent** — sixty people have its Client Secret.
- **Delete the `workshop-<date>` access policy**, especially if you used *Allow all current and
  future tools* or the **Everyone** role.
- Disable the sixty attendee accounts, or reset their passwords.

---

## Deliberately out of scope

Say this from the front so nobody spends the session wondering:

- **Vaulting the GitHub, Slack and database secrets** in **Idira Secrets Manager**. The product
  is named repeatedly in the lab as the correct destination, and Lesson 4 tells attendees to say
  so to clients — but nobody vaults anything today. The Secrets Manager MCP server ships only as
  a stdio Docker container, and Docker Desktop needs admin rights on Windows, so it cannot be
  used in this room. Follow-up session.
- **Demonstrating Idira EPM.** It is *named* — prework step 5, Lesson 3 step 2, the cheat sheet,
  slide 6, Module 3 — because it answers "what stops anyone running the CLI?", which is a customer
  question. There is no EPM exercise, no console tour and no screenshot. If you promise one you will
  owe the room ten minutes you do not have.
- **Authoring an AI agent access policy.** Attendees *consume* the policy you created in G5 and
  the lab explains how it is structured, but they never write one — that needs the Secure AI
  Admin role, which they do not have.
- **Tests, CI, branching strategy.** The optional Lesson 8 walks the
  spec → tickets → implement → review harness, but only far enough to see the shape of it. The
  AI-harness workshop covers the rest.

The content will later be extended to cover the previous AI-harness workshop. Not now.
