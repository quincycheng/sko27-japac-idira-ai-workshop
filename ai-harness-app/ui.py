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

import os
import sys

from rich.columns import Columns
from rich.console import Console
from rich.markdown import Markdown
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


def banner(stage: str, provider: str = "", model: str = "") -> None:
    """Print the Idira mark, the event, the stage, and which model we're on.

    Printed ONCE per run, at the top. Reprinting it mid-transcript is noise on a
    screen share. This replaces the old bare `[config] provider=... model=...`
    line -- same information, in the one place people look for it.
    """
    wordmark = Text()
    wordmark.append("\nIDIRA", style="brand")
    wordmark.append(" ®", style="meta")
    # grey62 rather than the ®'s grey42: an attribution nobody can read at the
    # back of the room is not an attribution.
    wordmark.append("  by Palo Alto Networks\n", style="subtitle")
    wordmark.append(EVENT + "\n", style="subtitle")
    wordmark.append(stage + "\n", style="brand")
    if provider or model:
        wordmark.append(f"{provider}  ·  {model}", style="meta")

    console.print()
    if _fancy_glyphs():
        mark = Text("\n".join(_MARK), style="mark")
        # Mark to the left of the wordmark, as in the SVG lockup.
        console.print(Columns([mark, wordmark], padding=(0, 2)))
    else:
        console.print(wordmark)
    console.print()


def model(text: str) -> None:
    """The model's voice: a panel, Markdown-rendered.

    Claude emits Markdown unprompted -- numbered findings, `file:line` in
    backticks, bold severities. Rendering it is what makes this read like a
    product instead of a log.
    """
    text = text.strip()
    if not text:
        return
    console.print(
        Panel(
            Markdown(text),
            title="[brand]Claude[/]",
            title_align="left",
            border_style=IDIRA_BLUE,
            width=PANEL_WIDTH,
            padding=(0, 1),
        )
    )


def plain(text: str) -> None:
    """Unpanelled model output, for Lessons 01-2.

    The early stages look austere because they ARE austere: no loop, no toolbox.
    The UI getting richer as the harness gets richer is part of the argument.
    """
    console.print(text.strip(), style="default")


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
    """Show what a tool returned. Only Lesson 05 calls this -- seeing the refusal
    text IS that stage's payoff, and showing results everywhere spends the
    surprise early."""
    flat = " ".join(text.split())
    if len(flat) > limit:
        flat = flat[:limit] + " …"
    style = "danger" if ("Refused" in text or "refused" in text) else "meta"
    console.print(Text(f"  ↳ {flat}", style=style))


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


def context(step: int, input_tokens: int, messages: int) -> None:
    """Lesson 04's live accounting line -- the number that kills a naive agent."""
    console.print(
        Text(f"  ctx  step {step:>2}  input_tokens={input_tokens}  messages={messages}", style="meta")
    )


def compacted(folded: int, chars: int) -> None:
    console.print(
        Text(f"  ⤿ compacted {folded} messages into a {chars}-char note", style="warn")
    )


def usage(stop_reason: str, input_tokens: int, output_tokens: int) -> None:
    """Lesson 01's footer: the raw material for context management later."""
    console.print()
    console.print(
        Text(
            f"stop_reason={stop_reason}  input_tokens={input_tokens}  output_tokens={output_tokens}",
            style="meta",
        )
    )


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


def postmortem(fired: list) -> None:
    """Lesson 05's closing argument."""
    console.print()
    if fired:
        body = Text("A file the agent read tried to hijack it. These controls refused it:\n", style="default")
        for label in fired:
            body.append(f"  • {label}\n", style="danger")
        body.append(
            "\nThe model was influenced by untrusted input; the HARNESS bounded the "
            "blast radius. That is the defense -- least privilege, not a better prompt.",
            style="default",
        )
    else:
        body = Text(
            "No control was triggered this run. The model spotted the injected block\n"
            "and declined it on its own -- so no malicious call ever reached the\n"
            "harness for a control to refuse.\n\n"
            "That is a good outcome, not a failed demo, but do NOT let the room take it\n"
            "as the lesson. It is the model choosing well, and next run it may choose\n"
            "differently. Run it again to see behavior vary. Safety cannot depend on the\n"
            "model resisting; it must live in what the tools are allowed to do.",
            style="default",
        )
    console.print(
        Panel(
            body,
            title="[danger]post-mortem — what actually happened[/]",
            title_align="left",
            border_style=DANGER,
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


def fmt_args(tool_input: dict) -> str:
    return ", ".join(f"{k}={v!r}" for k, v in (tool_input or {}).items())


def parse_auto(argv: list) -> tuple[bool | None, list]:
    """Pull --yes/--no out of argv. Returns (auto, remaining_args).

    --no is worth its three lines: it guarantees the room sees the controls fire
    at least once, which Lesson 05 cannot promise on its own.
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
