# Pin IDSEC_PROFILES_FOLDER on Windows during setup

The `idsec` CLI resolves its profiles folder from `IDSEC_PROFILES_FOLDER`, falling back to the
`HOME` environment variable joined with `.idsec/profiles`
(`idsec-sdk-golang/pkg/profiles/idsec_profile_loader.go:126`). Windows PowerShell sets no `HOME`
environment variable, so on Windows that fallback is a **relative** path and the profile belongs
to whichever folder the attendee was standing in. Setup runs from the workshop folder, and
lesson 09 works inside `sandbox-app`, so every `idsec` command in that lesson answered
`No profile found` on Windows, including the ones the agent runs. So `check-prereqs.ps1` pins
`IDSEC_PROFILES_FOLDER` to `%USERPROFILE%\.idsec\profiles` as a persistent user environment
variable, and moves a profile left behind in the workshop folder into it.

## Considered options

- **Set `HOME` on Windows instead.** One variable, same effect on `idsec`. Rejected: `HOME`
  is read by git, ssh and much else, so changing it on a managed laptop to fix one CLI moves
  every other tool's idea of where home is.
- **Teach the `zsp-aws` skill to find the profile and prefix each call.** Rejected as the
  primary fix: lesson 09 steps 4, 6 and 8 are typed by the attendee with no agent involved, so a
  skill cannot reach them. The skills still document the lookup order, because an attendee whose
  setup predates this pin needs to understand the message.
- **Tell attendees to run every `idsec` command from the workshop folder.** Rejected: it makes
  a fragile invariant load-bearing across five lessons, and the agent's working directory is
  `sandbox-app` by design.

## Consequences

`%USERPROFILE%\.idsec\profiles` was chosen over a workshop-owned folder because it is where the
CLI already writes its logs, and because it is what `$HOME\.idsec\profiles` means in PowerShell
and what `~/.idsec/profiles` means on macOS. That keeps the paths already printed in the lab
guide and the skills true on both platforms.

The pin is per user and persists after the workshop. It is written as an `ExpandString` holding
`%USERPROFILE%`, so it follows a profile that moves, and an attendee who already set the
variable themselves keeps their own value.

`check-prereqs.sh` is deliberately untouched: macOS and Linux always set `HOME`, so the fallback
is already absolute there and pinning would add a variable that changes nothing.
