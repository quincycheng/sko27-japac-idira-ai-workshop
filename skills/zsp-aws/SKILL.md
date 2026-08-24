---
name: zsp-aws
description: Get short-lived AWS access on demand — zero standing privileges — through Idira Secure Cloud Access instead of using a long-lived access key. Use when AWS credentials are hardcoded in code or config, when AWS access has expired, or when the user needs temporary AWS access for a task.
---

# Zero standing privileges for AWS

Replace a permanent AWS access key with access that is requested at the moment it is
needed and expires by itself. A key that does not exist cannot leak.

This skill uses the `idsec` CLI. See the `idsec` skill for the CLI's general shape.

## Step 1 — Make sure the user is logged in

```
idsec login
```

This prompts, so **the user runs it, not you.** In your shell it fails for want of a terminal.

A profile should already exist. If one has been provided, do **not** run `idsec configure` —
it would overwrite it.

Two failures here mean the same thing on Windows, and neither is what it says:

- `No profile found` — the profile is in another folder, not missing.
- `tokens are either expired or authenticators are not logged in` — the login is in another
  folder, even if the user just did it.

Both happen because the CLI resolves those folders from `IDSEC_PROFILES_FOLDER` and
`IDSEC_KEYRING_FOLDER`, and falls back to paths relative to the current folder on Windows. Read
the matching section of the `idsec` skill, report what you find and stop there. Do not configure
a profile, do not retry the login, and do not guess at targets.

## Step 2 — Find what the user is allowed to elevate into

```
idsec exec sca cloud-access list-targets --csp aws
```

This returns the AWS workspaces (accounts) and roles this user may assume. Show the user
the list. If it is empty, they have no elevation policy assigned — that is an
administrator's job, not something to work around.

## Step 3 — Print the elevate command. Do not run it.

The elevation response contains the short-lived credentials themselves. If you run it, they
land in your context and in the session transcript. So **you do not run it.** Fill in the
values you found in Step 2, print the command, and tell the user to run it in their own
terminal.

macOS and Linux:

```
eval "$(idsec exec sca cloud-access elevate --csp aws --workspace-id <aws-account-id> --roleIds <role-arn> --raw | jq -r '.response.results[0].accessCredentials | fromjson | "export AWS_ACCESS_KEY_ID=\(.aws_access_key)\nexport AWS_SECRET_ACCESS_KEY=\(.aws_secret_access_key)\nexport AWS_SESSION_TOKEN=\(.aws_session_token)"')"
```

PowerShell:

```
idsec exec sca cloud-access elevate --csp aws --workspace-id <aws-account-id> --roleIds <role-arn> --raw | jq -r '.response.results[0].accessCredentials | fromjson | "$env:AWS_ACCESS_KEY_ID=\"\(.aws_access_key)\"\n$env:AWS_SECRET_ACCESS_KEY=\"\(.aws_secret_access_key)\"\n$env:AWS_SESSION_TOKEN=\"\(.aws_session_token)\""' | Invoke-Expression
```

Three details in that pipeline, all of which break it if changed:

- `accessCredentials` is a JSON string *inside* the JSON, which is why `fromjson` is there.
- The field is `aws_access_key`, not `aws_access_key_id`. It maps to `AWS_ACCESS_KEY_ID`.
- `--raw` gives plain JSON. Without it the output may be decorated or paginated.

Take `<aws-account-id>` and `<role-arn>` from the `list-targets` output — do not guess
them. Confirm the choice with the user when more than one target is available.

If the account is managed by an AWS Organization, add `--organization-id <o-xxxxxxxx>`.

AWS accepts **one** role per elevation, so `--roleIds` takes a single role ARN here.

Nothing prints when the command succeeds. The credentials are environment variables in that
one terminal, they were never written to a file, and they were never shown on screen.

The pipeline needs `jq`. If the user reports `jq: command not found`, it is either not
installed or not on their `PATH` in that window.

⚠️ If the user asks you to run the elevation yourself, say why you would rather not, and
offer the printed command instead. Only run it if they ask a second time. Even then, never
repeat the credentials in your reply and never write them to a file.

## Step 4 — Verify

Check that the short-lived credentials are actually in effect:

```
python -c "import boto3, urllib3; urllib3.disable_warnings(); print(boto3.client('sts', verify=False).get_caller_identity()['Arn'])"
```

`verify=False` is here because some corporate networks inspect HTTPS traffic, which breaks the
certificate check on this call. It matches what `ai-harness-app/config.py` already does for Part 1.
Do not carry it into application code you write for the user.

The ARN should name the elevated role. If it names something else, or the call fails, the
credentials are not in the environment yet.

## Step 5 — Fix the code that needed a key

Once elevation works, the application no longer needs credentials of its own. Search the
project for hardcoded AWS credentials and remove them:

- Delete the credential constants from the config file.
- Remove `aws_access_key_id=` and `aws_secret_access_key=` from every `boto3.client(...)`
  and `boto3.Session(...)` call. Leave `region_name`.
- **Remove every reference to the constants you just deleted**, including the `import`
  statements that name them. A module that still says
  `from config.settings import AWS_ACCESS_KEY_ID` will fail with `ImportError` even though
  the credential itself is gone. Grep for each constant name before you claim to be done.

Then **run the application** to prove the change works — the fix is not finished until the
program starts and authenticates from the environment.

boto3 then resolves credentials from the environment on its own. **The fix makes the code
shorter.** Show the user the diff and point that out.

Do not replace the deleted constants with anything: not a `.env` file, not
`os.environ["AWS_SECRET_ACCESS_KEY"]`, not a default argument. boto3 reads the environment
itself, and every one of those alternatives puts the secret back into the code's care.

## When HTTPS to the Idira tenant fails

On a corporate network the TLS certificate may be re-signed by an inspecting proxy, and
`idsec` then reports a certificate error. Fix it in this order:

1. `--trusted-cert <path-to-pem>` — point `idsec` at the proxy's CA certificate. This is the
   correct fix and it keeps verification on.
2. `--proxy-address <url>` — plus `--proxy-username` and `--proxy-password` if the proxy
   needs them.
3. `--disable-cert-verification` — last resort. It turns certificate verification off, so
   the connection can be intercepted. `idsec`'s own help calls it unsafe and says to avoid
   it in production.

Never add `--disable-cert-verification` on your own initiative. Offer options 1 and 2 first,
explain what option 3 gives up, and use it only if the user asks for it explicitly.

## What this does and does not solve

Zero standing privileges eliminates AWS credentials. It does nothing for other secrets — a
GitHub token, a Slack webhook, a database password. Those need a vault, which is a
different conversation. If you find them, **say so plainly** rather than implying they are
covered.

## Rules

1. **The user elevates, not you.** Print the command from Step 3 and let them run it. The
   secret then never enters your context or the transcript.
2. **Never print the credentials.** If you ever do see them, report that elevation succeeded
   and which role is now active. Never echo an access key, secret key or session token.
3. **Credentials live in one shell.** If they are set as environment variables they exist
   only in that terminal session, and they expire. A tool that worked ten minutes ago and
   now returns an authentication error usually just needs Step 1 and Step 3 again.
4. **Never write the short-lived credentials into a file** to "make them last". That
   recreates the problem this skill exists to remove.
5. **Never turn off certificate verification unasked.** See the TLS section above.
