# Working in this repo

## Writing rules for lab pages

Everything under `lab/` is read by an attendee, at a desk, under time pressure. Many of them are not
native English speakers, and their AI knowledge varies from none to expert. Write for that reader.

- **Plain English.** Short common words. "Access AWS", not "Borrow some AWS access".
- **One idea per sentence, about 20 words.** If a sentence needs a dash to hold two ideas together,
  it is two sentences.
- **No em dashes** in attendee prose. Use a full stop, or a colon when a list follows. Generated
  terminal output and Python docstrings are exempt: they are not read as prose.
- **No decorative emoji.** They are allowed in `h1`, in `.callout-label`, and as the ✅ that marks a
  correct answer. Nowhere else, and not in step titles.
- **Instruction first, explanation second.** "Paste it into your terminal. Nothing prints." Not a
  paragraph about what success feels like.
- **No asides, no jokes, no nudging.** Cut "worth reading", "much more instructive", "that is the
  point". State the fact and move on.
- **Define jargon on first use**, in five words, inline and bold. `capability record`, `context
  window`, `standing credential`. The cheat sheet is the reference page; do not add a glossary box.
- **Sentence case headings**, except `Your Tasks`, `Knowledge Check`, `The Code (optional)` and
  `The Fast Way (Recommended)` on the setup page.
- **No durations on attendee pages.** Times describing the trainer's clock, a customer demo, or a
  video length are fine.
- **A step ends by naming its proof.** One line: the command that shows it worked, or the exact output
  to expect. "It prints `libraries ready`." Not "you should be all set".
- **Keep a step body under about 80 words of prose**, not counting code blocks, callouts and lists. If
  it runs longer, the step is doing two things.
- **Delete a `section-intro` unless the attendee acts on it.** "You can skip the first 2 steps" stays.
  "Three rows move at once today" goes. The same test applies to a `standfirst`: two sentences, both
  load-bearing.
- Do not bold filenames, paths or variables. `<code>` carries those. Bold is for jargon on first use
  and for the one word in a step you cannot afford to misread.

These apply to prose an attendee reads between commands. `warn`, `stop` and knowledge-check `why`
boxes are exempt from the word cap: they are safety and teaching text, and they are already short.

Lesson 01 (`lab/0001-one-call.html`) is the reference for this style. Match it.

## Structural rules

- Pages must work from `file://` with no network: no CDN, no modules, no `fetch`. Two exceptions embed
  Google content in `.embed` iframes: lesson 06's optional step, which holds a Slides deck and a Drive
  video, and the `The deck` section of `lab/reference/securing-agentic-ai.html`. Every embed carries a
  plain link next to it and a sentence saying corporate Google access is needed, and nothing on either
  page depends on an embed loading. Lesson 06's step is also marked `step-opt`.
- **Never embed YouTube.** The player returns error 153 to a page with no referrer, which is every page
  opened from `file://`. Link to the video and give its length instead.
- `lab/assets/lab.js` holds `PAGES`, the single source of truth for nav and pager.
- One prompt per code block, on one physical line. The app's chatbox reads one line per Enter, so a
  pasted newline is a sent message.
- Blocks between `<!-- BEGIN GENERATED -->` and `<!-- END GENERATED -->` belong to
  `build-lab-code.py`. Edit its inputs instead: `ai-harness-app/*.py`, `lab/annotations/*.md`,
  `lab/idira-thread.md`. Then run `.venv/bin/python build-lab-code.py` and check it with `--check`.
