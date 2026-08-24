---
name: zsp-azure
description: Activate a short-lived Azure role on demand — zero standing privileges — through Idira Secure Cloud Access instead of holding a permanent role assignment. Use when the user needs temporary Azure access, when an Azure role assignment is permanent and should not be, or when they ask whether Secure Cloud Access covers more than AWS.
---

# Zero standing privileges for Azure

Replace a permanent Azure role assignment with one that is requested at the moment it is
needed and expires by itself. The same CLI, the same login and the same audit trail as
`zsp-aws`, pointed at a different cloud.

This skill uses the `idsec` CLI. See the `idsec` skill for the CLI's general shape, and
`zsp-aws` for the AWS version of this workflow.

**Read this difference first.** An AWS elevation hands back short-lived credentials. An Azure
elevation hands back a **session id** and nothing else. There is no access key, no token, and
nothing to export into a shell. The role becomes active for the signed-in user in the Azure
directory, and Idira has recorded who asked for it.

## Step 1 — Make sure you are logged in

```
idsec login
```

A profile should already exist. If one has been provided, do **not** run `idsec configure` —
it would overwrite it.

If this reports `No profile found`, the profile is almost certainly in another folder rather
than missing: the CLI reads `IDSEC_PROFILES_FOLDER`, and falls back to a path that is relative
to the current folder on Windows. Read the "No profile found" section of the `idsec` skill and
stop there. Do not configure a profile and do not guess at targets.

## Step 2 — Find what the user is allowed to activate

```
idsec exec sca cloud-access list-targets --csp azure
```

Each entry names a workspace and a role. Azure workspaces come back with a
`workspaceType`, and a directory-scoped one looks like this:

```
{
  "workspaceId": "032734d4-b0fe-4736-92df-d923b68c0316",
  "workspaceName": "COM-NP-Int L-Sales Engineering-Azure-External",
  "role": { "id": "5d6b6bb7-de71-4623-b4af-96380a352509", "name": "Security Reader" },
  "organizationId": "032734d4-b0fe-4736-92df-d923b68c0316",
  "workspaceType": "directory"
}
```

Show the user the list. If it is empty, they have no elevation policy assigned for Azure —
that is an administrator's job, not something to work around.

## Step 3 — Print the elevate command

Keep the same habit as `zsp-aws`: fill in the values, print the command, and let the user run
it in their own terminal. It is one command on macOS, Linux and PowerShell alike, because
there is nothing to pipe and nothing to export.

```
idsec exec sca cloud-access elevate --csp azure --workspace-id <workspace-id> --roleIds <role-id> --organization-id <organization-id>
```

For the workshop tenant, those values are:

```
idsec exec sca cloud-access elevate --csp azure --workspace-id 032734d4-b0fe-4736-92df-d923b68c0316 --roleIds e3973bdf-4987-49ae-837a-ba8e231c7286 --organization-id 032734d4-b0fe-4736-92df-d923b68c0316
```

Three details about the Azure flags:

- `--organization-id` is **required** here. For a directory-scoped workspace it carries the
  same value as `--workspace-id`. AWS only needs it when the account sits in an Organization.
- `--csp azure` is what changes the response shape. Nothing else in the command line signals
  that no credential is coming back.
- The role id accepted by `elevate` is not always the one printed by `list-targets`, because
  a workspace can expose more than one entitlement. In the workshop tenant, use the id above.
  In any other tenant, offer the ids from `list-targets` and let the user confirm.

The response is a receipt, not a secret:

```
{
  "response": {
    "organizationId": "032734d4-b0fe-4736-92df-d923b68c0316",
    "csp": "AZURE",
    "results": [
      {
        "workspaceId": "032734d4-b0fe-4736-92df-d923b68c0316",
        "roleId": "e3973bdf-4987-49ae-837a-ba8e231c7286",
        "sessionId": "02718437-7e3a-4277-bb0c-1a1b499ed804"
      }
    ]
  }
}
```

A `sessionId` came back, so the elevation was granted. Because that response holds no
credential, the user may paste it to you and you may read it back to them. That is the one
place this skill is more relaxed than `zsp-aws`.

If the user asks you to run the Azure elevation yourself, you may. Nothing secret enters the
transcript. Say why the AWS equivalent is different, so the distinction is learned rather
than guessed at later.

## Step 4 — What you can and cannot check

There is nothing to export, so there is no environment to test. Do not invent a verification
step, and do not tell the user to install the Azure CLI to prove this worked.

- The `sessionId` is the confirmation that policy allowed the request.
- The activation applies to the user's own Azure sign-in, so the place to see it is the Azure
  portal, under their assigned roles.
- The session expires on its own. Nothing has to be revoked, cleaned up or unset.

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

This is the multi-cloud point, and it is the whole reason the skill exists: one CLI, one
login, one policy engine and one audit trail, across more than one cloud provider.

It does **not** change anything about an application that talks to AWS. If the user is
working on a codebase whose credentials are AWS credentials, use `zsp-aws` — activating an
Azure role will not make that code run. Say so plainly rather than letting the two get
mixed up.

It also does nothing for other secrets: a GitHub token, a Slack webhook, a database
password. Those need a vault, which is a different conversation.

## Rules

1. **The user elevates, not you** — by default, to keep one habit across both clouds. For
   Azure you may run it if asked, because the response contains no credential.
2. **Never print a credential.** No credential comes back from an Azure elevation. If one
   ever does, treat it exactly as `zsp-aws` says: never echo it, never write it down.
3. **Sessions expire.** Access that worked earlier and now fails usually just needs Step 1
   and Step 3 again. That is the feature, not a fault.
4. **Never write anything from an elevation into a file** to make it last longer. That
   recreates the problem this skill exists to remove.
5. **Never turn off certificate verification unasked.** See the TLS section above.
