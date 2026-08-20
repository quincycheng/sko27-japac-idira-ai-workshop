"""The session: one conversation, its settings, and its running cost.

This is the file that turns six one-shot scripts into something you can talk to.
Each lesson constructs a Session with a few switches flipped, and the switches
ARE the curriculum:

    lesson 01   remember=False                  -> it forgets you every message
    lesson 02   remember=True                   -> it doesn't
    lesson 03   + system prompt, + output style  -> and the gauge starts climbing
    lesson 04   tier="frontier", + tools         -> it can finally act
    lesson 05   + skills, + MCP, + memory        -> a harness

Nothing here is clever. It is a list of messages, a dict of settings, and four
numbers read off each response. That is genuinely all a harness is, and being
able to say so from memory is what Part 1 is for.

The counters are the reason this file exists rather than the settings. "Watch the
number climb" only works if the number is always on screen, and a footer printed
after every single call is the cheapest honest way to do that in a terminal that
people are going to screenshot.
"""

import os
import re
from pathlib import Path

import ui
from config import MODELS, pick_model
from converse_provider import ContextWindowExceeded

HERE = Path(__file__).resolve().parent
STYLES_DIR = HERE / "styles"
PROMPTS_DIR = HERE / "prompts"

# Where lesson 05 keeps what it remembers between runs. Nothing before lesson 05
# writes it, which is deliberate: a fresh process forgetting everything is
# lesson 01's whole point, so persistence arrives once, late, as a design choice
# with a file behind it.
MEMORY_FILE = HERE / "memory.md"


def read_style(name: str) -> str:
    """Load styles/<name>.md. An output style is a file, exactly like Claude Code's."""
    path = STYLES_DIR / f"{name}.md"
    if not path.is_file():
        available = ", ".join(sorted(p.stem for p in STYLES_DIR.glob("*.md")))
        raise SystemExit(f"No output style '{name}'. Available: {available}.")
    return strip_comments(path.read_text())


def strip_comments(text: str) -> str:
    """Remove HTML comments from a markdown file before it is sent to a model.

    Every markdown file in this app carries a note explaining itself to whoever
    reads the repo, and none of those notes are addressed to the model. Stripping
    them is a decision somebody had to make: left in, they are tokens the model
    reads, is influenced by, and charges you for.
    """
    while "<!--" in text and "-->" in text:
        head, rest = text.split("<!--", 1)
        text = head + rest.split("-->", 1)[1]
    return text.strip()


def read_prompt(name: str = "system") -> str:
    """Load prompts/<name>.md — the agent's rules — minus its HTML comments."""
    path = PROMPTS_DIR / f"{name}.md"
    if not path.is_file():
        raise SystemExit(f"No prompt file at {path}.")
    return strip_comments(path.read_text())


def styles() -> list:
    return sorted(p.stem for p in STYLES_DIR.glob("*.md"))


def speaker_for(model_id: str) -> str:
    """A short, TRUE name for whoever is answering, for the panel title.

    Lessons 01-03 run Llama, so a panel headed "Claude" would be a small lie in a
    workshop whose whole subject is knowing what is actually in your context.
    """
    if "anthropic" in model_id:
        return "Claude"
    name = model_id.split(":")[0].split(".")[-1]
    return re.sub(r"-v\d+$", "", name)


def _diagnose(error: Exception) -> None:
    """Turn the two failures that actually happen in a room into advice.

    Both of these produce a forty-line botocore traceback by default, which on a
    projector reads as "the workshop is broken" and costs a helper five minutes
    per person. Neither is a bug in this app, and both have a one-line answer.

    Anything else is re-raised by the caller: a stack trace for a genuinely
    unexpected error is more useful than a guess dressed up as a diagnosis.
    """
    text = f"{type(error).__name__}: {error}"

    # There used to be a branch here for CERTIFICATE_VERIFY_FAILED, telling people
    # to point AWS_CA_BUNDLE at their corporate root CA. It is gone because the app
    # no longer verifies certificates at all (config.py, the TLS note) -- so the
    # error it diagnosed can no longer happen, and advice for an impossible failure
    # is worse than no advice. If verification is ever turned back on, this branch
    # comes back with it.

    if any(
        marker in text
        for marker in ("ExpiredToken", "InvalidClientTokenId", "UnrecognizedClient",
                       "security token included in the request is invalid",
                       "AuthenticationError", "credential")
    ):
        ui.refused(
            "those AWS credentials are no longer good",
            text,
            "The temporary credentials in this terminal window have expired or "
            "were never valid. Fetch a fresh set the way the setup page describes, "
            "paste them into THIS window, and run the lesson again. Every new "
            "terminal tab needs its own paste.",
        )
        raise SystemExit(1)

    if "AccessDenied" in text or "don't have access to the model" in text:
        ui.refused(
            "this account cannot call that model",
            text,
            "The credentials are fine; the permission is not. Either model access "
            "is not enabled for this model in Bedrock, or the role's policy does "
            "not allow bedrock:InvokeModel on it. That is an owner fix — see "
            "docs/owner-prep.md gate G2.",
        )
        raise SystemExit(1)


# --- filler, for /fill -------------------------------------------------------
# Deliberately self-describing: an attendee who runs /context after /fill should
# be able to see at a glance which part of the window is padding and which part is
# their own conversation. Filler that impersonated a real exchange would make the
# one screen in this app whose job is telling you the truth start lying.
_FILLER_ASK = "[workshop filler] Go over that again in as much detail as you can."

_FILLER_REPLY = (
    "[workshop filler] "
    + (
        "This paragraph exists to take up room in the context window. It is not "
        "something the model said, and it is not something you asked for. Every "
        "copy of it is re-sent to the model on the next turn, is counted in the "
        "input tokens on the footer, and is charged for exactly like real "
        "conversation, because as far as the model is concerned that is what it "
        "is: tokens in one flat stream, with nothing marking their origin. "
    )
    * 4
)


class Session:
    """One conversation with one model, plus everything the harness adds to it."""

    def __init__(
        self,
        tier="frontier",
        remember=True,
        system=None,
        style=None,
        tools=None,
        max_tokens=1024,
        memory=False,
    ):
        self.client, self.model_id, self.caps = pick_model(tier)
        self.tier = tier
        self.speaker = speaker_for(self.model_id)
        self.remember = remember
        self.system_prompt = system
        self.style_name = style
        self.style_text = read_style(style) if style else None
        self.tools = tools
        self.max_tokens = max_tokens
        self.memory = memory

        self.messages = []
        self.turns = 0
        self.last_usage = None
        self.total_input = 0
        self.total_output = 0
        self.compactions = 0
        # Set the first time we have to fake a system prompt, so the footer can
        # say so rather than leaving the attendee to wonder where it went.
        self.system_was_prepended = False

    # --- what the model actually receives ---------------------------------

    def instructions(self) -> str:
        """The system prompt and the output style, concatenated.

        One flat string, because that is what they are by the time the model sees
        them. Two files on disk, one blob of tokens on the wire -- and everything
        the agent later reads with a tool lands in the same stream. That is the
        whole reason prompt injection works, and it is visible right here.
        """
        parts = [p for p in (self.system_prompt, self.style_text) if p]
        if self.memory and MEMORY_FILE.is_file():
            remembered = strip_comments(MEMORY_FILE.read_text())
            if remembered:
                parts.append("What you remember from previous sessions:\n" + remembered)
        return "\n\n".join(parts)

    def _payload(self, user_text: str) -> tuple:
        """Build (messages, system) for one call. Returns what goes on the wire.

        The interesting branch is `caps.system`. A model with a system role gets
        its instructions in the dedicated field, where the API keeps them separate
        from the conversation. A model without one gets them PREPENDED into the
        first user message, because there is nowhere else to put them.

        Same words, same tokens, same effect on the answer -- and no boundary at
        all between our instructions and the user's text. Old models worked this
        way for years, which is a large part of why "just tell it not to" was
        never a control.
        """
        instructions = self.instructions()
        history = list(self.messages) if self.remember else []

        if instructions and not self.caps.system:
            self.system_was_prepended = True
            if not history:
                user_text = f"{instructions}\n\n---\n\n{user_text}"
            return history + [{"role": "user", "content": user_text}], None

        return (
            history + [{"role": "user", "content": user_text}],
            instructions or None,
        )

    # --- one exchange ------------------------------------------------------

    def send(self, user_text: str, quiet=False):
        """Send one message. Print the answer and the footer. Return the response.

        Returns None when the request did not fit in the context window, which in
        lesson 03 is not a failure -- it is the wall, arriving on cue.
        """
        messages, system = self._payload(user_text)
        return self._call(messages, system, quiet=quiet)

    def send_blocks(self, blocks: list, quiet=True):
        """Continue the conversation with raw content blocks — i.e. tool results.

        The agent loop in agent.py needs this: a tool_result is not typed text, it
        is a block that has to reference the tool_use id it answers. Everything
        else about the call is identical, which is the point worth noticing --
        a tool result is just another user message. Nothing marks it as machine
        output, and nothing marks it as untrusted.

        An empty `blocks` re-sends the conversation unchanged, which is how a
        paused turn is resumed.
        """
        messages = list(self.messages)
        if blocks:
            messages = messages + [{"role": "user", "content": blocks}]
        # Instructions were either sent in the system field (and must be again) or
        # already prepended into the first message, in which case they are in
        # `messages` and must not be repeated.
        system = self.instructions() if self.caps.system else ""
        return self._call(messages, system or None, quiet=quiet)

    def _call(self, messages: list, system, quiet=False):
        """One request. The only place in the app that talks to a model."""
        kwargs = {
            "model": self.model_id,
            "max_tokens": self.max_tokens,
            "messages": messages,
        }
        if system:
            kwargs["system"] = system
        if self.tools and self.caps.tools:
            kwargs["tools"] = self.tools

        try:
            with ui.thinking():
                response = self.client.messages.create(**kwargs)
        except ContextWindowExceeded:
            ui.wall(self.caps.window, self.total_input)
            return None
        except Exception as error:  # noqa: BLE001 - diagnose the two that happen, re-raise the rest
            _diagnose(error)
            raise

        self.turns += 1
        self.last_usage = response.usage
        self.total_input += response.usage.input_tokens
        self.total_output += response.usage.output_tokens

        # Keep the transcript whether or not we will re-send it. Lesson 01 has a
        # full history and deliberately throws it away on every call, which is a
        # more honest demonstration than not recording it at all.
        self.messages = messages + [
            {"role": "assistant", "content": response.content}
        ]

        if not quiet:
            for block in response.content:
                if block.type == "text" and block.text.strip():
                    ui.model(block.text, self.speaker)
            self.footer(response)
        return response

    # --- the display -------------------------------------------------------

    def used(self) -> int:
        """Tokens in the LAST request. This is what the gauge is a share of.

        Not a running total: it is how full the window was at the moment the model
        answered. On a conversation that keeps growing, the two happen to climb
        together, which is exactly the trap lesson 02 walks into.
        """
        return self.last_usage.input_tokens if self.last_usage else 0

    def percent(self) -> float:
        return 100.0 * self.used() / self.caps.window if self.caps.window else 0.0

    def footer(self, response=None):
        ui.footer(
            tier=self.tier,
            model_id=self.model_id,
            caps=self.caps,
            stop_reason=getattr(response, "stop_reason", None),
            input_tokens=self.used(),
            output_tokens=(
                response.usage.output_tokens if response is not None else 0
            ),
            percent=self.percent(),
            turns=self.turns,
            messages=len(self.messages) if self.remember else 0,
            remember=self.remember,
            prepended=self.system_was_prepended,
            style=self.style_name,
        )

    # --- context engineering ----------------------------------------------

    def compact(self) -> bool:
        """Fold the middle of the transcript into a note. Lesson 03's payoff.

        Keeps the first message (the task) and the last two intact and summarises
        everything between them. The boundary rule that makes this fiddly: a
        tool_use block and its tool_result are ONE unit, and slicing between them
        makes the next request invalid. Keeping the tail whole is what avoids it.

        The summary is written by the model itself -- cheap, and it keeps the
        details the model thinks it needs rather than the ones we guessed at.
        """
        if len(self.messages) <= 4:
            ui.note("Nothing worth compacting yet — fewer than four messages.")
            return False

        head, middle, tail = self.messages[:1], self.messages[1:-2], self.messages[-2:]

        # Summarising costs a call, and that call has to fit in the same window we
        # are trying to clear. On a transcript that is already at the wall it does
        # not, so drop the oldest half and try again -- unread, and said out loud.
        # This is not a workaround: it is the real shape of the problem, and the
        # reason a production harness compacts on the way up rather than waiting
        # for the wall. Anything you were told at 98% is gone unsummarised.
        candidate, dropped, note = middle, 0, ""
        while candidate:
            try:
                note = self._summarise(candidate)
                break
            except ContextWindowExceeded:
                half = len(candidate) // 2 or len(candidate)
                dropped += half
                candidate = candidate[half:]
        if dropped:
            ui.note(f"Too full to summarise in one call — dropped {dropped} messages unread.")
            ui.note("Compact on the way up, not at the wall. This is why.")
        if not note:
            note = "(the transcript was too large to summarise; it was discarded)"

        self.messages = (
            head
            + [{"role": "user", "content": f"[Earlier conversation, compacted]\n{note}"}]
            + tail
        )
        self.compactions += 1
        ui.compacted(len(middle), len(note))
        return True

    def _summarise(self, messages: list) -> str:
        """Ask the model to summarise part of its own transcript. One call.

        Deliberately NOT self.send: this is a side conversation about the
        conversation, and putting it in the transcript would grow the thing we are
        shrinking. Raises ContextWindowExceeded if the summary request itself does
        not fit, which the caller handles.
        """
        summary = self.client.messages.create(
            model=self.model_id,
            max_tokens=512,
            messages=[
                {
                    "role": "user",
                    "content": (
                        "Summarise this transcript for your own future reference. "
                        "Keep every concrete finding (file:line, secret, risk) and "
                        "which files were already inspected. Drop the chatter.\n\n"
                        + _stringify(messages)
                    ),
                }
            ],
        )
        return "\n".join(b.text for b in summary.content if b.type == "text").strip()

    def fill(self, percent=95) -> bool:
        """Pad the transcript with labelled filler until it is `percent` full.

        This is a teaching device and the app says so on screen every time it runs.
        The honest way to reach the wall is to keep talking, and on an 8k window
        that is about twenty turns -- roughly five percent a turn, measured, not
        guessed. Twenty turns is fine at your desk and far too slow with sixty
        people waiting, so this jumps the queue.

        What is real about it: the filler is genuinely in the transcript, it is
        genuinely re-sent on the next turn, and the failure it causes is Bedrock
        refusing the request rather than anything this app pretends. What is fake
        is only WHO said it and how long it took to accumulate.

        Sizing is an estimate -- roughly four characters per token, which is close
        enough for English prose and never exact. That is why the default is 95%
        rather than 100%: it puts the wall one ordinary question away instead of
        betting the demo on an approximation landing precisely.

            /fill        -> one question away from the wall
            /fill 60     -> into the amber dumb zone, still working
        """
        if not self.caps.window:
            ui.note("This model has no declared window, so there is nothing to fill.")
            return False
        if not self.remember:
            # Padding a transcript that _payload throws away would produce a full
            # gauge and no consequence at all -- the opposite of the lesson.
            ui.note("This lesson re-sends nothing, so filler would change no number.")
            ui.note("Lesson 02 turns history on. Filling only means something there.")
            return False

        target = int(self.caps.window * percent / 100) * 4  # ~4 chars per token
        have = len(_stringify(self.messages))
        added = 0
        while have < target:
            self.messages.append(
                {"role": "user", "content": _FILLER_ASK}
            )
            self.messages.append(
                {"role": "assistant", "content": [{"type": "text", "text": _FILLER_REPLY}]}
            )
            have += len(_FILLER_ASK) + len(_FILLER_REPLY)
            added += 2

        ui.note(f"Padded the transcript with {added} synthetic messages.")
        ui.note(f"Estimated {percent}% of {self.caps.window:,} tokens. Now ask something.")
        return True

    def reset(self):
        self.messages = []
        self.turns = 0
        self.last_usage = None
        ui.note("Conversation cleared. The model now knows nothing about you.")

    def switch(self, tier: str):
        """Change models mid-conversation. Keeps the transcript, drops what cannot survive.

        Downgrading to a model with no tool support has to discard tool_use and
        tool_result blocks, because the target model has no way to read them. Say
        that out loud when it happens: a transcript is not portable between
        models, which is a real constraint on "just swap the model out".
        """
        if tier not in MODELS:
            ui.note(f"Unknown model '{tier}'. Try: {', '.join(MODELS)}.")
            return
        self.client, self.model_id, self.caps = pick_model(tier)
        self.tier = tier
        self.speaker = speaker_for(self.model_id)
        if not self.caps.tools:
            self.messages = [
                m for m in self.messages if not _has_tool_blocks(m["content"])
            ]
        ui.model_switched(tier, self.model_id, self.caps)

    def remember_this(self, text: str):
        """Append a line to memory.md. Lesson 05 only."""
        with MEMORY_FILE.open("a") as handle:
            handle.write(text.rstrip() + "\n")
        ui.note(f"Written to {MEMORY_FILE.name}. It will still be there tomorrow.")


# --- the chatbox -------------------------------------------------------------


# Kept under 70 characters a line: this panel is 100 wide at most and drops to
# the terminal width, and a wrapped help list on a projector looks broken.
HELP = """/model legacy|frontier   switch models mid-conversation
/style eli5|deep-dive    swap the output style
/system                  show the instructions being sent
/context                 show everything in the context, and the totals
/compact                 fold the middle of this conversation into a note
/fill [percent]          pad the window with filler to reach the wall now
/reset                   forget everything and start over
/remember <text>         write a line to memory.md  (lesson 05 only)
/help                    this list
/exit                    leave"""


def chat(session: Session, on_message=None):
    """Read-eval-print, with slash commands. The 'chatbox' each lesson ends in.

    The commands are named after Claude Code's on purpose. By Part 2 the same
    words do the same jobs in a real harness, so the tool feels like this one
    wearing better clothes -- which is the entire handover Part 1 is building to.

    `on_message` lets a lesson own the exchange -- lesson 04 onward needs the
    tool loop, not a single call. Default is one plain call.
    """
    ui.chat_intro(HELP)
    while True:
        try:
            line = ui.ask()
        except (EOFError, KeyboardInterrupt):
            ui.note("Bye.")
            return
        if not line.strip():
            continue

        if line.startswith("/"):
            if _command(session, line):
                return
            continue

        if on_message:
            on_message(session, line)
        else:
            session.send(line)


def _command(session: Session, line: str) -> bool:
    """Handle one slash command. Returns True if the session should end."""
    parts = line.split()
    name, args = parts[0], parts[1:]

    if name in {"/exit", "/quit"}:
        return True
    if name == "/help":
        ui.chat_intro(HELP)
    elif name == "/model":
        if args:
            session.switch(args[0])
        else:
            ui.note(f"Usage: /model {'|'.join(MODELS)}")
    elif name == "/style":
        if not args:
            ui.note(f"Usage: /style {'|'.join(styles())}")
        else:
            try:
                session.style_text = read_style(args[0])
                session.style_name = args[0]
                ui.style_switched(args[0], session.style_text)
            except SystemExit as error:
                ui.note(str(error))
    elif name == "/system":
        ui.system_view(session.system_prompt, session.style_text, session.caps.system)
    elif name == "/context":
        ui.context_view(session)
    elif name == "/remember":
        if not args:
            ui.note("Usage: /remember <something worth keeping>")
        elif not session.memory:
            # Writing it anyway would be a lie of omission: this lesson never
            # reads the file back, so nothing would appear to happen.
            ui.note("This lesson has memory switched off — nothing would read it back.")
            ui.note("Lesson 05 turns it on. Until then, forgetting is the default.")
        else:
            session.remember_this(" ".join(args))
    elif name == "/compact":
        session.compact()
    elif name == "/fill":
        try:
            session.fill(int(args[0]) if args else 95)
        except ValueError:
            ui.note("Usage: /fill [percent]   e.g. /fill 60 for the dumb zone")
    elif name == "/reset":
        session.reset()
    else:
        ui.note(f"Unknown command {name}. /help for the list.")
    return False


# --- helpers ----------------------------------------------------------------


def _has_tool_blocks(content) -> bool:
    if isinstance(content, str):
        return False
    for block in content or []:
        btype = block["type"] if isinstance(block, dict) else getattr(block, "type", "")
        if btype in {"tool_use", "tool_result"}:
            return True
    return False


def _stringify(messages: list) -> str:
    out = []
    for message in messages:
        content = message["content"]
        if isinstance(content, str):
            out.append(f"{message['role']}: {content}")
            continue
        for block in content:
            btype = block["type"] if isinstance(block, dict) else getattr(block, "type", "")
            if btype == "text":
                text = block["text"] if isinstance(block, dict) else block.text
                out.append(f"{message['role']}: {text}")
            else:
                out.append(f"{message['role']}: <{btype}>")
    return "\n".join(out)


def env_summary() -> str:
    """One line for the banner: which provider, and whether memory is in play."""
    provider = os.environ.get("LLM_PROVIDER", "bedrock")
    return f"provider={provider}"
