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

```
idsec configure                          # interactive; creates a profile
idsec login                              # log in with the default profile
idsec login --profile-name <name>        # log in with a named profile
idsec login --force                      # re-login even if the token looks valid
idsec profiles list                      # see what profiles exist
```

If a command fails with an authentication error, run `idsec login` before doing anything
else — tokens expire, and an expired token is by far the most common cause.

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

## Rules

1. **Never print a credential.** If a command returns a secret, an access key, a password
   or a token, say that it succeeded and describe what it returned. Do not echo the value
   into the transcript.
2. **Never pass a secret on the command line** where you can avoid it — it lands in shell
   history. Prefer interactive prompts.
3. **Read-only first.** When exploring, use `list`/`get` subcommands before anything that
   creates, updates or deletes. Confirm with the user before any write.
4. **Diagnose with the log.** Detailed output goes to `~/.idsec/logs/idsec-cli.log`
   regardless of terminal verbosity. Read it when a command fails opaquely.
5. **Never create or overwrite a profile.** `idsec configure` is the user's command, not
   yours, and a missing profile is a location problem far more often than a real absence.
   See "No profile found" above.
6. **Never route around an endpoint control.** If the CLI is blocked from running by application
   control (Idira EPM or equivalent), do not copy the binary elsewhere, rename it, change its
   permissions, or look for another way to execute it. Tell the user what blocked it and that it
   needs a policy change or an authorization request from whoever administers their endpoints.
