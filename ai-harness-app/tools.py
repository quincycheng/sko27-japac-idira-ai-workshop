"""The tools our agent can call.

A "tool" is two things that must stay in sync:
  1. A JSON schema  -> tells the model the tool exists and how to call it.
  2. A Python function -> what actually runs when the model asks for it.

The model never runs code. It only ever *asks* ("please call read_file with
path=...") and WE decide whether and how to honour that. That gap -- between the
model's request and our execution -- is where all safety lives. This matters to
a security audience: the model is untrusted input driving privileged actions.

Theme: a read-mostly triage agent that investigates a small code repo for
hardcoded secrets and obvious vulnerabilities. Everything is sandboxed to the
`sandbox/` directory so a wrong path can't escape onto your laptop.
"""

import os
import re
import subprocess

# Everything the agent touches is confined to this directory.
SANDBOX_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sandbox")


def _safe_path(path: str) -> str:
    """Resolve `path` inside the sandbox, or raise if it tries to escape.

    This one function is the entire security boundary for the filesystem tools.
    The model can send any string it wants; we refuse anything outside sandbox/.
    """
    full = os.path.realpath(os.path.join(SANDBOX_ROOT, path))
    if full != SANDBOX_ROOT and not full.startswith(SANDBOX_ROOT + os.sep):
        raise ValueError(f"Path '{path}' escapes the sandbox. Refused.")
    return full


# --- Tool implementations ---------------------------------------------------
# Each returns a plain string. That string becomes the tool_result the model
# sees on the next turn, so keep it readable -- the model reads it like a human.


def list_files(path: str = ".") -> str:
    root = _safe_path(path)
    if not os.path.isdir(root):
        return f"'{path}' is not a directory."
    lines = []
    for entry in sorted(os.listdir(root)):
        full = os.path.join(root, entry)
        marker = "/" if os.path.isdir(full) else ""
        lines.append(f"{entry}{marker}")
    return "\n".join(lines) or "(empty directory)"


def read_file(path: str) -> str:
    full = _safe_path(path)
    if not os.path.isfile(full):
        return f"'{path}' is not a file."
    with open(full, "r", errors="replace") as f:
        content = f.read()
    # Number the lines: makes the model's findings citable ("secret on line 12").
    numbered = [f"{i:>4} | {line}" for i, line in enumerate(content.splitlines(), 1)]
    return "\n".join(numbered) or "(empty file)"


def search_code(pattern: str, path: str = ".") -> str:
    """Regex-search files under `path`. The agent's main investigative tool."""
    root = _safe_path(path)
    try:
        regex = re.compile(pattern)
    except re.error as e:
        return f"Invalid regex: {e}"

    hits = []
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, SANDBOX_ROOT)
            try:
                with open(full, "r", errors="replace") as f:
                    for lineno, line in enumerate(f, 1):
                        if regex.search(line):
                            hits.append(f"{rel}:{lineno}: {line.rstrip()}")
            except OSError:
                continue
    if not hits:
        return f"No matches for /{pattern}/."
    return "\n".join(hits[:100])  # cap output so one tool call can't blow up context


# An allowlist: the ONLY shell commands we will run, no matter what the model asks.
# Demonstrates the request/execution gap concretely -- the model can ask for
# `rm -rf /`; it simply will not be in the dict, so it never runs.
_ALLOWED_COMMANDS = {
    "sbom": ["cat", "requirements.txt"],
    "whoami": ["whoami"],
}


def run_command(name: str) -> str:
    if name not in _ALLOWED_COMMANDS:
        return (
            f"Command '{name}' is not on the allowlist. "
            f"Allowed: {', '.join(_ALLOWED_COMMANDS)}."
        )
    result = subprocess.run(
        _ALLOWED_COMMANDS[name],
        cwd=SANDBOX_ROOT,
        capture_output=True,
        text=True,
        timeout=10,
    )
    return (result.stdout + result.stderr).strip() or "(no output)"


# --- The schemas the model sees ---------------------------------------------
TOOLS = [
    {
        "name": "list_files",
        "description": "List files and directories at a path inside the repo.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Directory path relative to repo root. Defaults to '.'.",
                }
            },
            "required": [],
        },
    },
    {
        "name": "read_file",
        "description": "Read a file's contents with line numbers.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "File path relative to repo root."}
            },
            "required": ["path"],
        },
    },
    {
        "name": "search_code",
        "description": (
            "Regex-search the repo. Use this to hunt for secrets, dangerous "
            "function calls, etc. Returns matching 'file:line: text' rows."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "pattern": {"type": "string", "description": "A Python regular expression."},
                "path": {
                    "type": "string",
                    "description": "Directory to search under. Defaults to '.'.",
                },
            },
            "required": ["pattern"],
        },
    },
    {
        "name": "run_command",
        "description": (
            "Run one of a small allowlist of read-only shell commands. "
            "Allowed names: 'sbom' (list dependencies), 'whoami'."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "description": "The allowlisted command name."}
            },
            "required": ["name"],
        },
    },
]

# Dispatch table: tool name -> implementation. The loop uses this to route a
# tool_use block to the right function.
TOOL_FUNCTIONS = {
    "list_files": list_files,
    "read_file": read_file,
    "search_code": search_code,
    "run_command": run_command,
}


def execute_tool(name: str, tool_input: dict) -> str:
    """Run one tool by name. Catch everything -- a tool that raises should hand
    the error back to the model as a normal result, not crash the harness."""
    func = TOOL_FUNCTIONS.get(name)
    if func is None:
        return f"Unknown tool: {name}"
    try:
        return func(**tool_input)
    except Exception as e:  # noqa: BLE001 - deliberately broad: never crash the loop
        return f"Tool '{name}' raised {type(e).__name__}: {e}"
