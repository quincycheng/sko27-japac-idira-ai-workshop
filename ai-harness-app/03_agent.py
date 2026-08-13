"""LESSON 03 — From "a loop with a tool" to "an agent".

Same loop as Lesson 02. Three things turn it into something that feels agentic:

  1. A SYSTEM PROMPT  -> gives the model a role, a goal, and rules of engagement.
  2. A TOOLBOX        -> several tools, so the model has to *choose* and *sequence*.
  3. GUARDRAILS       -> an iteration cap, pause_turn handling, and a human
                          approval gate on the calls that deserve one.

Point out to the audience: the loop body barely changed from Lesson 02. Capability
came from the tools and the prompt, not from more harness code.

The approval gate is the three lines marked (!) below, and they are worth reading
out loud: `tools.needs_approval` decides WHETHER a call is sensitive, `ui.approve`
draws the prompt, and THE LOOP -- not the model, not the tool -- decides what
happens. That is the whole thesis of the talk in three lines.

Run it:
    python 03_agent.py
    python 03_agent.py "Look for command-injection risks in this repo."
    python 03_agent.py --yes    # approve everything (unattended rehearsal)
    python 03_agent.py --no     # refuse everything
"""

import sys

import ui
from config import MODEL, PROVIDER, client
from tools import HUMAN_DENIED, TOOLS, execute_tool, needs_approval

SYSTEM_PROMPT = """You are a security triage agent investigating a code repository.

Your job: find concrete security problems -- hardcoded secrets, dangerous calls
(eval/exec/shell), injection risks -- and report them precisely.

Rules:
- Investigate with the tools before drawing conclusions. Don't guess file contents.
- Cite findings as file:line with a one-line explanation of the risk.
- When you have enough to report, stop calling tools and write a short findings
  summary ordered by severity. Be concise."""

MAX_ITERATIONS = 12  # a runaway agent is a security problem; always bound the loop


def run_agent(task: str, auto: bool | None = None) -> str:
    messages = [{"role": "user", "content": task}]

    for step in range(1, MAX_ITERATIONS + 1):
        with ui.thinking():
            response = client.messages.create(
                model=MODEL,
                max_tokens=4096,
                system=SYSTEM_PROMPT,
                tools=TOOLS,
                messages=messages,
            )

        # pause_turn: the model paused a long turn (common with server tools).
        # Just echo its turn back and let it continue -- no tools to run yet.
        if response.stop_reason == "pause_turn":
            messages.append({"role": "assistant", "content": response.content})
            continue

        # The model stopped asking for tools, so this turn IS the answer. Return
        # it and let the caller render it once -- printing narration here too
        # would show the same text twice.
        if response.stop_reason != "tool_use":
            return _final_text(response)

        # Mid-investigation narration: only reached when tools are still coming.
        for block in response.content:
            if block.type == "text" and block.text.strip():
                ui.model(block.text)

        messages.append({"role": "assistant", "content": response.content})

        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                ui.tool(block.name, block.input)

                # (!) THE GATE. tools.py says whether a person should look;
                # ui.py asks them; this loop decides. The model gets a normal
                # tool_result either way, so a refusal is something it can
                # reason about rather than a crash.
                reason = needs_approval(block.name, block.input)
                if reason and not ui.approve(block.name, block.input, reason, auto):
                    output = HUMAN_DENIED
                else:
                    output = execute_tool(block.name, block.input)

                tool_results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": output,
                    }
                )
        messages.append({"role": "user", "content": tool_results})

    return "(stopped: hit the iteration cap -- the agent kept working past the limit)"


def _final_text(response) -> str:
    return "\n".join(b.text for b in response.content if b.type == "text").strip()


if __name__ == "__main__":
    auto, argv = ui.parse_auto(sys.argv[1:])
    task = argv[0] if argv else (
        "Audit this repo for hardcoded secrets and dangerous code. "
        "Give me a prioritized findings list."
    )
    ui.banner("Lesson 03 — the agent", PROVIDER, MODEL)
    ui.task(task)
    ui.final(run_agent(task, auto))
