"""STAGE 1 — The bare model call.

This is the atom. No loop, no tools, no memory. You send messages, you get
one response back. Everything else in this talk is scaffolding around THIS.

Run it:
    python 01_bare_call.py
"""

from config import MODEL, client


def main() -> None:
    response = client.messages.create(
        model=MODEL,
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": "In two sentences, what is an 'agentic harness'?",
            }
        ],
    )

    # The response is a list of content blocks. For a plain answer it's one
    # text block, but it can also contain tool_use blocks (Stage 2) or thinking
    # blocks. Always iterate and check the type -- don't assume content[0].text.
    for block in response.content:
        if block.type == "text":
            print(block.text)

    # This metadata is the raw material for context management later (Stage 4).
    print("\n---")
    print(f"stop_reason : {response.stop_reason}")
    print(f"input_tokens : {response.usage.input_tokens}")
    print(f"output_tokens: {response.usage.output_tokens}")


if __name__ == "__main__":
    main()
