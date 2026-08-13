# Prework email

Send **one week before** the session. Chase non-responders **three days before**.

Replace everything in `<angle brackets>` before sending. Attach or link the workshop folder and
mirror both `idsec` archives.

---

**Subject:** SKO27 TechSummit · Idira AI Workshops, `<date>` — 25 minutes of setup needed beforehand 🧰

Hi `<name>`,

You are booked into **SKO27 TechSummit - Idira AI Workshops** on **`<date>` at `<time>`** — the
vibe coding session. It is 90 minutes and almost all of it is hands-on, on your own laptop.

**Please do the setup below before the day.** It takes about 25 minutes. There are around
sixty of us and two trainers — if everyone installs software during the session, nobody gets to
the interesting part.

## Your details

| | |
| --- | --- |
| **Attendee number** | `<nn>` |
| **Portal** | https://ngid.cyberark.cloud/ |
| **Username** | `<username>` |
| **Initial password** | `<password>` |
| **`idsec configure` — tenant subdomain** | `<subdomain>` |
| **`idsec configure` — username** | `<username>` |

Bring these with you. You will also get them on a card on the day.

## Downloads

| What | Link |
| --- | --- |
| Workshop folder | `<clone URL or share link>` |
| `idsec` — official releases page | https://github.com/cyberark/idsec-cli-golang/releases |
| `idsec` for macOS (mirror) | `<share link>` |
| `idsec` for Windows (mirror) | `<share link>` |

The releases page is the primary source — pick the newest release and the file matching your
machine. The prework page tells you exactly which filename to look for. The mirrors are there in
case GitHub is blocked on your network.

## What to do

1. Get the **workshop folder** onto your laptop, into your Downloads folder.
2. Open the folder, go into `lab`, and **double-click `0000-prework.html`**. It opens in your
   browser.
3. Follow the **seven steps** on that page. Pick macOS or Windows at the top and the whole page
   adjusts to your machine.

That page is the real instructions — this email is just the links and your login.

## Three things worth knowing

**Nothing needs administrator rights.** Everything installs into your own home folder. If you
get a prompt asking for admin credentials, stop and reply to this email — something has gone
sideways and we would like to know.

**You will set up a Python virtual environment** (step 3). It is a folder inside the project
holding the libraries this workshop needs — nothing is installed system-wide, nothing can break
another tool on your laptop, and cleaning up afterwards is deleting one folder. Two things to
remember from that step:

- Your prompt shows `(.venv)` when it is switched on.
- It is **per terminal window**. New window, activate again. Write the activation command down;
  you will need it more than once on the day. (This is the single most common problem in the
  room, and the easiest to fix.)

**If `python` is not found but `python3` is**, that is normal on a Mac and step 2 shows you how
to add a one-line alias so every instruction in the lab just works. No admin rights, nothing
installed.

**No coding experience is needed.** Genuinely, that is the point of the session. If you have
never opened a terminal, you are exactly who this was written for.

## If something does not work

**Reply to this email.** Please do not wait for the day.

One step in particular cannot be fixed from your seat during the session — **step 7**, where you
check you can reach AWS through the portal. If the **AWS** tile is missing, or no accounts are
listed, or there is no **Access keys** link, that is an access entitlement we have to grant
for you in advance. Tell us this week.

**The other one to tell us about early: a download your laptop refuses to run.** 🖥️ If `idsec` or
Claude Code is *blocked* rather than missing — a message about a policy, an administrator, or
**Idira EPM** — that is endpoint application control, and it needs a policy change rather than
anything you can do. Please don't try to work around it; just reply, and use the **Request
authorization** button if you are offered one.

See you on `<date>`. Bring a charger. 🔋

`<your name>`

---

## Checklist for the sender

- [ ] The workshop folder is distributed as a **git repository** (clone URL, or a zip that still
      contains `.git/`) — Lesson 07 uses `/security-review`, which needs version control
- [ ] `docs/` is **not** in what attendees receive
- [ ] Share links or clone URL tested from a device that has never opened them
- [ ] `idsec` mirrors are on a share that needs **no login**
- [ ] The `idsec` archive filenames match what `lab/0000-prework.html` step 5 tells people to type
- [ ] Attendee numbers and logins are correct per row — mail-merge, do not hand-edit sixty emails
- [ ] `idsec configure` has been run once by you, and its prompts match what the card says
- [ ] **`idsec` and Claude Code are permitted by the EPM policy on the attendees' laptop fleet** —
      confirmed with the team that owns the EPM sets, *before* this email goes out, because the fix
      has a lead time and no attendee can apply it
- [ ] Calendar invite sent separately, with the same links in the body

### Not in this email, on purpose

The **Identity Broker** details for Lesson 10 — Gateway URL, Client ID, Client Secret — are
**not** sent in advance. There is no prework for that lesson, and a client secret in sixty
inboxes is a worse idea than a client secret on sixty cards. Put them on the cards or on a
slide on the day. See gate G5 in [owner-prep.md](owner-prep.md).
