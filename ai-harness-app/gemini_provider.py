"""Adapter: Gemini on Vertex AI (Express mode) via the native `google-genai`
SDK, made to look exactly like the Anthropic client.

The client is constructed with `genai.Client(vertexai=True, api_key=...)`, which
routes to the Vertex AI backend (aiplatform.googleapis.com). Note that a plain
`genai.Client(api_key=...)` instead targets the Gemini Developer API / AI Studio
(generativelanguage.googleapis.com) -- a DIFFERENT endpoint. An API key is
minted for one backend and rejected by the other, so the two are not
interchangeable.

Unlike the OpenAI-compatible shim we used before, this talks to Gemini in its
OWN format and translates both directions, so the harness (Lessons 01-4) never
learns the difference:

  * messages: Anthropic uses typed content blocks (text / tool_use /
    tool_result) inside user/assistant turns. Gemini uses `Content(role, parts)`
    where a part is a `text`, a `function_call`, or a `function_response`, and
    the assistant role is spelled "model".
  * tools: Anthropic uses {"name","description","input_schema"}. Gemini uses
    `Tool(function_declarations=[FunctionDeclaration(name, description,
    parameters=<Schema>)])`, where Schema types are UPPERCASE ("OBJECT",
    "STRING", ...).

Everything here returns objects shaped like Anthropic responses
(`.content` blocks, `.stop_reason`, `.usage.input_tokens`).

The `google-genai` import is deferred to construction time, so importing this
module costs nothing unless you actually select the Gemini provider.
"""

from types import SimpleNamespace

# Gemini finish reasons -> Anthropic stop reasons. tool_use is inferred from the
# presence of a function_call part, so it isn't in this map.
_FINISH_REASON = {"STOP": "end_turn", "MAX_TOKENS": "max_tokens"}

# JSON-schema type names -> Gemini Schema type enum names (which are uppercase).
_TYPE_MAP = {
    "object": "OBJECT",
    "array": "ARRAY",
    "string": "STRING",
    "integer": "INTEGER",
    "number": "NUMBER",
    "boolean": "BOOLEAN",
}


def _btype(block) -> str:
    return block["type"] if isinstance(block, dict) else getattr(block, "type", "")


def _bget(block, key, default=None):
    if isinstance(block, dict):
        return block.get(key, default)
    return getattr(block, key, default)


def _to_genai_schema(js):
    """Our JSON-schema dict -> a genai `types.Schema` (recursively)."""
    from google.genai import types

    if not isinstance(js, dict):
        return None
    kind = _TYPE_MAP.get(js.get("type", "object"), "STRING")
    schema = types.Schema(type=kind)
    if js.get("description"):
        schema.description = js["description"]
    if js.get("enum"):
        schema.enum = [str(e) for e in js["enum"]]
    if kind == "OBJECT":
        props = js.get("properties") or {}
        schema.properties = {k: _to_genai_schema(v) for k, v in props.items()}
        if js.get("required"):
            schema.required = list(js["required"])
    if kind == "ARRAY" and "items" in js:
        schema.items = _to_genai_schema(js["items"])
    return schema


def _to_genai_tools(tools):
    """Anthropic tool schemas -> a single genai `Tool` with function declarations."""
    from google.genai import types

    decls = []
    for t in tools or []:
        decls.append(
            types.FunctionDeclaration(
                name=t["name"],
                description=t.get("description", ""),
                parameters=_to_genai_schema(
                    t.get("input_schema") or {"type": "object", "properties": {}}
                ),
            )
        )
    return [types.Tool(function_declarations=decls)] if decls else None


def _to_genai_contents(messages):
    """Anthropic-style messages -> a list of genai `Content` turns.

    Gemini identifies a tool response by the tool's NAME, but our tool_result
    blocks only carry the tool_use_id. We rebuild the id->name map from the
    assistant turns in the transcript (the full history is passed every call),
    then use it to label each function_response.
    """
    from google.genai import types

    id_to_name = {}
    for m in messages:
        content = m["content"]
        if m["role"] == "assistant" and isinstance(content, list):
            for b in content:
                if _btype(b) == "tool_use":
                    id_to_name[_bget(b, "id")] = _bget(b, "name")

    contents = []
    for m in messages:
        role, content = m["role"], m["content"]
        g_role = "model" if role == "assistant" else "user"

        # Plain string turn (e.g. the initial user task).
        if isinstance(content, str):
            contents.append(types.Content(role=g_role, parts=[types.Part(text=content)]))
            continue

        parts = []
        for b in content:
            bt = _btype(b)
            if bt == "text":
                text = _bget(b, "text", "")
                if text:
                    parts.append(types.Part(text=text))
            elif bt == "tool_use":
                part = types.Part(
                    function_call=types.FunctionCall(
                        name=_bget(b, "name"),
                        args=_bget(b, "input") or {},
                    )
                )
                # Gemini 3 requires the opaque thought_signature it emitted with
                # the function_call to be echoed back on the SAME part in the
                # history. Drop it and the API rejects the next turn with a 400.
                sig = _bget(b, "thought_signature")
                if sig is not None:
                    part.thought_signature = sig
                parts.append(part)
            elif bt == "tool_result":
                name = id_to_name.get(_bget(b, "tool_use_id"), "tool")
                out = _bget(b, "content", "")
                parts.append(
                    types.Part(
                        function_response=types.FunctionResponse(
                            name=name,
                            response={"result": out if isinstance(out, str) else str(out)},
                        )
                    )
                )
        if parts:
            contents.append(types.Content(role=g_role, parts=parts))
    return contents


class _Messages:
    def __init__(self, client: "GeminiClient"):
        self._client = client
        self._counter = 0

    def create(self, model, max_tokens, messages, system=None, tools=None, **_ignored):
        from google.genai import types

        config = types.GenerateContentConfig(
            temperature=self._client.temperature,
            max_output_tokens=max_tokens,
        )
        if system:
            config.system_instruction = system

        genai_tools = _to_genai_tools(tools)
        if genai_tools:
            config.tools = genai_tools
            # OUR loop runs the tools -- turn off the SDK's automatic calling so
            # it hands us the function_call instead of executing it itself.
            config.automatic_function_calling = types.AutomaticFunctionCallingConfig(
                disable=True
            )

        resp = self._client._sdk.models.generate_content(
            model=model,
            contents=_to_genai_contents(messages),
            config=config,
        )
        return self._to_anthropic_response(resp)

    def _to_anthropic_response(self, resp) -> SimpleNamespace:
        blocks = []
        stop_reason = "end_turn"

        candidates = getattr(resp, "candidates", None) or []
        if candidates:
            cand = candidates[0]
            fr = getattr(cand, "finish_reason", None)
            fr_name = getattr(fr, "name", None) or (str(fr) if fr else "STOP")
            stop_reason = _FINISH_REASON.get(fr_name, "end_turn")

            content = getattr(cand, "content", None)
            for p in (getattr(content, "parts", None) or []) if content else []:
                # Preserve the per-part thought_signature so we can hand it back
                # to Gemini on the next turn (see _to_genai_contents).
                sig = getattr(p, "thought_signature", None)
                if getattr(p, "text", None):
                    blocks.append(
                        SimpleNamespace(
                            type="text", text=p.text, thought_signature=sig
                        )
                    )
                fc = getattr(p, "function_call", None)
                if fc is not None:
                    self._counter += 1
                    tool_id = getattr(fc, "id", None) or f"call_{self._counter}"
                    blocks.append(
                        SimpleNamespace(
                            type="tool_use",
                            id=tool_id,
                            name=fc.name,
                            input=dict(getattr(fc, "args", None) or {}),
                            thought_signature=sig,
                        )
                    )

        if any(b.type == "tool_use" for b in blocks):
            stop_reason = "tool_use"

        um = getattr(resp, "usage_metadata", None)
        return SimpleNamespace(
            content=blocks,
            stop_reason=stop_reason,
            usage=SimpleNamespace(
                input_tokens=getattr(um, "prompt_token_count", 0) or 0,
                output_tokens=getattr(um, "candidates_token_count", 0) or 0,
            ),
        )


class GeminiClient:
    """Drop-in stand-in for AnthropicVertex, backed by the google-genai SDK."""

    def __init__(self, api_key, temperature=0.2):
        try:
            from google import genai
        except ImportError:
            raise SystemExit(
                "The 'google-genai' package is required for the Gemini provider.\n"
                "Install it with: pip install google-genai"
            ) from None
        # Certificate verification off, to match every other provider -- see the
        # TLS note at the top of config.py. Guarded because `client_args` is the
        # newer google-genai spelling and this provider is optional and untested
        # in the room: an SDK that does not accept it should still run the lesson.
        try:
            from google.genai import types

            self._sdk = genai.Client(
                vertexai=True,
                api_key=api_key,
                http_options=types.HttpOptions(client_args={"verify": False}),
            )
        except Exception:
            self._sdk = genai.Client(vertexai=True, api_key=api_key)
        self.temperature = temperature
        self.messages = _Messages(self)
