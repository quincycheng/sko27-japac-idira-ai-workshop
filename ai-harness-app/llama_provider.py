"""A tiny adapter so a local llama.cpp model looks exactly like the Anthropic client.

This runs the model IN-PROCESS via `llama-cpp-python` (the `llama_cpp.Llama`
class) -- no separate server to start. `create_chat_completion` speaks the
OpenAI chat format, which differs from Anthropic's in two ways this demo cares
about:

  * messages: OpenAI uses flat strings + a separate `tool_calls` array + `tool`
    role messages; Anthropic uses typed content blocks (text / tool_use /
    tool_result) inside user/assistant turns.
  * tools: OpenAI wraps schemas as {"type":"function","function":{...}};
    Anthropic uses {"name","description","input_schema"}.

This module translates in both directions and returns response objects shaped
like Anthropic responses (`.content` blocks, `.stop_reason`, `.usage.input_tokens`).
The whole point of the talk lands here: the LOOP never changes. Only the thing
behind `client` does -- Claude on Vertex, Gemini, or a GGUF model on your laptop.

The `llama_cpp` import is deferred to construction time (loading a model is
expensive), so importing this module costs nothing unless you select the
llama provider.
"""

import json
from types import SimpleNamespace

_STOP_REASON = {"stop": "end_turn", "tool_calls": "tool_use", "length": "max_tokens"}


def _btype(block) -> str:
    return block["type"] if isinstance(block, dict) else getattr(block, "type", "")


def _bget(block, key, default=None):
    if isinstance(block, dict):
        return block.get(key, default)
    return getattr(block, key, default)


def _to_openai_tools(tools):
    out = []
    for t in tools or []:
        out.append(
            {
                "type": "function",
                "function": {
                    "name": t["name"],
                    "description": t.get("description", ""),
                    "parameters": t.get("input_schema", {"type": "object", "properties": {}}),
                },
            }
        )
    return out


def _to_openai_messages(system, messages):
    """Anthropic-style (system + typed blocks) -> OpenAI chat messages."""
    out = []
    if system:
        out.append({"role": "system", "content": system})

    for m in messages:
        role, content = m["role"], m["content"]

        # Plain string turn (e.g. the initial user task).
        if isinstance(content, str):
            out.append({"role": role, "content": content})
            continue

        # Assistant turn: fold text blocks into content, tool_use -> tool_calls.
        if role == "assistant":
            text_parts, tool_calls = [], []
            for b in content:
                if _btype(b) == "text":
                    text_parts.append(_bget(b, "text", ""))
                elif _btype(b) == "tool_use":
                    tool_calls.append(
                        {
                            "id": _bget(b, "id"),
                            "type": "function",
                            "function": {
                                "name": _bget(b, "name"),
                                "arguments": json.dumps(_bget(b, "input") or {}),
                            },
                        }
                    )
            msg = {"role": "assistant", "content": "\n".join(text_parts) or None}
            if tool_calls:
                msg["tool_calls"] = tool_calls
            out.append(msg)
            continue

        # User turn carrying tool_result blocks -> one OpenAI `tool` message each.
        for b in content:
            if _btype(b) == "tool_result":
                out.append(
                    {
                        "role": "tool",
                        "tool_call_id": _bget(b, "tool_use_id"),
                        "content": _bget(b, "content", ""),
                    }
                )
            elif _btype(b) == "text":
                out.append({"role": "user", "content": _bget(b, "text", "")})
    return out


class _Messages:
    def __init__(self, client: "LlamaClient"):
        self._client = client
        self._counter = 0

    def create(self, model, max_tokens, messages, system=None, tools=None, **_ignored):
        kwargs = {
            "messages": _to_openai_messages(system, messages),
            "max_tokens": max_tokens,
            "temperature": self._client.temperature,
        }
        if tools:
            kwargs["tools"] = _to_openai_tools(tools)
            kwargs["tool_choice"] = "auto"

        # model is ignored: llama.cpp serves whatever weights were loaded.
        data = self._client._llm.create_chat_completion(**kwargs)
        return self._to_anthropic_response(data)

    def _to_anthropic_response(self, data) -> SimpleNamespace:
        choice = data["choices"][0]
        msg = choice.get("message", {})
        blocks = []

        if msg.get("content"):
            blocks.append(SimpleNamespace(type="text", text=msg["content"]))

        for tc in msg.get("tool_calls") or []:
            fn = tc.get("function", {})
            raw_args = fn.get("arguments", "{}")
            try:
                parsed = raw_args if isinstance(raw_args, dict) else json.loads(raw_args or "{}")
            except (json.JSONDecodeError, TypeError):
                parsed = {}
            tool_id = tc.get("id")
            if not tool_id:
                self._counter += 1
                tool_id = f"call_{self._counter}"
            blocks.append(
                SimpleNamespace(type="tool_use", id=tool_id, name=fn.get("name"), input=parsed)
            )

        stop_reason = _STOP_REASON.get(choice.get("finish_reason"), "end_turn")
        if any(b.type == "tool_use" for b in blocks):
            stop_reason = "tool_use"  # normalize: some templates say "stop" alongside tool_calls

        usage = data.get("usage") or {}
        return SimpleNamespace(
            content=blocks,
            stop_reason=stop_reason,
            usage=SimpleNamespace(
                input_tokens=usage.get("prompt_tokens", 0),
                output_tokens=usage.get("completion_tokens", 0),
            ),
        )


class LlamaClient:
    """Drop-in stand-in for AnthropicVertex, backed by an in-process GGUF model."""

    def __init__(
        self,
        model_path,
        n_ctx=8192,
        n_gpu_layers=-1,
        chat_format=None,
        temperature=0.2,
        verbose=False,
    ):
        try:
            from llama_cpp import Llama
        except ImportError:
            raise SystemExit(
                "The 'llama-cpp-python' package is required for the llama provider.\n"
                "Install it with: pip install llama-cpp-python"
            ) from None
        # n_gpu_layers=-1 offloads everything it can (Metal on Mac, CUDA on a GPU
        # build); it's harmlessly ignored on a CPU-only build. chat_format=None
        # uses the template baked into the GGUF; override it (e.g.
        # "chatml-function-calling") if a model needs help with tool calls.
        self._llm = Llama(
            model_path=model_path,
            n_ctx=n_ctx,
            n_gpu_layers=n_gpu_layers,
            chat_format=chat_format,
            verbose=verbose,
        )
        self.temperature = temperature
        self.messages = _Messages(self)
