# Helper runbook

You are one of 5–6 helpers for ~60 attendees. Read this once. It is short on purpose.

## Your job

Get people unstuck in under two minutes, and move on. You are not teaching — the lab guide
teaches. You are removing obstacles.

**Do the attendee prework yourself before the session**, on your own laptop, both the macOS
and Windows steps if you can. Ten minutes now saves you improvising in front of someone.

**And do [Lesson 5](../lab/0005-identity-broker.html) at least once**, including the browser
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

---

## The top four, in order

### 1 · "It worked, and now nothing works" 🥇

**Almost always: they are in a different terminal window.**

Environment variables live in one window. New tab, new window, restarted terminal, closed
laptop lid and reopened onto a fresh session — all the same problem.

**Tell:** `NoCredentialsError`, or Claude Code failing to reach Bedrock, right after
something that had been working.

**Fix:** cheat sheet §1. Re-paste the AWS credentials, re-set the three Bedrock variables,
re-activate the virtual environment, `cd` back to `sandbox-app`. About 40 seconds.

**Prevent:** as you walk the room, say "keep that window open" more often than feels necessary.

### 2 · No `(.venv)` in the prompt 🥈

**Tell:** `No module named boto3`, or `ModuleNotFoundError: boto3`, from any `python` command.

Look at their prompt before you look at anything else. If it does not start with `(.venv)`,
that is the whole problem. The virtual environment is **per terminal window**, exactly like the
environment variables — same cause, different symptom.

**Fix:**

```
# macOS
cd ~/Downloads/vibe-coding-workshop && source .venv/bin/activate

# Windows
cd $HOME\Downloads\vibe-coding-workshop; .\.venv\Scripts\Activate.ps1
```

Then `cd sandbox-app` again. Prompt shows `(.venv)`, boto3 works.

**Windows variant:** `Activate.ps1 cannot be loaded because running scripts is disabled on this
system`. Execution policy, no admin rights needed:

```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

**If there is no `.venv` folder at all** — they skipped prework step 3. Two minutes with you:

```
# macOS                          # Windows
python -m venv .venv             py -m venv .venv
source .venv/bin/activate        .\.venv\Scripts\Activate.ps1
pip install -r sandbox-app/requirements.txt
```

**Do not** `pip install --user boto3` as a shortcut. It sometimes works, it sometimes hits a
managed-Python restriction, and it teaches the opposite of what prework step 3 exists to teach.
The venv is thirty seconds.

### 3 · `command not found` 🥉

For `claude` or `idsec`. The tool is installed; the shell cannot see it.

**macOS**

```
ls ~/bin/idsec              # is the file actually there?
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
Test-Path $HOME\bin\idsec.exe
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
*this is Idira EPM deciding which tools may run on a managed endpoint — the same idea as Lesson 3,
one layer lower down.*

### 4 · Expired or rejected credentials

**Tell:** `ExpiredToken`, `ExpiredTokenException`, `UnrecognizedClientException`,
`InvalidClientTokenId`.

**Fix:** back to the portal, re-copy Option 1, re-paste. Cheat sheet §2.

The permission set is configured for a 4-hour session, so genuine expiry should not happen
inside the slot. If you see it repeatedly, tell a trainer — it may mean G1 in the owner prep
was not applied, which affects the whole room.

Partial paste is more common than real expiry: three lines, and people sometimes get two.
Have them check all three variables are set:

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

### Lesson 1

| Symptom | Cause | Fix |
| --- | --- | --- |
| `AccessDeniedException` naming a model | Typo in `ANTHROPIC_MODEL` or wrong region | Re-set with the Copy button; region is `us-east-1` |
| `python` opens the Microsoft Store | Windows app alias | Use `py` — but inside an active `.venv`, plain `python` works |
| `python: command not found` (mac) | Only `python3` exists, and no alias | `python3` for now; `alias python="python3"` in `~/.zshrc` afterwards |
| `No module named boto3` | Virtual environment not active | Top-four #2. Check the prompt for `(.venv)` first. |
| `Activate.ps1 cannot be loaded` | PowerShell execution policy | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, then activate |
| Agent starts but asks them to log in | `CLAUDE_CODE_USE_BEDROCK` is not set in *this* window | Cheat sheet §1(b) |
| Certificate or TLS error reaching Bedrock | A corporate CA bundle variable set by laptop policy | `unset AWS_CA_BUNDLE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE` (Windows: `Remove-Item Env:AWS_CA_BUNDLE, Env:REQUESTS_CA_BUNDLE, Env:CURL_CA_BUNDLE -ErrorAction SilentlyContinue`), then retry. Still failing → escalate. |
| `cd` fails | Unzipped somewhere other than Downloads | macOS: type `cd ` then drag the folder in. Windows: copy the path from Explorer's address bar. |

### Lesson 2

Mostly prompt-driven, so mostly fine. Four things:

- **The agent asks permission to run a command and they do not notice.** They sit waiting.
  Point at the prompt.
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
  - `SSLError` or `CERTIFICATE_VERIFY_FAILED` — the certificate chain is not trusted. On a
    managed laptop this is usually a corporate CA bundle left pointing at the office proxy.
    **Try this first, in that window** (it is a 20-second fix and it works):

    ```
    # macOS
    unset AWS_CA_BUNDLE REQUESTS_CA_BUNDLE CURL_CA_BUNDLE
    # Windows
    Remove-Item Env:AWS_CA_BUNDLE, Env:REQUESTS_CA_BUNDLE, Env:CURL_CA_BUNDLE -ErrorAction SilentlyContinue
    ```

    Then re-run. Still failing, or failing for several people? 🙋 **Escalate** — the network is
    inspecting TLS, and that breaks Claude Code on Bedrock for those people too.
  - `EndpointConnectionError` — no route to Bedrock at all. Check Wi-Fi, then escalate.
  Anything else that names a credential (`UnrecognizedClientException`, `InvalidClientTokenId`)
  is the expected outcome — the app *does* have credentials, they are just fake. That is the
  point of the step.

### Lesson 3

| Symptom | Cause | Fix |
| --- | --- | --- |
| `idsec login` asks for a password and they expected a browser | On most tenant configurations the sign-in is entirely in the terminal — password, then an MFA check | It is the password on their card. Nothing echoes as they type. If it *does* print a URL and no browser opens, they paste that URL into a browser by hand. |
| Authentication error on any `idsec` command | Token expired | `idsec login --force` |
| `list-targets` returns empty | No elevation policy for this user | **Escalate to a trainer.** This is a tenant config problem, not fixable at the desk. |
| Agent invents a flag that does not exist | Old CLI build | Have them ask the agent to run `idsec sca cloud-access elevate --help` and use what it actually reports |
| Elevated role missing from the portal | Not refreshed | Refresh the portal tab. It takes a few seconds to appear. |
| Agent tries to set environment variables itself | It cannot — it runs in a subprocess | They must `/exit` first. This is by design and worth saying out loud. |
| Something failed with no useful message | — | `~/.idsec/logs/idsec-cli.log` has the detail |

### Lesson 4

| Symptom | Cause | Fix |
| --- | --- | --- |
| App still fails after the edit | Elevated credentials not in this window | `get_caller_identity()` check at the top of the lesson |
| `AccessDeniedException` on Bedrock after elevating | The elevated role may lack `bedrock:InvokeModel` | **Escalate immediately** — this is owner-prep gate G2 and it affects everyone |
| Agent also removed `region_name` | Over-eager edit | Have them ask it to put `region_name=AWS_REGION` back |
| Agent moved the keys to a `.env` file instead of deleting them | It solved the wrong problem | Great teaching moment. "You have hidden it, not removed it. Ask it again, and say *delete*." |
| `ImportError: cannot import name 'AWS_ACCESS_KEY_ID' from 'config.settings'` | The agent deleted the constants but left the `import` in `summarize.py` that asks for them | **The most likely Lesson 4 failure.** Back into the agent: *"summarize.py still imports the constants you deleted — remove them from the import and run the app."* The lesson's diff shows all seven removed lines. |
| `grep` still finds `AKIA` | Usually `config/__pycache__/*.pyc` — Python's compiled copy still holds the old string. Otherwise `.claude/` history or a backup file | The lesson's command already excludes `__pycache__`; if they typed a plain `grep -r`, that is what they hit. Worth thirty seconds: caches, images and git history keep copies, which is why the real last step is deleting the key at the source. |

### Lesson 5 — the Identity Broker 🛡️

This is the only module with an authentication flow, so it fails in ways the rest of the day
does not. **Read this one properly before the session, and do the lesson yourself once.**

The one rule: **a refused tool call is escalated, not debugged.** Refusals mean the server is
disabled or no policy matches, and both are tenant-side.

| Symptom | Cause | Fix |
| --- | --- | --- |
| `claude mcp add` complains about arguments | It was run *inside* the agent | Run it in the terminal, before starting `claude`. `/exit` first if needed. |
| It never prompted for the client secret | They typed `--client-secret <value>` | The flag takes **no** value. Re-run without it and let it prompt. |
| Server listed but *needs authentication* | They have not signed in yet | `/mcp` inside the agent → pick the server → sign in in the browser |
| Browser opens, then the callback page will not load | The redirect goes to `http://localhost:<port>` — a VPN or proxy ate it | Try again; if it repeats, have them disconnect the VPN for that one step. 🙋 tell a trainer if several people hit it. |
| Browser never opens | Default browser not set | Copy the URL from the terminal into a browser manually |
| Signed in, but the tools are not listed | The connection has not refreshed | `/mcp` again. Tools appear automatically once authentication completes. |
| Tool count reads *Not discovered yet* in the console | No agent has connected to that server yet | Expected before the first connection. Not an attendee problem. |
| A tool call is **refused** | Server disabled, or no policy matches this user + agent + tool | **Escalate to a trainer.** Do not debug it — it is tenant-side and affects everyone. |
| It worked, then everything stopped, room-wide | The trainer just clicked **Disable** 😄 | That is the demo. Say "watch the front of the room." |
| Wrong Gateway URL | One character off in a long URL | Compare against the slide. Errors here often *look* like auth failures. |

**Do not let anyone paste their Client Secret into a chat, a shared doc, or the projector.**
It is a lab credential in a lab tenant, but the habit is the thing we are teaching.

### Lessons 6–8 — the optional ones

Nobody is expected to reach these, and none of them can break the mandatory work. Help
lightly and prefer pointing at the page over explaining.

| Symptom | Cause | Fix |
| --- | --- | --- |
| Lesson 6: the agent puts a key in the file | That **is** the experiment 🎯 | Ask them what they would do about it. Best conversation of the day. |
| Lesson 6: the agent does *not* put a key in the file | Also a valid result | Have them compare with a neighbour. The point is that the outcome varies, which is why review is a step. |
| Lesson 7: the new skill is never used | Description too vague, or wrong folder | `.claude/skills/<name>/SKILL.md`, and test it in a **fresh** conversation |
| Lesson 8: `/to-spec` etc. do not appear | `/setup-matt-pocock-skills` not run | Run it once, then retry. Those skills are deliberately not auto-selectable. |
| Lesson 8: `/implement` is taking ages | Working as designed — that is the AFK part ☕ | Tell them to leave it alone and read the ticket list while it runs |

---

## The fallback that always works

If a machine is genuinely broken, **two people, one laptop**. The driver types, the other
reads the lab guide aloud and decides what to ask the agent. Pairs frequently learn more than
individuals, and it takes ten seconds to arrange.

## What to escalate immediately

- `list-targets` empty for more than one person → tenant policy gap
- Bedrock `AccessDeniedException` after elevating → gate G2 gap, affects the room
- Repeated genuine credential expiry → gate G1 not applied
- The share link or clone URL not loading → everyone downstream is blocked
- **Any refused MCP tool call in Lesson 5** → the server is disabled, or no access policy
  matches. Gate G5. Affects the whole room and cannot be fixed at a desk.
- **`localhost` callbacks failing for more than one person** → the venue network is
  intercepting the Broker sign-in redirect. Trainer decision, not a desk fix.
- **`idsec` or `claude` blocked by endpoint application control** (EPM or equivalent) → needs an
  endpoint policy change, which nobody in the room can make. One person → loaner laptop. More than
  one → the trainer needs to know, because the managed-laptop fleet will do it to everybody.
- **`SSLError` / `CERTIFICATE_VERIFY_FAILED` from Python or from Claude Code**, after unsetting
  the CA bundle variables → the network is inspecting TLS. Everything that talks to AWS is
  affected, so it is a room-wide problem, not a laptop problem.

These are not desk-side fixes. Get a trainer, because they change what the front of the
room should be doing.
