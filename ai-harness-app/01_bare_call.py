"""LESSON 01 — The bare model call.

This is the atom. No loop, no tools, no memory. You send messages, you get
one response back. Everything else in this talk is scaffolding around THIS.

Run it:
    python 01_bare_call.py
"""

import ui
from config import MODEL, PROVIDER, client

QUESTION = "In two sentences, what is an 'agentic harness'?"


def main() -> None:
    ui.banner("Lesson 01 — the bare model call", PROVIDER, MODEL)
    ui.task(QUESTION)

    with ui.thinking():
        response = client.messages.create(
            model=MODEL,
            max_tokens=1024,
            messages=[{"role": "user", "content": QUESTION}],
        )

    # The response is a list of content blocks. For a plain answer it's one
    # text block, but it can also contain tool_use blocks (Lesson 02) or thinking
    # blocks. Always iterate and check the type -- don't assume content[0].text.
    for block in response.content:
        if block.type == "text":
            ui.plain(block.text)

    # This metadata is the raw material for context management later (Lesson 04).
    ui.usage(
        response.stop_reason,
        response.usage.input_tokens,
        response.usage.output_tokens,
    )


if __name__ == "__main__":
    main()
