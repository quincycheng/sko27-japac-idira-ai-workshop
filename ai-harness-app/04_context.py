"""STAGE 4 — Context management: the thing that makes agents survive long tasks.

The loop from Stage 3 has a hidden failure mode: every turn appends to
`messages`, so the context grows without bound. Long investigation -> you blow
the context window, latency and cost climb, and the model gets lost in its own
transcript. This is THE hard part of building a real harness.

Two moves shown here:
  1. ACCOUNTING  -> watch input tokens climb each turn (usage is on every response).
  2. COMPACTION  -> when history gets big, summarize the old middle turns into a
                    single note and keep going. This is, in miniature, exactly
                    what Claude Code does when it "compacts" a long session.

Run it:
    python 04_context.py
"""

import sys

from config import MODEL, client
from tools import TOOLS, execute_tool

SYSTEM_PROMPT = (
    "You are a security triage agent. Investigate the repo with tools, then "
    "report concrete findings as file:line with a one-line risk explanation."
)

MAX_ITERATIONS = 20
# Deliberately tiny so compaction triggers on stage in a small repo. In real
# life you'd set this to a fraction of the model's context window.
COMPACT_THRESHOLD_TOKENS = 3000


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

        # (1) ACCOUNTING: input_tokens is the size of everything we sent this
        # turn -- it only goes up as the transcript grows. This is the number
        # that eventually kills a naive agent.
        used = response.usage.input_tokens
        print(f"[ctx  ] step {step:>2} | input_tokens={used} | messages={len(messages)}")

        for block in response.content:
            if block.type == "text" and block.text.strip():
                print(f"[model] {block.text.strip()}")

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
                tool_results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": execute_tool(block.name, block.input),
                    }
                )
        messages.append({"role": "user", "content": tool_results})

        # (2) COMPACTION: when the transcript is getting heavy, fold the old
        # turns into a summary so the loop can keep running.
        if used > COMPACT_THRESHOLD_TOKENS:
            messages = compact(messages)

    return "(stopped at iteration cap)"


def compact(messages: list) -> list:
    """Summarize everything except the original task and the last 2 messages.

    We ask the model itself to write the summary -- cheap, and it keeps exactly
    the details the model thinks it needs. The tricky part is boundaries: never
    split a tool_use from its matching tool_result, or the next call 400s. Here
    we keep the very first message (the task) and the last two intact, and
    compress the middle.
    """
    if len(messages) <= 4:
        return messages  # nothing worth compacting yet

    head, middle, tail = messages[:1], messages[1:-2], messages[-2:]

    transcript = _stringify(middle)
    summary = client.messages.create(
        model=MODEL,
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": (
                    "Summarize this agent transcript for your own future reference. "
                    "Keep every concrete finding (file:line, secret, risk) and which "
                    "files were already inspected. Drop chatter.\n\n" + transcript
                ),
            }
        ],
    )
    note = _final_text(summary)
    print(f"[COMPACT] folded {len(middle)} messages into a {len(note)}-char note")

    compacted_marker = {
        "role": "user",
        "content": f"[Earlier investigation, compacted]\n{note}",
    }
    # Tail must still start cleanly. If the last two messages begin mid-tool-call,
    # keeping the head + a summary + tail preserves the tool_use/tool_result
    # pairing because we never sliced inside the tail.
    return head + [compacted_marker] + tail


def _stringify(messages: list) -> str:
    out = []
    for m in messages:
        content = m["content"]
        if isinstance(content, str):
            out.append(f"{m['role']}: {content}")
        else:
            for block in content:
                btype = getattr(block, "type", None) or (
                    block.get("type") if isinstance(block, dict) else None
                )
                out.append(f"{m['role']}: <{btype} block>")
    return "\n".join(out)


def _final_text(response) -> str:
    return "\n".join(b.text for b in response.content if b.type == "text").strip()


def _fmt(tool_input: dict) -> str:
    return ", ".join(f"{k}={v!r}" for k, v in tool_input.items())


if __name__ == "__main__":
    task = sys.argv[1] if len(sys.argv) > 1 else (
        "Do a thorough audit: inspect every file, then report all security "
        "findings prioritized by severity."
    )
    print(f"TASK: {task}")
    final = run_agent(task)
    print("\n" + "=" * 60)
    print(final)
