"""LESSON 02 — Conversation history, and what it costs.

One character changed from lesson 01: `remember=False` became `remember=True`.

That is the entire difference between "a model" and "a chatbot". The model did
not learn anything and has not changed. What changed is that the HARNESS now
keeps the transcript and re-sends all of it with every new message, so the model
appears to remember a conversation it is being told about from scratch each time.

Watch two things:

    1. The follow-up that failed in lesson 01 now works.
    2. `in=` on the footer climbs with every message, and never comes down.

The second one is the lesson. Re-sending the history is not free and it is not a
feature of the model -- it is a design decision, made by us, paid for per turn,
and it is why your agent gets slower and more expensive the longer you talk.

Run it:
    python 02_conversation.py
"""

import session
import ui

OPENER = "In two sentences, what is an 'agentic harness'?"
FOLLOW_UP = "Now say that again, but shorter."


def main() -> None:
    # Same model as lesson 01, same lack of tools. Only `remember` differs.
    chat = session.Session(tier="legacy", remember=True, max_tokens=400)

    ui.banner("Lesson 02 — conversation history", chat.model_id, chat.caps)
    ui.task(OPENER)
    chat.send(OPENER)

    # The exact follow-up that failed in lesson 01, run for you so the room sees
    # both outcomes within a minute of each other.
    ui.task(FOLLOW_UP)
    chat.send(FOLLOW_UP)

    ui.note("Same follow-up as lesson 01. This time it landed.")
    ui.note("Compare in= with lesson 01's. Then keep chatting and watch it climb.")
    ui.note("/context shows you exactly what is being re-sent every time.")

    session.chat(chat)


if __name__ == "__main__":
    main()
