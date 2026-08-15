"""The loop. This is the harness, and it is about thirty lines.

A model cannot *do* anything. It produces text, and when you give it tools it
produces a request to call one. The harness is the loop that:

    1. sends the conversation + the tool definitions to the model
    2. if the model asks for a tool  -> decide, run it, feed the result back
    3. repeat until the model stops asking, or until we run out of patience

Step 2 is where every security property of an agent lives, and it is worth being
precise about who does what:

    the model decides    what it would LIKE to happen
    this loop decides    whether it happens at all
    tools.py decides     what is even possible

Nothing in the model can overrule steps two or three, and no wording in the
system prompt is needed to make that true. That is the sentence to take to a
customer: an agent is safe because of what its harness permits, not because of
how its prompt is phrased.

Lessons 04, 05 and 06 all run this same function. Only what goes in changes: the
task, the toolbox, and whether the file it reads is hostile.
"""

import ui
from tools import HUMAN_DENIED, execute_tool, needs_approval

# The iteration cap. A guardrail against a loop that never converges -- a model
# that keeps asking for one more file will otherwise keep asking until your
# budget or your context window runs out. Drop this to 2 and watch a real
# investigation get cut off mid-thought; that is what a too-tight cap costs.
MAX_ITERATIONS = 20


def run(session, task: str, auto=None, on_result=None, execute=None, hooks=()) -> str:
    """Run the agent loop until the model stops asking for tools.

    `auto` short-circuits the approval gate for unattended runs: True approves
    everything, False refuses everything, None asks a human each time.
    `on_result` is handed every (name, input, output) triple, which is how lesson
    05 knows which controls fired.
    `execute` replaces the local dispatch table -- lesson 05 passes one that also
    routes to an MCP server and to a subagent. The loop stays identical, which is
    the point: a harness grows by adding tools, not by rewriting the loop.
    `hooks` are functions run before every call, in order, each able to block it.

    Note what is NOT here: no clearing of the transcript. The loop appends to
    whatever conversation the session already has, so a second task in the same
    chatbox can build on the first -- lesson 02's re-sent history, still running,
    now carrying tool calls as well as talk.
    """
    reply = session.send(task, quiet=True)
    if reply is None:
        return "(the request did not fit in the context window)"

    for _step in range(MAX_ITERATIONS):
        # Show the model's narration for this turn before anything runs, so the
        # room reads its reasoning in the order it happened.
        for block in reply.content:
            if block.type == "text" and block.text.strip():
                ui.model(block.text, session.speaker)

        session.footer(reply)

        # Some providers pause a long turn and expect to be asked to continue.
        # Nothing new is added; the conversation is simply re-sent.
        if reply.stop_reason == "pause_turn":
            reply = session.send_blocks([])
            continue

        # No tool requested -> the model is done. This is the answer.
        if reply.stop_reason != "tool_use":
            return _text(reply)

        # Run every tool the model asked for this turn, collecting the results.
        results = []
        for block in reply.content:
            if block.type != "tool_use":
                continue
            ui.tool(block.name, block.input)

            # HOOKS FIRST. Code, not text: a hook can refuse the call outright and
            # nothing in the conversation gets a vote. Lesson 05 wires two up;
            # before then this list is empty and the loop is unchanged.
            blocked = None
            for hook in hooks:
                blocked = hook(block.name, block.input)
                if blocked:
                    break

            # THE GATE. Three lines, and they are the thesis of Part 1:
            # tools.needs_approval decides WHETHER a call is sensitive, ui.approve
            # draws the prompt, and THE LOOP -- not the model -- acts on the answer.
            reason = needs_approval(block.name, block.input)
            if blocked:
                output = blocked
            elif reason and not ui.approve(block.name, block.input, reason, auto):
                output = HUMAN_DENIED
            else:
                output = (execute or execute_tool)(block.name, block.input)

            ui.tool_result(output)
            if on_result:
                on_result(block.name, block.input, output)
            results.append(
                {
                    "type": "tool_result",
                    "tool_use_id": block.id,  # must match the tool_use id
                    "content": output,
                }
            )

        # Tool results go back as one user message, and round we go. Note what is
        # NOT happening: nobody checked whether that output is trustworthy. It is
        # now indistinguishable from our own instructions. Lesson 05 proves it.
        reply = session.send_blocks(results)
        if reply is None:
            return "(the request did not fit in the context window)"

    return f"(stopped at the iteration cap of {MAX_ITERATIONS})"


def _text(reply) -> str:
    return "\n".join(b.text for b in reply.content if b.type == "text").strip()
