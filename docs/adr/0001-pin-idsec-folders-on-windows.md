# Pin the idsec profile and token folders on Windows during setup

The `idsec` CLI resolves two folders the same way, from an environment variable falling back to
the `HOME` environment variable:

- the profiles folder, from `IDSEC_PROFILES_FOLDER`, else `HOME` + `.idsec/profiles`
  (`idsec-sdk-golang/pkg/profiles/idsec_profile_loader.go:126`)
- the cached login, from `IDSEC_KEYRING_FOLDER`, else `HOME` + `.idsec/cache/keyring`
  (`pkg/common/keyring/idsec_basic_keyring.go:88`)

Windows PowerShell sets no `HOME` environment variable, so on Windows both fallbacks are
**relative** paths and both belong to whichever folder the attendee was standing in. Setup runs
from the workshop folder and lesson 09 works inside `sandbox-app`, so every `idsec` command in
that lesson failed on Windows: first `No profile found`, and once the profiles folder was pinned,
`tokens are either expired or authenticators are not logged in` for a login the attendee had just
done. So `check-prereqs.ps1` pins both variables under `%USERPROFILE%\.idsec` as persistent user
environment variables, and moves a profile or a token cache left behind in the workshop folder
into them.

The token folder is genuinely load-bearing on Windows, which is not obvious: the CLI asks
Windows Credential Manager first and falls back to this folder. Credential Manager rejects a blob
over roughly 2.5 KB and an idsec token is a JWT, and the read path falls back on Windows even for
a plain miss, which the SDK's own comment attributes to creds being "too long for windows cred
manager" (`pkg/common/keyring/idsec_os_provided_keyring.go:145`).

`~/.idsec/logs/idsec-cli.log` is where this is legible, and it is worth knowing which lines to
read, because the obvious reading of them is wrong. `The specified item could not be found in the
keyring` is `ErrKeyNotFound`: the store opened and held no entry. A store the process cannot reach
logs `Failed to open OS keyring` instead. So that message plus the `No token found` that follows
the fallback does not mean the credential store was unreadable from that shell; it means the login
was saved elsewhere. The fallback also leaves a fingerprint on disk, since `NewIdsecBasicKeyring`
creates its folder on construction (`idsec_basic_keyring.go:92`): a `.idsec/cache/keyring`
directory appears in whatever folder the fallback resolved to.

## Considered options

- **Set `HOME` on Windows instead.** One variable, both folders fixed. Rejected: `HOME` is read
  by git, ssh and much else, so changing it on a managed laptop to fix one CLI moves every other
  tool's idea of where home is.
- **Teach the `zsp-aws` skill to find the profile and the token and prefix each call.** Rejected
  as the primary fix: lesson 09 steps 4, 6 and 8 are typed by the attendee with no agent
  involved, so a skill cannot reach them. There is also no flag for either folder. The skills
  still document the lookup order, because an attendee whose setup predates this pin needs to
  understand the message.
- **Tell attendees to run every `idsec` command from the workshop folder.** Rejected: it makes a
  fragile invariant load-bearing across five lessons, and the agent's working directory is
  `sandbox-app` by design.

## Consequences

`%USERPROFILE%\.idsec` was chosen over a workshop-owned folder because it is where the CLI
already writes its logs, so one `.idsec` holds everything, and because it is what `$HOME\.idsec`
means in PowerShell and what `~/.idsec` means on macOS. That keeps the paths already printed in
the lab guide and the skills true on both platforms.

Both pins are per user and persist after the workshop. They are written as `ExpandString` values
holding `%USERPROFILE%`, so they follow a profile that moves, and an attendee who already set
either variable themselves keeps their own value. They are also checked independently, because an
attendee who ran the earlier version of this script has the profiles variable pinned and the
keyring one still missing.

The token cache is moved rather than recreated, so an attendee does not sign in twice. `keyring`
and `mac` move together or not at all: the second is a SHA256 of the first and the SDK refuses a
pair that disagrees. Neither file is otherwise path-bound, because the encryption key is the
hostname. A cache already in the pinned folder is never overwritten, since one encrypted file
cannot be merged into another; the stray one is reported and left alone, and the login that setup
performs writes a fresh token to the pinned folder anyway.

A variable pinned after Claude Code started is invisible to the agent, which inherits its
environment at launch. Lesson 09 and the `idsec` skill both say so, because the symptom is the
attendee's own terminal working while the agent's does not.

`check-prereqs.sh` is deliberately untouched: macOS and Linux always set `HOME`, so both
fallbacks are already absolute there and pinning would add variables that change nothing.
