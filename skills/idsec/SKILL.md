---
name: idsec
description: Drive the Idira idsec CLI for any Identity Security Platform operation — profiles and login, plus the sia, sca, pcloud, identity, policy, cmgr and sechub services. Use whenever the user wants to inspect or change something in Idira from the command line.
---

# idsec — the Idira CLI

`idsec` is the official command-line interface for the Idira Identity Security Platform
(formerly CyberArk). It is a single binary. It needs no installer and no admin rights.

## Check it is there first

```
idsec version
```

If that fails, the binary is usually not on `PATH`. Ask the user where they extracted it rather
than guessing, then either use the full path or help them add it to `PATH`.

**Distinguish "missing" from "blocked".** A message about a policy, an administrator, an
application being blocked, or **Idira EPM** (Endpoint Privilege Manager) is not a `PATH` problem:
it is endpoint application control deciding which executables may run on that machine. `idsec` is a
privileged tool — whoever can run it can request elevation — so this is a deliberate control, and
it is the layer beneath the one this CLI operates in. Report it and stop. See rule 6.

## Every command has the same shape

```
idsec <service> <subcommand> [flags]
```

`exec` is the default verb and is always omitted — `idsec sia sso short-lived-password` is
the same as `idsec exec sia sso short-lived-password`.

## Services

| Service | What it covers |
| --- | --- |
| `sia` | Secure Infrastructure Access — SSO, K8s, databases, VMs, connectors, certificates |
| `sca` | Secure Cloud Access — **zero standing privileges**: elevation into AWS and Azure at the moment of use |
| `pcloud` | PCloud — accounts, safes, applications |
| `identity` | Identity — users, roles, directories, auth profiles, policies |
| `policy` | Access control policies for cloud access, databases and VMs |
| `cmgr` | Connector Manager |
| `sechub` | Secrets Hub — secret stores, sync policies, scans |

Note the overlap: `idsec policy cloud-access …` **manages the policies**, while
`idsec sca cloud-access …` **uses them to elevate**. They are different services with a
similarly named subcommand. Read the user's intent carefully before choosing.

## Discover flags — never invent them

The CLI is under active development and flag names change between releases. Before running
any command you have not run in this session, get its real flags:

```
idsec <service> --help
idsec <service> <subcommand> --help
```

If a flag you expected does not exist, do not improvise a similar one. Report what `--help`
actually offers and ask.

## Profiles and login

Authentication lives in profiles, stored in the **profiles folder**. The CLI resolves that
folder in one order, and there is no flag for it:

1. the `IDSEC_PROFILES_FOLDER` environment variable, if it is set
2. otherwise `HOME` joined with `.idsec/profiles`

Step 2 reads the `HOME` *environment variable*. **Windows PowerShell does not set one** —
`$HOME` there is a PowerShell variable, not an environment variable — so the fallback becomes
`.idsec\profiles` **relative to the current folder**. A profile created in one folder is
invisible from another, and the CLI says `No profile found` rather than naming a path.

The **token cache**, the file that remembers a login, is resolved the same way and has the
same defect:

1. the `IDSEC_KEYRING_FOLDER` environment variable, if it is set
2. otherwise `HOME` joined with `.idsec/cache/keyring`

On Windows the CLI tries the OS credential store first and falls back to that folder, which it
does often, because a token is usually too long for Windows Credential Manager. So on Windows a
login also belongs to the folder it was done in. Profile and login are two separate lookups: it
is normal to find the profile and still be told the login expired.

```
idsec configure                          # interactive; creates a profile
idsec login                              # log in with the default profile
idsec login --profile-name <name>        # log in with a named profile
idsec login --force                      # re-login even if the token looks valid
idsec profiles list                      # see what profiles exist
```

If a command fails with an authentication error, a login is the first thing to try — tokens
expire, and an expired token is by far the most common cause. Ask the user to run `idsec login`
in their own terminal. It prompts, so it cannot succeed in yours.

When a profile file has been provided for the user, do **not** run `idsec configure` — it
would overwrite it. Go straight to `idsec login`.

### "No profile found"

This nearly always means the profile is somewhere else, not that it is absent. Before you
conclude anything, report the three facts that tell them apart:

- the value of `IDSEC_PROFILES_FOLDER`, and whether a profile exists there
- whether `.idsec/profiles` exists in the current folder, or in a folder above it
- whether the home `.idsec` directory holds only `logs`

That last one is the signature of the Windows case. The log path is resolved from the OS home
directory rather than from `HOME`, so on a machine where the two disagree the logs are in the
real home and the profiles are not.

The fix is to set `IDSEC_PROFILES_FOLDER` to the folder that holds the profile, which the user
does in their own terminal. Do not fix it by moving or writing a profile yourself.

**Do not run `idsec configure`, and do not suggest it.** A user who reached you already has a
profile, so `configure` overwrites rather than repairs, and it needs an interactive terminal
you do not have.

### "Tokens are either expired or authenticators are not logged in"

Read this one carefully when the user says they have already logged in. It means this shell
found no usable token, which is not the same as their login having lapsed. On Windows the
likeliest cause is the folder split above: they logged in from one folder, you are in another.

Report these facts before concluding anything:

- the value of `IDSEC_KEYRING_FOLDER`, and whether `keyring` and `mac` exist in it
- whether `.idsec/cache/keyring` exists in the current folder, or in a folder above it

**The log tells you which half failed.** The log records the store lookup in words, and two of
them mean opposite things:

- `Failed to get password from OS keyring: The specified item could not be found` — the store
  opened, and held nothing under that key. A miss, not a permission problem.
- `Failed to open OS keyring` — the store itself was unreachable. This is the only one of the two
  that is about access.

Either way the CLI then falls back to the folder from step 2, and a following `No token found`
means that folder holds no `keyring` file. A miss plus that fallback is the signature of a login
saved in another folder. The login's own lines are in the same log, above yours: look for
`Trying to save token`, then either `Saved token successfully` or `Falling back to basic keyring
as we failed to save token`. The second one names the cause outright.

**Do not conclude that your shell cannot reach the credential store.** On Windows, Credential
Manager is readable by every process of the signed-in user, child processes included. That theory
sends the user hunting for a problem they do not have, and it is contradicted by the log line
above whenever the message is about a missing item.

Three more things, all of which cost the user time if you get them wrong.

**Never open the token cache.** Do not read, copy, decode or move `keyring`, `mac`, or anything
in a credential store, and do not work around a tool that refuses to let you. Report where the
token is not, and stop.

**You cannot log in for them.** `idsec login` needs an interactive terminal and your shell has
no TTY. On Windows it fails with `Failed to get isp username: Incorrect function`. Say that
once and ask them to run it themselves. Do not retry it, and do not try `--force`.
`--silent --refresh-auth` is not a way around it either: with no cached token to refresh it exits
0 and leaves the next call just as unauthenticated, which reads as success and is not one.

**A variable set after your session started is invisible to you.** Your process inherited its
environment when it launched. If the user says they pinned `IDSEC_KEYRING_FOLDER` and you read
it as empty, that is the reason: ask them to restart this session, not to set it again. A quick
way to tell the two of you apart is to have them run the failing command in their own terminal.
If it works there and not here, the difference is the environment, not the login.

## Rules

1. **Never print a credential.** If a command returns a secret, an access key, a password
   or a token, say that it succeeded and describe what it returned. Do not echo the value
   into the transcript.
2. **Never pass a secret on the command line** where you can avoid it — it lands in shell
   history. Prefer interactive prompts.
3. **Read-only first.** When exploring, use `list`/`get` subcommands before anything that
   creates, updates or deletes. Confirm with the user before any write.
4. **Diagnose with the log.** Detailed output goes to `~/.idsec/logs/idsec-cli.log` regardless of
   terminal verbosity, and on Windows to `%USERPROFILE%\.idsec\logs\idsec-cli.log`. Use that
   second path there rather than `~`: the log folder is the only one the CLI resolves from the
   operating system's home directory instead of the `HOME` variable, so the two can differ.
   Read it when a command fails opaquely.
5. **Never create or overwrite a profile.** `idsec configure` is the user's command, not
   yours, and a missing profile is a location problem far more often than a real absence.
   See "No profile found" above.
6. **Never route around an endpoint control.** If the CLI is blocked from running by application
   control (Idira EPM or equivalent), do not copy the binary elsewhere, rename it, change its
   permissions, or look for another way to execute it. Tell the user what blocked it and that it
   needs a policy change or an authorization request from whoever administers their endpoints.
