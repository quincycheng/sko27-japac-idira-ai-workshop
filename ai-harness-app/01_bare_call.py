"""LESSON 01 — One call to a model. It cannot remember, and it cannot act.

This is the atom. No loop, no tools, no memory. You send messages, you get one
response back. Everything else in Part 1 is scaffolding around THIS.

Two things are switched off on purpose, and both matter:

    remember=False   -> we do not re-send the conversation, so every message you
                        type arrives at a model that has never heard of you
    tier="legacy"    -> Llama 3 8B: no tool support, and an 8,192-token window

Ask it something, then ask a follow-up that depends on your first message. Watch
it fail. Then look at the numbers at the bottom -- they are tiny, because almost
nothing is being sent. Hold on to that; by lesson 03 they will not be.

Read the panel titles. They say `llama3-8b-instruct`, not `Claude`, because that
is who is answering. Part 1 is about knowing exactly what is in your context and
exactly who is reading it, and that starts with not letting the UI flatter you.

Run it:
    python 01_bare_call.py
"""

import session
import ui

QUESTION = "In two sentences, what is an 'agentic harness'?"

# What to type next, printed for the room so sixty people ask the same thing.
FOLLOW_UP = "Now say that again, but shorter."


def main() -> None:
    # A Session with everything turned off is just a model call with a footer.
    chat = session.Session(tier="legacy", remember=False, max_tokens=400)

    ui.banner("Lesson 01 — one call to a model", chat.model_id, chat.caps)
    ui.task(QUESTION)

    # The one line that is the whole of "AI": messages in, one response out.
    # `send` prints the answer, then prints the footer. Nothing else happens.
    chat.send(QUESTION)

    ui.note(f'Now try a follow-up. Type: "{FOLLOW_UP}"')
    ui.note("It has no idea what 'that' refers to. There is nothing to refer to.")

    # The chatbox. Same call, over and over, each one starting from nothing.
    session.chat(chat)

if __name__ == "__main__":
    main()