---
name: zsp-aws
description: Get short-lived AWS access on demand — zero standing privileges — through Idira Secure Cloud Access instead of using a long-lived access key. Use when AWS credentials are hardcoded in code or config, when AWS access has expired, or when the user needs temporary AWS access for a task.
---

# Zero standing privileges for AWS

Replace a permanent AWS access key with access that is requested at the moment it is
needed and expires by itself. A key that does not exist cannot leak.

This skill uses the `idsec` CLI. See the `idsec` skill for the CLI's general shape.

## Step 1 — Make sure you are logged in

```
idsec login
```

A profile should already exist at `~/.idsec/profiles`. If one has been provided, do **not**
run `idsec configure` — it would overwrite it.

## Step 2 — Find what the user is allowed to elevate into

```
idsec sca cloud-access list-targets --csp aws
```

This returns the AWS workspaces (accounts) and roles this user may assume. Show the user
the list. If it is empty, they have no elevation policy assigned — that is an
administrator's job, not something to work around.

## Step 3 — Elevate

```
idsec sca cloud-access elevate --csp aws --workspace-id <aws-account-id> --roleIds <role-arn>
```

If the account is managed by an AWS Organization, add `--organization-id <o-xxxxxxxx>`.

Take `<aws-account-id>` and `<role-arn>` from the `list-targets` output — do not guess
them. Confirm the choice with the user when more than one target is available.

AWS accepts **one** role per elevation, so `--roleIds` takes a single role ARN here.

Run `idsec sca cloud-access elevate --help` before your first elevation in a session to
confirm the flags and to see exactly how this build returns the credentials.

⚠️ The response may contain the short-lived credentials themselves, in an `accessCredentials`
field. **Do not repeat them in your reply, and never write them to a file.** Report that
elevation succeeded and which role is now active, and let the user collect the credentials
the way their lab or runbook tells them to.

## Step 4 — Verify

Check that the short-lived credentials are actually in effect:

```
python -c "import boto3; print(boto3.client('sts').get_caller_identity()['Arn'])"
```

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

## What this does and does not solve

Zero standing privileges eliminates AWS credentials. It does nothing for other secrets — a
GitHub token, a Slack webhook, a database password. Those need a vault, which is a
different conversation. If you find them, **say so plainly** rather than implying they are
covered.

## Rules

1. **Never print the credentials.** Report that elevation succeeded and which role is now
   active. Never echo an access key, secret key or session token.
2. **Credentials live in one shell.** If they are set as environment variables they exist
   only in that terminal session, and they expire. A tool that worked ten minutes ago and
   now returns an authentication error usually just needs Step 1 and Step 3 again.
3. **Never write the short-lived credentials into a file** to "make them last". That
   recreates the problem this skill exists to remove.
