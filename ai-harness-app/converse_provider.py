"""Adapter: any non-Anthropic Bedrock model, made to look like the Anthropic client.

Why this file exists at all: the legacy tier in config.py is
`meta.llama3-8b-instruct-v1:0`, and the `anthropic` SDK only speaks to Anthropic
models. Everything else on Bedrock -- Llama, Mistral, Nova, Titan -- is reached
through boto3's **Converse** API, which is Bedrock's one-shape-fits-all interface.

Same job as gemini_provider.py: translate both directions so the lessons never
see the difference in FORMAT. What it deliberately does NOT do is paper over the
difference in CAPABILITY. The legacy model has:

  * no tool support     -> passing `tools` raises, loudly, here
  * an 8,192-token context window, which it enforces exactly

Those two facts are the entire reason the legacy tier is worth having, so hiding
them would defeat the point. config.py declares them in the capability record,
the harness reads that record, and the guardrail below exists to catch the case
where someone edits a lesson and forgets. A confusing 400 from AWS is a worse
lesson than an exception that says what the model cannot do.

Converse maps onto the Anthropic shape almost exactly, which is the interesting
part for a security audience: "the model is a replaceable part" is *true at the
wire level*, and that is precisely why your controls cannot live inside it.

    Anthropic                       Converse
    ---------------------------     ------------------------------------
    messages=[{role, content}]      messages=[{role, content:[{text}]}]
    max_tokens=N                    inferenceConfig={maxTokens: N}
    response.content[].text         output.message.content[].text
    response.stop_reason            stopReason  (same vocabulary)
    response.usage.input_tokens     usage.inputTokens
"""

from types import SimpleNamespace

# Converse stop reasons happen to use the same words as Anthropic's, with two
# extras that only Bedrock produces. Mapped explicitly rather than passed through
# so that a new value shows up as itself instead of silently reading as end_turn.
_STOP_REASON = {
    "end_turn": "end_turn",
    "max_tokens": "max_tokens",
    "stop_sequence": "stop_sequence",
    "tool_use": "tool_use",
    "content_filtered": "content_filtered",
    "guardrail_intervened": "guardrail_intervened",
}

# Bedrock's own words for "you sent more tokens than this model can hold". We
# translate it into the wall the lesson is about, rather than a stack trace.
_TOO_LONG = ("too long", "too many tokens", "maximum context", "input is too long")


class ContextWindowExceeded(Exception):
    """The request did not fit in the model's context window.

    A named exception rather than a raw ClientError because in lesson 03 this is
    not an error -- it is the point. The session layer catches it and explains it.
    """


def _flatten(content) -> str:
    """Anthropic content (str or block list) -> the plain text Converse wants.

    Only text blocks can survive here, because a model with no tool support can
    never have produced a tool_use block and can never be sent a tool_result.
    Anything else in the transcript is a bug upstream, so it is dropped rather
    than half-translated into something the model would misread as content.
    """
    if isinstance(content, str):
        return content
    parts = []
    for block in content or []:
        btype = block["type"] if isinstance(block, dict) else getattr(block, "type", "")
        if btype == "text":
            text = block["text"] if isinstance(block, dict) else getattr(block, "text", "")
            if text:
                parts.append(text)
    return "\n".join(parts)


def _to_converse_messages(messages) -> list:
    """Anthropic messages -> Converse messages, merging same-role neighbours.

    Converse requires strictly alternating user/assistant turns. Our transcripts
    can legitimately hold two user messages in a row, so adjacent same-role turns
    are joined instead of being rejected by the API.
    """
    out = []
    for message in messages:
        role = "assistant" if message["role"] == "assistant" else "user"
        text = _flatten(message["content"])
        if not text:
            continue
        if out and out[-1]["role"] == role:
            out[-1]["content"][0]["text"] += "\n\n" + text
        else:
            out.append({"role": role, "content": [{"text": text}]})
    return out


class _Messages:
    def __init__(self, client: "ConverseClient"):
        self._client = client

    def create(self, model, max_tokens, messages, system=None, tools=None, **_ignored):
        if tools:
            raise ValueError(
                f"{model} has no tool support, and this adapter does not translate "
                "tool schemas into Converse's toolConfig. The harness is supposed "
                "to read caps.tools before offering a toolbox -- that check is the "
                "lesson, so do not work around it here."
            )

        kwargs = {
            "modelId": model,
            "messages": _to_converse_messages(messages),
            "inferenceConfig": {"maxTokens": max_tokens, "temperature": 0.2},
        }
        # A system prompt is passed straight through when we are given one. Some
        # Converse models take it and some refuse it -- Mistral 7B refuses, Llama 3
        # accepts -- and which is which belongs in config.py's capability record,
        # not in an adapter that is only supposed to change shapes.
        if system:
            kwargs["system"] = [{"text": system}]

        try:
            response = self._client._sdk.converse(**kwargs)
        except Exception as error:  # noqa: BLE001 - re-raised, narrowed below
            text = str(error).lower()
            if any(marker in text for marker in _TOO_LONG):
                raise ContextWindowExceeded(str(error)) from None
            if "doesn't support system" in text:
                raise ValueError(
                    f"{model} has no system role, but config.py says it does. Set "
                    "system=False in its capability record and the harness will "
                    "prepend the instructions into the first user message instead "
                    "(see session.py._payload)."
                ) from None
            raise

        message = response.get("output", {}).get("message", {})
        blocks = [
            SimpleNamespace(type="text", text=part["text"])
            for part in message.get("content", [])
            if part.get("text")
        ]
        usage = response.get("usage", {})
        return SimpleNamespace(
            content=blocks,
            stop_reason=_STOP_REASON.get(
                response.get("stopReason", "end_turn"), response.get("stopReason")
            ),
            usage=SimpleNamespace(
                input_tokens=usage.get("inputTokens", 0),
                output_tokens=usage.get("outputTokens", 0),
            ),
        )


class ConverseClient:
    """Drop-in stand-in for AnthropicBedrock, backed by boto3 Converse.

    Reads the same temporary AWS_* credentials from the environment as everything
    else in this workshop -- boto3 finds them itself, so there is no second
    credential and no extra login.
    """

    def __init__(self, region):
        try:
            import boto3
        except ImportError:
            raise SystemExit(
                "boto3 is required for the legacy model.\n"
                "Install it with: python -m pip install -r requirements.txt"
            ) from None
        # verify=False, and the warning it would otherwise print on every request
        # is silenced in config. Both facts, and the reason for them, are written
        # out in full at the top of config.py.
        import config

        config._hush_tls_warnings()
        self._sdk = boto3.client("bedrock-runtime", region_name=region, verify=False)
        self.messages = _Messages(self)
