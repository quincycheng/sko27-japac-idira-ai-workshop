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
it is the layer beneath the one this CLI operates in. Report it and stop. See rule 5.

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

Authentication lives in profiles, stored at `~/.idsec/profiles`.

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
5. **Never route around an endpoint control.** If the CLI is blocked from running by application
   control (Idira EPM or equivalent), do not copy the binary elsewhere, rename it, change its
   permissions, or look for another way to execute it. Tell the user what blocked it and that it
   needs a policy change or an authorization request from whoever administers their endpoints.
