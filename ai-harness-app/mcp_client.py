"""The MCP client. Two transports, one protocol, no magic.

MCP is how a harness gets tools it did not write. Lessons 04 and 05 used
`tools.py`, where we authored both the schema and the function. Here the schema
and the function both live somewhere else, and all we do is relay.

    stdio             we spawn a process and talk newline-delimited JSON to it
    streamable-http   we POST JSON-RPC to a URL and read JSON or SSE back

`mcp_server_local.py` in this repo speaks the first one. The workshop's remote
target speaks the second:

    https://mcpplaygroundonline.com/mcp-stateless-server?rev=2026-07-28

That server is the "Stateless 2026-07-28" playground: multi round-trip requests
and signed requestState. Stateless means the server keeps nothing between calls
-- so anything it needs to remember mid-operation comes back to us in a
`requestState` blob that we must echo on the follow-up request. We do echo it,
verbatim, and we verify NOTHING about the signature: that signature is for the
server to check when we hand it back, so the server can trust its own state
without storing it. Say that out loud in the lesson, because the shape of the
trust is the interesting part -- the server protects itself from us, and nothing
in the protocol protects us from the server.

TWO THINGS THIS FILE IS HONEST ABOUT

  1. The remote path could not be exercised from the network this workshop was
     written on: the corporate proxy returns "Web Page Blocked" for that
     hostname. That is not a bug to route around. An unauthenticated MCP server
     on the public internet, handed live tool schemas and live tool output for an
     agent that can read your repo, is exactly what egress filtering exists to
     stop. Expect the block in the room, and treat it as the finding it is.
     Lesson 05 therefore defaults to stdio and treats HTTP as the optional beat.

  2. No authentication is implemented here, because that server needs none. A
     real MCP server does, and the version of this question you will be asked by
     a customer is "who is the agent, and who said it could call that?" -- which
     is Idira Identity for the token and the AI Agent Identity Broker for the gateway
     that mints and audits it. See lab/reference/securing-agentic-ai.html.
"""

import json
import os
import subprocess
import sys

PROTOCOL_VERSION = "2026-07-28"
PLAYGROUND_URL = "https://mcpplaygroundonline.com/mcp-stateless-server?rev=2026-07-28"

# Prefix every MCP tool so a name collision with tools.py is impossible and so
# the room can see, in the ⚙ lines, which calls left the building.
PREFIX = "mcp__"


class MCPError(RuntimeError):
    pass


class _Transport:
    """Shared JSON-RPC plumbing: an id counter, and the two-call handshake."""

    def __init__(self):
        self._next_id = 0
        self.server_info = {}

    def _id(self):
        self._next_id += 1
        return self._next_id

    def _send(self, payload, expect_reply=True):
        raise NotImplementedError

    def initialize(self):
        result, _state = self.request(
            "initialize",
            {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {},
                "clientInfo": {"name": "idira-workshop-harness", "version": "1.0.0"},
            },
        )
        self.server_info = result.get("serverInfo", {})
        # The spec requires this notification before any other request. It has no
        # id and gets no answer, which is why _send takes expect_reply.
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"}, expect_reply=False)
        return result

    def request(self, method, params=None, request_state=None):
        payload = {"jsonrpc": "2.0", "id": self._id(), "method": method}
        if params is not None:
            payload["params"] = params
        if request_state is not None:
            # The 2026-07-28 round-trip: hand the server its own signed state
            # back so a stateless process can resume an operation it forgot.
            payload["requestState"] = request_state
        reply = self._send(payload)
        if reply is None:
            raise MCPError(f"No reply to {method}.")
        if "error" in reply:
            error = reply["error"]
            raise MCPError(f"{method} failed: {error.get('code')} {error.get('message')}")
        return reply.get("result", {}), reply.get("requestState")

    # --- what the harness actually uses ---------------------------------------

    def list_tools(self):
        result, _state = self.request("tools/list")
        return result.get("tools", [])

    def call_tool(self, name, arguments, max_round_trips=4):
        """Call one tool, following as many round trips as the server asks for.

        A stateless server may answer a call with "not finished, ask me again and
        include this state". We loop rather than recurse so the cap is obvious:
        an unbounded round-trip is a denial-of-service the server can inflict on
        us, and nothing in the protocol stops it.
        """
        state = None
        for _hop in range(max_round_trips):
            result, state = self.request(
                "tools/call", {"name": name, "arguments": arguments}, request_state=state
            )
            text = _result_text(result)
            # An incomplete result plus a state to echo means "call me again".
            if state and not result.get("content"):
                continue
            if result.get("isError"):
                return f"The MCP tool reported an error: {text}"
            return text
        return f"Gave up after {max_round_trips} round trips to '{name}'."

    def close(self):
        pass


class StdioTransport(_Transport):
    """Spawn a server process and talk to its stdin/stdout. The offline path."""

    def __init__(self, command):
        super().__init__()
        self.process = subprocess.Popen(  # noqa: S603 - command is ours, not the model's
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )

    def _send(self, payload, expect_reply=True):
        self.process.stdin.write(json.dumps(payload) + "\n")
        self.process.stdin.flush()
        if not expect_reply:
            return None
        line = self.process.stdout.readline()
        if not line:
            raise MCPError("The MCP server closed its output. Is it still running?")
        return json.loads(line)

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.close()
            self.process.terminate()


class HttpTransport(_Transport):
    """POST JSON-RPC to a URL. Handles both a JSON reply and an SSE stream.

    Uses httpx, which arrives with the anthropic SDK -- no extra install for a
    lesson that most rooms will not be able to reach anyway.
    """

    def __init__(self, url, timeout=30.0):
        super().__init__()
        import config

        self.url = url
        self.session_id = None
        # Same transport as every model call in Part 1, which means certificate
        # verification is OFF here too. Read the note at the top of config.py --
        # this connection carries tool results back into the agent's context, so
        # it is the one where unverified TLS should bother you most.
        self.client = config.insecure_http_client(timeout=timeout)

    def _send(self, payload, expect_reply=True):
        headers = {
            "Content-Type": "application/json",
            # Both, because the server chooses which one to answer with.
            "Accept": "application/json, text/event-stream",
            "MCP-Protocol-Version": PROTOCOL_VERSION,
        }
        if self.session_id:
            headers["Mcp-Session-Id"] = self.session_id

        response = self.client.post(self.url, json=payload, headers=headers)
        # A stateless server should not issue one, but honour it if it does.
        self.session_id = response.headers.get("Mcp-Session-Id", self.session_id)

        if response.status_code == 202 or not expect_reply:
            return None
        if response.status_code >= 400:
            snippet = " ".join(response.text.split())[:200]
            raise MCPError(f"HTTP {response.status_code} from the MCP server: {snippet}")

        if "text/event-stream" in response.headers.get("Content-Type", ""):
            return _first_sse_message(response.text)
        return response.json()

    def close(self):
        self.client.close()


def _first_sse_message(body):
    """Pull the first JSON payload out of an SSE response body."""
    for line in body.splitlines():
        if line.startswith("data:"):
            chunk = line[5:].strip()
            if chunk:
                return json.loads(chunk)
    raise MCPError("The event stream contained no data.")


def _result_text(result):
    """Flatten an MCP result's content blocks into the string the model will read."""
    parts = []
    for block in result.get("content") or []:
        if block.get("type") == "text":
            parts.append(block.get("text", ""))
        else:
            parts.append(f"<{block.get('type')} block, not rendered>")
    return "\n".join(p for p in parts if p).strip()


# --- connecting, and turning their schemas into ours -------------------------


def connect(remote=False, url=None):
    """Open one MCP connection. Returns (transport, anthropic_tools, dispatch).

    `anthropic_tools` is their schema, renamed into the shape our model expects:
    `inputSchema` becomes `input_schema` and the name gains a prefix. That is the
    whole of the adaptation, and it is worth noticing how little there is -- MCP
    and the tool-use API describe the same thing.
    """
    if remote or url:
        transport = HttpTransport(url or PLAYGROUND_URL)
    else:
        here = os.path.dirname(os.path.abspath(__file__))
        transport = StdioTransport(
            [sys.executable, os.path.join(here, "mcp_server_local.py")]
        )

    transport.initialize()
    remote_tools = transport.list_tools()

    anthropic_tools = []
    dispatch = {}
    for tool in remote_tools:
        name = PREFIX + tool["name"]
        anthropic_tools.append(
            {
                "name": name,
                # Their words, verbatim, straight into our model's context. A
                # hostile server writes its description to influence the model,
                # and we have just relayed it without reading it.
                "description": tool.get("description", ""),
                "input_schema": tool.get("inputSchema") or {"type": "object", "properties": {}},
            }
        )
        dispatch[name] = tool["name"]

    return transport, anthropic_tools, dispatch


def make_executor(transport, dispatch):
    """A function the agent loop can call for any mcp__ tool."""

    def execute(name, tool_input):
        try:
            return transport.call_tool(dispatch[name], tool_input or {})
        except MCPError as error:
            return f"Refused: the MCP server call failed. {error}"

    return execute
