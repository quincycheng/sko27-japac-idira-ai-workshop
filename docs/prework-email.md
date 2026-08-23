# Prework email

Send **one week before** the session. Chase non-responders **three days before**.

Replace everything in `<angle brackets>` before sending. Attach or link the workshop folder and
mirror both `idsec` archives.

---

**Subject:** SKO27 TechSummit · Idira AI Workshops, `<date>` — 25 minutes of setup needed beforehand 🧰

Hi `<name>`,

You are booked into **SKO27 TechSummit - Idira AI Workshops** on **`<date>` at `<time>`** — the
vibe coding session. It is **two sessions — 1:00–2:00pm and 3:00–4:30pm**, and almost all of it
is hands-on, on your own laptop. In the first half you build an AI agent out of parts, in about
fifteen lines of Python at a time. In the second half you point a real one at an Idira problem.

**Please do the setup below before the day.** It takes about 25 minutes. There are around
sixty of us and two trainers — if everyone installs software during the session, nobody gets to
the interesting part.

## Your details

You sign in with **your own CYBRWorld account**, the one ending in `@cyberarklab.com`. Nobody issues
you a workshop login. These three answers are what `idsec configure` asks for:

| | |
| --- | --- |
| **Identity Tenant Subdomain** | `demo` |
| **Identity URL** | https://aam4614.my.idaptive.app/ |
| **Username** | your own, ending in `@cyberarklab.com` |

Already using `idsec` against another tenant? Make a second profile:
`idsec configure --profile-name cybrworld`, then `idsec login --profile-name cybrworld`.

**One more check, and it is browser-only.** Lessons 09 and 10 open the console at
`demo.cyberark.cloud`. Same account, no `idsec` involved, nothing to install. Please open it this week
and sign in. Note which browser you used: Lesson 10 opens a sign-in page from the terminal, and it uses
your default browser. If you have joined recently and a page says you have no access, tell us this week
rather than on the day.

## Downloads

| What | Link |
| --- | --- |
| Workshop folder | `<clone URL or share link>` |
| `idsec` — official releases page | https://github.com/cyberark/idsec-cli-golang/releases |
| `idsec` for macOS (mirror) | `<share link>` |
| `idsec` for Windows (mirror) | `<share link>` |

The releases page is the primary source — pick the newest release and the file matching your
machine. The setup page tells you exactly which filename to look for. The mirrors are there in
case GitHub is blocked on your network.

## What we need to hear about this week 🚩

The setup script checks everything, including your AWS access and whether each program really
starts. Two of its answers cannot be fixed from your seat, and neither can a helper fix them on the
day. Both need days of lead time. So please run the script this week and post in
**#cybr-japac-ts-all** on Slack if you see either of these.

**1. No AWS role came back.** The script runs `idsec exec sca cloud-access list-targets --csp aws`
for you. An empty list, or an error about policy, is an **access entitlement** we have to grant in
advance.

**2. A program is blocked rather than missing.** 🖥️ A message about a policy, an administrator, or
**Idira EPM** is endpoint application control. It needs a policy change rather than anything you can
do. Please don't try to work around it. Just reply, and use the **Request for authorization** button
if you are offered one.

## What to do

1. Get the **workshop folder** onto your laptop, into your Downloads folder.
2. **Run the setup script.** Open a terminal in that folder and run one line:

   ```
   # macOS
   bash check-prereqs.sh

   # Windows PowerShell
   .\check-prereqs.ps1
   ```

   It checks everything, offers to fix what it can, and finishes by telling you exactly what is
   left. Most people are done at this point. It touches nothing outside your home folder and this
   project folder, and it changes nothing without asking you first.
3. **Anything it could not fix**, or if you would rather read what you are doing: open the folder, go
   into `lab`, and **double-click `0000-setup.html`**. Pick macOS or Windows at the top and the
   whole page adjusts to your machine. It walks through the same nine steps by hand.

4. **Arrange your screen, and leave it that way.** 🪟 Put the **lab guide on one half** of your screen
   and a **terminal on the other**, side by side. Every instruction on the day is "read this, then type
   that", and you do not want to be flipping between two full-screen windows to follow it.

   On a Mac, hover the green ● button of a window and choose **Tile Window to Left of Screen**, then do
   the other window on the right. On Windows, click a window and press `Win` + `←`, then the other and
   `Win` + `→`. Give the terminal about **80 columns** — a bit wider than
   half on a small laptop screen is fine.

   Do it today rather than on the day. It takes ten seconds when nobody is talking and two minutes when
   somebody is. 🖥️ Bringing a second screen? Even better — guide on one, terminal on the other.

That page is the real instructions — this email is just the links, your tenant settings, and the
script that saves you most of the typing.

## A few things worth knowing

**Nothing needs administrator rights.** Everything installs into your own home folder. If you
get a prompt asking for admin credentials, stop and post in #cybr-japac-ts-all — something has gone
sideways and we would like to know.

**You will set up a Python virtual environment** (step 3). It is a folder inside the project
holding the libraries this workshop needs — nothing is installed system-wide, nothing can break
another tool on your laptop, and cleaning up afterwards is deleting one folder. Two things to
remember from that step:

- Your prompt shows `(.venv)` when it is switched on.
- It is **per terminal window**. New window, activate again. Write the activation command down;
  you will need it more than once on the day. (This is the single most common problem in the
  room, and the easiest to fix.)

**If `python` is not found but `python3` is**, that is normal on a Mac and nothing needs fixing.
Use `python3` for the one command that creates the virtual environment. After that, the environment
supplies its own `python`, so every instruction in the lab works.

**No coding experience is needed.** Genuinely, that is the point of the session. If you have
never opened a terminal, you are exactly who this was written for.

## If something does not work

**Ask in #cybr-japac-ts-all on Slack.** Please do not wait for the day.

Run the setup script first if you have not — it names the problem for you, which makes your message
much easier for us to act on. Then paste what it printed into the channel.

And the two at the top of this email, again, because they are the ones that cannot wait: **no AWS
role** and **a program your laptop refuses to run**. Both need days, not minutes.

See you on `<date>`. Bring a charger. 🔋

`<your name>`

---

## Checklist for the sender

- [ ] The workshop folder is distributed as a **git repository** (clone URL, or a zip that still
      contains `.git/`) — Lesson 08 uses `/security-review`, which needs version control
- [ ] `docs/` is **not** in what attendees receive
- [ ] Share links or clone URL tested from a device that has never opened them
- [ ] `idsec` mirrors are on a share that needs **no login**
- [ ] The `idsec` archive filenames match what `lab/0000-setup.html` step 5 tells people to type
- [ ] Every attendee has a **CYBRWorld account** ending in `@cyberarklab.com`, and an AWS
      entitlement in Secure Cloud Access against it — checked before this email goes out
- [ ] `idsec configure` has been run once by you against `demo.cyberark.cloud`, and its prompts match
      the three values in this email
- [ ] Every attendee can **sign in to `demo.cyberark.cloud`** in a browser, and read **Inventory > AI**,
      **Policies > AI agent access** and **Audit and Reports** there. A standard account has all three.
      The email asks them to check it themselves, and new hires are the ones who find out they cannot.
      Gate G4 in [owner-prep.md](owner-prep.md) covers what to do about stragglers
- [ ] `jq` installs cleanly on both platforms from the URLs in `lab/0000-setup.html` step 5
- [ ] **`idsec`, `jq` and Claude Code are permitted by the EPM policy on the attendees' laptop fleet** —
      confirmed with the team that owns the EPM sets, *before* this email goes out, because the fix
      has a lead time and no attendee can apply it
- [ ] Calendar invite sent separately, with the same links in the body

### Not in this email, on purpose

The **Identity Broker** details for Lesson 10 are not sent in advance, because they do not need to be:
the Gateway URL and Client ID are printed in the lesson itself, and there is no client secret. The agent
is registered as a public client. See gate G5 in [owner-prep.md](owner-prep.md).

The console address and the sign-in check **are** in the email. Neither is a secret, and the sign-in is
the one part of Lesson 10 that has to be sorted out beforehand.
