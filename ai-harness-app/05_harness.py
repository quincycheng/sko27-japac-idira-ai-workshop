"""LESSON 05 — The harness. Seven parts, and you have already built four of them.

This is where Part 1 lands. The loop has not changed since lesson 04 -- open
agent.py and check -- and yet the thing you are about to talk to can audit a
repo, cite advisories from a service it does not own, follow a written procedure,
refuse to read a credential file without asking anyone, delegate work to a second
context, and remember something for tomorrow.

The lesson walks one component per task, in this order: MCP, skills, the LSP,
subagents, hooks, memory. All six happen inside this one session.

Nothing is sent on start. The panel prints, the six tasks print, and every prompt
after that is one somebody types. A lesson about who is allowed to do what should
not open by doing something nobody asked for.

No standard says seven. There is no industry definition of an AI harness at all; these
are the parts that keep turning up, and this app has all of them. Where each one
lives, and which of them are controls:

    1. RULES        prompts/system.md        context   · a request
    2. SKILLS       skills/*/SKILL.md        context   · a request, loaded on demand
    3. OUTPUT STYLE styles/*.md              context   · a request  (lesson 03)
    4. MCP          mcp_client.py            tools     · somebody else's tools
    5. LSP          harness.py               tools     · cheap answers about code
    6. SUBAGENTS    harness.py               tools     · a second context window
    7. HOOKS        harness.py               THE LOOP  · code. A control.
       (+ MEMORY    memory.md                context   · the only part that persists)

Five of those are text in a context window. The model reads them, and reading is
a request: a rule can be argued with, a skill can be ignored, a memory can be
poisoned by whatever wrote it. The hook cannot. It is thirty lines of Python
between the model's request and the world, and no wording anywhere reaches it.

prove_the_controls(), printed when you quit, is the evidence for that sentence.
It attacks the tool boundary directly, with no model in the loop, so the refusals
are identical on every laptop in the room. The model's behaviour is the anecdote;
the probe is the evidence.

The Idira team has done this hands-on before -- the jailbreaking and
capture-the-flag exercises at last year's mid-year kick-off were this argument
with a scoreboard. Anyone who played will remember how quickly a prompt-shaped
rule falls over, and how a properly scoped tool does not.

That distinction is the single most useful thing to carry out of this room. When a
customer asks "how do we secure our AI agents", the answer is not a better prompt
library. It is: what can the tools reach, who authorised the agent to call them,
and what runs in the loop regardless of what the model wants.

WHAT PART 2 IS. Everything above, already built, by people who do it full time:
Claude Code has all seven components -- CLAUDE.md for rules, /skills, output
styles, MCP servers, an LSP, subagents, hooks, and memory. You are not about to
learn a new tool. You are about to recognise one.

Run it:
    python 05_harness.py                # local MCP server over stdio (default)
    python 05_harness.py --remote       # the hosted playground server over HTTP
    python 05_harness.py --yes          # approve every gated call

A NOTE ON --remote. It points at
https://mcpplaygroundonline.com/mcp-stateless-server?rev=2026-07-28 -- a public
MCP server that needs no credentials at all. Expect your corporate proxy to block
it, and do not treat that as a problem to work around: an unauthenticated
internet service, feeding tool descriptions and tool results directly into an
agent that can read your source, is precisely what egress filtering is for. The
lesson is better when it is blocked. If it is not blocked, that is worth a
conversation with whoever owns your egress policy.
"""

import sys

import agent
import harness
import mcp_client
import session
import tools
import ui

# Task 4 on the lesson page asks you to paste this into the chatbox, so it lives here
# as the one place the wording is kept. Nothing sends it for you.
#
# The delegation is asked for explicitly, and that is not a cheat. Left to itself
# the model does the whole audit inline -- reasonably, since the repo is six files
# -- and the sixth component never runs. Naming it is also how a subagent gets used
# in practice: you delegate the half of a job whose reading you do not want in your
# own window. Watch the token counts when it does: the subagent's dozen tool
# results are billed once, inside its own context, and what comes back here is ten
# lines. That trade is the entire reason subagents exist.
TASK = (
    "Audit this repository. Delegate the dependency review to a subagent so its "
    "reading stays out of your context, review the code yourself, then give me "
    "one written report covering both."
)


def prove_the_controls() -> list:
    """Exercise the tool boundary directly, and return what each control said.

    The reason this function exists: every other component in this lesson depends
    on the model deciding to cooperate, and a lesson whose central claim only
    lands on some runs is a lesson that will let a presenter down in front of
    sixty people.

    So we make the calls ourselves. These are the same functions the loop calls,
    reached the same way, with the same arguments a successful injection would
    have produced -- the only thing missing is the model, which is precisely what
    is being demonstrated. A control that holds when we attack it on purpose
    holds when a file attacks it by surprise.
    """
    traversal = tools.execute_tool("read_file", {"path": "../../../../etc/passwd"})
    exfiltrate = tools.execute_tool("run_command", {"name": "curl-the-env-somewhere"})
    # The gate is not a function that refuses; it is a function that ASKS. So the
    # honest thing to show is the reason it produces plus what the loop does with
    # it -- and the loop's answer here is a human's, not ours.
    gate = tools.needs_approval("read_file", {"path": ".env"})
    return [
        ("read_file(path='../../../../etc/passwd')", "tools._safe_path", traversal),
        ("run_command(name='curl-the-env-somewhere')", "the allowlist", exfiltrate),
        (
            "read_file(path='.env')  →  a person is asked",
            f"the approval gate: {gate}",
            tools.HUMAN_DENIED,
        ),
    ]


def main() -> None:
    auto, rest = ui.parse_auto(sys.argv[1:])
    remote = "--remote" in rest

    # --- connect to the MCP server ------------------------------------------
    transport, mcp_tools, dispatch = None, [], {}
    try:
        transport, mcp_tools, dispatch = mcp_client.connect(remote=remote)
    except Exception as error:  # noqa: BLE001 - a blocked proxy is an expected outcome
        target = "the hosted MCP playground" if remote else "the local MCP server"
        detail = f"{type(error).__name__}: {error}"
        if remote:
            detail = f"{mcp_client.PLAYGROUND_URL}\n\n{detail}"
        ui.unreachable(target, detail)
        ui.note("Carrying on without it. Everything else in the lesson still works.")

    mcp_execute = mcp_client.make_executor(transport, dispatch) if transport else None

    # --- assemble the toolbox ------------------------------------------------
    toolbox, execute = harness.build(
        session, agent, tools.TOOLS, mcp_tools=mcp_tools, mcp_execute=mcp_execute
    )

    # Rules + the skills catalogue. Note how little of the skills goes in: two
    # lines of description for two files of instructions, because the bodies
    # arrive only if the model asks. That is the same trade lesson 03 made you
    # pay for, spent deliberately this time.
    rules = session.read_prompt("system")
    catalogue = harness.skills_catalogue()

    chat = session.Session(
        tier="frontier",
        remember=True,
        system=(rules + "\n\n" + catalogue).strip(),
        tools=toolbox,
        max_tokens=3000,
        memory=True,  # memory.md joins the context. The only part that survives.
    )

    ui.banner("Lesson 05 — the harness", chat.model_id, chat.caps)
    ui.harness_summary(
        rules_file="prompts/system.md",
        skills=[name for name, _d, _b in harness.list_skills()],
        mcp=(
            f"{len(mcp_tools)} tools from "
            + (mcp_client.PLAYGROUND_URL if remote else "mcp_server_local.py (stdio)")
            if mcp_tools
            else "not connected"
        ),
        lsp=[t["name"] for t in harness.LSP_TOOLS],
        hooks=[h.__name__ for h in harness.HOOKS],
        subagents="delegate",
        memory=str(session.MEMORY_FILE.name),
        total_tools=len(toolbox),
    )

    ui.note("Task 1, MCP: check flask 2.0.1 against the advisory service.")
    ui.note("Task 2, skills: ask for a formal report and watch load_skill fire.")
    ui.note("Task 3, the LSP: ask what functions are defined in harness.py.")
    ui.note("Task 4, subagents: paste the audit prompt from the page, then read the token counts.")
    ui.note("Task 5, hooks: ask it to read sandbox/.env. The hook refuses, and asks nobody.")
    ui.note(f"Task 5 again: read {harness.AUDIT_LOG.name}. Every call is there, the subagent's too.")
    ui.note("Task 6, memory: /remember <something>, then quit and start again.")

    def on_message(chat_session, line):
        ui.final(agent.run(chat_session, line, auto=auto, execute=execute, hooks=harness.HOOKS))

    try:
        session.chat(chat, on_message=on_message)
    finally:
        if transport:
            transport.close()
        # Printed on the way out rather than at startup. By the time the room has
        # worked through six tasks, anything printed before the chatbox has
        # scrolled off the screen, and this panel is the one thing here that must
        # be seen.
        ui.control_probe(prove_the_controls())
        ui.note("The harness is gone. memory.md and audit.log are not. That was the point.")


if __name__ == "__main__":
    main()
