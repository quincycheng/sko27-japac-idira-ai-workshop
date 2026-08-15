"""LESSON 04 — Tools, and the loop that makes a model an agent.

Lessons 01-03 built a very expensive pen pal. It could describe a vulnerability;
it could not go and look for one. This lesson adds the two things that change
that, and neither of them is a better model:

    tools.py   a list of things that CAN happen, written by us
    agent.py   a loop that decides whether each request actually happens

That is the whole of "agentic". Read agent.py before you run this -- it is
thirty lines, and after today you should be able to describe it from memory to a
customer who is worried about what their AI agent can reach.

Two things to watch, in this order:

  1. THE OLD MODEL CANNOT PLAY. We ask it first, on purpose, and the provider
     refuses. Not badly -- at all. Tools are a capability, not a prompt, and this
     is the moment the upgrade earns itself rather than being announced.

  2. THE COST STEP. The tool schemas are sent on EVERY turn, before the model has
     said a word, and every tool result joins the transcript that gets re-sent.
     Compare the first `in=` here with lesson 02's. A four-tool agent starts
     several hundred tokens in the hole and grows faster than a conversation.

Then read the transcript for what the room usually misses: the tool results land
in exactly the same undivided stream as our instructions. Nothing labels them as
machine output, and nothing labels them as untrusted. Lesson 05 is where that
stops being fatal, because the control it adds is not in the stream at all.

Run it:
    python 04_tools_and_agents.py            # you approve each sensitive call
    python 04_tools_and_agents.py --yes      # approve everything (unattended)
    python 04_tools_and_agents.py --no       # refuse everything, to see the gate bite
"""

import sys

import agent
import session
import tools
import ui

TASK = (
    "Investigate this repository for hardcoded secrets and obvious "
    "vulnerabilities. Cite file:line for every finding and rate each one. "
    "There are six credentials planted; find all of them."
)


def show_the_old_model_refuse() -> None:
    """Hand the legacy model a toolbox and let the provider answer.

    We deliberately go around our own harness here -- `Session` would quietly
    drop the tools, which is the polite thing for an app to do and the useless
    thing for a lesson to do. Calling the client directly gets the real error.
    """
    old = session.Session(tier="legacy", remember=False, max_tokens=200)
    try:
        old.client.messages.create(
            model=old.model_id,
            max_tokens=200,
            messages=[{"role": "user", "content": TASK}],
            tools=tools.TOOLS,
        )
    except Exception as error:  # noqa: BLE001 - the error IS the demonstration
        ui.capability_refused("use tools", f"{type(error).__name__}: {error}")
        return
    # If a swapped-in LEGACY_MODEL does support tools, say so rather than lying.
    ui.note("This legacy model accepted the tools. Skip beat 1 and say why: you")
    ui.note("swapped LEGACY_MODEL for something newer than the default legacy tier.")


def main() -> None:
    auto, _rest = ui.parse_auto(sys.argv[1:])

    ui.banner("Lesson 04 — tools and agents", "", None)
    ui.task("First, ask the model from lessons 01-03 to do this job:")
    ui.note(TASK)
    show_the_old_model_refuse()

    # The upgrade, and everything it brings: tools, a system role, 200k of room.
    chat = session.Session(
        tier="frontier",
        remember=True,
        system=session.read_prompt("system"),
        tools=tools.TOOLS,
        max_tokens=2048,
    )
    ui.model_switched(chat.tier, chat.model_id, chat.caps)
    ui.note(f"{len(tools.TOOLS)} tools, sent on every single turn whether used or not.")

    ui.task(TASK)
    findings = agent.run(chat, TASK, auto=auto)
    ui.final(findings)

    ui.note("Every ⚙ line was the model ASKING. agent.py decided. Nothing else did.")
    ui.note("Run /context: the tool results are now part of what you re-send forever.")
    ui.note("Ask it something else — it keeps the findings, and the bill keeps climbing.")

    # The chatbox, but now every message goes through the loop rather than
    # straight to the model, so a typed follow-up can call tools too.
    session.chat(chat, on_message=lambda s, line: ui.final(agent.run(s, line, auto=auto)))


if __name__ == "__main__":
    main()
