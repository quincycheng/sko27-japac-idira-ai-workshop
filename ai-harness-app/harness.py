"""The other four harness parts: skills, an LSP, hooks, and subagents.

Lesson 05 assembles seven components. Three of them already exist in this repo
and you have been using them since lesson 03:

    rules      prompts/system.md          lesson 03 put it in the context
    MCP        mcp_client.py              tools somebody else wrote
    memory     memory.md, via Session     the one thing that survives a restart

This file holds the remaining four. Each is deliberately small, because the point
of lesson 05 is not that these are hard to build -- it is that Claude Code has
all seven, you have now seen what each one is, and none of them are magic.

The one that matters most for a security conversation is HOOKS, and it is the
least glamorous. Rules, skills and memory are all text in the context window: the
model reads them, and a model that reads an instruction can be argued out of it.
A hook is code in the loop. It runs whether the model likes it or
not. Of the seven components, hooks and the tool boundary are the only two that
are controls; the other five are configuration.
"""

import ast
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import ui

HERE = Path(__file__).resolve().parent
SKILLS_DIR = HERE / "skills"
SANDBOX = HERE / "sandbox"
AUDIT_LOG = HERE / "audit.log"


# =============================================================================
# 1. SKILLS -- a folder of instructions the agent can choose to read
# =============================================================================
#
# A skill is a directory with a SKILL.md in it. The harness shows the model only
# the NAME and DESCRIPTION of each one up front, and the body arrives only if the
# model asks for it. That is "progressive disclosure", and it is a context
# decision, not a cleverness decision: ten skills loaded eagerly is ten skills'
# worth of tokens on every turn, and lesson 03 taught you what that costs.
#
# Claude Code's skills are the same shape -- a folder, a markdown file, a
# description that gets read and a body that usually does not.


def list_skills():
    """Every skills/*/SKILL.md, as (name, description, body).

    Bodies come back with their HTML comments stripped, like every other markdown
    file this app sends. The notes in a SKILL.md explain the skill to a reader of
    the repo; the model does not need to be told why it is being given
    instructions.
    """
    from session import strip_comments

    found = []
    if not SKILLS_DIR.is_dir():
        return found
    for directory in sorted(p for p in SKILLS_DIR.iterdir() if p.is_dir()):
        path = directory / "SKILL.md"
        if not path.is_file():
            continue
        text = strip_comments(path.read_text())
        found.append((directory.name, _first_paragraph(text), text))
    return found


def _first_paragraph(text):
    """The description a skill advertises: its first non-heading line."""
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            return line
    return "(no description)"


SKILL_TOOL = {
    "name": "load_skill",
    "description": (
        "Load the full instructions for one of the available skills. Skills are "
        "listed by name in your instructions; load one when its description "
        "matches the task at hand."
    ),
    "input_schema": {
        "type": "object",
        "properties": {"name": {"type": "string", "description": "The skill's name."}},
        "required": ["name"],
    },
}


def skills_catalogue():
    """The one paragraph of context that makes skills discoverable."""
    skills = list_skills()
    if not skills:
        return ""
    lines = [f"  - {name}: {description}" for name, description, _body in skills]
    return (
        "Skills available to you. Each is a set of instructions you can load with "
        "the load_skill tool when it fits the task:\n" + "\n".join(lines)
    )


def load_skill(name=""):
    for skill_name, _description, body in list_skills():
        if skill_name == name.strip():
            return body
    available = ", ".join(n for n, _d, _b in list_skills()) or "none"
    return f"No skill named '{name}'. Available: {available}."


# =============================================================================
# 2. LSP -- the agent asks the code about itself instead of guessing
# =============================================================================
#
# A Language Server Protocol server is what your editor uses to know that
# `password_hash` is defined at utils.py:10 without reading every file. Give an
# agent the same thing and it stops burning a 400-line file to answer a
# one-line question. That is a CONTEXT saving, which by now you know is also a
# cost saving and a quality saving.
#
# HONEST LABEL: this is not a real LSP. A real one is a separate process speaking
# JSON-RPC -- much like the MCP server in this repo, which is why the two feel
# similar. Standing up pylsp needs an install we cannot ask sixty laptops for, so
# these two tools use Python's own `ast` module to answer the same two questions.
# The interface is the lesson; the implementation is a stand-in, and saying so is
# better than pretending.


LSP_TOOLS = [
    {
        "name": "outline_file",
        "description": (
            "List the functions, classes and imports in a Python file with their "
            "line numbers, without reading the whole file. Cheap: use this before "
            "read_file when you only need to know what is in there."
        ),
        "input_schema": {
            "type": "object",
            "properties": {"path": {"type": "string", "description": "Path inside the repo."}},
            "required": ["path"],
        },
    },
    {
        "name": "find_definition",
        "description": (
            "Find where a function or class is defined, by name, across the repo. "
            "Returns file:line."
        ),
        "input_schema": {
            "type": "object",
            "properties": {"symbol": {"type": "string", "description": "Function or class name."}},
            "required": ["symbol"],
        },
    },
]


def _python_files():
    for dirpath, _dirs, files in os.walk(SANDBOX):
        for name in files:
            if name.endswith(".py"):
                yield Path(dirpath) / name


def outline_file(path=""):
    from tools import _safe_path  # the same sandbox boundary, reused deliberately

    try:
        full = Path(_safe_path(path))
    except ValueError as error:
        return f"Refused: {error}"
    if not full.is_file():
        return f"'{path}' is not a file."
    try:
        tree = ast.parse(full.read_text(errors="replace"))
    except SyntaxError as error:
        return f"Could not parse {path}: {error}"

    lines = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            args = ", ".join(a.arg for a in node.args.args)
            lines.append(f"{node.lineno:>4} | def {node.name}({args})")
        elif isinstance(node, ast.ClassDef):
            lines.append(f"{node.lineno:>4} | class {node.name}")
        elif isinstance(node, (ast.Import, ast.ImportFrom)):
            names = ", ".join(a.name for a in node.names)
            lines.append(f"{node.lineno:>4} | import {names}")
    return "\n".join(sorted(lines)) or "(nothing defined in this file)"


def find_definition(symbol=""):
    hits = []
    for path in _python_files():
        try:
            tree = ast.parse(path.read_text(errors="replace"))
        except SyntaxError:
            continue
        for node in ast.walk(tree):
            named = isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
            if named and node.name == symbol.strip():
                rel = path.relative_to(SANDBOX)
                hits.append(f"{rel}:{node.lineno}")
    return "\n".join(hits) if hits else f"No definition of '{symbol}' found."


# =============================================================================
# 3. HOOKS -- code in the loop, which is why they are the only real control here
# =============================================================================
#
# A hook is a function the harness runs BEFORE (or after) a tool call, with the
# power to stop it. Claude Code calls the interesting one PreToolUse and lets it
# return a refusal. It is the same idea as `needs_approval` in tools.py, with one
# difference that matters at three in the morning: a hook does not ask anybody.
#
# Two are wired up in this lesson, and they are the two shapes you will be asked
# about by a customer:
#
#   deny_secret_reads   a policy hook. Deterministic, silent, unarguable. No
#                       prompt reaches it, so no prompt can talk it round. This
#                       is where "the agent must never touch production
#                       credentials" actually goes.
#   audit_every_call    an observability hook. Refuses nothing, records
#                       everything. When somebody asks "what did the agent do
#                       last Tuesday", this file is the only honest answer -- and
#                       notice that the model has no way to know it exists.
#
# A hook returns a string to BLOCK the call (the string becomes the tool result
# the model sees) or None to allow it.

SECRET_NAMES = (".env", "id_rsa", ".pem", "credentials")


def deny_secret_reads(name, tool_input):
    """Block any tool call whose path looks like a credential store."""
    path = str((tool_input or {}).get("path") or "").lower()
    if path and any(marker in path for marker in SECRET_NAMES):
        return (
            "Refused: blocked by a harness policy hook. Credential files are "
            "not readable by this agent, and no instruction in the conversation "
            "can change that."
        )
    return None


def audit_every_call(name, tool_input):
    """Append one line per tool call to audit.log. Never blocks."""
    entry = {
        "at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "tool": name,
        "input": tool_input,
    }
    with AUDIT_LOG.open("a") as handle:
        handle.write(json.dumps(entry) + "\n")
    return None


HOOKS = [audit_every_call, deny_secret_reads]


# =============================================================================
# 4. SUBAGENTS -- a second context window, so the first one stays clean
# =============================================================================
#
# The naive reason to want a subagent is "so it can do two things at once". The
# real reason is lesson 03: a fresh agent gets a fresh context window, does one
# noisy job in it -- reading six files, running four searches -- and hands back
# only its conclusion. The parent's window grows by a paragraph instead of by
# forty thousand tokens.
#
# This is also the honest answer to "how do I work on a big project without
# hitting the dumb zone", and it is the mechanism underneath the optional AFK
# lesson in Part 2: break the work into tickets, give each one its own window.
#
# Note what the subagent does NOT get: our conversation. It starts from nothing
# but the brief we write. That is a feature and a trap -- a badly written brief
# produces a confidently wrong answer, and the parent has no way to tell.

SUBAGENT_TOOL = {
    "name": "delegate",
    "description": (
        "Hand a self-contained investigation to a subagent with its own fresh "
        "context. It cannot see this conversation, so state everything it needs "
        "in the brief. It returns only its final answer, which keeps this "
        "conversation small. Use it for anything that means reading a lot to "
        "learn a little."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "brief": {
                "type": "string",
                "description": "The complete task, written for someone with no context.",
            }
        },
        "required": ["brief"],
    },
}


def delegate(session_module, agent_module, tool_list, auto=True, execute=None, hooks=()):
    """Build the `delegate` implementation, given the modules it needs.

    Takes them as arguments rather than importing them, because harness.py is
    imported BY the lesson that owns those modules and a circular import would be
    a silly way to lose ten minutes on stage.

    `execute` and `hooks` are handed straight to the child's loop, and passing the
    hooks is not optional in any sense that matters. A hook that guards the parent
    but not its subagents is not a control -- it is a control with a documented
    bypass, reachable by any model that can write the word "delegate". Read that
    sentence again with a customer's architecture in mind: this is exactly the hole
    that appears when a team adds subagents to a system whose policy enforcement
    was written for one agent.
    """

    def run_subagent(brief=""):
        ui.note("subagent starting — its own window, its own bill, no memory of us")
        child = session_module.Session(
            tier="frontier",
            remember=True,
            system=(
                "You are a focused sub-investigator. Do the single task you are "
                "given using the tools available, then answer in at most ten "
                "lines. Cite file:line. Do not ask questions -- you have no one "
                "to ask."
            ),
            tools=tool_list,
            max_tokens=1500,
        )
        # auto=True by default: a subagent cannot pause for a human, because the
        # human is watching the parent. Worth being uncomfortable about -- an
        # approval gate you delegated past is not an approval gate. In a real
        # deployment the subagent gets a SMALLER toolbox instead, which is why
        # the tool list is a parameter here.
        answer = agent_module.run(
            child, brief, auto=auto, execute=execute, hooks=hooks
        )
        ui.note(
            f"subagent finished: {child.total_input:,} in / {child.total_output:,} out, "
            "and none of it landed in your window"
        )
        return answer

    return run_subagent


# =============================================================================
# Assembly
# =============================================================================


def build(session_module, agent_module, base_tools, mcp_tools=None, mcp_execute=None):
    """Everything above, as one toolbox and one dispatch table.

    Returns (tools, execute) where `execute(name, input)` routes a call to
    whichever of the five sources owns it. The lesson passes `execute` to the
    agent loop, and the loop neither knows nor cares which tools are local, which
    are somebody else's server, and which are another agent entirely.
    """
    import tools as local_tools

    toolbox = list(base_tools) + LSP_TOOLS + [SKILL_TOOL, SUBAGENT_TOOL]
    toolbox += list(mcp_tools or [])

    # `handlers` is referenced inside execute() but assigned after it, which is
    # fine -- the name is looked up when the call happens, not when the function is
    # defined. The order is forced: the subagent needs `execute`, and `execute`
    # needs the subagent. Late binding is what unties the knot.
    def execute(name, tool_input):
        if name.startswith("mcp__") and mcp_execute:
            return mcp_execute(name, tool_input)
        handler = handlers.get(name)
        if handler is None:
            return local_tools.execute_tool(name, tool_input)
        try:
            return handler(**(tool_input or {}))
        except Exception as error:  # noqa: BLE001 - a tool must never crash the loop
            return f"Tool '{name}' raised {type(error).__name__}: {error}"

    # What the child gets, and what it does not. It inherits the file tools, the
    # LSP and the MCP server -- delegating a dependency review to an agent that
    # cannot reach the advisory feed would be delegating nothing. It does NOT get
    # SUBAGENT_TOOL, so it cannot spawn its own children: there is no depth limit
    # in this loop, and a model that can delegate recursively will eventually
    # discover that. It gets the same `execute` and the same HOOKS as its parent.
    child_tools = list(base_tools) + LSP_TOOLS + list(mcp_tools or [])
    run_subagent = delegate(
        session_module,
        agent_module,
        child_tools,
        execute=execute,
        hooks=HOOKS,
    )

    handlers = {
        "outline_file": outline_file,
        "find_definition": find_definition,
        "load_skill": load_skill,
        "delegate": run_subagent,
    }

    return toolbox, execute
