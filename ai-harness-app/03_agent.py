"""STAGE 3 — From "a loop with a tool" to "an agent".

Same loop as Stage 2. Three things turn it into something that feels agentic:

  1. A SYSTEM PROMPT  -> gives the model a role, a goal, and rules of engagement.
  2. A TOOLBOX        -> several tools, so the model has to *choose* and *sequence*.
  3. GUARDRAILS       -> an iteration cap and pause_turn handling so the loop is
                          safe to run unattended on stage.

Point out to the audience: the loop body barely changed from Stage 2. Capability
came from the tools and the prompt, not from more harness code.

Run it:
    python 03_agent.py
    python 03_agent.py "Look for command-injection risks in this repo."
"""

import sys

from config import MODEL, client
from tools import TOOLS, execute_tool

SYSTEM_PROMPT = """You are a security triage agent investigating a code repository.

Your job: find concrete security problems -- hardcoded secrets, dangerous calls
(eval/exec/shell), injection risks -- and report them precisely.

Rules:
- Investigate with the tools before drawing conclusions. Don't guess file contents.
- Cite findings as file:line with a one-line explanation of the risk.
- When you have enough to report, stop calling tools and write a short findings
  summary ordered by severity. Be concise."""

MAX_ITERATIONS = 12  # a runaway agent is a security problem; always bound the loop


def run_agent(task: str) -> str:
    messages = [{"role": "user", "content": task}]

    for step in range(1, MAX_ITERATIONS + 1):
        response = client.messages.create(
            model=MODEL,
            max_tokens=4096,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
        )

        for block in response.content:
            if block.type == "text" and block.text.strip():
                print(f"\n[model] {block.text.strip()}")

        # pause_turn: the model paused a long turn (common with server tools).
        # Just echo its turn back and let it continue -- no tools to run yet.
        if response.stop_reason == "pause_turn":
            messages.append({"role": "assistant", "content": response.content})
            continue

        if response.stop_reason != "tool_use":
            return _final_text(response)

        messages.append({"role": "assistant", "content": response.content})

        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                print(f"[tool ] {block.name}({_fmt(block.input)})")
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


def _fmt(tool_input: dict) -> str:
    return ", ".join(f"{k}={v!r}" for k, v in tool_input.items())


if __name__ == "__main__":
    task = sys.argv[1] if len(sys.argv) > 1 else (
        "Audit this repo for hardcoded secrets and dangerous code. "
        "Give me a prioritized findings list."
    )
    print(f"TASK: {task}")
    final = run_agent(task)
    print("\n" + "=" * 60)
    print(final)
