"""LESSON 02 — The loop. This is the harness.

A model can't *do* anything. It can only produce text and, when you give it
tools, ask to call them. The "harness" is the loop that:

    1. sends the conversation + tool definitions to the model
    2. if the model asks to use a tool -> run it, feed the result back
    3. repeat until the model stops asking

That's it. That loop is the entire difference between "a chatbot" and "an agent".
This file is deliberately self-contained (one inline tool) so you can see every
moving part. Lesson 03 swaps in a real toolbox.

Run it:
    python 02_single_tool.py
"""

import ui
from config import MODEL, PROVIDER, client
from tools import search_code  # reuse the sandboxed implementation

# One tool. One schema. That's all the model knows exists.
TOOLS = [
    {
        "name": "search_code",
        "description": "Regex-search the repo. Returns matching 'file:line: text' rows.",
        "input_schema": {
            "type": "object",
            "properties": {
                "pattern": {"type": "string", "description": "A Python regular expression."}
            },
            "required": ["pattern"],
        },
    }
]

TASK = "Search this repo for any hardcoded secrets or API keys. Report what you find."


def run_agent(task: str) -> None:
    # The conversation is just a list of messages. We keep appending to it.
    messages = [{"role": "user", "content": task}]

    while True:
        with ui.thinking():
            response = client.messages.create(
                model=MODEL,
                max_tokens=2048,
                tools=TOOLS,
                messages=messages,
            )

        # Show the model's narration for this turn.
        for block in response.content:
            if block.type == "text":
                ui.plain(block.text)

        # No tool requested -> the model is done talking. Exit the loop.
        if response.stop_reason != "tool_use":
            break

        # CRITICAL: append the model's ENTIRE turn, including tool_use blocks.
        # If you drop them, the tool_result you send next won't have anything
        # to attach to and the API will reject the request.
        messages.append({"role": "assistant", "content": response.content})

        # Run every tool the model asked for this turn, collect the results.
        tool_results = []
        for block in response.content:
            if block.type == "tool_use":
                pattern = block.input.get("pattern")
                ui.tool("search_code", {"pattern": pattern})
                # The model occasionally emits a tool call with missing/empty
                # args. Validate before calling so a bad request comes back as a
                # normal tool_result the model can recover from -- never a crash.
                if not pattern:
                    output = "error: 'pattern' is required and must be non-empty."
                else:
                    output = search_code(**block.input)
                tool_results.append(
                    {
                        "type": "tool_result",
                        "tool_use_id": block.id,  # must match the tool_use id
                        "content": output,
                    }
                )

        # Tool results go back as a single user message. Loop again.
        messages.append({"role": "user", "content": tool_results})


if __name__ == "__main__":
    ui.banner("Lesson 02 — the loop", PROVIDER, MODEL)
    ui.task(TASK)
    run_agent(TASK)
