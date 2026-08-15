#!/usr/bin/env python3
"""Put the real Python source into the lab pages, with clickable annotations.

WHY THIS EXISTS
The lab guide used to quote fragments of each lesson script by hand. Fragments
rot: somebody improves 03_context.py, nobody re-reads five HTML files, and by the
next session the guide is teaching code that is not in the repo. An audience of
Domain Consultants notices, and once they have caught the guide out once they stop
trusting the rest of it.

So the pages no longer contain code. They contain a one-line marker:

    <!-- annotated-source: 03_context.py -->

and this script fills in everything after it, from the file itself. The source in
the guide is the source on disk, by construction.

THREE MORE BLOCKS, ON THE SAME TERMS
The same argument applies to anything else a page CLAIMS. Three more markers:

    <!-- scorecard: 01 -->   "What you have built so far" — the fourteen-item
                             capability scoreboard, derived from the
                             `session.Session(...)` arguments in the lesson script
                             and the capability records in config.py. A page can no
                             longer say "tools: yes" for a lesson that never
                             enabled them.

    <!-- idira: 01 -->       "Where Idira fits" — the risk, the product and the
                             sentence to say to a customer, from
                             lab/idira-thread.md. One file rather than the same
                             mapping hand-copied into six lessons and the
                             reference page, because product names drift faster
                             than code does.

    <!-- terminal: 04-transcript -->
                             the app's own output. Not a mock: the real ui.py
                             prints the banner, the panel, the footer, the tool
                             transcript, the approval question and the refusals
                             into a recording console, and the result is exported
                             with the real colours, the real Idira mark and the
                             real capability line. It is the first thing an
                             attendee compares against their screen, so it cannot
                             be typed.

                             Markers are NAMED rather than numbered, because a
                             lesson has more than one screen worth showing — see
                             TERMINALS for the whole list, and run_script for what
                             a name can be made of. Two of them do not draw
                             anything, they CALL something: 05-probe runs the real
                             prove_the_controls(), 05-refusal runs the real policy
                             hook and fails the build if it ever stops refusing.

                             Every `› ` line in one comes out wrapped in a
                             .term-prompt carrying the bare prompt in data-copy,
                             which is what lab.js hangs a per-prompt ⧉ button off.
                             One button, one prompt, one message — the Python
                             chatbox reads with console.input(), so a pasted
                             newline is a SENT message.

ANNOTATIONS
The interesting lines need explaining, and an explanation is not something you can
derive from the code. Those live in lab/annotations/<page>.md, and each one is
anchored to a piece of the source TEXT rather than to a line number:

    ## 03_context.py :: chat = session.Session(
    ### Every argument here is a lesson
    until: max_tokens=400,
    Body prose. Plain paragraphs, `inline code`, and **bold**.

An anchor that no longer matches exactly one line is a hard error, not a warning.
That is the whole point of the design: the day somebody renames a variable, the
build fails and tells them which explanation needs re-reading. A generator that
silently dropped the annotation would be worse than the hand-written pages it
replaced, because it would look maintained.

Annotations describe BLOCKS, not lines. `until:` is on almost every one of them,
because a single highlighted line in the middle of a function is a riddle: the
reader has to reconstruct the surrounding statement before the note makes sense.
Highlighting the whole construct and explaining the whole construct is what an
IDE's own "explain this" would do, and it reads correctly on a projector.

Blocks are numbered by where they land in the file, not by the order they appear in
the .md, so the badges in the gutter always count downwards and the notes underneath
read in the same direction as the code. Write the annotations in whatever order
suits you.

HIGHLIGHTING
Python source is coloured at build time by the standard library's `tokenize`
module, into `tok-*` spans that lab.css paints with the VS Code Dark+ palette.
There is no CDN and no highlighter script, because the guide has to run from
`file://` on a laptop with no network. Line numbers stay a CSS counter and the
token spans carry no text of their own, so the copy button still yields Python
you can paste into a terminal.

USAGE
    .venv/bin/python build-lab-code.py            # write the blocks into lab/*.html
    .venv/bin/python build-lab-code.py --check    # fail if a page is out of date
    .venv/bin/python build-lab-code.py --diff     # show what would change, write nothing

Run it with the workshop's own interpreter, not the system one. Everything except
the terminal blocks is standard library, but a `terminal:` marker imports the app --
ui.py, config.py, session.py and rich -- to print the block. No credentials and no
network are needed for that; it never calls a model.

--check is the gate that matters. Run it before a session; if it passes, no page
in the guide is quoting code that no longer exists.
"""

from __future__ import annotations

import argparse
import ast
import builtins
import copy
import html
import io
import keyword
import os
import re
import sys
import tokenize
from pathlib import Path

HERE = Path(__file__).resolve().parent
LAB = HERE / "lab"
APP = HERE / "ai-harness-app"
ANNOTATIONS = LAB / "annotations"
IDIRA_FILE = LAB / "idira-thread.md"
PAGES_FILE = LAB / "assets" / "lab.js"

MARKER = re.compile(r"<!--\s*annotated-source:\s*([A-Za-z0-9_.\-/]+)\s*-->")

# Three more generated blocks, on the same terms as the source listings: a marker
# in the page, the content derived from something that is not the page.
#
#   <!-- scorecard: 01 -->   "What you have built so far", from the lesson scripts
#   <!-- idira: 01 -->       "Where Idira fits", from lab/idira-thread.md
#   <!-- terminal: NAME -->  the app's own output, printed by the real ui.py
#   <!-- idira-table -->     the product mapping table, from the same thread file
SCORECARD_MARKER = re.compile(r"<!--\s*scorecard:\s*(\d\d)\s*-->")
IDIRA_MARKER = re.compile(r"<!--\s*idira:\s*(\d\d)\s*-->")
# Named, not numbered: a lesson has more than one panel worth showing, and
# "04-transcript" says which one where "04" could not.
TERMINAL_MARKER = re.compile(r"<!--\s*terminal:\s*([\w.-]+)\s*-->")
IDIRA_TABLE_MARKER = re.compile(r"<!--\s*idira-table\s*-->")
ALL_MARKERS = (
    MARKER,
    SCORECARD_MARKER,
    IDIRA_MARKER,
    TERMINAL_MARKER,
    IDIRA_TABLE_MARKER,
)

# At or under this many lines, a file is shown whole with no inner scrollbar.
WHOLE_FILE_LINES = 160
BEGIN = "<!-- BEGIN GENERATED: {name} — build-lab-code.py owns this block -->"
END = "<!-- END GENERATED: {name} -->"

# Files this tool is allowed to inline. An allowlist rather than "anything under
# ai-harness-app", so a typo in a marker fails loudly instead of quietly shipping
# the wrong file (or a credential file) into a page the whole room reads.
ALLOWED = {
    "01_bare_call.py",
    "02_conversation.py",
    "03_context.py",
    "04_tools_and_agents.py",
    "05_harness.py",
    "agent.py",
    "session.py",
    "tools.py",
    "harness.py",
    "config.py",
    "mcp_client.py",
    "converse_provider.py",
    "prompts/docs-agent.md",
    "prompts/system.md",
}


class BuildError(Exception):
    """Something is out of sync. Always names the file and the anchor."""


# --- annotations -------------------------------------------------------------


class Annotation:
    def __init__(self, source: str, anchor: str, title: str):
        self.source = source  # which file it belongs to
        self.anchor = anchor  # substring identifying the first line
        self.until = ""  # optional substring identifying the last line
        self.title = title
        self.body: list[str] = []

    @property
    def html_body(self) -> str:
        # Spans, not <p>s, because the note is rendered INSIDE the <pre> (see
        # render_source) and <pre> takes phrasing content only. lab.css lays them
        # out as blocks.
        return "".join(
            f'<span class="src-note-p">{inline(p)}</span>'
            for p in self.body
            if p.strip()
        )


def parse_annotations(path: Path) -> list[Annotation]:
    """Read one annotations file. Deliberately tiny: four line shapes, no library.

    ## <file> :: <anchor text>      starts an annotation
    ### <title>                     its heading
    until: <text>                   optional, extends the highlight to that line
    anything else                   body prose, blank-line separated

    HTML comments are stripped first, so the file can explain itself to whoever
    edits it next without that text ending up on the page.
    """
    text = path.read_text()
    while "<!--" in text and "-->" in text:
        head, rest = text.split("<!--", 1)
        text = head + rest.split("-->", 1)[1]

    out: list[Annotation] = []
    current: Annotation | None = None
    paragraph: list[str] = []

    def flush() -> None:
        if current is not None and paragraph:
            current.body.append(" ".join(paragraph))
        paragraph.clear()

    for raw in text.splitlines():
        line = raw.rstrip()
        if line.startswith("## "):
            flush()
            spec = line[3:].strip()
            if "::" not in spec:
                raise BuildError(
                    f"{path.name}: '## {spec}' needs the form "
                    "'## <file.py> :: <anchor text>'"
                )
            source, anchor = (part.strip() for part in spec.split("::", 1))
            current = Annotation(source, anchor, title="")
            out.append(current)
        elif line.startswith("### "):
            flush()
            if current is None:
                raise BuildError(f"{path.name}: '{line}' before any '## file :: anchor'")
            current.title = line[4:].strip()
        elif line.lower().startswith("until:"):
            flush()
            if current is None:
                raise BuildError(f"{path.name}: '{line}' before any '## file :: anchor'")
            current.until = line.split(":", 1)[1].strip()
        elif not line.strip():
            flush()
        else:
            paragraph.append(line.strip())
    flush()

    for ann in out:
        if not ann.title:
            raise BuildError(
                f"{path.name}: the annotation for '{ann.anchor}' has no '### title'"
            )
        if not ann.body:
            raise BuildError(
                f"{path.name}: the annotation '{ann.title}' has no body text. "
                "A highlight with nothing to say should not be a highlight."
            )
    return out


def inline(text: str) -> str:
    """Escape, then re-allow `code` and **bold**. No markdown library, no CDN."""
    out = html.escape(text)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    return out


# --- syntax highlighting -----------------------------------------------------
#
# The lab used to show this code in one flat colour, and it read like a wall. An
# audience that spends its working life in an IDE reads code faster when `def`,
# a string and a comment are three different colours, and does not have to be
# told which is which.
#
# Done here, at build time, with `tokenize` from the standard library. The two
# obvious alternatives were both worse: a highlighter loaded from a CDN cannot
# work at all (the guide runs from file:// with no network), and a hand-written
# regex highlighter gets triple-quoted strings and f-strings wrong in exactly
# the files where the docstring IS the lesson.

# Keywords Dark+ paints blue rather than purple, plus the two names that behave
# like keywords in every method in this repo.
_KW_BLUE = frozenset({
    "def", "class", "lambda", "global", "nonlocal", "True", "False", "None",
    "self", "cls",
})

# Builtins that name a type, so they take the teal that other class names take.
# `str` and `Exception` should not be two different colours.
_TYPE_BUILTINS = frozenset({
    "bool", "bytearray", "bytes", "complex", "dict", "float", "frozenset",
    "int", "list", "object", "set", "str", "tuple", "type",
})

_BUILTIN_NAMES = frozenset(dir(builtins))

# f-strings tokenise into their own token types from 3.12 on. Ask rather than
# assume, so the build still runs on an older interpreter.
_STRING_TOKENS = frozenset(
    {tokenize.STRING}
    | {
        kind
        for kind in (
            getattr(tokenize, name, None)
            for name in ("FSTRING_START", "FSTRING_MIDDLE", "FSTRING_END")
        )
        if kind is not None
    }
)

_SKIP_TOKENS = frozenset({
    tokenize.NEWLINE, tokenize.NL, tokenize.INDENT, tokenize.DEDENT,
    tokenize.ENDMARKER, tokenize.ENCODING,
})


def syntax_spans(text: str) -> dict[int, list[tuple[int, int, str]]]:
    """Column ranges to colour, keyed by 0-based line. Raises on unlexable text.

    Columns rather than token strings, because the two are not always the same:
    an f-string's FSTRING_MIDDLE reports `{` where the source says `{{`. Slicing
    the real line is the only version that cannot corrupt what is on the page.
    """
    src = text if text.endswith("\n") else text + "\n"
    lines = src.splitlines()
    toks = [
        t
        for t in tokenize.generate_tokens(io.StringIO(src).readline)
        if t.type not in _SKIP_TOKENS
    ]

    # Rows whose first token is `@`, i.e. decorator lines. Cheaper and more
    # honest than trying to infer a decorator from the tokens around a name.
    first_on_row: dict[int, tokenize.TokenInfo] = {}
    for tok in toks:
        first_on_row.setdefault(tok.start[0], tok)
    decorated = {
        row
        for row, tok in first_on_row.items()
        if tok.type == tokenize.OP and tok.string == "@"
    }

    spans: dict[int, list[tuple[int, int, str]]] = {}

    def add(row: int, start: int, end: int, kind: str) -> None:
        if end > start:
            spans.setdefault(row, []).append((start, end, kind))

    def neighbour(i: int, step: int) -> tokenize.TokenInfo | None:
        j = i + step
        while 0 <= j < len(toks) and toks[j].type == tokenize.COMMENT:
            j += step
        return toks[j] if 0 <= j < len(toks) else None

    for i, tok in enumerate(toks):
        kind = classify(tok, i, toks, neighbour, decorated)
        if kind is None:
            continue
        (srow, scol), (erow, ecol) = tok.start, tok.end
        if srow == erow:
            add(srow - 1, scol, ecol, kind)
            continue
        # A docstring or a triple-quoted block: colour it line by line, or the
        # spans would not line up with the <span class="l"> per source line.
        add(srow - 1, scol, len(lines[srow - 1]), kind)
        for row in range(srow + 1, erow):
            add(row - 1, 0, len(lines[row - 1]), kind)
        add(erow - 1, 0, ecol, kind)

    return spans


def classify(tok, i, toks, neighbour, decorated) -> str | None:
    """One token -> one `tok-*` suffix, or None to leave it the default colour.

    Deliberately short of what a language server knows. It gets a name wrong
    now and then — a local called `Session` would be painted like a class — and
    that is an acceptable trade for a highlighter with no dependencies and no
    ability to change what the code says.
    """
    if tok.type == tokenize.COMMENT:
        return "com"
    if tok.type in _STRING_TOKENS:
        return "str"
    if tok.type == tokenize.NUMBER:
        return "num"
    if tok.type == tokenize.OP:
        # Operators and punctuation stay the default ink, as they do in Dark+.
        # The `@` of a decorator is the exception, because it belongs to the name.
        return "dec" if tok.string == "@" and tok.start[0] in decorated else None
    if tok.type != tokenize.NAME:
        return None

    name = tok.string
    if keyword.iskeyword(name):
        return "kwd" if name in _KW_BLUE else "kw"
    if tok.start[0] in decorated:
        return "dec"

    before = neighbour(i, -1)
    if before is not None and before.type == tokenize.NAME:
        if before.string == "def":
            return "fn"
        if before.string == "class":
            return "cls"
    if name in _KW_BLUE:  # self, cls
        return "kwd"
    if name in _BUILTIN_NAMES:
        return "cls" if name[:1].isupper() or name in _TYPE_BUILTINS else "fn"

    # CamelCase reads as a type to everyone in the room, and it is checked before
    # the call test so `session.Session(...)` is a class being constructed rather
    # than a function being called. ALL_CAPS deliberately gets no colour of its
    # own: this repo's constants are the things lessons ask you to edit, and they
    # are easier to find in one colour than in a fourth one.
    if name[:1].isupper() and not name.isupper():
        return "cls"

    after = neighbour(i, 1)
    if (
        after is not None
        and after.type == tokenize.OP
        and after.string == "("
        and after.start == tok.end
    ):
        return "fn"
    return None


def highlight_line(line: str, spans: list[tuple[int, int, str]]) -> str:
    """One source line as HTML. Escaped first, always; spans never overlap."""
    if not spans:
        return html.escape(line)

    # Merge touching spans of the same colour first. An f-string arrives as three
    # or four string tokens with the expressions between them, and one <span> per
    # token would triple the size of every page for no visible difference.
    merged: list[list] = []
    for start, end, kind in sorted(spans):
        if merged and merged[-1][2] == kind and start <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], end)
        else:
            merged.append([start, end, kind])

    out: list[str] = []
    cursor = 0
    for start, end, kind in merged:
        start = max(start, cursor)
        if end <= start:
            continue
        if start > cursor:
            out.append(html.escape(line[cursor:start]))
        out.append(f'<span class="tok-{kind}">{html.escape(line[start:end])}</span>')
        cursor = end
    if cursor < len(line):
        out.append(html.escape(line[cursor:]))
    return "".join(out)


# --- locating an anchor in the source ---------------------------------------


def find_range(lines: list[str], ann: Annotation, source: str) -> tuple[int, int]:
    """Which lines this annotation highlights. Raises unless the anchor is unique.

    Uniqueness is the contract. A substring that matches two lines cannot be
    resolved without guessing, and a generator that guesses which line an
    explanation belongs to will eventually attach it to the wrong one on a page
    sixty people are reading.
    """
    hits = [i for i, line in enumerate(lines) if ann.anchor in line]
    if not hits:
        raise BuildError(
            f"{source}: no line contains {ann.anchor!r}\n"
            f"    (annotation: {ann.title!r})\n"
            "    The code moved. Re-read the annotation and update its anchor."
        )
    if len(hits) > 1:
        rows = ", ".join(str(h + 1) for h in hits)
        raise BuildError(
            f"{source}: {ann.anchor!r} matches {len(hits)} lines ({rows})\n"
            f"    (annotation: {ann.title!r})\n"
            "    Lengthen the anchor until it matches exactly one."
        )
    start = hits[0]

    if not ann.until:
        return start, start
    tail = [i for i, line in enumerate(lines) if i >= start and ann.until in line]
    if not tail:
        raise BuildError(
            f"{source}: no line at or after {start + 1} contains {ann.until!r}\n"
            f"    (annotation: {ann.title!r}, 'until:' clause)"
        )
    return start, tail[0]


# --- rendering ---------------------------------------------------------------


def render(source: str, annotations: list[Annotation]) -> str:
    """One source file plus its annotations, as the HTML block for a lab page."""
    path = APP / source
    if not path.is_file():
        raise BuildError(f"marker names {source}, which does not exist under {APP}")

    raw = path.read_text()
    lines = raw.splitlines()
    mine = [a for a in annotations if a.source == source]

    # Colour, if this is Python. A file that will not tokenise still gets shown —
    # plainly, and with a warning, because a broken page is worse than a beige one.
    spans: dict[int, list[tuple[int, int, str]]] = {}
    if source.endswith(".py"):
        try:
            spans = syntax_spans(raw)
        except Exception as error:  # tokenize is lenient; this means real damage
            print(
                f"warning: {source} would not tokenise ({error}); "
                "showing it without syntax colours",
                file=sys.stderr,
            )

    # Numbered by where they land in the file, not by the order they were written
    # in, so the badges in the gutter always count downwards. Note order follows,
    # because a reader working through the notes should be walking down the code.
    ranges = sorted(
        ((find_range(lines, a, source), a) for a in mine), key=lambda pair: pair[0]
    )
    mine = [a for _r, a in ranges]

    # line index -> annotation number, resolved before rendering so an overlap is
    # caught here rather than producing two highlights fighting over one line.
    owner: dict[int, int] = {}
    bounds: dict[int, tuple[int, int]] = {}
    for number, ((start, end), ann) in enumerate(ranges, 1):
        bounds[number] = (start, end)
        for i in range(start, end + 1):
            if i in owner:
                raise BuildError(
                    f"{source}: line {i + 1} is claimed by two annotations "
                    f"({mine[owner[i] - 1].title!r} and {ann.title!r})"
                )
            owner[i] = number

    body: list[str] = []
    for i, line in enumerate(lines):
        text = highlight_line(line, spans.get(i, []))
        # A blank line still needs a line number and a box to sit in, but it does
        # not need a full line's worth of height, and it must NOT be padded with
        # `&nbsp;` to get one: U+00A0 is not valid Python outside a string, so a
        # copied listing with one blank line in it fails to parse. The span stays
        # genuinely empty and lab.css gives it its height.
        blank = " blank" if not text else ""
        number = owner.get(i)
        if number is None:
            body.append(f'<span class="l{blank}">{text}</span>')
            continue
        # A region, not a stripe of unrelated lines: the first and last lines are
        # marked so the CSS can close the box, and only the first line is a tab
        # stop. Fifteen identical tab stops for one note is not accessibility.
        ann = mine[number - 1]
        start, end = bounds[number]
        edge = ""
        if i == start:
            edge += " ann-first"
        if i == end:
            edge += " ann-last"
        attrs = f'class="l{blank} ann{edge}" data-ann="{number}"'
        if i == start:
            attrs += (
                f' role="button" tabindex="0" aria-expanded="false"'
                f' aria-label="{html.escape(ann.title)}"'
            )
        body.append(f"<span {attrs}>{text}</span>")
        # The note goes here: in the listing, directly under the last line of the
        # block it explains, collapsed until somebody asks for it. It used to be a
        # rail at the foot of the listing, and on a file of any length that put the
        # explanation off-screen from the only thing it makes sense next to.
        #
        # It lives INSIDE the <pre> so it can sit between two lines of code without
        # splitting the listing into separate scrollers and restarting the line
        # numbers. That is also why every part of it is a <span>: <pre> takes
        # phrasing content only. lab.js builds the copy text from the `.l` spans
        # alone, so none of this prose can reach the clipboard.
        if i == end:
            body.append(
                f'<span class="src-note" data-ann="{number}">'
                f'<span class="src-note-h">'
                f'<span class="src-note-num">{number}</span>{inline(ann.title)}'
                f"</span>{ann.html_body}</span>"
            )

    count = len(mine)
    hint = (
        f"{count} annotated block{'s' if count != 1 else ''} — click one to read why"
        if count
        else "The whole file, unabridged."
    )

    # Short files render whole. An inner scrollbar earns its keep on session.py at
    # 600-odd lines; on a 50-line lesson script it is a box that hides code for no
    # reason. The number is a judgement, not a law: about two screens of a laptop.
    whole = " src-whole" if len(lines) <= WHOLE_FILE_LINES else ""

    return (
        f'<div class="src{whole}" data-file="{html.escape(source)}">\n'
        f'  <div class="src-head">'
        f'<span class="src-file">ai-harness-app/{html.escape(source)}</span>'
        f'<span class="src-hint">{hint}</span></div>\n'
        # Joined with NOTHING, deliberately. Every line is a block-level <span>, so
        # a newline between two of them is preserved by `white-space: pre` and lays
        # out as its own empty line box: the listing renders at double the leading
        # you asked for, and the tint on a multi-line annotation shows a pale gap
        # between each of its rows. lab.js rebuilds the newlines for the copy
        # button from the spans themselves.
        f'  <div class="code"><pre><code>' + "".join(body) + "</code></pre></div>\n"
        f"</div>"
    )


# --- the capability scorecard ------------------------------------------------
#
# "What you have built so far": the same fourteen items on every Part 1 lesson,
# with the one this lesson added badged. The items are fixed from lesson 01 onward
# on purpose — a scoreboard whose rows change is not a scoreboard — so lesson 01
# shows twelve "not yet", which is exactly its lesson.
#
# It is DERIVED, not written. Ten of the fourteen come from the `session.Session(...)`
# arguments in the lesson script itself, and the model's three facts come from the
# capability records in config.py. A guide that hand-claimed "tools: yes" would
# eventually claim it for a lesson that had not enabled them; this cannot.
#
# The five rows that are not constructor arguments — controls in the loop, skills,
# MCP, LSP, subagents — are declared below, keyed by the lesson they first appear in.

LESSON_SCRIPTS = {
    "01": "01_bare_call.py",
    "02": "02_conversation.py",
    "03": "03_context.py",
    "04": "04_tools_and_agents.py",
    "05": "05_harness.py",
}

# Not `Session` arguments, so there is nothing to read them off. The lesson number
# each one first becomes true in, and the file that implements it. The controls
# live in tools.py (_safe_path, the run_command allowlist, the approval gate) and
# in harness.py (the hooks) rather than as a `hooks=` argument, which is why this
# table exists at all. MCP is here for the same reason: 05_harness.py reaches its
# server through mcp_client.connect() and hands the tools to harness.build(), so
# there is no `mcp=` on the Session to read. (There is an `mcp=` in that file, on
# the ui.harness_summary call, which is why this is a table and not a grep.)
DECLARED = {
    "controls": "05",
    "skills": "05",
    "mcp": "05",
    "lsp": "05",
    "subagents": "05",
}

# (group, label, token, key). The token is the vocabulary the terminal already
# uses for the same fact: the banner's own words for the model rows, and for the
# harness rows the argument or the file that implements it, which is deliberately
# the same inventory 05_harness.py prints in its docstring.
SC_MODEL = "The model"
SC_HARNESS = "The harness: you build these"

SC_ROWS = [
    (SC_MODEL, "LLM access", "bedrock", "llm"),
    (SC_MODEL, "Model", None, "model"),
    (SC_MODEL, "Context window", None, "window"),
    (SC_MODEL, "Tool support", None, "model_tools"),
    (SC_HARNESS, "Conversation history", "remember=", "remember"),
    (SC_HARNESS, "Rules", "prompts/system.md", "rules"),
    (SC_HARNESS, "Output style", "styles/*.md", "style"),
    (SC_HARNESS, "Tools and the loop", "agent.py", "tools"),
    (SC_HARNESS, "Controls in the loop", "tools.py", "controls"),
    (SC_HARNESS, "Skills", "skills/*/SKILL.md", "skills"),
    (SC_HARNESS, "MCP", "mcp_client.py", "mcp"),
    (SC_HARNESS, "LSP", "harness.py", "lsp"),
    (SC_HARNESS, "Subagents", "harness.py", "subagents"),
    (SC_HARNESS, "Long-term memory", "memory.md", "memory"),
]

VALUE_ROWS = {"model", "window"}


def last_constant(node, want):
    """The last constant of type `want` anywhere under `node`, or None.

    config.py wraps every capability in an environment override:

        model_id=os.environ.get("LEGACY_MODEL", "meta.llama3-8b-instruct-v1:0")
        window=int(os.environ.get("LEGACY_WINDOW", "8192"))

    In both shapes — and in the `A or B or "default"` chain the frontier tier uses
    — the value that ships is the LAST literal in the expression. Reading it that
    way means an override can be added or removed without touching this script.

    Ordered by source position, not by walk order: ast.walk is breadth-first, so
    "the last node it yields" is not "the last literal in the source". That
    distinction silently returned the environment variable's NAME rather than the
    model id for the frontier tier, which is exactly the kind of plausible-looking
    wrong answer this whole script exists to prevent.
    """
    best = None
    for child in ast.walk(node):
        if not isinstance(child, ast.Constant) or not isinstance(child.value, want):
            continue
        at = (getattr(child, "lineno", 0), getattr(child, "col_offset", 0))
        if best is None or at > best[0]:
            best = (at, child.value)
    return best[1] if best else None


def model_caps():
    """tier -> {model_id, window, tools, system}, read from config.py's MODELS."""
    tree = ast.parse((APP / "config.py").read_text())
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign):
            continue
        if not any(isinstance(t, ast.Name) and t.id == "MODELS" for t in node.targets):
            continue
        if not isinstance(node.value, ast.Dict):
            break
        out = {}
        for key, value in zip(node.value.keys, node.value.values):
            if not isinstance(value, ast.Call):
                continue
            kw = {k.arg: k.value for k in value.keywords if k.arg}
            missing = {"model_id", "window", "tools", "system"} - set(kw)
            if missing:
                raise BuildError(
                    f"config.py: the {ast.literal_eval(key)!r} capability record is "
                    f"missing {', '.join(sorted(missing))}. The scorecard reads "
                    "these; add them or update build-lab-code.py on purpose."
                )
            window = last_constant(kw["window"], (int, str))
            out[ast.literal_eval(key)] = {
                "model_id": last_constant(kw["model_id"], str),
                "window": int(window) if window is not None else 0,
                "tools": bool(last_constant(kw["tools"], bool)),
                "system": bool(last_constant(kw["system"], bool)),
            }
        if out:
            return out
    raise BuildError(
        "config.py: could not find a MODELS dict of capability records. The "
        "scorecard is generated from it, so this is a hard stop rather than a "
        "page that guesses what the model can do."
    )


def short_model(model_id: str) -> str:
    """A short, true name for the panel and the scorecard to agree on.

    The same rule as session.speaker_for, minus its `anthropic -> "Claude"` case:
    the scorecard has room for the version, and "Claude" on its own would not tell
    a reader that lesson 04 moved them to Sonnet 4.5.
    """
    name = model_id.split(":")[0].split(".")[-1]
    name = re.sub(r"-v\d+$", "", name)
    return re.sub(r"-\d{8}$", "", name)


def session_flags(lesson: str) -> dict:
    """The keyword arguments of the lesson's `chat = session.Session(...)` call.

    The LAST such assignment, deliberately: lesson 04 builds a throwaway `old`
    session on the legacy tier to be refused the toolbox in front of the room, and
    the scorecard describes where the lesson LANDS, not where it starts.
    """
    script = LESSON_SCRIPTS[lesson]
    tree = ast.parse((APP / script).read_text())
    found = None
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign):
            continue
        if not any(isinstance(t, ast.Name) and t.id == "chat" for t in node.targets):
            continue
        call = node.value
        if isinstance(call, ast.Call) and getattr(call.func, "attr", "") == "Session":
            found = call
    if found is None:
        raise BuildError(
            f"{script}: no `chat = session.Session(...)` assignment. The scorecard "
            "is generated from that call, so a renamed variable has to be a "
            "deliberate edit here rather than a silently empty scoreboard."
        )
    return {kw.arg: kw.value for kw in found.keywords if kw.arg}


def lesson_state(lesson: str) -> dict:
    """Every scorecard row's answer for one lesson."""
    flags = session_flags(lesson)
    tier_node = flags.get("tier")
    tier = ast.literal_eval(tier_node) if tier_node is not None else "frontier"

    caps = model_caps()
    if tier not in caps:
        raise BuildError(
            f"{LESSON_SCRIPTS[lesson]}: tier={tier!r} is not in config.py's MODELS."
        )
    caps = caps[tier]

    def flag_is_true(name):
        node = flags.get(name)
        return node is not None and last_constant(node, bool) is True

    n = int(lesson)
    return {
        "tier": tier,
        "llm": True,
        "model": short_model(caps["model_id"] or ""),
        "window": f"{caps['window']:,} tokens",
        "window_token": f"window={caps['window']:,}",
        "model_tools": caps["tools"],
        # Present-at-all is the test for the rows whose argument is an expression
        # rather than a literal: `system=session.read_prompt("system")`,
        # `style=style`, `tools=tools.TOOLS`.
        "remember": flag_is_true("remember"),
        "rules": "system" in flags,
        "style": "style" in flags,
        "tools": "tools" in flags,
        "memory": flag_is_true("memory"),
        **{key: n >= int(first) for key, first in DECLARED.items()},
    }


def built_so_far(lesson: str) -> dict:
    """lesson_state, accumulated from lesson 01 up to `lesson`.

    The section is called "what you have built so far", and once a part is built it
    stays built — so the yes/no rows are a high-water mark across the lessons up to
    here, not a snapshot of one script. Without this, output style reads yes at 03
    and no again at 04, because 03 is the only lesson that passes `style=`: a true
    statement about that one file, and a wrong statement about the attendee's
    progress. 05_harness.py's own inventory agrees, listing output style as one of
    its seven parts and annotating it "(lesson 03)".

    The value rows — model, context window — take this lesson's reading instead,
    because those replace rather than accumulate: lesson 04 moves to a different
    model with a bigger window, and claiming both windows at once would be nonsense.
    """
    state = lesson_state(lesson)
    for n in range(1, int(lesson)):
        earlier = lesson_state(f"{n:02d}")
        for key, value in earlier.items():
            if isinstance(value, bool) and value:
                state[key] = True
    return state


def render_scorecard(lesson: str) -> str:
    """The scorecard block for one lesson, with this lesson's addition badged."""
    if lesson not in LESSON_SCRIPTS:
        raise BuildError(
            f"<!-- scorecard: {lesson} --> names a lesson with no script. "
            f"Known: {', '.join(sorted(LESSON_SCRIPTS))}."
        )
    state = built_so_far(lesson)

    # What changed since the lesson before. Derived rather than declared, so the
    # badge cannot end up on a row the code did not actually turn on. Lesson 01 is
    # the baseline and gets no badges: nothing was added, this is where you start.
    previous = f"{int(lesson) - 1:02d}"
    before = built_so_far(previous) if previous in LESSON_SCRIPTS else None

    groups: dict[str, list[str]] = {}
    for group, label, token, key in SC_ROWS:
        value = state[key]
        is_value_row = key in VALUE_ROWS

        if key == "model":
            token = f"tier={state['tier']}"
        elif key == "window":
            token = state["window_token"]
        elif key == "model_tools":
            token = f"tools={'yes' if value else 'no'}"

        changed = (
            before is not None
            and not is_value_row
            and bool(value)
            and not bool(before[key])
        )
        # A value that changed is worth badging too: lesson 04 moves the window
        # from 8,192 to 200,000, and that is the least visible big change in Part 1.
        if before is not None and is_value_row and value != before[key]:
            changed = True

        state_class = "is-yes" if value else "is-no"
        mark = "✅" if value else "⬜"
        parts = [f'<span class="sc-mark">{mark}</span>']
        if is_value_row:
            parts.append(f'<span class="sc-label">{html.escape(label)}</span>')
            parts.append(f'<span class="sc-val">{html.escape(str(value))}</span>')
        else:
            parts.append(f'<span class="sc-label">{html.escape(label)}</span>')
        parts.append(f'<code class="sc-tok">{html.escape(token)}</code>')
        if changed:
            parts.append('<span class="sc-badge">new</span>')

        groups.setdefault(group, []).append(
            f'<div class="sc-item {state_class}">' + "".join(parts) + "</div>"
        )

    blocks = []
    for group in (SC_MODEL, SC_HARNESS):
        items = "\n      ".join(groups.get(group, []))
        blocks.append(
            f'  <div class="sc-group">\n'
            f"    <h3>{html.escape(group)}</h3>\n"
            f'    <div class="sc-grid">\n      {items}\n    </div>\n'
            f"  </div>"
        )
    return '<div class="scorecard">\n' + "\n".join(blocks) + "\n</div>"


# --- the Idira thread --------------------------------------------------------


def parse_idira() -> tuple[dict[str, dict], dict[str, dict]]:
    """Read lab/idira-thread.md into (lesson entries, product records).

    Lesson entries are `lesson -> {risk, say, products: [(name, does), ...]}`.
    Product records are `name -> {tag, risk, controls, met, hands-on}`, in file
    order, and each one fills a row of the reference page's mapping table.

    Same line-shape parser as the annotations, and the same contract: a missing
    field is a hard error. Fifteen lessons each making a product claim is exactly
    the content that must not be half-written.

    A lesson can name more than one product — lesson 01's standing-credential
    risk is answered by three — so the product name and what it does share one
    `product:` line rather than living in a heading and a separate `does:`.
    """
    if not IDIRA_FILE.is_file():
        raise BuildError(f"{IDIRA_FILE.name} is missing, and a page asks for it.")

    text = IDIRA_FILE.read_text()
    while "<!--" in text and "-->" in text:
        head, rest = text.split("<!--", 1)
        text = head + rest.split("-->", 1)[1]

    lessons: dict[str, dict] = {}
    products: dict[str, dict] = {}
    current = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("## "):
            heading = line[3:].strip()
            if heading.lower().startswith("product:"):
                name = heading.partition(":")[2].strip()
                if name in products:
                    raise BuildError(
                        f"{IDIRA_FILE.name}: two '## product: {name}' records. "
                        "One product, one row, one place to edit it."
                    )
                current = products[name] = {"name": name}
            else:
                current = lessons[heading] = {"products": []}
            continue
        if not line or ":" not in line:
            continue
        field, _, value = line.partition(":")
        field, value = field.strip().lower(), value.strip()
        if field not in ("risk", "say", "product", "tag", "controls", "met", "hands-on"):
            continue
        if current is None:
            raise BuildError(
                f"{IDIRA_FILE.name}: '{line[:30]}…' appears before any '## <lesson>'"
            )
        if field == "product":
            if "--" not in value:
                raise BuildError(
                    f"{IDIRA_FILE.name}: 'product: {value[:40]}…' needs the form "
                    "'product: <name> -- <what it does about the risk>'"
                )
            name, _, does = value.partition("--")
            current["products"].append((name.strip(), does.strip()))
        elif field in ("met", "hands-on"):
            current[field] = [n.strip() for n in value.split(",") if n.strip()]
        else:
            current[field] = value

    for lesson, entry in lessons.items():
        missing = [f for f in ("risk", "say") if not entry.get(f)]
        if not entry["products"]:
            missing.append("product")
        if missing:
            raise BuildError(
                f"{IDIRA_FILE.name}: lesson {lesson} is missing "
                f"{', '.join(sorted(missing))}. Every entry needs a risk, at least "
                "one product and a say — a half-written product claim is worse "
                "than none."
            )

    for name, record in products.items():
        missing = [
            f for f in ("tag", "risk", "controls", "met") if not record.get(f)
        ]
        if missing:
            raise BuildError(
                f"{IDIRA_FILE.name}: product '{name}' is missing "
                f"{', '.join(sorted(missing))}. Every record needs a tag, a risk, "
                "what it controls, and at least one lesson under 'met'."
            )

    # The check the whole file exists for: a lesson may not name a product the
    # reference page cannot then explain. Renaming a product is one edit here and
    # a build failure everywhere it was left behind.
    for lesson, entry in lessons.items():
        for name, _ in entry["products"]:
            if name not in products:
                raise BuildError(
                    f"{IDIRA_FILE.name}: lesson {lesson} names '{name}', which has "
                    f"no '## product: {name}' record. Add the record, or fix the "
                    "name in the lesson entry."
                )

    return lessons, products


def parse_pages() -> dict[str, dict]:
    """Lesson number -> {f, t, g}, read out of the PAGES array in assets/lab.js.

    The page list already exists once, in the file the browser reads, and it is
    the thing that decides both the nav and the pager. Copying it into this tool
    would make a third owner of "which file is lesson 09", so the table's links
    are resolved from the real array instead.
    """
    if not PAGES_FILE.is_file():
        raise BuildError(f"{PAGES_FILE.name} is missing, and a page asks for it.")

    text = PAGES_FILE.read_text()
    start = text.find("var PAGES = [")
    end = text.find("];", start)
    if start == -1 or end == -1:
        raise BuildError(
            f"{PAGES_FILE.name}: could not find 'var PAGES = [ … ];'. If the array "
            "moved or changed shape, this parser has to move with it."
        )

    entry = re.compile(
        r"\{\s*f:\s*'([^']+)'\s*,\s*n:\s*'([^']*)'\s*,"
        r"\s*t:\s*'([^']*)'\s*,\s*g:\s*'([^']*)'\s*\}"
    )
    pages: dict[str, dict] = {}
    for file, number, title, group in entry.findall(text[start:end]):
        if number:
            pages[number] = {"f": file, "t": title, "g": group}
    if not pages:
        raise BuildError(
            f"{PAGES_FILE.name}: the PAGES array parsed to nothing. Check the "
            "entry shape — this parser expects f/n/t/g in that order."
        )
    return pages


def _lesson_links(numbers: list[str], pages: dict[str, dict], prefix: str) -> str:
    """"01, 07" -> 'Lessons <a>01</a>, <a>07</a>'. 00 links by its own title."""
    named, numbered = [], []
    for number in numbers:
        page = pages.get(number)
        if page is None:
            raise BuildError(
                f"{IDIRA_FILE.name}: lesson {number} is not in the PAGES array in "
                f"{PAGES_FILE.name}. One of the two is wrong."
            )
        href = html.escape(prefix + page["f"])
        if number == "00":
            named.append(f'<a href="{href}">{html.escape(page["t"])}</a>')
        else:
            numbered.append(f'<a href="{href}">{number}</a>')
    if numbered:
        word = "Lesson" if len(numbered) == 1 else "Lessons"
        named.append(f"{word} " + ", ".join(numbered))
    return ", ".join(named)


def render_idira_table(prefix: str = "") -> str:
    """The product mapping table on reference/securing-agentic-ai.html.

    One row per product record, in file order. `prefix` is what to put in front
    of a page filename to reach it from the page being generated — "../" from
    lab/reference/, nothing from lab/.
    """
    _, products = parse_idira()
    pages = parse_pages()

    rows = []
    for record in products.values():
        where = _lesson_links(record["met"], pages, prefix)
        if record.get("hands-on"):
            hands_on = _lesson_links(record["hands-on"], pages, prefix)
            where += (
                f'<br><span class="svg-sub">hands-on in {hands_on}</span>'
            )
        rows.append(
            "  <tr>\n"
            f'    <td><strong>{inline(record["name"])}</strong><br>'
            f'<span class="svg-sub">{inline(record["tag"])}</span></td>\n'
            f'    <td>{inline(record["risk"])}</td>\n'
            f'    <td>{inline(record["controls"])}</td>\n'
            f"    <td>{where}</td>\n"
            "  </tr>"
        )

    head = (
        "  <tr><th>Product</th><th>The risk it answers</th>"
        "<th>What it actually controls</th><th>Where you met it</th></tr>"
    )
    return "<table>\n" + head + "\n" + "\n".join(rows) + "\n</table>"


def render_idira(lesson: str) -> str:
    """The "Where Idira fits" block for one lesson."""
    entries, _ = parse_idira()
    if lesson not in entries:
        raise BuildError(
            f"<!-- idira: {lesson} --> has no '## {lesson}' entry in "
            f"{IDIRA_FILE.name}."
        )
    entry = entries[lesson]

    products = "\n".join(
        f"    <dt>{inline(name)}</dt>\n    <dd>{inline(does)}</dd>"
        for name, does in entry["products"]
    )

    return (
        '<div class="idira">\n'
        f'  <p class="idira-risk"><span class="callout-label">🧨 The risk you just '
        f'saw.</span> {inline(entry["risk"])}</p>\n'
        "  <p class=\"idira-kicker\">What answers it</p>\n"
        f"  <dl>\n{products}\n  </dl>\n"
        f'  <p class="idira-say">🗣️ “{inline(entry["say"])}”</p>\n'
        '  <p class="idira-more"><a href="reference/securing-agentic-ai.html">'
        "One platform, every identity. The deck and the videos →</a></p>\n"
        "</div>"
    )


# --- the terminal, as the terminal actually prints it ------------------------
#
# A hand-typed mock of the app's output is the worst kind of drift: it is the
# first thing an attendee compares against their screen, and the palette, the
# Idira mark, the capability line and the gauge are all decided in ui.py and
# config.py. So this block is not typed — it is PRINTED, by the real ui.py, into
# a recording console, and exported as HTML with the real colours.
#
# Nothing here calls a model. ui.banner, ui.task, ui.model and ui.footer are pure
# formatters, so the block is generated offline with no credentials.
#
# Only two things below are stated rather than derived: the illustrative answer
# text and the token counts, because those come from a live model. Everything you
# can get wrong by hand — the colours, the mark, the capability line, the gauge
# percentage, the history label — comes from the code.
#
# A block is a SCRIPT: an ordered list of ui.py calls, named rather than numbered,
# because a lesson has more than one thing worth showing and "the output of lesson
# 04" is not a thing. `<!-- terminal: 04-transcript -->` is.
#
#     {"do": "footer", "in": 122, ...}   ->  ui.footer(...)
#
# Which is the whole design: every panel in the guide is one of these, so adding a
# panel is adding data, and the panel on the page is drawn by the code that draws
# the panel on the attendee's screen. The three panels that drifted while they were
# hand-typed are the argument — ui.control_probe's title has been "the controls,
# proven without the model" for months, and lesson 05 still said "every control, no
# model involved"; ui.wall grew two paragraphs that lesson 03 never got; and lesson
# 06's refusal quoted a hook whose wording lives in harness.py.

# Wide enough for the mark to sit beside the wordmark, as ui.py designed it: the
# widest banner row is 18 cells of mark, 2 of gap and 69 of capability line. One
# column spare, and no more — the block has to fit the page's text column without
# a horizontal scrollbar, and lab.css sets the font size that makes 90 columns fit.
TERM_WIDTH = 90

# The illustrative answers. Stated, not derived: they came from a live model once,
# and re-asking on every build would need credentials, cost money and change the
# page every time. Kept up here because they are the only prose in this section.
A_HARNESS = (
    "An agentic harness is the code around a language model that gives it a loop, a "
    "set of tools it may call, and limits on what those tools can reach. The model "
    "supplies the text; the harness supplies the memory, the actions and the rules."
)
A_SHORTER = (
    "It is the code around a model that gives it a loop, tools and limits — the "
    "model writes, the harness remembers and acts."
)

Q_HARNESS = "In two sentences, what is an 'agentic harness'?"
Q_SHORTER = "Now say that again, but shorter."

TERMINALS = {
    # --- lesson 01: one call, and the numbers underneath it ---------------------
    "01": {
        "tier": "legacy",
        "script": [
            {"do": "banner", "stage": "Lesson 01 — one call to a model"},
            {"do": "task", "text": Q_HARNESS},
            {"do": "model", "text": A_HARNESS},
            {"do": "footer", "stop": "end_turn", "in": 26, "out": 74, "turn": 1},
        ],
    },
    # --- lesson 02: the same opener, then the follow-up that failed in 01 -------
    #
    # Two blocks rather than one, because the page asks the room to look at the two
    # footers separately: in=26 and then in=122, for a follow-up of six words.
    "02-opener": {
        "tier": "legacy",
        "remember": True,
        "script": [
            {"do": "banner", "stage": "Lesson 02 — conversation history"},
            {"do": "task", "text": Q_HARNESS},
            {"do": "model", "text": A_HARNESS},
            {
                "do": "footer",
                "stop": "end_turn",
                "in": 26,
                "out": 80,
                "turn": 1,
                "messages": 2,
            },
        ],
    },
    "02-followup": {
        "tier": "legacy",
        "remember": True,
        "script": [
            {"do": "task", "text": Q_SHORTER},
            {"do": "model", "text": A_SHORTER},
            {
                "do": "footer",
                "stop": "end_turn",
                "in": 122,
                "out": 48,
                "turn": 2,
                "messages": 4,
            },
            {"do": "note", "text": "Same follow-up as lesson 01. This time it landed."},
        ],
    },
    # --- lesson 03: instructions cost tokens, the window fills, the wall --------
    "03-footers": {
        "tier": "legacy",
        "remember": True,
        "script": [
            {
                "do": "footer",
                "stop": "end_turn",
                "in": 450,
                "out": 397,
                "turn": 1,
                "messages": 2,
                "style": "deep-dive",
            },
            {
                "do": "footer",
                "stop": "end_turn",
                "in": 870,
                "out": 358,
                "turn": 2,
                "messages": 4,
                "style": "deep-dive",
            },
        ],
    },
    "03-maxtokens": {
        "tier": "legacy",
        "remember": True,
        "script": [
            {
                "do": "footer",
                "stop": "max_tokens",
                "in": 8059,
                "out": 128,
                "turn": 15,
                "messages": 30,
                "style": "deep-dive",
            },
        ],
    },
    "03-wall": {
        "tier": "legacy",
        "script": [{"do": "wall", "spent": 8600}],
    },
    # --- lesson 04: a capability is not a setting, then the loop ---------------
    "04-refusal": {
        "tier": "legacy",
        "script": [
            {
                "do": "capability_refused",
                "what": "use tools",
                # The provider's own words, from the exception 04_tools_and_agents.py
                # catches. The one line here that a build cannot check, because
                # checking it would mean calling Bedrock.
                "detail": "ValidationException: This model doesn't support tool use.",
            },
            {"do": "model_switched", "tier": "frontier"},
            {"do": "note", "text": "{tools} tools, sent on every single turn whether used or not."},
        ],
    },
    "04-transcript": {
        "tier": "frontier",
        "script": [
            {"do": "tool", "name": "list_files", "args": {"path": "."}},
            {
                "do": "tool_result",
                "text": ".env app.py config.py RELEASE_NOTES.md requirements.txt utils.py",
            },
            {"do": "tool", "name": "read_file", "args": {"path": "config.py"}},
            {"do": "tool_result", "text": '1 | """App configuration.'},
            {
                "do": "tool",
                "name": "search_code",
                "args": {"pattern": "(?i)(api[_-]?key|secret|token|password)"},
            },
            {"do": "tool_result", "text": 'config.py:4: AWS_ACCESS_KEY_ID = "AKIA…'},
            # auto=None, so the room sees the question a person actually answers.
            # render_terminal closes stdin for exactly this: ui.approve asks, hits
            # EOF and returns False, which is also what happens if you ^D at it.
            {
                "do": "approve",
                "name": "read_file",
                "args": {"path": ".env"},
                "reason": "The path looks like it holds credentials.",
            },
        ],
    },
    # --- lesson 05: the controls, and the hook -------------------------------
    # Not illustrative at all: the panel is drawn from prove_the_controls(), the
    # same function the lesson runs, calling the same tools. The refusals in the
    # block are the refusals, and if a control stops holding, the build says so.
    "05-probe": {"tier": "frontier", "script": [{"do": "control_probe"}]},
    "05-harness": {"tier": "frontier", "script": [{"do": "harness_summary"}]},
    "05-refusal": {
        "tier": "frontier",
        "script": [
            {"do": "tool", "name": "read_file", "args": {"path": "sandbox/.env"}},
            # The hook's own return value, imported. Nobody retypes a refusal.
            {"do": "tool_result", "from_hook": ["read_file", {"path": "sandbox/.env"}]},
        ],
    },
}


CSS_COLOUR = "--{name}:\\s*#([0-9a-fA-F]{{6}})\\s*;"


def term_theme():
    """rich's export palette, carrying the page's own code-block colours.

    rich exports as if the terminal were black on white, so anything the app
    prints as bold-but-uncoloured -- ui.task()'s prompt line, for one -- comes out
    #000000 and vanishes into a dark code block. The two colours that decide it are
    the two lab.css already paints every code block with, so they are read from
    there rather than repeated here.
    """
    from rich.color_triplet import ColorTriplet  # noqa: PLC0415
    from rich.terminal_theme import DEFAULT_TERMINAL_THEME  # noqa: PLC0415

    css = (LAB / "assets" / "lab.css").read_text(encoding="utf-8")
    picked = {}
    for name in ("code-bg", "code-ink"):
        found = re.search(CSS_COLOUR.format(name=name), css)
        if not found:
            raise BuildError(
                f"lab.css no longer defines --{name} as a six-digit hex colour, so "
                "the terminal block cannot be exported in the colours of the block "
                "it sits in. Update term_theme()."
            )
        hex6 = found.group(1)
        picked[name] = ColorTriplet(*(int(hex6[i : i + 2], 16) for i in (0, 2, 4)))

    theme = copy.copy(DEFAULT_TERMINAL_THEME)  # keep its ANSI 0-15, replace the rest
    theme.background_color = picked["code-bg"]
    theme.foreground_color = picked["code-ink"]
    return theme


def app_modules():
    """The app, imported. One place to fail with an explanation rather than a stack."""
    os.environ.setdefault("COLUMNS", str(TERM_WIDTH))
    os.environ.setdefault("LLM_PROVIDER", "bedrock")
    if str(APP) not in sys.path:
        sys.path.insert(0, str(APP))
    try:
        import config  # noqa: PLC0415
        import harness  # noqa: PLC0415
        import session as app_session  # noqa: PLC0415
        import tools as app_tools  # noqa: PLC0415
        import ui  # noqa: PLC0415
        from rich.console import Console  # noqa: PLC0415
    except ImportError as error:
        raise BuildError(
            f"cannot import the app to render the terminal block ({error}). These "
            "blocks are printed by the real ui.py rather than typed by hand, so the "
            "generator needs the app's environment: run "
            "`.venv/bin/python build-lab-code.py` from the repo root."
        ) from error
    return config, app_session, ui, app_tools, harness, Console


def harness_module():
    """05_harness.py, imported for prove_the_controls(). Not a legal module name."""
    import importlib.util  # noqa: PLC0415

    path = APP / "05_harness.py"
    spec = importlib.util.spec_from_file_location("lesson05", path)
    if spec is None or spec.loader is None:
        raise BuildError(f"cannot load {path} to draw the control-probe panel.")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def caps_for(config, tier: str, where: str):
    caps = config.MODELS.get(tier)
    if caps is None:
        raise BuildError(
            f"TERMINALS[{where!r}] asks for tier={tier!r}, which is not in "
            f"config.py's MODELS. Known: {', '.join(sorted(config.MODELS))}."
        )
    return caps


def run_script(name: str, spec: dict, mods) -> None:
    """Perform one block's script against the real ui.py.

    Every `do` is a ui function, and every argument it can get wrong is derived: the
    gauge percentage from caps.window, the tool count from tools.TOOLS, the refusals
    from the functions that refuse. What is stated in TERMINALS is only what a build
    cannot know — an illustrative answer, a token count from a run that happened once.
    """
    config, app_session, ui, app_tools, harness, _ = mods
    caps = caps_for(config, spec["tier"], name)
    remember = spec.get("remember", False)

    for step in spec["script"]:
        do = step["do"]

        if do == "banner":
            ui.banner(step["stage"], caps.model_id, caps)
        elif do == "task":
            ui.task(step["text"])
        elif do == "model":
            ui.model(step["text"], app_session.speaker_for(caps.model_id))
        elif do == "note":
            ui.note(step["text"].format(tools=len(app_tools.TOOLS)))
        elif do == "blank":
            ui.console.print()
        elif do == "footer":
            shown = caps_for(config, step.get("tier", spec["tier"]), name)
            ui.footer(
                tier=shown.name,
                model_id=shown.model_id,
                caps=shown,
                stop_reason=step["stop"],
                input_tokens=step["in"],
                output_tokens=step["out"],
                # Derived exactly as Session.percent() does it, so the gauge on the
                # page and the gauge in the terminal cannot disagree.
                percent=100.0 * step["in"] / shown.window if shown.window else 0.0,
                turns=step["turn"],
                messages=step.get("messages", 0),
                remember=step.get("remember", remember),
                style=step.get("style"),
            )
        elif do == "wall":
            ui.wall(caps.window, step["spent"])
        elif do == "capability_refused":
            ui.capability_refused(step["what"], step["detail"])
        elif do == "model_switched":
            to = caps_for(config, step["tier"], name)
            ui.model_switched(to.name, to.model_id, to)
        elif do == "tool":
            ui.tool(step["name"], step["args"])
        elif do == "tool_result":
            if "from_tool" in step:
                tool_name, tool_args = step["from_tool"]
                text = app_tools.execute_tool(tool_name, tool_args)
            elif "from_hook" in step:
                tool_name, tool_args = step["from_hook"]
                text = harness.deny_secret_reads(tool_name, tool_args)
                if text is None:
                    raise BuildError(
                        f"TERMINALS[{name!r}] shows harness.deny_secret_reads "
                        f"blocking {tool_args!r} and it no longer does. The lesson "
                        "claims the hook is unarguable, so this is not a block to "
                        "hand-type around — fix the hook or fix the lesson."
                    )
            else:
                text = step["text"]
            ui.tool_result(text)
        elif do == "approve":
            ui.approve(step["name"], step["args"], step["reason"])
        elif do == "control_probe":
            ui.control_probe(harness_module().prove_the_controls())
        elif do == "harness_summary":
            harness_summary(mods)
        else:
            raise BuildError(
                f"TERMINALS[{name!r}] has a step with do={do!r}, which run_script "
                "does not know how to perform. Add it there, next to the ui function "
                "it calls."
            )


def harness_summary(mods) -> None:
    """Lesson 05's panel, wired up exactly as 05_harness.py wires it up.

    Including the MCP connection, which is a local stdio subprocess rather than a
    network call — so the panel says what is really in the toolbox, and the tool
    count on the page is the count. If the server will not start the build stops,
    which is the right outcome: that number is the one the lesson asks the room to
    read twice.
    """
    config, app_session, ui, app_tools, harness, _ = mods
    del config
    import agent as app_agent  # noqa: PLC0415
    import mcp_client  # noqa: PLC0415

    try:
        transport, mcp_tools, dispatch = mcp_client.connect(remote=False)
    except Exception as error:  # noqa: BLE001
        raise BuildError(
            f"cannot start the local MCP server to draw lesson 05's panel "
            f"({type(error).__name__}: {error}). It is a stdio subprocess, not a "
            "network call, so this is usually a missing dependency."
        ) from error

    try:
        toolbox, _execute = harness.build(
            app_session,
            app_agent,
            app_tools.TOOLS,
            mcp_tools=mcp_tools,
            mcp_execute=mcp_client.make_executor(transport, dispatch),
        )
        ui.harness_summary(
            rules_file="prompts/system.md",
            skills=[n for n, _d, _b in harness.list_skills()],
            mcp=f"{len(mcp_tools)} tools from mcp_server_local.py (stdio)",
            lsp=[t["name"] for t in harness.LSP_TOOLS],
            hooks=[h.__name__ for h in harness.HOOKS],
            subagents="delegate",
            memory=str(app_session.MEMORY_FILE.name),
            total_tools=len(toolbox),
        )
    finally:
        transport.close()


# A prompt line, so lab.js can hang a copy button off it. The text comes out of the
# plain rendering rather than the coloured spans, so the `› ` marker, the styling and
# the button itself all stay out of what gets pasted.
PROMPT_LINE = "›"


def render_terminal(name: str) -> str:
    """One named block of the app's output, printed by the real ui.py and exported."""
    if name not in TERMINALS:
        raise BuildError(
            f"<!-- terminal: {name} --> has no entry in TERMINALS. "
            f"Known: {', '.join(sorted(TERMINALS))}."
        )
    mods = app_modules()
    ui, Console = mods[2], mods[5]

    recorder = Console(
        theme=ui.THEME,
        highlight=False,
        record=True,
        force_terminal=True,
        color_system="truecolor",
        width=TERM_WIDTH,
        legacy_windows=False,
    )
    # ui prints through its module-level console, so swapping it is how we capture
    # output. It also makes ui._fancy_glyphs() true, which is what puts the Idira
    # mark in the block — the same test a real truecolor terminal passes.
    #
    # stdin goes with it. ui.approve with no `auto` ASKS, and the question is part of
    # what the room sees; closing stdin means it asks, reads EOF and returns False,
    # deterministically, instead of hanging a build on a terminal that has one.
    was_console, ui.console = ui.console, recorder
    was_stdin, sys.stdin = sys.stdin, io.StringIO("")
    try:
        run_script(name, TERMINALS[name], mods)
        exported = recorder.export_html(inline_styles=True, theme=term_theme())
    finally:
        ui.console = was_console
        sys.stdin = was_stdin

    body = exported[exported.index("<code") :]
    body = body[body.index(">") + 1 : body.index("</code>")]
    # rich pads every line to the console width. Harmless in a <pre>, but it
    # trebles the size of the block and makes the diff unreadable.
    lines = [re.sub(r"\s+(?=</span>$)", "", ln).rstrip() for ln in body.split("\n")]
    lines = [mark_prompt(ln) for ln in lines]
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()

    return (
        '<div class="code code-term"><pre><code>'
        + "\n".join(lines)
        + "</code></pre></div>"
    )


def mark_prompt(line: str) -> str:
    """Wrap a `› …` line in .term-prompt, carrying the bare prompt in data-copy.

    Which is what gives every prompt inside a transcript its own copy button. The
    block as a whole has none: it holds the answers too, and nobody has any use for
    those on a clipboard.
    """
    plain = html.unescape(re.sub(r"<[^>]+>", "", line)).strip()
    if not plain.startswith(PROMPT_LINE):
        return line
    prompt = plain[len(PROMPT_LINE) :].strip()
    if not prompt:
        return line
    return (
        f'<span class="term-prompt" data-copy="{html.escape(prompt, quote=True)}">'
        f"{line}</span>"
    )


# --- rewriting a page --------------------------------------------------------


def blocks_in(page: Path, text: str, annotations: list[Annotation]):
    """Every generated block in one page, in document order: (match, name, html).

    All the marker types share one pass so the BEGIN/END skip logic below — which
    is what makes this tool idempotent rather than appending a fresh copy every
    run — exists once rather than five times.
    """
    found = []
    # How to reach lab/0009-x.html from the page being written. Only the reference
    # pages are a directory down, and only they carry the mapping table.
    prefix = "" if page.parent == LAB else "../"

    for match in MARKER.finditer(text):
        source = match.group(1)
        if source not in ALLOWED:
            raise BuildError(
                f"{page.name}: marker names {source!r}, which is not in ALLOWED. "
                "Add it there on purpose, or fix the marker."
            )
        found.append((match, source, render(source, annotations)))

    for match in SCORECARD_MARKER.finditer(text):
        lesson = match.group(1)
        found.append((match, f"scorecard {lesson}", render_scorecard(lesson)))

    for match in IDIRA_MARKER.finditer(text):
        lesson = match.group(1)
        found.append((match, f"idira {lesson}", render_idira(lesson)))

    for match in TERMINAL_MARKER.finditer(text):
        lesson = match.group(1)
        found.append((match, f"terminal {lesson}", render_terminal(lesson)))

    for match in IDIRA_TABLE_MARKER.finditer(text):
        found.append((match, "idira-table", render_idira_table(prefix)))

    found.sort(key=lambda item: item[0].start())
    return found


def rebuild_page(page: Path, annotations: list[Annotation]) -> str:
    """Return the page's new text, with every generated block refreshed."""
    text = page.read_text()
    out: list[str] = []
    cursor = 0

    for match, name, block in blocks_in(page, text, annotations):
        begin = BEGIN.format(name=name)
        end = END.format(name=name)

        out.append(text[cursor : match.end()])
        cursor = match.end()

        # Skip over the previous generation of this block, if there is one, so the
        # tool is idempotent rather than appending a fresh copy every run.
        after = text[cursor:]
        stripped = after.lstrip()
        if stripped.startswith(begin):
            lead = len(after) - len(stripped)
            close = after.find(end)
            if close == -1:
                raise BuildError(
                    f"{page.name}: found the BEGIN marker for {name} with no "
                    f"matching END. Delete the block by hand and re-run."
                )
            cursor += close + len(end)
            del lead

        out.append(f"\n{begin}\n{block}\n{end}")

    out.append(text[cursor:])
    return "".join(out)


# --- the one thing a generator cannot generate: hand-typed output ------------
#
# A `.code` block gets a Copy button. A `.code-term` block does not, because it is
# the app talking and there is nothing to paste. Get that class wrong and the page
# offers to copy a transcript — two prompts AND two model answers — which is how
# lesson 02 came to look as though `› Now say that again, but shorter.` were a
# command you type.
#
# So it is checked rather than remembered. Any hand-written block that talks like
# the app fails the build, and the fix is either the class or a `terminal:` marker.
OUTPUT_SIGNS = (
    "›",  # ui.task's prompt marker
    "╭─",  # any ui.py panel
    "stop_reason=",  # ui.footer
    "⚙ ",  # ui.tool
    "↳ ",  # ui.tool_result
    "% of the window",  # ui.gauge
)
CODE_BLOCK = re.compile(r'<div class="code([^"]*)"><pre><code>(.*?)</code></pre></div>', re.S)


def output_offences(text: str) -> list[tuple[int, str]]:
    """Hand-written blocks that print like the app but are not classed as output."""
    offences = []
    for match in CODE_BLOCK.finditer(text):
        classes, body = match.group(1), match.group(2)
        if "code-term" in classes:
            continue
        # A generated source listing. Its per-line spans are the tell, and a
        # docstring inside it may legitimately quote any of the signs below.
        if '<span class="l' in body:
            continue
        plain = html.unescape(re.sub(r"<[^>]+>", "", body))
        for sign in OUTPUT_SIGNS:
            if sign in plain:
                line = text[: match.start()].count("\n") + 1
                offences.append((line, sign))
                break
    return offences


def annotations_for(page: Path) -> list[Annotation]:
    """lab/0003-x.html -> lab/annotations/0003.md. Absent means no highlights."""
    stem = page.name.split("-", 1)[0]
    path = ANNOTATIONS / f"{stem}.md"
    return parse_annotations(path) if path.is_file() else []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if out of date")
    parser.add_argument("--diff", action="store_true", help="show changes, write nothing")
    args = parser.parse_args()

    every_page = sorted(list(LAB.glob("*.html")) + list(LAB.glob("reference/*.html")))

    # Before anything is written: no page may offer to copy the app's own output.
    # This one is a hand-authoring error, so it fails in every mode — there is
    # nothing for --check to be a gate on if the write path lets it through.
    bad = [(p, o) for p in every_page for o in output_offences(p.read_text())]
    if bad:
        for page, (line, sign) in bad:
            print(
                f"error: {page.name}:{line} is a code block containing {sign!r}, so it "
                "is the app's output, but it is not class=\"code code-term\" — the page "
                "is offering a Copy button for a transcript. Generate it with a "
                "`<!-- terminal: NAME -->` marker, or class it as output.",
                file=sys.stderr,
            )
        return 2

    pages = [p for p in every_page if any(m.search(p.read_text()) for m in ALL_MARKERS)]
    if not pages:
        print("No page contains a generated-block marker.")
        return 0

    stale: list[str] = []
    for page in pages:
        try:
            new = rebuild_page(page, annotations_for(page))
        except BuildError as error:
            print(f"error: {error}", file=sys.stderr)
            return 2

        old = page.read_text()
        if new == old:
            print(f"  ok       {page.name}")
            continue
        stale.append(page.name)
        if args.check:
            print(f"  STALE    {page.name}")
        elif args.diff:
            print(f"  would rewrite {page.name}")
        else:
            page.write_text(new)
            print(f"  written  {page.name}")

    if args.check and stale:
        print(
            f"\n{len(stale)} page(s) are out of date. Run: python build-lab-code.py",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
