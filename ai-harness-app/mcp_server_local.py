"""A real MCP server, in eighty lines, speaking over stdin and stdout.

This exists so lesson 05 works on a locked-down laptop. It is not a mock: it
speaks the same JSON-RPC that a hosted MCP server speaks, over the stdio
transport instead of HTTP, and `mcp_client.py` cannot tell the difference.

Reading it is worth ninety seconds, because it demolishes the mystique. An MCP
server is a process that answers three questions:

    initialize   who are you, which protocol version
    tools/list   what can you do, and what arguments do you take
    tools/call   do it, here is the result as text

That is the protocol. Everything else in the specification is refinement. The
significant thing is what it means for a security review: the SCHEMAS and the
RESULTS both come from the server. When you connect an agent to someone else's
MCP server you are letting a third party inject both tool descriptions and tool
output straight into your model's context, and neither one is authenticated by
the protocol itself.

The tools here deliberately do something the local toolbox cannot: look up
vulnerability advisories for the dependencies in sandbox/requirements.txt. That
is the felt difference in lesson 05 -- the agent stops guessing about CVEs and
starts citing them, because it now has a service that knows.

Run standalone to poke at it by hand:
    echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | python mcp_server_local.py
"""

import json
import sys

PROTOCOL_VERSION = "2025-06-18"

# A tiny offline advisory feed. Real data, deliberately matched to
# sandbox/requirements.txt so the agent finds something on its first look.
ADVISORIES = {
    ("flask", "2.0.1"): [
        "CVE-2023-30861 (high): Flask may cache a response containing a session "
        "cookie and serve it to the wrong client when behind a caching proxy. "
        "Fixed in 2.2.5 / 2.3.2.",
    ],
    ("requests", "2.25.1"): [
        "CVE-2023-32681 (medium): Proxy-Authorization header leaked to the "
        "destination server on redirect. Fixed in 2.31.0.",
    ],
    ("pyyaml", "5.3.1"): [
        "CVE-2020-14343 (critical): yaml.full_load and the FullLoader still "
        "permit arbitrary code execution via crafted YAML. Fixed in 5.4. "
        "Use yaml.safe_load.",
    ],
}

TOOLS = [
    {
        "name": "advisory_lookup",
        "description": (
            "Look up known security advisories for one dependency. Returns CVE "
            "identifiers, severity and the version that fixes each issue."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "package": {"type": "string", "description": "Package name, e.g. 'flask'."},
                "version": {"type": "string", "description": "Pinned version, e.g. '2.0.1'."},
            },
            "required": ["package", "version"],
        },
    },
    {
        "name": "advisory_feed_status",
        "description": "Report how fresh this advisory feed is and what it covers.",
        "inputSchema": {"type": "object", "properties": {}, "required": []},
    },
]


def advisory_lookup(package="", version=""):
    key = (package.strip().lower(), version.strip())
    hits = ADVISORIES.get(key)
    if hits:
        return "\n".join(hits)
    return (
        f"No advisories on file for {package} {version}. "
        "This feed is a small offline snapshot, so absence is not assurance."
    )


def advisory_feed_status():
    covered = ", ".join(f"{name} {ver}" for name, ver in sorted(ADVISORIES))
    # Saying this out loud in the tool result is the point: the agent will repeat
    # it, and the room hears an external service telling the model how much to
    # trust it. A hostile server would say something more flattering.
    return (
        "Offline snapshot bundled with the workshop. Not updated, not "
        f"authoritative, and covering exactly: {covered}."
    )


HANDLERS = {"advisory_lookup": advisory_lookup, "advisory_feed_status": advisory_feed_status}


def handle(request):
    """One JSON-RPC request in, one response out (or None for notifications)."""
    method = request.get("method")
    request_id = request.get("id")

    # Notifications have no id and get no reply. `notifications/initialized` is
    # the client saying "understood"; there is nothing to answer.
    if request_id is None:
        return None

    if method == "initialize":
        return _ok(
            request_id,
            {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "idira-local-advisories", "version": "1.0.0"},
            },
        )
    if method == "ping":
        return _ok(request_id, {})
    if method == "tools/list":
        return _ok(request_id, {"tools": TOOLS})
    if method == "tools/call":
        params = request.get("params") or {}
        name = params.get("name")
        func = HANDLERS.get(name)
        if func is None:
            return _error(request_id, -32602, f"Unknown tool: {name}")
        try:
            text = func(**(params.get("arguments") or {}))
        except Exception as error:  # noqa: BLE001 - report, never die mid-session
            # MCP's own convention: a tool that fails returns a RESULT with
            # isError set, not a JSON-RPC error. The distinction matters -- the
            # model is supposed to read the failure and adapt.
            return _ok(
                request_id,
                {
                    "content": [{"type": "text", "text": f"{type(error).__name__}: {error}"}],
                    "isError": True,
                },
            )
        return _ok(request_id, {"content": [{"type": "text", "text": text}], "isError": False})

    return _error(request_id, -32601, f"Method not found: {method}")


def _ok(request_id, result):
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def _error(request_id, code, message):
    return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def main():
    # Newline-delimited JSON, one message per line, in both directions. That is
    # the entire stdio transport.
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            continue
        response = handle(request)
        if response is not None:
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
