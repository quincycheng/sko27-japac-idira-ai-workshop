# Helper runbook

You are one of 5–6 helpers for ~60 attendees. Read this once. It is short on purpose.

## Your job

Get people unstuck in under two minutes, and move on. You are not teaching — the lab guide
teaches. You are removing obstacles.

**Do the attendee setup yourself before the session**, on your own laptop, both the macOS
and Windows steps if you can. Ten minutes now saves you improvising in front of someone.

**Run all five Part 1 scripts once**, from `ai-harness-app/`. They take about ten minutes end to
end and it is the half of the day where sixty non-developers meet a terminal, so it is where you
will be busiest. Two things to notice while you do it: Part 1 needs **`anthropic` and `rich`**,
which are a *different* requirements file from Part 2's `boto3`; and every script fails with a
plain-English panel rather than a traceback, which means the screen usually tells you the answer
before you do.

**And do [Lesson 10](../lab/0010-identity-broker.html) at least once**, including the browser
sign-in. It is the only module with an authentication flow, and if you have never seen it you
cannot tell "not signed in yet" from "no policy allows this" — which are the same-looking
failure with completely different responses.

## Rules of engagement

1. **Ask "what did you type, and what came back?"** before you touch anything. Half of these
   resolve themselves once the person reads their own error aloud.
2. **Do not take the keyboard.** Point at the screen and say the command. If someone is
   drowning, dictate it — but they type it.
3. **Two minutes, then escalate.** Wave over a trainer or move the person to a loaner laptop.
   Do not spend eight minutes debugging one machine while five hands are up.
4. **Never type anyone's password**, and never let a credential end up on the projector.
5. **Pair people up.** Two attendees sharing one working laptop is a fine outcome. Falling
   behind alone is not.
6. **If their page does not match yours, check the version before anything else.** The guide changes
   during the week. A step you cannot find, a filename that is wrong, an output that does not match the
   page: check this first, because debugging the wrong version wastes both of your two minutes.

   ```
   # macOS                          # Windows PowerShell
   bash update.sh                   .\update.ps1
   ```

   It prints their version and whether it is the current one. If it offers to update, say yes. If it
   prints a web address instead, git cannot update that folder — send them to the hosted guide at that
   address and carry on. Their local files stay as they are, which is fine unless the change was to
   lesson code.

---

## The top four, in order

### 1 · "It worked, and now nothing works" 🥇

**Almost always: they are in a different terminal window.**

Environment variables live in one window. New tab, new window, restarted terminal, closed
laptop lid and reopened onto a fresh session — all the same problem.

**Tell:** `NoCredentialsError`, or Claude Code failing to reach Bedrock, right after
something that had been working.

**Fix:** cheat sheet §1. Re-run the one-line `idsec` elevate command from §2, re-set the three
Bedrock variables, re-activate the virtual environment, `cd` back to the folder the lesson uses —
`ai-harness-app` in Part 1, `sandbox-app` in Part 2. About 40 seconds.

**Prevent:** as you walk the room, say "keep that window open" more often than feels necessary.

**In Part 1 the script says it for you.** The lesson scripts print *"those AWS credentials are no
longer good"* in a panel, with the fix, instead of a traceback. Read the panel to the attendee
rather than diagnosing from scratch.

### 2 · No `(.venv)` in the prompt 🥈

**Tell:** `No module named boto3`, or `ModuleNotFoundError: boto3`, from any `python` command —
or, in Part 1, `No module named anthropic` or `No module named rich`.

Look at their prompt before you look at anything else. If it does not start with `(.venv)`,
that is the whole problem. The virtual environment is **per terminal window**, exactly like the
environment variables — same cause, different symptom.

**Fix:**

```
# macOS
cd ~/Downloads/sko27-japac-idira-ai-workshop && source .venv/bin/activate

# Windows
cd $HOME\Downloads\sko27-japac-idira-ai-workshop; .\.venv\Scripts\Activate.ps1
```

Then `cd` back into the lesson's folder. Prompt shows `(.venv)`, the imports work.

⚠️ **Part 1 needs a different requirements file from Part 2.** `boto3` is Part 2's;
`anthropic` and `rich` are Part 1's. Someone whose venv was built before Part 1 existed — or who
installed one file by hand — will have one and not the other. One command fixes it either way:

```
python -m pip install -r ai-harness-app/requirements.txt -r sandbox-app/requirements.txt
```

**Windows variant:** `Activate.ps1 cannot be loaded because running scripts is disabled on this
system`. Execution policy, no admin rights needed:

```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

**If there is no `.venv` folder at all** — they skipped setup step 3. Two minutes with you:

```
# macOS                          # Windows
python -m venv .venv             py -m venv .venv
source .venv/bin/activate        .\.venv\Scripts\Activate.ps1
pip install -r ai-harness-app/requirements.txt -r sandbox-app/requirements.txt
```

**Do not** `pip install --user boto3` as a shortcut. It sometimes works, it sometimes hits a
managed-Python restriction, and it teaches the opposite of what setup step 3 exists to teach.
The venv is thirty seconds.

### 3 · `command not found` 🥉

For `claude`, `idsec` or `jq`. The tool is installed; the shell cannot see it. `idsec` and `jq` both
live in `~/bin`, so one `PATH` fix covers both.

**macOS**

```
ls ~/bin/idsec ~/bin/jq     # are the files actually there?
echo $PATH                  # does it contain /Users/<name>/bin?
```

If the file exists but `PATH` does not include it, they added the `.zshrc` line and never
opened a new terminal — or they are in `bash`, not `zsh`. Quick unblock for the session:

```
export PATH="$HOME/bin:$PATH"
```

For `claude`, the installer puts it in `~/.local/bin`:

```
export PATH="$HOME/.local/bin:$PATH"
```

**Windows**

```
Test-Path $HOME\bin\idsec.exe, $HOME\bin\jq.exe
$env:Path -split ';' | Select-String 'bin'
```

The user-scope `PATH` change only applies to **new** PowerShell windows. If they edited it and
did not restart, restarting PowerShell is the fix — but then they lose their AWS credentials
too, so redo cheat sheet §1 afterwards. Session-only unblock:

```
$env:Path = "$env:Path;$HOME\bin"
```

Also check they are in **PowerShell**, not Command Prompt. `$env:` syntax silently does
nothing useful in `cmd.exe`, which is a nasty way to lose five minutes.

**Blocked is not the same as missing.** 🖥️ If the file *is* on `PATH` and the shell finds it but the
program will not start — a message about a policy, an administrator, "this application is blocked",
or **Idira EPM** — that is endpoint **application control**, not a `PATH` problem. There is no
desk-side fix: the attendee has no admin rights, and working around application control is the
opposite of what we are teaching. If a **Request authorization** button is offered, have them use it.
Otherwise 🙋 **escalate** and move them to a loaner laptop. Say the useful sentence while you do it:
*this is Idira EPM deciding which tools may run on a managed endpoint — the same idea as Lesson 09,
one layer lower down.*

### 4 · Expired or rejected credentials

**Tell:** `ExpiredToken`, `ExpiredTokenException`, `UnrecognizedClientException`,
`InvalidClientTokenId`.

**Fix:** run the one-line `idsec` elevate command again, in that same terminal window. Cheat sheet §2.

The permission set is configured for at least a 4-hour session against a day that runs 1:00pm to
4:30pm, so genuine expiry is unlikely — but it is *possible* late in slot 2 for anyone who ran the
command well before 1:00pm, and the fix is simply to run it again. If you see it repeatedly, and
early, tell a trainer — it may mean G1 in the owner prep was not applied, which affects the whole
room.

A wrong terminal window is more common than real expiry. The credentials live in the one window that
ran the command, and nowhere else. Have them check all three variables are set:

```
# macOS
env | grep AWS_
# Windows
Get-ChildItem env: | Where-Object Name -like 'AWS_*'
```

They should see `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` **and** `AWS_SESSION_TOKEN`.
A missing session token is the classic silent failure.

---

## The rest, by lesson

### Lessons 01–06 — Part 1 and the break time activity 🏗️

**The single most important thing to know about this half:** most of what looks broken is the
lesson working. The old model forgetting, the agent stopping mid-investigation, a hook refusing a
file read, the numbers not matching the trainer's — all scripted. Before you fix anything, ask
yourself whether the page predicted it.

**Where they should be:** `ai-harness-app/`, not `sandbox-app/`. Same venv, same three `AWS_*`
lines, plus `AWS_REGION`. Cheat sheet §5, "Part 1, lessons 01 to 05".

**The two real failures** both print a titled panel with the fix in it, so read the panel out
loud rather than guessing:

| Panel says | What it is | Who fixes it |
| --- | --- | --- |
| *"those AWS credentials are no longer good"* | Expired, partly pasted, or a different terminal window | 🙋 You. Top four #1 and #4. |
| *"this account cannot call that model"* | Bedrock **model access** not enabled, or the role lacks `bedrock:InvokeModel` on that model | 🚩 **Escalate — owner-prep G2/G2b.** Affects the whole room, and note *which* tier failed: the legacy model is a separate access grant from Sonnet. |

🔓 **There used to be a third: a TLS-interception panel.** It is gone, because Part 1 no longer
verifies certificates at all — see the note at the top of `ai-harness-app/config.py`. So in Part 1,
**a certificate error is not a thing that can happen**, and a corporate CA bundle variable is not
worth checking. If somebody asks why the banner says `tls=unverified`, that is deliberate and the
answer is on the cheat sheet: it stops a proxy ending their lesson 01, and it is a shortcut nobody
should copy. It **does** still bite Claude Code in Part 2 — see Lesson 07 below.

Everything else, by lesson:

| Lesson | Symptom | What is going on |
| --- | --- | --- |
| 01 | "It didn't answer my follow-up properly" | 🎯 That is the lesson. No history is attached. Ask them to say out loud *why*, then move on. |
| 01 | Output is short, blunt, or a bit odd | Also the lesson. It is a 2024 8B model with a 200-token cap. Do not apologise for it. |
| 01–06 | Their token counts differ from the trainer's | Expected, every time, for everyone. The *shape* is the lesson, never the digits. The trainer says this at the front; you will say it twenty more times. |
| 02 | Second answer costs more input tokens than the first | 🎯 The whole point. The conversation is re-sent every turn. |
| 03 | `/fill` makes the answers noticeably worse | 🎯 The dumb zone, on purpose. `/compact` or `/reset` gets it back. |
| 03 | A panel saying *"The request did not fit"* | 🎯 The wall, reached on purpose. The panel names both ways out: `/compact` or `/reset`. |
| 03 | `/style eli5` did not change the answer's length | 🎯 The best beat in Part 1 — history outweighs instructions. `/reset`, then the same command works. Let them see it. |
| 04 | The first call errors out about tools | 🎯 The legacy model has no tool support. The error *is* the demonstration. |
| 04 | The agent stops before finding all six secrets | Check `MAX_ITERATIONS` — the lesson invites them to set it to 2. If they did, that is the answer. |
| 04 | They cannot find the sixth secret by hand | Nobody does. The hidden `.env` and the password inside a `postgres://` URL are the point of the hunt. |
| 05 | The agent refuses to read a file, or refuses a command | 🎯 `_safe_path` and the command allowlist. Not a bug. `--no` makes every refusal visible. |
| 05 | The injection "didn't work" | Correct — the controls held. `prove_the_controls()`, which the script prints when they quit, is the evidence to point at. |
| 05 | `could not reach the local MCP server` | The script carries on without it and says so. Everything else in the lesson still works. Not worth two minutes. |
| 05 | `--remote` cannot reach the playground server | Not an attendee step any more, so they should not be running it. If they are: very likely the venue proxy. Drop the flag and use the local server. |
| 05 | `/remember` seems to do nothing | It appends to `ai-harness-app/memory.md`. Have them open the file, or `/context`. |
| any | `No module named anthropic` / `rich` | Top four #2 — and note it is Part 1's requirements file, not Part 2's. |

⚠️ **One thing to actually prevent:** attendees editing `ai-harness-app/` files and not putting
them back. The lessons invite exactly that — change `MAX_ITERATIONS`, widen `_ALLOWED_COMMANDS`,
delete a hook. That is fine within a lesson, but a widened allowlist carried into Lesson 05 makes
`prove_the_controls()` report a pass where it should report a refusal, and the lesson then teaches the
opposite of its point. If someone's controls behave
strangely, ask what they changed before you look at anything else. `git diff` in the workshop
folder answers it in five seconds.

### Lesson 07

| Symptom | Cause | Fix |
| --- | --- | --- |
| `AccessDeniedException` naming a model | Typo in `ANTHROPIC_MODEL` or wrong region | Re-set with the Copy button; region is `us-east-1` |
| The elevate one-liner printed something instead of nothing | The `eval` or `Invoke-Expression` at the end was lost in the paste | Use the Copy button rather than selecting the text. If a credential did print, it is short-lived and scoped to a sandbox account, so re-run and move on. |
| `jq: command not found` | Setup `jq` install did not stick | Setup step 5. One binary in `~/bin`, and this window has to see it on `PATH`. |
| `idsec: command not found` | Same, for `idsec` | Setup step 5. If the shell finds it but it will not *start*, that is EPM — top-four #3. |
| Bottom line of the agent does not say **auto** | They missed the `Shift+Tab` presses | Keep pressing `Shift+Tab`. It cycles round. Every lesson after this one assumes auto mode. |
| `python` opens the Microsoft Store | Windows app alias | Use `py` — but inside an active `.venv`, plain `python` works |
| `python: command not found` (mac) | Only `python3` exists on that machine | Use `python3` to create the venv. Once it is active, plain `python` works. No alias needed. |
| `No module named boto3` | Virtual environment not active | Top-four #2. Check the prompt for `(.venv)` first. |
| `Activate.ps1 cannot be loaded` | PowerShell execution policy | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, then activate |
| Windows `Security warning: run only scripts that you trust`, on every script | The folder came out of a downloaded zip, so every file in it still carries the downloaded-file mark | In the workshop folder: `Get-ChildItem -Recurse \| Unblock-File`. Answer `R` to get past the prompt in front of you |
| `Unexpected token` from a `.ps1`, with `ðŸ` or `â` in the message | Windows PowerShell 5.1 reads a BOM-less `.ps1` using the machine's ANSI code page. Any non-ASCII character in the file becomes mojibake and it fails to parse. Not their fault and nothing they typed | `.\update.ps1` pulls a fixed copy. If git is not working, hand them a copy from your USB stick. 🚩 tell the trainer: it means a shipped script lost its byte order mark |
| Setup script says `[CHECK] git not installed` | git is genuinely missing. It is **not** a blocker: everything in Part 1 and nearly all of Part 2 runs without it | Do not stop the lesson for it. Only `update.ps1`/`update.sh` and Lesson 08's `/security-review` need it. Windows: https://git-scm.com/download/win, all defaults, no admin. Mac: `xcode-select --install`. Then a new terminal window |
| A `Sign in to GitHub` window opens, twice, and they have no GitHub account | The zip we shipped left a dead one-hour Actions token in `.git/config`. It is an HTTP header, not a credential, so git sends it, GitHub answers 401, and Git Credential Manager asks for a login it cannot use. **Nobody needs an account: the repo is public** | Close both windows. `.\update.ps1` / `bash update.sh` removes the dead token, and after that plain git commands in that folder work anonymously. Do not let them create an account for this |
| Setup script says `no version history in this folder` | They took GitHub's "Source code (zip)" instead of the workshop package, so `.git` never arrived | `.\update.ps1` / `bash update.sh` offers to repair it. Lesson 08 needs the history, so sort it before then |
| Agent starts but asks them to log in | `CLAUDE_CODE_USE_BEDROCK` is not set in *this* window | Cheat sheet §1(b) |
| Claude Code: `self signed certificate in certificate chain` / `UNABLE_TO_VERIFY_LEAF_SIGNATURE` | The network inspects HTTPS. **Part 2 only** — Part 1 does not verify certificates, so this is the first time it bites. Node ignores `AWS_CA_BUNDLE`. | Corporate root CA path on the card → `NODE_EXTRA_CA_CERTS=/path/to/corp-root.pem` in that window. No path and the room is moving → `NODE_TLS_REJECT_UNAUTHORIZED=0`, today only, and say out loud it is the same shortcut Part 1 takes and the same one you would refuse at a client. Several people → 🚩 tell the trainer, it is the venue network. |
| `cd` fails | Unzipped somewhere other than Downloads | macOS: type `cd ` then drag the folder in. Windows: copy the path from Explorer's address bar. |

### Lesson 08

Mostly prompt-driven, so mostly fine. Five things:

- **The agent asks permission to run a command and they do not notice.** They sit waiting.
  Point at the prompt, then check the bottom line of the window. If it does not say **auto**, they
  missed the `Shift+Tab` presses in Lesson 07. Keep pressing `Shift+Tab`; it cycles round.
- **`/security-review` is now the optional step at the end.** It runs for a few minutes. If somebody
  started it early and is now stuck watching it, that is fine. Move them on to Lesson 09 and let it
  finish in the background.
- **The review finds three secrets, not four.** Fine — the database password is inside a
  connection URL and is easy to miss. Have them ask: *"is there a credential inside any URL
  in this project?"* That is a better outcome than being told the answer.
- **`/security-review` reports nothing to review.** Expected on a fresh clone — it looks at
  *changes*, and there are none yet. The lesson says what to do next: ask for the whole project
  instead, *"run a security review across every file in this project, not just changed ones"*.
  Not a bug, not worth two minutes of debugging. The trainer will have said which behaviour to
  expect at the front; if they did not, this is the line.
- **Step 1 ends in a raw traceback, not a friendly message.** The lesson expects the app to say
  the credentials were *rejected*. Look at the last line of the traceback:
  - `SSLError` or `CERTIFICATE_VERIFY_FAILED` — the certificate chain is not trusted. Note that
    `sandbox-app/summarize.py` is **not** one of the Part 1 scripts: it does verify certificates,
    on purpose, because it is the file the agent reviews in this lesson and rewrites in Lesson 14,
    and we are not putting a second vulnerability into it. On a managed laptop this is usually a
    corporate CA bundle left pointing at the office proxy. **Try this first, in that window** (it
    is a 20-second fix and it works):

    ```
    # macOS
    unset AWS_CA_BUNDLE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE
    # Windows
    Remove-Item Env:AWS_CA_BUNDLE, Env:REQUESTS_CA_BUNDLE, Env:CURL_CA_BUNDLE -ErrorAction SilentlyContinue
    ```

    Then re-run. Still failing, or failing for several people? 🙋 **Escalate** — the network is
    inspecting HTTPS, and the same person is about to hit it in Claude Code as well (row above:
    `NODE_EXTRA_CA_CERTS`).
  - `EndpointConnectionError` — no route to Bedrock at all. Check Wi-Fi, then escalate.
  Anything else that names a credential (`UnrecognizedClientException`, `InvalidClientTokenId`)
  is the expected outcome — the app *does* have credentials, they are just fake. That is the
  point of the step.

### Lesson 09

| Symptom | Cause | Fix |
| --- | --- | --- |
| `idsec login` asks for a password and they expected a browser | On most tenant configurations the sign-in is entirely in the terminal — password, then an MFA check | It is their own CYBRWorld password, the account ending in `@cyberarklab.com`. Nothing echoes as they type. If it *does* print a URL and no browser opens, they paste that URL into a browser by hand. |
| Authentication error on any `idsec` command | Token expired | `idsec login --force` |
| Signed in, but to the wrong tenant | They already used `idsec` against another tenant | `idsec login --profile-name cybrworld`. If that profile does not exist yet, `idsec configure --profile-name cybrworld` first, with the three values from the prework email. |
| `list-targets` returns empty | No elevation policy for this user | **Escalate to a trainer.** This is a tenant config problem, not fixable at the desk. |
| Agent invents a flag that does not exist | Old CLI build | Have them ask the agent to run `idsec exec sca cloud-access elevate --help` and use what it actually reports |
| `jq: command not found` | The setup `jq` install did not stick | Setup step 5. It is one binary in `~/bin`, and the new terminal window has to see it on `PATH`. |
| Agent ran the elevate command instead of printing it | It ignored the skill | Not a disaster, but the credentials are now in its transcript. Have them `/exit`, run the command themselves, and say why: what the agent reads, it keeps. |
| Agent tries to set environment variables itself | It cannot — it runs in a subprocess | This is exactly why the lesson has the attendee run the command. Worth saying out loud. |
| Something failed with no useful message | — | `~/.idsec/logs/idsec-cli.log` has the detail |
| Optional Azure step: the response has no credentials in it | Working as designed | Azure elevation returns a `sessionId` and nothing else. There is nothing to export and nothing to clean up. The `zsp-azure` skill says so, and the attendee may paste the response back to the agent. |
| Optional Azure step: `list-targets --csp azure` is empty, or elevate is rejected | No Azure entitlement for this user | Leave it. The step is optional and the mandatory work does not touch Azure. 🙋 tell a trainer so the owner knows the room's entitlement. |

### Lesson 10 — MCP: AI Agent Identity Broker 🛡️

This is the only module with an authentication flow, so it fails in ways the rest of the day
does not. **Read this one properly before the session, and do the lesson yourself once.**

Two things to know before you walk the room. It runs on **CYBRWorld**, `demo.cyberark.cloud`, the same
tenant as Lesson 09, so there is no tenant to switch. A sign-in that "works" in the wrong browser
profile is still a real failure mode. And the lesson has two console acts: steps 6 to 9 are read-only
clicking, not terminal work.

The one rule: **one refusal is expected, a second is escalated.** Step 5 has everyone call
`beta_features` and be refused. That is the lesson working. Any *other* refused call means no policy
matches or the server is disabled, and both are tenant-side.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `claude mcp add` complains about arguments | It was run *inside* the agent | Run it in the terminal, before starting `claude`. `/exit` first if needed. |
| They are looking for a client secret | There is none. The agent is a public client | Everything they need is on the lesson page: Gateway URL, Client ID, callback port. Nothing comes from Slack this year. |
| The browser never comes back to the terminal | Port 8080 is already in use by something else | `claude mcp remove idira-ai-broker-entrasonar`, then re-add with `--callback-port 8123`. |
| Server listed but *needs authentication* | They have not signed in yet | `/mcp` inside the agent → pick the server → sign in in the browser |
| Browser opens, then the callback page will not load | The redirect goes to `http://localhost:<port>` — a VPN or proxy ate it | Try again; if it repeats, have them disconnect the VPN for that one step. 🙋 tell a trainer if several people hit it. |
| Browser never opens | Default browser not set | Copy the URL from the terminal into a browser manually |
| Signs in, but authentication still fails | The browser opened a **different profile**, signed into another tenant | Press `c` in the terminal to copy the sign-in URL, then paste it into the browser profile that has their CYBRWorld session. The error does not say this. |
| `beta_features` was **allowed** | The policy has been edited, or it uses *Allow all current and future tools* | 🙋 tell a trainer. Step 5 and the whole of act 2 stop making sense, room-wide. |
| Signed in, but the tools are not listed | The connection has not refreshed | `/mcp` again. Tools appear automatically once authentication completes. |
| Worked earlier, now says the server **needs re-authorization** | The token expired. Expected, and it is the lesson's point | `/mcp` and sign in again. Say why: the agent holds a short-lived token, not a credential. |
| Tool count reads *Not discovered yet* in the console | No agent has connected to that server yet | Expected before the first connection. Not an attendee problem. |
| A tool call is **refused** | No policy matches this user + agent + tool, or the server is disabled | **Escalate to a trainer.** Do not debug it — it is tenant-side and affects everyone. |
| It worked, then everything stopped, room-wide | **Not** a demo. Nothing in the tenant is changed during the session | **Escalate immediately.** This is a real outage, not the kill switch. |
| Wrong Gateway URL | One character off in a long URL | Copy it from the lesson page rather than typing it. Errors here often *look* like auth failures. |
| Console page shows an error or an empty list (steps 6–9) | Signed in as the wrong account, or the read role is missing | Check they are signed in to `demo.cyberark.cloud` with their own `@cyberarklab.com` account. If that is right, 🙋 tell a trainer: it affects everyone. New hires are the likely case. |
| Console is very slow on steps 6–9 | Sixty people are hitting the same tenant | Expected. Have them wait rather than reloading repeatedly. |
| They can find one call in the audit log, not both | Filter is right, they stopped at the success | Both records are there. The `beta_features` denial is the one worth opening. |
| They cannot find their own call in the audit log | Filter not set | Time range = last 24 hours, Service name = **Secure AI Agents**, filter by **Username** with their own login name ending `@cyberarklab.com`. |

**The Client ID on the lesson page is not a secret**, and there is no secret in this lesson. If somebody
asks why not, that is the best question of the module: the browser sign-in is what proves who they are.

### Lessons 11–14 — the optional ones

Nobody is expected to reach these, and none of them can break the mandatory work. Help
lightly and prefer pointing at the page over explaining.

| Symptom | Cause | Fix |
| --- | --- | --- |
| Lesson 11: the agent puts a key in the file | That **is** the experiment 🎯 | Ask them what they would do about it. Best conversation of the day. |
| Lesson 11: the agent does *not* put a key in the file | Also a valid result | Have them compare with a neighbour. The point is that the outcome varies, which is why review is a step. |
| Lesson 12: the new skill is never used | Description too vague, or wrong folder | `.claude/skills/<name>/SKILL.md`, and test it in a **fresh** conversation |
| Lesson 13: `/to-spec` etc. do not appear | `/setup-matt-pocock-skills` not run | Run it once, then retry. Those skills are deliberately not auto-selectable. |
| Lesson 13: `/implement` is taking ages | Working as designed — that is the AFK part ☕ | Tell them to leave it alone and read the ticket list while it runs |

**Lesson 14 is the one that fails in real ways**, because it edits code the attendee then has to run.
It is the follow-up to Lesson 09 on the same sandbox app, so it needs elevated credentials in that
window.

| Symptom | Cause | Fix |
| --- | --- | --- |
| App still fails after the edit | Elevated credentials not in this window | `get_caller_identity()` check at the top of the lesson |
| `AccessDeniedException` on Bedrock after elevating | The elevated role may lack `bedrock:InvokeModel` | **Escalate immediately** — this is owner-prep gate G2 and it affects everyone |
| Agent also removed `region_name` | Over-eager edit | Have them ask it to put `region_name=AWS_REGION` back |
| Agent moved the keys to a `.env` file instead of deleting them | It solved the wrong problem | Great teaching moment. "You have hidden it, not removed it. Ask it again, and say *delete*." |
| `ImportError: cannot import name 'AWS_ACCESS_KEY_ID' from 'config.settings'` | The agent deleted the constants but left the `import` in `summarize.py` that asks for them | **The most likely Lesson 14 failure.** Back into the agent: *"summarize.py still imports the constants you deleted — remove them from the import and run the app."* The lesson's diff shows all seven removed lines. |
| `grep` still finds `AKIA` | Usually `config/__pycache__/*.pyc` — Python's compiled copy still holds the old string. Otherwise `.claude/` history or a backup file | The lesson's command already excludes `__pycache__`; if they typed a plain `grep -r`, that is what they hit. Worth thirty seconds: caches, images and git history keep copies, which is why the real last step is deleting the key at the source. |


---

## The fallback that always works

If a machine is genuinely broken, **two people, one laptop**. The driver types, the other
reads the lab guide aloud and decides what to ask the agent. Pairs frequently learn more than
individuals, and it takes ten seconds to arrange.

## Who fixes what — the three tiers

Sort every problem into one of three tiers before you touch it. Most of what you will be called over
for is **Self**, and the single most useful thing you can do all day is know that and say it.

| Tier | Who fixes it | How you recognise it |
| --- | --- | --- |
| **Self** 🧑 | The attendee, usually by running the setup script | Something is missing or not on `PATH`. Nothing is broken; a step was skipped. |
| **Helper** 🙋 | You, at the desk, in under two minutes | Wrong window, wrong shell, wrong folder, partial paste. The machine is fine and the account is fine. |
| **Tenant** 🚩 | The workshop owner, tenant-side, before or during | Policy, registration, network or endpoint. Nobody in the room can fix it, and it usually affects more than one person. |

### Tier 1 · Self — point at the script, do not debug

**The setup script is the answer to most of the day's questions.** From the workshop folder:

```
# macOS
bash check-prereqs.sh
# Windows
.\check-prereqs.ps1
```

It checks everything, fixes most of it, and says plainly what it could not. Say this rather than
typing anything yourself:

> Run the prereq script from the workshop folder, then open a new terminal. It will tell you what it
> fixed.

| Symptom | Almost always | What you say |
| --- | --- | --- |
| `idsec: command not found` | Setup step 5 skipped, or `PATH` edited without a new terminal | Run the script. It downloads `idsec` and fixes `PATH`. Then **new terminal**. |
| `claude: command not found` | Same shape: installed under `~/.local/bin`, not on `PATH` | Run the script, then **new terminal**. The script looks in that folder, so if it is already installed it prints the full path instead of offering to install it again. |
| `No module named boto3` / `anthropic` / `rich` | No `.venv`, or libraries never installed | Run the script. It builds the venv and installs both requirements files. |
| A CA bundle variable pointing at a file that is gone | Set by policy on a laptop that has moved networks | Harmless for this workshop now — nothing here reads it. Only chase it if something *else* on the laptop is failing; step 9 of the script names the variable and prints the `unset` line. |
| No `.venv` folder at all | Setup step 3 skipped | Run the script. Do **not** `pip install --user`. |
| `idsec configure` never run | Setup step 6 skipped | Their card has the tenant subdomain and username. Two minutes. |
| The page in front of them does not match yours | Their copy is behind. They missed the update the trainer called | Run `update.sh` / `update.ps1`, say yes when it offers. Then reload the page in the browser. |
| `update.sh` prints a web address instead of updating | No `.git` in their folder: they downloaded GitHub's "Source code (zip)" instead of the workshop package | Send them to that address for the guide. Note it down: Lesson 08's `/security-review` needs the history too, and the script offers to repair it. |

⚠️ **The new-terminal cost.** Any `PATH` fix needs a fresh window, and a fresh window has no AWS
credentials in it. Tell them that in the same breath, or they will fix `idsec` and immediately break
Bedrock. Cheat sheet §1 puts it back.

**The most common misdiagnosis of the day:** `idsec version` failing in Lesson 09 gets reported as
"the CLI is broken". It is not. It is setup step 5, and the lesson now says so before it mentions
your card.

**And the most common misdiagnosis of Part 1:** the lesson working, reported as the lesson broken.
A model that forgets, an agent that stops early, a hook that refuses, a style instruction that gets
ignored — every one of those is a scripted beat with a callout next to it on the page. The question
to ask first is *"what does the page say should happen?"*, not *"what went wrong?"*. Part 1 has
exactly three real failures and they all arrive in a titled panel.

### Tier 2 · Helper — the four you actually fix

These are the top four above, and they are yours: wrong terminal window, no `(.venv)`, `PATH` not
picked up in this shell, and partial or expired credential paste. Two minutes each, then move.

Also yours: wrong folder, Command Prompt instead of PowerShell, execution policy on `Activate.ps1`,
and an agent waiting on a permission prompt nobody noticed.

### Tier 3 · Tenant — escalate immediately, do not debug

**Get a trainer.** These change what the front of the room should be doing, and several of them are
gate failures from [owner-prep.md](owner-prep.md) that will hit everybody within minutes.

| Symptom | What it means | Gate |
| --- | --- | --- |
| *"this account cannot call that model"* in **any** Part 1 lesson | Bedrock model access is not enabled for that tier, or the policy is missing `bedrock:InvokeModel` on it. Say **which tier** — legacy and frontier are separate grants. Affects the room, in lesson 01. | G2b |
| `list-targets` empty, for more than one person | No elevation policy covers these users | G2 |
| Bedrock `AccessDeniedException` **after** elevating | The elevated role lacks `bedrock:InvokeModel`. Affects the room. | G2 |
| Repeated genuine credential expiry | Session duration still 1 hour | G1 |
| Any **refused** MCP tool call in Lesson 10 | Server disabled, or no policy matches user + agent + tool | G5 |
| `localhost` callback fails for more than one person | The venue network is intercepting the Broker sign-in redirect | — |
| `idsec` or `claude` **blocked** by endpoint application control 🖥️ | Needs an EPM policy change. Nobody in the room has the rights. One person → loaner laptop. Several → the fleet will do it to everybody. | — |
| Claude Code failing on certificates for more than one person | The venue network inspects HTTPS. **Part 2 only** — Part 1 does not verify, so this surfaces for the first time at Lesson 07 and can look like a new problem when it is not. What the trainer needs is one corporate root CA path for `NODE_EXTRA_CA_CERTS`; failing that, tell the room to set `NODE_TLS_REJECT_UNAUTHORIZED=0` from the front, once, with the caveat said out loud. The setup script reports this a week early under *"How this network treats HTTPS"* — worth knowing whether the replies mentioned it. | — |
| `--remote` in lesson 05 blocked for more than one person | Egress filtering on the venue network. Harmless — the local MCP server covers the lesson — but the trainer should stop offering the flag from the front. | — |
| The share link or clone URL not loading | Everyone downstream is blocked | G3 / G6 |
| `/security-review` behaving differently for different people | The repo shipped without a first commit | G6 |

**Blocked is not missing.** 🖥️ If the shell finds the program and it still will not start — a message
about a policy, an administrator, "this application is blocked", or **Idira EPM** — that is
application control, not `PATH`, and the setup script cannot help. If a **Request authorization**
option is offered, have them use it. Otherwise escalate and move them to a loaner laptop. Say the
useful sentence while you walk them over:

> This is Idira EPM deciding which tools may run on a managed endpoint. Same idea as Lesson 09, one
> layer lower down.

### What setup was supposed to catch

Every Tier 1 row above is a setup step. When you see a cluster of them, that is worth telling a
trainer even though each one is individually trivial: it means setup did not land, and the
whole room is about ten minutes behind where the run of show assumes it is.
