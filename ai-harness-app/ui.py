"""The presentation layer -- everything the audience SEES, and nothing else.

Why this file exists: the five numbered stages are the lesson. Every line of
`rich` formatting in them would be a line competing with the lesson. So the
stages call one-liners (`ui.model(text)`, `ui.tool(name, args)`) and all the
styling lives here.

What this file deliberately does NOT contain: any decision about what the agent
is allowed to do. That is `tools.py`. This file can draw an approval prompt; it
has no opinion on when one is needed.

Colours are the Idira palette (#265bff) plus the amber/salmon already used by
lab/assets/lab.css, so warnings and refusals stay legible on a projector --
blue-on-black is the least readable combination in a big room.
"""

# Keeps this file importable on Python 3.9, which is what a managed Mac already
# has and what the setup page asks for. Without it, `bool | None` in the signatures
# below is a TypeError the moment the module loads. See tools.py for the longer
# version of this note.
from __future__ import annotations

import os
import sys

from rich.columns import Columns
from rich.console import Console
from rich.markdown import Markdown
from rich.padding import Padding
from rich.panel import Panel
from rich.text import Text
from rich.theme import Theme

# --- Palette -----------------------------------------------------------------
IDIRA_BLUE = "#265bff"  # the logo blue -- the ONLY colour in the mark
WARN = "#e8c07a"  # lab.css amber -- approval prompts
DANGER = "#f28b82"  # lab.css salmon -- refusals, high severity
EVENT = "SKO27 TechSummit — Idira AI Workshops"

THEME = Theme(
    {
        "brand": f"bold {IDIRA_BLUE}",
        "mark": IDIRA_BLUE,
        "subtitle": "grey62",
        "meta": "grey42",
        "tool": "grey58",
        "warn": f"bold {WARN}",
        "danger": f"bold {DANGER}",
        "ok": f"bold {IDIRA_BLUE}",
    }
)

console = Console(theme=THEME, highlight=False)

# rich's Markdown renderer reflows to the terminal width; on a very wide window
# that produces unreadably long lines, so cap it.
PANEL_WIDTH = min(100, max(60, console.width - 2))


def _fancy_glyphs() -> bool:
    """Can this terminal do 24-bit colour AND braille glyphs?

    Windows conhost and any TERM without truecolor will render #265bff as a
    muddy approximation and may print the braille characters as '?'. We cannot
    pre-check this in check-prereqs (it depends on the terminal, not the
    install), so detect at runtime and fall back to plain text.

    Font coverage of U+28xx is the one thing we CANNOT detect -- a terminal can
    be truecolor and UTF-8 and still draw tofu boxes. Hence the manual escape
    hatch: IDIRA_PLAIN_BANNER=1 to skip the mark on a laptop that renders it
    badly, without editing this file five minutes before a session.
    """
    if os.environ.get("IDIRA_PLAIN_BANNER"):
        return False
    if console.color_system != "truecolor":
        return False
    encoding = (getattr(sys.stdout, "encoding", "") or "").lower()
    return "utf" in encoding


# The Idira mark, rasterised from lab/assets/idira-logo-light.svg: an isometric
# cube drawn as a thick "C" -- a hexagonal ring open at the upper right, with
# the cube's right face detached inside it.
#
# Braille, not half-blocks: each cell is 2x4 subpixels instead of 1x2, and the
# mark is nothing but diagonals. At this size half-blocks staircase the
# diagonals so coarsely that the mark reads as a crescent rather than a cube.
#
# Flat #265bff throughout, because the source SVG is flat -- ring and face are
# both class="st0". What separates the face from the arm above it is the gap,
# not a shade. Do not "add depth" here; there is no second brand blue.
#
# 18 cells wide against 8 tall, which is a DELIBERATE ~1.3x horizontal stretch
# of the SVG's 19.7:22.8 -- not a rasterising bug. At true aspect (14x8) the
# strokes are only 4 braille dots across and read as thin on a projector; the
# stretch widens the left bar to 6 dots without spending another row of height.
# If you restore true proportions, go to 16x9 rather than back to 14x8.
#
# The blanks are U+2800 (blank braille), not spaces, so every row is 18 cells
# wide in fonts where braille and ASCII advance differently.
#
# The wordmark does not survive as art at any size that fits a terminal, so
# "IDIRA" is set as styled text instead.
_MARK = [
    "⠀⠀⠀⠀⠀⣀⣤⣴⣾⣷⣶⣤⣀⠀⠀⠀⠀⠀",
    "⢀⣠⣤⣶⣿⣿⣿⣿⠿⠿⣿⣿⣿⣿⣶⣦⣄⡀",
    "⣿⣿⣿⡿⠟⠋⠉⠀⠀⠀⠀⠉⠙⠻⠿⠛⠋⠁",
    "⣿⣿⣿⡇⠀⠀⠀⠀⠀⢀⣠⣴⣶⣿⡇⠀⠀⠀",
    "⣿⣿⣿⡇⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⡇⠀⠀⠀",
    "⣿⣿⣿⣷⣦⣄⣀⠀⠀⣿⣿⡿⠟⠋⠁⠀⠀⠀",
    "⠈⠙⠛⠿⣿⣿⣿⣿⣶⠉⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠉⠛⠻⢿⠀⠀⠀⠀⠀⠀⠀⠀⠀",
]


def banner(stage: str, model: str = "", caps=None) -> None:
    """Print the Idira mark, the event, the stage, and what the model can do.

    Printed ONCE per run, at the top. Reprinting it mid-transcript is noise on a
    screen share -- the per-turn numbers live in footer() instead.

    The capability line is here rather than in the footer because it is the thing
    an attendee needs before the first answer arrives, not after it: "this model
    has no tools and an 8k window" explains what is about to happen.
    """
    provider = os.environ.get("LLM_PROVIDER", "bedrock")

    wordmark = Text()
    wordmark.append("\nIDIRA", style="brand")
    wordmark.append(" ®", style="meta")
    # grey62 rather than the ®'s grey42: an attribution nobody can read at the
    # back of the room is not an attribution.
    wordmark.append("  by Palo Alto Networks\n", style="subtitle")
    wordmark.append(EVENT + "\n", style="subtitle")
    wordmark.append(stage + "\n", style="brand")
    if model:
        wordmark.append(f"{provider}  ·  {model}\n", style="meta")
    if caps is not None:
        wordmark.append(_caps_text(caps), style="meta")

    console.print()
    if _fancy_glyphs():
        mark = Text("\n".join(_MARK), style="mark")
        # Mark to the left of the wordmark, as in the SVG lockup.
        console.print(Columns([mark, wordmark], padding=(0, 2)))
    else:
        console.print(wordmark)
    console.print()


def _caps_text(caps) -> str:
    """The capability record, in one line. Read this out loud in lesson 01.

    `tls=unverified` is on this line rather than in a comment somewhere because
    this is the app's honesty line, and the one thing an honesty line cannot do is
    leave out the awkward fact. Part 1 does not verify certificates -- config.py
    says why at length, and the cheat sheet says why you must not copy it. Anyone
    who reads this banner has been told.
    """
    return (
        f"tier={caps.name}  tools={'yes' if caps.tools else 'no'}  "
        f"system role={'yes' if caps.system else 'no'}  "
        f"window={caps.window:,}  tls=unverified"
    )


def model(text: str, speaker: str = "the model") -> None:
    """The model's voice: a panel, Markdown-rendered.

    Claude emits Markdown unprompted -- numbered findings, `file:line` in
    backticks, bold severities. Rendering it is what makes this read like a
    product instead of a log.

    The panel is titled with whichever model actually answered, never a generic
    "Claude". Lessons 01-03 are not talking to Claude, and a workshop about
    knowing what is in your context should not mislabel who is in the room.
    """
    text = text.strip()
    if not text:
        return
    console.print(
        Panel(
            Markdown(text),
            title=f"[brand]{speaker}[/]",
            title_align="left",
            border_style=IDIRA_BLUE,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def task(text: str) -> None:
    console.print(Text("› ", style="brand") + Text(text, style="default"))
    console.print()


def tool(name: str, tool_input: dict) -> None:
    """One dim line per tool call, printed as it happens.

    Inline and immediate on purpose: grouping calls into a block means holding
    output back until the turn ends, which on a projector looks like the demo
    has frozen.

    Forced onto ONE line. A long regex has no spaces to break on, so the default
    wrap would push the whole argument to the next row and leave the icon
    stranded on its own -- ellipsis truncation keeps the tool name visible, which
    is the part that matters at a glance.
    """
    console.print(
        Text(f"  ⚙ {name}({fmt_args(tool_input)})", style="tool"),
        no_wrap=True,
        overflow="ellipsis",
    )


def tool_result(text: str, limit: int = 300) -> None:
    """Show what a tool returned, truncated.

    Every lesson from 04 shows these, because a tool result is the one thing in
    the transcript the room needs to see arriving: it is untrusted text being
    spliced into the model's context, and it is why a rule is only ever a request.

    Padding rather than a literal two-space prefix, so a wrapped refusal stays
    indented instead of starting the second line hard against the margin.
    """
    flat = " ".join(text.split())
    if len(flat) > limit:
        flat = flat[:limit] + " …"
    style = "danger" if "refused" in text.lower() else "meta"
    console.print(Padding(Text(f"↳ {flat}", style=style), (0, 0, 0, 2)))


def approve(name: str, tool_input: dict, reason: str, auto: bool | None = None) -> bool:
    """Ask a human to sign off on one tool call. Returns True to allow.

    `auto` short-circuits for unattended runs: True = --yes, False = --no,
    None = actually ask. Note this function decides NOTHING about danger; the
    caller passes in a reason that `tools.py` produced.
    """
    console.print(
        Panel(
            Text(f"{name}({fmt_args(tool_input)})\n\n", style="default")
            + Text(reason, style="warn"),
            title="[warn]approval required[/]",
            title_align="left",
            border_style=WARN,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )
    if auto is not None:
        console.print(
            Text(
                f"  {'allowed' if auto else 'denied'} automatically (--{'yes' if auto else 'no'})",
                style="warn",
            )
        )
        return auto
    try:
        answer = console.input("  [warn]allow this call?[/] [meta](y/N)[/] ")
    except (EOFError, KeyboardInterrupt):
        console.print()
        return False
    return answer.strip().lower() in {"y", "yes"}


def compacted(folded: int, chars: int) -> None:
    console.print(
        Text(f"  ⤿ compacted {folded} messages into a {chars}-char note", style="warn")
    )


# --- The footer: the numbers, after every single call ------------------------
#
# Printed after each exchange rather than pinned to the bottom of the terminal.
# A truly sticky footer needs rich's Live display and the alternate screen, which
# would stop the transcript scrolling -- and the transcript is the thing people
# screenshot and scroll back through. Repeating four lines per turn is the
# cheaper honest answer: the numbers are always on screen because they are
# always printed.

# Where the gauge changes colour. Not a published threshold -- a teaching device,
# and the pages say so. The point of the band is that answer quality falls off
# inside a filling window with nothing in the output to announce it.
DUMB_ZONE = 50  # percent
CRITICAL = 80  # percent


def gauge(percent: float, width: int = 24) -> Text:
    """The context gauge: a bar, a percentage, and a dumb-zone marker.

    A percentage rather than a token count, because "4,812" means nothing to
    anybody and "59%" means something to everybody. The bar earns its space at
    the back of a room where the digits are unreadable.
    """
    filled = max(0, min(width, int(round(width * percent / 100.0))))
    style = "ok"
    if percent >= CRITICAL:
        style = "danger"
    elif percent >= DUMB_ZONE:
        style = "warn"

    bar = Text()
    bar.append("█" * filled, style=style)
    bar.append("░" * (width - filled), style="meta")
    bar.append(f"  {percent:5.1f}% of the window", style=style)
    if percent >= CRITICAL:
        bar.append("  ← out of room", style="danger")
    elif percent >= DUMB_ZONE:
        bar.append("  ← dumb zone", style="warn")
    return bar


def footer(
    tier,
    model_id,
    caps,
    stop_reason,
    input_tokens,
    output_tokens,
    percent,
    turns,
    messages,
    remember,
    prepended=False,
    style=None,
) -> None:
    """Everything that happened on that call, in four lines.

    Deliberately includes `remember`: an attendee looking at a small, flat token
    count needs to see WHY it is flat, and "history: not re-sent" is the reason.
    """
    console.print()
    console.print(
        Text(f"  {tier}  ·  {model_id}", style="meta")
    )
    console.print(
        Text(
            f"  stop_reason={stop_reason}  in={input_tokens:,}  out={output_tokens:,}"
            f"  turn={turns}",
            style="meta",
        )
    )
    console.print(Text("  ", style="meta") + gauge(percent))

    # Short labels, because this line has to survive an 80-column terminal
    # without wrapping into an unindented second row on a projector.
    extras = [f"history: {messages} re-sent" if remember else "history: dropped"]
    if style:
        extras.append(f"style: {style}")
    if prepended:
        extras.append("system: prepended")
    console.print(Text("  " + "  ·  ".join(extras), style="meta"))
    console.print()


def wall(window: int, spent: int) -> None:
    """The context window, reached. In lesson 03 this is the point, not a bug."""
    console.print()
    console.print(
        Panel(
            Text(
                f"The request did not fit. This model holds {window:,} tokens and the "
                "conversation is now bigger than that.\n\n"
                "Nothing degraded gracefully: it worked, and then it did not. Two ways "
                "out, and they are the whole of context engineering —\n"
                "  • /compact  fold what is already here into a note\n"
                "  • /reset    start again, and size the next job to fit\n\n"
                "A bigger model buys you room. It does not change the shape of this "
                "problem, and Claude Code hits the same wall on a long enough task.",
                style="default",
            ),
            title="[danger]context window exceeded[/]",
            title_align="left",
            border_style=DANGER,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def note(text: str) -> None:
    """A one-line aside from the harness itself, not from the model."""
    console.print(Text(f"  · {text}", style="warn"))


def model_switched(tier: str, model_id: str, caps) -> None:
    console.print()
    console.print(
        Panel(
            Text(f"{model_id}\n{_caps_text(caps)}", style="default"),
            title=f"[brand]switched to the {tier} model[/]",
            title_align="left",
            border_style=IDIRA_BLUE,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def refused(title: str, detail: str, footnote: str) -> None:
    """Something the harness could not do, drawn as a panel rather than a traceback.

    Both callers are moments where a failure IS the teaching: an old model that
    cannot use tools, and a network that will not reach an unauthenticated MCP
    server. A stack trace reads as a broken demo; a panel reads as a finding.
    """
    console.print()
    console.print(
        Panel(
            Text(f"{detail}\n\n", style="default") + Text(footnote, style="warn"),
            title=f"[danger]{title}[/]",
            title_align="left",
            border_style=DANGER,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def capability_refused(what: str, detail: str) -> None:
    """Lesson 04's opening beat: the old model, asked to do something it cannot."""
    refused(
        f"the legacy model cannot {what}",
        detail,
        "No prompt, no retry and no amount of budget changes this. A capability "
        "is not a setting.",
    )


def unreachable(target: str, detail: str) -> None:
    """Lesson 05's MCP server, blocked. Expected, and worth saying why."""
    refused(
        f"could not reach {target}",
        detail,
        "An unauthenticated MCP server on the public internet, feeding tool "
        "schemas and tool output into an agent that can read your source, is "
        "what egress filtering exists for. This block is the lesson working.",
    )


def style_switched(name: str, text: str) -> None:
    console.print()
    console.print(
        Panel(
            Markdown(text),
            title=f"[brand]output style: {name}  ({len(text)} chars of instructions)[/]",
            title_align="left",
            border_style=IDIRA_BLUE,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def harness_summary(
    rules_file,
    skills,
    mcp,
    lsp,
    hooks,
    subagents,
    memory,
    total_tools,
) -> None:
    """Lesson 05's opening slide, drawn from what is actually wired up.

    Generated rather than written: a hand-typed list of components would go stale
    the first time somebody added a skill, and this page is the one an attendee
    photographs.
    """
    rows = [
        ("1 rules", rules_file, "context · request"),
        ("2 skills", ", ".join(skills) or "none found", "context · on demand"),
        ("3 style", "styles/*.md  (/style)", "context · request"),
        ("4 MCP", mcp, "tools · third party"),
        ("5 LSP", ", ".join(lsp), "tools · cheap reads"),
        ("6 subagents", subagents, "tools · new window"),
        ("7 hooks", ", ".join(hooks), "THE LOOP · CONTROL"),
        ("+ memory", memory, "context · persists"),
    ]
    # Fixed columns, truncated rather than wrapped: this panel has to survive an
    # 80-column terminal, and a wrapped table is unreadable on a projector.
    body = Text()
    for label, what, kind in rows:
        style = "warn" if "LOOP" in kind else "default"
        if len(what) > 33:
            what = what[:32] + "…"
        body.append(f"{label:<13}", style="brand")
        body.append(f"{what:<34}", style="default")
        body.append(f"{kind}\n", style=style)
    body.append(
        f"\n{total_tools} tools in the toolbox, every schema sent on every turn.",
        style="meta",
    )
    console.print()
    console.print(
        Panel(
            body,
            title="[brand]the harness — seven parts, one loop[/]",
            title_align="left",
            border_style=IDIRA_BLUE,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def system_view(system_prompt, style_text, has_system_role: bool) -> None:
    """Show exactly what instructions the model is being sent, and how.

    The `has_system_role` line is the one worth reading twice. On a model with no
    system role there is no boundary between our instructions and the user's
    words -- they are one string. Everything a tool returns later joins the same
    string. That is prompt injection, visible before it is explained.
    """
    body = Text()
    if not (system_prompt or style_text):
        body.append("Nothing. This lesson sends no instructions at all.", style="default")
    else:
        if has_system_role:
            body.append(
                "Sent in the API's `system` field. That keeps it out of the "
                "transcript, and it does NOT make it a boundary — the model reads "
                "one flat stream either way.\n\n",
                style="meta",
            )
        else:
            body.append(
                "This model has NO system role, so the harness prepends all of "
                "this into your first message. Instructions and data, one string, "
                "no boundary.\n\n",
                style="warn",
            )
        body.append((system_prompt or "") + "\n", style="default")
        if style_text:
            body.append("\n" + style_text, style="default")
    console.print()
    console.print(
        Panel(
            body,
            title="[brand]the instructions[/]",
            title_align="left",
            border_style=IDIRA_BLUE,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def context_view(session) -> None:
    """Everything currently in the context, itemised. `/context`."""
    instructions = session.instructions()
    body = Text()
    body.append(f"instructions   {len(instructions):>6} chars\n", style="default")
    body.append(f"messages       {len(session.messages):>6} in the transcript\n", style="default")
    body.append(
        f"re-sent        {'yes' if session.remember else 'no — every message starts from nothing'}\n",
        style="default",
    )
    body.append(f"last request   {session.used():>6,} tokens\n", style="default")
    body.append(f"window         {session.caps.window:>6,} tokens\n", style="default")
    body.append(f"compactions    {session.compactions:>6}\n", style="default")
    body.append(
        f"\nbilled so far  in={session.total_input:,}  out={session.total_output:,}",
        style="meta",
    )
    console.print()
    console.print(
        Panel(
            body,
            title="[brand]what the model is holding[/]",
            title_align="left",
            border_style=IDIRA_BLUE,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )
    console.print(Text("  ", style="meta") + gauge(session.percent()))


def chat_intro(help_text: str) -> None:
    console.print()
    console.print(
        Panel(
            Text(help_text, style="default"),
            title="[brand]your turn — type a message, or a command[/]",
            title_align="left",
            border_style=IDIRA_BLUE,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def ask() -> str:
    """The chatbox prompt. Raises EOFError on Ctrl-D, which the caller handles."""
    return console.input("[brand]you ›[/] ")


def final(text: str) -> None:
    if not text.strip():
        return
    console.print()
    console.print(
        Panel(
            Markdown(text.strip()),
            title="[brand]findings[/]",
            title_align="left",
            border_style=IDIRA_BLUE,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def control_probe(rows: list) -> None:
    """Lesson 05's guarantee: every control, exercised with no model involved.

    This panel exists because a model's cooperation is non-deterministic and the
    claim it is supposed to prove is not. Each row is a call made directly from
    the lesson script -- no model asked for it, no prompt could have talked us out
    of it -- and the refusal beside it is the real return value.

    Two columns per row rather than a paragraph, because the whole argument is the
    correspondence between what was attempted and what came back.
    """
    body = Text()
    body.append(
        "Called straight from 05_harness.py. No model, no prompt, no luck:\n\n",
        style="meta",
    )
    # Every row is prefixed with 13 characters, and the panel's inner width on an
    # 80-column terminal is about 74. Truncate to 58 so a long refusal cannot wrap
    # into an unindented second line and break the two-column correspondence that
    # is the entire point of the panel.
    for attempt, control, result in rows:
        body.append(f"  attempted  {_clip(attempt)}\n", style="default")
        body.append(f"  refused by {_clip(control)}\n", style="brand")
        body.append(f"  returned   {_clip(result)}\n\n", style="danger")
    body.append(
        "Three controls, none of them written in English, none of them arguable. "
        "That is the only part of this lesson that works every single time.",
        style="default",
    )
    console.print()
    console.print(
        Panel(
            body,
            title="[brand]the controls, proven without the model[/]",
            title_align="left",
            border_style=IDIRA_BLUE,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def thinking(label: str = "thinking"):
    """A spinner for the blocking model call.

    We do NOT stream. Real streaming would mean implementing `stream()` in both
    gemini_provider and llama_provider -- and a fake typewriter effect costs real
    seconds of stage time on every turn, which reads as the demo hanging.
    """
    return console.status(f"[brand]{label}…[/]", spinner="dots")


def _clip(text: str, limit: int = 58) -> str:
    """One line, never wrapped. For tables whose columns have to stay aligned."""
    flat = " ".join(str(text).split())
    return flat if len(flat) <= limit else flat[: limit - 1] + "…"


def fmt_args(tool_input: dict) -> str:
    return ", ".join(f"{k}={v!r}" for k, v in (tool_input or {}).items())


def parse_auto(argv: list) -> tuple[bool | None, list]:
    """Pull --yes/--no out of argv. Returns (auto, remaining_args).

    --no is worth its three lines: it guarantees the room sees the approval gate
    refuse a call, which the model's own behaviour cannot promise.
    """
    auto: bool | None = None
    rest = []
    for arg in argv:
        if arg in {"--yes", "-y"}:
            auto = True
        elif arg in {"--no", "-n"}:
            auto = False
        else:
            rest.append(arg)
    return auto, rest
